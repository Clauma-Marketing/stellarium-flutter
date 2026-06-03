import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/analytics_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/klaviyo_service.dart';
import '../../onboarding/presentation/widgets/permission_page_template.dart';

/// Sign-in / sign-up screen with Google, Apple and email+password.
class SignInScreen extends StatefulWidget {
  final VoidCallback onSignedIn;
  final VoidCallback? onSkip;

  const SignInScreen({
    super.key,
    required this.onSignedIn,
    this.onSkip,
  });

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _isLoading = false;
  bool _showEmailForm = false;
  bool _isSignUp = true;
  bool _obscurePassword = true;
  bool _emailOptIn = true;
  String? _error;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView(screenName: 'sign_in');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSignInSuccess() {
    if (_emailOptIn) {
      final email = AuthService.instance.currentUser?.email;
      if (email != null && email.isNotEmpty) {
        KlaviyoService.instance.setEmail(email);
      }
    }
    widget.onSignedIn();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AuthService.instance.signInWithGoogle();
      if (mounted) _onSignInSuccess();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'sign-in-cancelled') return;
      _setError(_friendlyError(e));
    } on FirebaseException catch (e) {
      _setError(_friendlyError(e));
    } catch (e) {
      _setError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AuthService.instance.signInWithApple();
      if (mounted) _onSignInSuccess();
    } on FirebaseException catch (e) {
      _setError(_friendlyError(e));
    } catch (e) {
      if (e.toString().contains('AuthorizationErrorCode.canceled')) return;
      _setError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      if (_isSignUp) {
        await AuthService.instance.signUpWithEmail(
          _emailController.text,
          _passwordController.text,
        );
      } else {
        await AuthService.instance.signInWithEmail(
          _emailController.text,
          _passwordController.text,
        );
      }
      if (mounted) _onSignInSuccess();
    } on FirebaseAuthException catch (e) {
      _setError(_friendlyError(e));
    } catch (e) {
      _setError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _setError('Please enter your email address first.');
      return;
    }
    try {
      await AuthService.instance.sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to $email'),
            backgroundColor: primaryBlue,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      _setError(_friendlyError(e));
    }
  }

  void _setError(String message) {
    if (mounted) setState(() => _error = message);
  }

  String _friendlyError(FirebaseException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists. Try signing in.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final showApple = !kIsWeb && Platform.isIOS;

    return PermissionPageTemplate(
      iconImagePath: 'assets/icons/sign-in.png',
      title: _showEmailForm
          ? (_isSignUp ? l10n.signInCreateAccount : l10n.signInWelcomeBack)
          : l10n.signInTitle,
      subtitle: l10n.signInSubtitle,
      features: const [],
      secondaryButtonText: widget.onSkip != null ? l10n.signInSkip : null,
      onSecondaryPressed: widget.onSkip,
      customContent: _buildSignInContent(l10n, showApple),
    );
  }

  Widget _buildSignInContent(AppLocalizations l10n, bool showApple) {
    return DefaultTextStyle(
      style: const TextStyle(decoration: TextDecoration.none),
      child: Column(
        children: [
          // Error message
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (!_showEmailForm) ...[
            // Google & Apple side by side
            Row(
              children: [
                Expanded(
                  child: _SocialButton(
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    iconWidget: SvgPicture.asset(
                      'assets/icons/google_logo.svg',
                      width: 22,
                      height: 22,
                    ),
                    label: 'Google',
                  ),
                ),
                if (showApple) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SocialButton(
                      onPressed: _isLoading ? null : _handleAppleSignIn,
                      iconWidget: const Icon(Icons.apple,
                          color: Colors.white, size: 24),
                      label: 'Apple',
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            // Divider
            Row(
              children: [
                Expanded(
                  child: Divider(color: Colors.white.withValues(alpha: 0.2)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    l10n.signInOr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(color: Colors.white.withValues(alpha: 0.2)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Email button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => setState(() => _showEmailForm = true),
                icon: Icon(Icons.email_outlined,
                    color: Colors.white.withValues(alpha: 0.9)),
                label: Text(
                  l10n.signInWithEmail,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
              ),
            ),
          ] else ...[
            // Email form
            _buildEmailForm(l10n),
          ],

          // Email opt-in checkbox
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _emailOptIn = !_emailOptIn),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Material(
                    color: Colors.transparent,
                    child: Checkbox(
                      value: _emailOptIn,
                      onChanged: (v) =>
                          setState(() => _emailOptIn = v ?? false),
                      activeColor: primaryBlue,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.signInEmailOptIn,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailForm(AppLocalizations l10n) {
    return Material(
      color: Colors.transparent,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              style: const TextStyle(color: Colors.white),
              decoration:
                  _inputDecoration(l10n.signInEmail, Icons.email_outlined),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                l10n.signInPassword,
                Icons.lock_outline,
              ).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 6) return 'At least 6 characters';
                return null;
              },
            ),
            if (!_isSignUp) ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _handleForgotPassword,
                  child: Text(
                    l10n.signInForgotPassword,
                    style: TextStyle(
                      color: primaryBlue.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
            ],
            // Submit button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleEmailSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _isSignUp
                            ? l10n.signInCreateAccount
                            : l10n.signInSignIn,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            // Toggle sign-in / sign-up
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isSignUp
                      ? l10n.signInAlreadyHaveAccount
                      : l10n.signInNoAccount,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _isSignUp = !_isSignUp;
                    _error = null;
                  }),
                  child: Text(
                    _isSignUp ? l10n.signInSignIn : l10n.signInCreateAccount,
                    style: const TextStyle(
                      color: primaryBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            // Back to social
            TextButton(
              onPressed: () => setState(() {
                _showEmailForm = false;
                _error = null;
              }),
              child: Text(
                l10n.signInBackToOptions,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
      prefixIcon:
          Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 20),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

/// Social sign-in button (Google / Apple style).
class _SocialButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget iconWidget;
  final String label;

  const _SocialButton({
    required this.onPressed,
    required this.iconWidget,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
