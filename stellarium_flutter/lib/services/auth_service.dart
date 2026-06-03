import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../features/onboarding/onboarding_service.dart';

/// Service to manage Firebase authentication.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Current authenticated user (null if signed out).
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Whether a user is currently signed in.
  bool get isSignedIn => _auth.currentUser != null;

  /// Dump the current Firebase auth state to the console.
  void debugDumpState(String tag) {
    final u = _auth.currentUser;
    if (u == null) {
      debugPrint('[AUTH:$tag] no FirebaseAuth.currentUser');
      return;
    }
    final providers = u.providerData.map((p) => p.providerId).join(',');
    debugPrint(
      '[AUTH:$tag] uid=${u.uid} email=${u.email} '
      'anon=${u.isAnonymous} providers=[$providers]',
    );
  }

  // ---------------------------------------------------------------------------
  // Email & Password
  // ---------------------------------------------------------------------------

  /// Create a new account with email and password.
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    debugPrint('[AUTH:email] sign-up ${email.trim()}');
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    debugPrint('[AUTH:email] sign-up OK uid=${cred.user?.uid}');
    return cred;
  }

  /// Sign in with an existing email and password.
  Future<UserCredential> signInWithEmail(String email, String password) async {
    debugPrint('[AUTH:email] sign-in ${email.trim()}');
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    debugPrint('[AUTH:email] sign-in OK uid=${cred.user?.uid}');
    return cred;
  }

  /// Send a password reset email.
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ---------------------------------------------------------------------------
  // Google Sign-In
  // ---------------------------------------------------------------------------

  Future<UserCredential> signInWithGoogle() async {
    debugPrint('[AUTH:google] starting sign-in');
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      debugPrint('[AUTH:google] cancelled by user');
      throw FirebaseAuthException(
        code: 'sign-in-cancelled',
        message: 'Google sign-in was cancelled.',
      );
    }
    debugPrint('[AUTH:google] got google user: ${googleUser.email}');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final cred = await _auth.signInWithCredential(credential);
    debugPrint(
      '[AUTH:google] firebase sign-in OK '
      'uid=${cred.user?.uid} new=${cred.additionalUserInfo?.isNewUser}',
    );
    return cred;
  }

  // ---------------------------------------------------------------------------
  // Apple Sign-In
  // ---------------------------------------------------------------------------

  Future<UserCredential> signInWithApple() async {
    debugPrint('[AUTH:apple] starting sign-in');

    // Per Apple's docs: generate a cryptographically secure random nonce,
    // send its SHA256 hash to Apple, and pass the *raw* nonce to Firebase.
    // Firebase hashes its copy and compares against the nonce embedded in
    // the identityToken — protects against replay attacks.
    final rawNonce = _generateNonce();
    final hashedNonce = _sha256ofString(rawNonce);

    // Step 1: native Apple sign-in via AuthenticationServices (sign_in_with_apple)
    final AuthorizationCredentialAppleID appleCredential;
    try {
      appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      debugPrint('[AUTH:apple] apple SDK error: code=${e.code} ${e.message}');
      rethrow;
    }
    debugPrint(
      '[AUTH:apple] got apple credential '
      'userId=${appleCredential.userIdentifier} '
      'email=${appleCredential.email} '
      'hasIdToken=${appleCredential.identityToken != null} '
      'hasAuthCode=${appleCredential.authorizationCode.isNotEmpty}',
    );
    _debugDecodeJwt('apple', appleCredential.identityToken);

    final identityToken = appleCredential.identityToken;
    if (identityToken == null) {
      throw FirebaseAuthException(
        code: 'missing-apple-id-token',
        message: 'Apple did not return an identityToken.',
      );
    }

    // Step 2: build Firebase's Apple-specific credential from Apple's response.
    final oauthCredential = AppleAuthProvider.credentialWithIDToken(
      identityToken,
      rawNonce,
      AppleFullPersonName(
        givenName: appleCredential.givenName,
        familyName: appleCredential.familyName,
      ),
    );

    // Step 3: sign in to Firebase. Firebase verifies the JWT signature
    // against Apple's public keys and the nonce against rawNonce.
    final UserCredential userCredential;
    try {
      userCredential = await _auth.signInWithCredential(oauthCredential);
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[AUTH:apple] firebase REJECTED token: '
        'code=${e.code} message=${e.message}',
      );
      rethrow;
    }
    debugPrint(
      '[AUTH:apple] firebase sign-in OK '
      'uid=${userCredential.user?.uid} '
      'new=${userCredential.additionalUserInfo?.isNewUser}',
    );

    // Apple only returns givenName/familyName on the *first* sign-in for an
    // app+Apple-ID combo. Persist them on the Firebase user.
    final displayName = [
      appleCredential.givenName,
      appleCredential.familyName,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' ');

    if (displayName.isNotEmpty &&
        (userCredential.user?.displayName == null ||
            userCredential.user!.displayName!.isEmpty)) {
      await userCredential.user?.updateDisplayName(displayName);
    }

    return userCredential;
  }

  // ---------------------------------------------------------------------------
  // Sign Out
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    debugPrint('[AUTH:signOut] uid=${_auth.currentUser?.uid}');
    await GoogleSignIn().signOut();
    await _auth.signOut();
    await OnboardingService.resetSignInCompleted();
    debugPrint('[AUTH:signOut] done');
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Decode and log the payload of a JWT (no signature verification).
  /// Used to inspect what claims Apple actually issued in the identityToken.
  void _debugDecodeJwt(String tag, String? token) {
    if (token == null) return;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return;
      String payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decoded = utf8.decode(base64.decode(payload));
      debugPrint('[AUTH:$tag] identityToken payload: $decoded');
    } catch (e) {
      debugPrint('[AUTH:$tag] failed to decode identityToken: $e');
    }
  }
}
