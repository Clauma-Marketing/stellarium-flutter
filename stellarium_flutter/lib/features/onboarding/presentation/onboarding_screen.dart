import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../services/analytics_service.dart';
import '../../../../services/firestore_sync_service.dart';
import '../../../../services/klaviyo_service.dart';
import '../../../../services/locale_service.dart';
import '../onboarding_service.dart';
import 'pages/att_permission_page.dart';
import 'pages/location_permission_page.dart';
import 'pages/notification_permission_page.dart';
import 'pages/sky_preview_page.dart';
import 'pages/welcome_page.dart';

/// Main onboarding screen that manages the onboarding flow
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Location data from permission page, passed to sky preview
  double? _latitude;
  double? _longitude;
  String? _locationName;

  // Check if we should show ATT page (iOS only)
  bool get _showAttPage => !kIsWeb && Platform.isIOS;

  // Sky preview is only available on mobile
  bool get _showSkyPreview => !kIsWeb;

  @override
  void initState() {
    super.initState();
    // Track onboarding screen view
    AnalyticsService.instance.logScreenView(screenName: 'onboarding');
    _trackPageView(0);
  }

  void _trackPageView(int page) {
    final pageNames = [
      'welcome',
      'location_permission',
      if (_showSkyPreview) 'sky_preview',
      'notification_permission',
      if (_showAttPage) 'att_permission',
    ];
    if (page < pageNames.length) {
      AnalyticsService.instance.logEvent(
        name: 'onboarding_page_view',
        parameters: {'page': pageNames[page], 'page_index': page},
      );
    }
  }

  // Total number of pages: Welcome, Location, [Sky Preview on mobile], Notification, [ATT on iOS]
  int get _totalPages {
    int count = 3; // Welcome, Location, Notification
    if (_showSkyPreview) count++;
    if (_showAttPage) count++;
    return count;
  }

  void _goToNextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    await OnboardingService.completeOnboarding();
    // Track onboarding completion
    AnalyticsService.instance.logOnboardingComplete();

    widget.onComplete();

    // These services are useful after onboarding, but they must never delay the
    // transition to the sign-in screen.
    unawaited(_initializePostOnboardingServices());
  }

  Future<void> _initializePostOnboardingServices() async {
    // Initialize services that were deferred from startup to avoid
    // triggering notification permission dialogs for new users
    if (!kIsWeb) {
      // Set up Firebase Messaging foreground handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        KlaviyoService.instance.handlePush(message.data);
      });

      // Initialize Klaviyo if not already initialized (must not block onboarding transition)
      if (!KlaviyoService.instance.isInitialized) {
        try {
          final locale = LocaleService.instance.locale;
          final languageCode = locale?.languageCode ??
              WidgetsBinding.instance.platformDispatcher.locale.languageCode;
          await KlaviyoService.instance
              .initialize(languageCode)
              .timeout(const Duration(seconds: 5));
          KlaviyoService.instance.setupTokenRefreshListener();
        } catch (e) {
          debugPrint('Klaviyo initialization failed: $e');
        }
      }

      // Firestore sync must not block the transition out of onboarding (it can hang when offline).
      unawaited(() async {
        try {
          await FirestoreSyncService.instance
              .initialize()
              .timeout(const Duration(seconds: 8));
          await FirestoreSyncService.instance
              .syncSavedStars()
              .timeout(const Duration(seconds: 8));
        } catch (e) {
          debugPrint('Deferred Firestore sync failed: $e');
        }
      }());
    }
  }

  void _onLocationObtained(double latitude, double longitude) {
    OnboardingService.saveUserLocation(latitude, longitude);
    setState(() {
      _latitude = latitude;
      _longitude = longitude;
    });
  }

  void _onLocationNameResolved(String locationName) {
    setState(() {
      _locationName = locationName;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<Widget> _buildPages() {
    int pageIndex = 0;

    final pages = <Widget>[
      // Page 0: Welcome
      WelcomePage(
        onGetStarted: _goToNextPage,
        currentPage: pageIndex++,
        totalPages: _totalPages,
      ),
      // Page 1: Location Permission
      LocationPermissionPage(
        onContinue: _goToNextPage,
        onLocationObtained: _onLocationObtained,
        onLocationNameResolved: _onLocationNameResolved,
        currentPage: pageIndex++,
        totalPages: _totalPages,
      ),
    ];

    // Sky Preview (mobile only)
    if (_showSkyPreview) {
      pages.add(
        SkyPreviewPage(
          onContinue: _goToNextPage,
          latitude: _latitude ?? OnboardingService.defaultLatitude,
          longitude: _longitude ?? OnboardingService.defaultLongitude,
          locationName: _locationName,
          currentPage: pageIndex++,
          totalPages: _totalPages,
        ),
      );
    }

    // Notification Permission
    pages.add(
      NotificationPermissionPage(
        onContinue: _goToNextPage,
        currentPage: pageIndex++,
        totalPages: _totalPages,
      ),
    );

    // ATT page for iOS only (last page)
    if (_showAttPage) {
      pages.add(
        AttPermissionPage(
          onContinue: _completeOnboarding,
          currentPage: pageIndex++,
          totalPages: _totalPages,
        ),
      );
    }

    return pages;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (page) {
          setState(() {
            _currentPage = page;
          });
          _trackPageView(page);
        },
        children: _buildPages(),
      ),
    );
  }
}
