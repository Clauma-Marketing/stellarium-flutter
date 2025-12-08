import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../widgets/permission_page_template.dart';

/// ATT (App Tracking Transparency) permission page - iOS only
class AttPermissionPage extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final int? currentPage;
  final int? totalPages;

  const AttPermissionPage({
    super.key,
    required this.onContinue,
    required this.onSkip,
    this.currentPage,
    this.totalPages,
  });

  @override
  State<AttPermissionPage> createState() => _AttPermissionPageState();
}

class _AttPermissionPageState extends State<AttPermissionPage> {
  bool _isLoading = false;

  List<FeatureItem> _getFeatures(AppLocalizations l10n) => [
    FeatureItem(
      icon: Icons.analytics_outlined,
      title: l10n.attImproveApp,
      description: l10n.attImproveAppDesc,
    ),
    FeatureItem(
      icon: Icons.ads_click,
      title: l10n.attRelevantContent,
      description: l10n.attRelevantContentDesc,
    ),
    FeatureItem(
      icon: Icons.privacy_tip_outlined,
      title: l10n.attPrivacyMatters,
      description: l10n.attPrivacyMattersDesc,
    ),
  ];

  Future<void> _requestAttPermission() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Only request on iOS
      if (!kIsWeb && Platform.isIOS) {
        // Check current status first
        final status = await AppTrackingTransparency.trackingAuthorizationStatus;

        if (status == TrackingStatus.notDetermined) {
          // Request permission
          await AppTrackingTransparency.requestTrackingAuthorization();
        }
      }
    } catch (e) {
      debugPrint('ATT permission error: $e');
    }

    setState(() {
      _isLoading = false;
    });

    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PermissionPageTemplate(
      icon: Icons.shield_outlined,
      title: l10n.attTitle,
      subtitle: l10n.attSubtitle,
      features: _getFeatures(l10n),
      primaryButtonText: _isLoading ? l10n.onboardingRequesting : l10n.onboardingContinue,
      secondaryButtonText: l10n.onboardingSkip,
      onPrimaryPressed: _requestAttPermission,
      onSecondaryPressed: widget.onSkip,
      privacyNotice: l10n.attPrivacyNotice,
      isLoading: _isLoading,
      currentPage: widget.currentPage,
      totalPages: widget.totalPages,
    );
  }
}
