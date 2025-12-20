import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../services/analytics_service.dart';
import '../../../../services/klaviyo_service.dart';
import '../../../../services/locale_service.dart';
import '../widgets/permission_page_template.dart';

/// Notification permission page - requests notification access during onboarding
class NotificationPermissionPage extends StatefulWidget {
  final VoidCallback onContinue;
  final int? currentPage;
  final int? totalPages;

  const NotificationPermissionPage({
    super.key,
    required this.onContinue,
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

  /// Initialize Klaviyo in the background without blocking the user flow.
  /// This prevents the app from getting stuck if Firebase is unreachable (e.g., in China).
  void _initializeKlaviyoAsync(String languageCode) {
    Future(() async {
      try {
        await KlaviyoService.instance.initialize(languageCode);
        KlaviyoService.instance.setupTokenRefreshListener();
        await KlaviyoService.instance.registerPushToken();
        debugPrint('Klaviyo initialized successfully in background');
      } catch (e) {
        debugPrint('Klaviyo background initialization error: $e');
      }
    });
  }

  Future<void> _requestNotificationPermission() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (!kIsWeb) {
        // Request notification permission
        final status = await Permission.notification.request();
        debugPrint('Notification permission status: $status');

        // If permission granted, initialize Klaviyo and register push token
        if (status.isGranted) {
          // Track permission granted
          AnalyticsService.instance.logPermissionGranted(permission: 'notification');
          // Initialize Klaviyo asynchronously (don't block user flow)
          // This prevents hanging if Firebase/Google services are blocked (e.g., in China)
          final locale = LocaleService.instance.locale;
          final languageCode = locale?.languageCode ??
              WidgetsBinding.instance.platformDispatcher.locale.languageCode;
          _initializeKlaviyoAsync(languageCode);
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
      iconImagePath: 'assets/icons/notification.png',
      title: l10n.notificationTitle,
      subtitle: l10n.notificationSubtitle,
      features: const [],
      primaryButtonText: _isLoading ? l10n.onboardingRequesting : l10n.notificationAllowNotifications,
      onPrimaryPressed: _requestNotificationPermission,
      isLoading: _isLoading,
      currentPage: widget.currentPage,
      totalPages: widget.totalPages,
    );
  }
}
