import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/analytics_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/locale_service.dart';
import '../../onboarding/presentation/widgets/animated_starfield.dart';
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

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AuthService.instance.signInWithGoogle();
      if (mounted) widget.onSignedIn();
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
      if (mounted) widget.onSignedIn();
    } on FirebaseException catch (e) {
      _setError(_friendlyError(e));
    } catch (e) {
      // Apple sign-in cancelled throws a PlatformException
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
      if (mounted) widget.onSignedIn();
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
    final locale = LocaleService.instance.locale?.languageCode ??
        Localizations.localeOf(context).languageCode;
    final showApple = !kIsWeb && Platform.isIOS;

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedStarfield(
        starCount: 50,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  // Logo
                  SvgPicture.asset(
                    locale == 'de'
                        ? 'assets/logo_de.svg'
                        : 'assets/star-reg_logo.svg',
                    height: 36,
                  ),
                  const SizedBox(height: 40),
                  // Title
                  Text(
                    _showEmailForm
                        ? (_isSignUp
                            ? l10n.signInCreateAccount
                            : l10n.signInWelcomeBack)
                        : l10n.signInTitle,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.signInSubtitle,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),

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
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (!_showEmailForm) ...[
                    // Social sign-in buttons
                    _SocialButton(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      iconWidget: SvgPicture.asset(
                        'assets/icons/google_logo.svg',
                        width: 22,
                        height: 22,
                      ),
                      label: l10n.signInWithGoogle,
                    ),
                    if (showApple) ...[
                      const SizedBox(height: 12),
                      _SocialButton(
                        onPressed: _isLoading ? null : _handleAppleSignIn,
                        iconWidget: const Icon(Icons.apple,
                            color: Colors.white, size: 24),
                        label: l10n.signInWithApple,
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Divider
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                              color: Colors.white.withValues(alpha: 0.2)),
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
                          child: Divider(
                              color: Colors.white.withValues(alpha: 0.2)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
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
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3)),
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

                  // Skip button
                  if (widget.onSkip != null) ...[
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: _isLoading ? null : widget.onSkip,
                      child: Text(
                        l10n.signInSkip,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],

                  // Loading indicator
                  if (_isLoading) ...[
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(color: primaryBlue),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailForm(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Email field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(l10n.signInEmail, Icons.email_outlined),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 12),
          // Password field
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
          // Forgot password
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
            const SizedBox(height: 20),
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
              child: Text(
                _isSignUp ? l10n.signInCreateAccount : l10n.signInSignIn,
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
