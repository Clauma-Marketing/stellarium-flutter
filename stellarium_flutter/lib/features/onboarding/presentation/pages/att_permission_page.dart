import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../services/analytics_service.dart';
import '../widgets/permission_page_template.dart';

/// ATT (App Tracking Transparency) permission page - iOS only
class AttPermissionPage extends StatefulWidget {
  final VoidCallback onContinue;
  final int? currentPage;
  final int? totalPages;

  const AttPermissionPage({
    super.key,
    required this.onContinue,
    this.currentPage,
    this.totalPages,
  });

  @override
  State<AttPermissionPage> createState() => _AttPermissionPageState();
}

class _AttPermissionPageState extends State<AttPermissionPage> {
  bool _isLoading = false;

  Future<void> _requestAttPermission() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Only request on iOS
      if (!kIsWeb && Platform.isIOS) {
        // Check current status first
        final status = await AppTrackingTransparency.trackingAuthorizationStatus;

        if (status == TrackingStatus.notDetermined) {
          final newStatus =
              await AppTrackingTransparency.requestTrackingAuthorization();
          if (newStatus == TrackingStatus.authorized) {
            AnalyticsService.instance.logPermissionGranted(permission: 'att');
          } else {
            AnalyticsService.instance.logPermissionSkipped(permission: 'att');
          }
        } else {
          // User already made a choice previously; iOS won't show the prompt again.
          // Proceed with onboarding regardless.
          if (status == TrackingStatus.authorized) {
            AnalyticsService.instance.logPermissionGranted(permission: 'att');
          } else {
            AnalyticsService.instance.logPermissionSkipped(permission: 'att');
          }
        }
      }
    } catch (e) {
      debugPrint('ATT permission error: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
    // Always continue onboarding, even if permission dialog can't be shown.
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PermissionPageTemplate(
      iconImagePath: 'assets/icons/privacy.png',
      title: l10n.attTitle,
      subtitle: l10n.attSubtitle,
      features: const [],
      primaryButtonText: _isLoading ? l10n.onboardingRequesting : l10n.onboardingContinue,
      onPrimaryPressed: _requestAttPermission,
      isLoading: _isLoading,
      currentPage: widget.currentPage,
      totalPages: widget.totalPages,
    );
  }
}
