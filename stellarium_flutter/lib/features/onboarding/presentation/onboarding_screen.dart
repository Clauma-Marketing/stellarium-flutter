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

  // Check if we should show ATT page (iOS only)
  bool get _showAttPage => !kIsWeb && Platform.isIOS;

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

  // Total number of pages: Welcome, Location, Notification, [ATT on iOS]
  int get _totalPages => _showAttPage ? 4 : 3;

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

  void _skipToNextPage() {
    _goToNextPage();
  }

  Future<void> _completeOnboarding() async {
    await OnboardingService.completeOnboarding();
    // Track onboarding completion
    AnalyticsService.instance.logOnboardingComplete();

    // Initialize services that were deferred from startup to avoid
    // triggering notification permission dialogs for new users
    if (!kIsWeb) {
      // Set up Firebase Messaging foreground handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        KlaviyoService.instance.handlePush(message.data);
      });

      // Initialize Klaviyo if not already initialized
      if (!KlaviyoService.instance.isInitialized) {
        final locale = LocaleService.instance.locale;
        final languageCode = locale?.languageCode ??
            WidgetsBinding.instance.platformDispatcher.locale.languageCode;
        await KlaviyoService.instance.initialize(languageCode);
        KlaviyoService.instance.setupTokenRefreshListener();
      }

      // Initialize Firestore sync
      await FirestoreSyncService.instance.initialize();
      await FirestoreSyncService.instance.syncSavedStars();
    }

    widget.onComplete();
  }

  void _onLocationObtained(double latitude, double longitude) {
    OnboardingService.saveUserLocation(latitude, longitude);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<Widget> _buildPages() {
    final pages = <Widget>[
      // Page 0: Welcome
      WelcomePage(
        onGetStarted: _goToNextPage,
        currentPage: 0,
        totalPages: _totalPages,
      ),
      // Page 1: Location Permission
      LocationPermissionPage(
        onContinue: _goToNextPage,
        onSkip: _skipToNextPage,
        onLocationObtained: _onLocationObtained,
        currentPage: 1,
        totalPages: _totalPages,
      ),
      // Page 2: Notification Permission
      NotificationPermissionPage(
        onContinue: _goToNextPage,
        onSkip: _skipToNextPage,
        currentPage: 2,
        totalPages: _totalPages,
      ),
    ];

    // Add ATT page for iOS only (last page)
    if (_showAttPage) {
      pages.add(
        AttPermissionPage(
          onContinue: _completeOnboarding,
          onSkip: _completeOnboarding,
          currentPage: 3,
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
