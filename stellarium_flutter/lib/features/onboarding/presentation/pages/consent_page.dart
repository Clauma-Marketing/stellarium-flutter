import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../services/consent_service.dart';
import '../widgets/permission_page_template.dart';

/// GDPR consent banner shown to users in the EEA, UK and Switzerland
/// (required by Google's EU User Consent Policy). The choice feeds
/// Google Consent Mode v2 via [ConsentService].
class ConsentPage extends StatefulWidget {
  final VoidCallback onContinue;
  final int? currentPage;
  final int? totalPages;

  const ConsentPage({
    super.key,
    required this.onContinue,
    this.currentPage,
    this.totalPages,
  });

  @override
  State<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends State<ConsentPage> {
  bool _isLoading = false;

  Future<void> _choose(bool granted) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    await ConsentService.instance.setChoice(granted: granted);
    if (mounted) setState(() => _isLoading = false);
    widget.onContinue();
  }

  Future<void> _openPrivacyPolicy() async {
    try {
      await launchUrl(
        Uri.parse('https://www.star-registration.com/policies/privacy-policy'),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Error opening privacy policy: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PermissionPageTemplate(
      iconImagePath: 'assets/icons/privacy.png',
      title: l10n.consentTitle,
      subtitle: l10n.consentMessage,
      features: const [],
      customContent: TextButton(
        onPressed: _openPrivacyPolicy,
        child: Text(
          l10n.privacyPolicy,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            decoration: TextDecoration.underline,
            decorationColor: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ),
      primaryButtonText: l10n.consentAccept,
      onPrimaryPressed: () => _choose(true),
      secondaryButtonText: l10n.consentDecline,
      onSecondaryPressed: () => _choose(false),
      isLoading: _isLoading,
      currentPage: widget.currentPage,
      totalPages: widget.totalPages,
    );
  }
}
