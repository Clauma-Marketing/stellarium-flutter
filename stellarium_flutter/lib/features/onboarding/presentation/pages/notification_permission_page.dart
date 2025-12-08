import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../services/klaviyo_service.dart';
import '../widgets/permission_page_template.dart';

/// Notification permission page - requests notification access during onboarding
class NotificationPermissionPage extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final int? currentPage;
  final int? totalPages;

  const NotificationPermissionPage({
    super.key,
    required this.onContinue,
    required this.onSkip,
    this.currentPage,
    this.totalPages,
  });

  @override
  State<NotificationPermissionPage> createState() =>
      _NotificationPermissionPageState();
}

class _NotificationPermissionPageState
    extends State<NotificationPermissionPage> {
  bool _isLoading = false;

  List<FeatureItem> _getFeatures(AppLocalizations l10n) => [
    FeatureItem(
      icon: Icons.nightlight_round,
      title: l10n.notificationMoonPhase,
      description: l10n.notificationMoonPhaseDesc,
    ),
    FeatureItem(
      icon: Icons.auto_awesome,
      title: l10n.notificationCelestialEvents,
      description: l10n.notificationCelestialEventsDesc,
    ),
    FeatureItem(
      icon: Icons.visibility,
      title: l10n.notificationVisibility,
      description: l10n.notificationVisibilityDesc,
    ),
  ];

  Future<void> _requestNotificationPermission() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (!kIsWeb) {
        // Request notification permission
        final status = await Permission.notification.request();
        debugPrint('Notification permission status: $status');

        // If permission granted, register push token with Klaviyo
        if (status.isGranted) {
          await KlaviyoService.instance.registerPushToken();
        }
      }
    } catch (e) {
      debugPrint('Notification permission error: $e');
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
      icon: Icons.notifications_active,
      title: l10n.notificationTitle,
      subtitle: l10n.notificationSubtitle,
      features: _getFeatures(l10n),
      primaryButtonText: _isLoading ? l10n.onboardingRequesting : l10n.onboardingContinue,
      secondaryButtonText: l10n.onboardingMaybeLater,
      onPrimaryPressed: _requestNotificationPermission,
      onSecondaryPressed: widget.onSkip,
      privacyNotice: l10n.notificationPrivacyNotice,
      isLoading: _isLoading,
      currentPage: widget.currentPage,
      totalPages: widget.totalPages,
    );
  }
}
