import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import 'features/onboarding/onboarding_service.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/onboarding/presentation/pages/star_registration_page.dart';
import 'features/subscription/presentation/subscription_screen.dart';
import 'widgets/star_info_sheet.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'services/analytics_service.dart';
import 'services/engagement_tracking_service.dart';
import 'services/firestore_sync_service.dart';
import 'services/klaviyo_service.dart';
import 'services/locale_service.dart';
import 'services/saved_stars_service.dart';
import 'services/star_notification_service.dart';
import 'services/subscription_availability_service.dart';
import 'services/background_music_service.dart';
import 'web_utils.dart';

/// Background message handler for Firebase Messaging.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Handle push notification for Klaviyo tracking
  await KlaviyoService.instance.handlePush(message.data);
}

/// Global navigator key for handling deep links from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Handle notification tap - extracts and opens links from notification data.
/// Supports both external URLs and in-app deep links.
///
/// Expected data format from push notification:
/// - "link": "https://www.star-registration.com" (external URL)
/// - "url": "https://..." (alternative key for external URL)
/// - "registration_number": "OSR-123456" (in-app: navigate to star)
/// - "screen": "subscription" (in-app: navigate to screen)
Future<void> _handleNotificationTap(RemoteMessage message) async {
  final data = message.data;
  debugPrint('Notification tapped with data: $data');

  // Track Klaviyo push open
  await KlaviyoService.instance.handlePush(data);

  // Check for external URL (supports multiple key names)
  final link = data['link'] ?? data['url'] ?? data['deep_link'];
  if (link != null && link.isNotEmpty) {
    try {
      final uri = Uri.parse(link);
      debugPrint('Opening URL from notification: $uri');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    } catch (e) {
      debugPrint('Error opening URL from notification: $e');
    }
  }

  // Check for in-app deep links
  final registrationNumber = data['registration_number'] ?? data['star'];
  if (registrationNumber != null && registrationNumber.isNotEmpty) {
    debugPrint('Deep link to star: $registrationNumber');
    // Store for HomeScreen to pick up and search
    await OnboardingService.saveFoundStarFromNotification(registrationNumber);
    return;
  }

  // Check for screen navigation
  final screen = data['screen'];
  if (screen != null && navigatorKey.currentState != null) {
    switch (screen) {
      case 'subscription':
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => SubscriptionScreen(
              onComplete: () => navigatorKey.currentState?.pop(),
            ),
          ),
        );
        break;
      // Add more screens as needed
    }
  }
}

/// Initialize star visibility notification services
/// Note: Firestore sync is deferred until after onboarding to avoid triggering
/// notification permission dialogs prematurely
Future<void> _initializeStarNotificationServices() async {
  try {
    // Initialize notification service (but don't request permissions - onboarding handles that)
    await StarNotificationService.instance.initialize();

    // Load saved stars
    await SavedStarsService.instance.load();

    // Check if user has completed onboarding before initializing Firestore sync
    // This prevents triggering notification permission dialogs for new users
    final onboardingComplete = await OnboardingService.isOnboardingComplete();
    if (onboardingComplete) {
      // Firestore sync must not block app startup (it can hang when offline).
      unawaited(() async {
        try {
          // Initialize Firestore sync for cloud-based notifications
          await FirestoreSyncService.instance
              .initialize()
              .timeout(const Duration(seconds: 8));

          // Sync all saved stars to Firestore (Firebase Functions handles notifications)
          await FirestoreSyncService.instance
              .syncSavedStars()
              .timeout(const Duration(seconds: 8));
        } catch (e) {
          debugPrint('Deferred Firestore sync failed: $e');
        }
      }());
    }

    debugPrint('Star notification services initialized successfully');
  } catch (e) {
    debugPrint('Error initializing star notification services: $e');
  }
}

void main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    if (kIsWeb) {
      registerStellariumViewFactory();
    }

    // Load locale preference
    await LocaleService.instance.load();

    // Initialize Firebase (only on mobile platforms)
    if (!kIsWeb) {
      try {
        await Firebase.initializeApp();
        AnalyticsService.instance.initialize();

        // Initialize Crashlytics
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;

        // Disable Crashlytics in debug mode (optional - remove if you want debug crashes)
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(!kDebugMode);

        // Initialize Firebase In-App Messaging
        // Messages are configured in Firebase Console and shown automatically
        FirebaseInAppMessaging.instance.setMessagesSuppressed(false);
        FirebaseInAppMessaging.instance.setAutomaticDataCollectionEnabled(true);
      } catch (e) {
        debugPrint('Firebase initialization error: $e');
      }
    }

    // Initialize Adapty SDK (only on mobile platforms)
    if (!kIsWeb) {
      try {
        await Adapty().activate(
          configuration: AdaptyConfiguration(
            apiKey: 'public_live_IOi0yFDb.WFTHrIKk8DzeTfEPmBwQ',
          )
            ..withLogLevel(AdaptyLogLevel.verbose)
            ..withActivateUI(true),
        );

        // Check if subscription services are available (async, non-blocking)
        // This allows users in China (no Google Play) to use the app without paywalls
        unawaited(SubscriptionAvailabilityService.instance.checkAvailability());
      } catch (e) {
        debugPrint('Adapty initialization error: $e');
        // Mark subscription services as unavailable if Adapty fails to initialize
        // This bypasses paywalls for users who can't access the service
        SubscriptionAvailabilityService.instance.markUnavailable();
      }
    }

    // Set up Firebase Messaging and notification services (only on mobile platforms)
    // Only initialize these for returning users who completed onboarding
    // to avoid triggering notification permission dialogs for new users
    if (!kIsWeb) {
      final onboardingComplete = await OnboardingService.isOnboardingComplete();

      if (onboardingComplete) {
        // Set up Firebase Messaging background handler
        FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler);

        // Handle foreground messages for Klaviyo tracking (if initialized)
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          KlaviyoService.instance.handlePush(message.data);
        });

        // Handle notification tap when app is in background
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

        // Handle notification tap that launched the app from terminated state
        final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          // Delay slightly to ensure app is ready
          Future.delayed(const Duration(milliseconds: 500), () {
            _handleNotificationTap(initialMessage);
          });
        }

        // Initialize Klaviyo for returning users
        final locale = LocaleService.instance.locale;
        final languageCode = locale?.languageCode ??
            WidgetsBinding.instance.platformDispatcher.locale.languageCode;
        await KlaviyoService.instance.initialize(languageCode);
        KlaviyoService.instance.setupTokenRefreshListener();

        // Initialize star visibility notification services
        await _initializeStarNotificationServices();
      } else {
        // For new users, just load saved stars (no Firebase Messaging setup)
        await SavedStarsService.instance.load();
      }
    }

    runApp(const StellariumApp());
  }, (error, stack) {
    // Catch errors outside of Flutter framework
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}

class StellariumApp extends StatefulWidget {
  const StellariumApp({super.key});

  @override
  State<StellariumApp> createState() => _StellariumAppState();
}

class _StellariumAppState extends State<StellariumApp> {
  @override
  void initState() {
    super.initState();
    LocaleService.instance.addListener(_onLocaleChanged);
    // Start background music after app is loaded
    BackgroundMusicService.instance.initialize();
  }

  @override
  void dispose() {
    LocaleService.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Stellarium',
      debugShowCheckedModeBanner: false,
      // Localization support
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('de'),
        Locale('zh'),
      ],
      // Use custom locale if set, otherwise use system locale
      locale: LocaleService.instance.locale,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: const AppEntryPoint(),
    );
  }
}

/// Entry point that checks onboarding status and routes accordingly
class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

enum AppScreen { loading, onboarding, starRegistration, subscription, home }

class _AppEntryPointState extends State<AppEntryPoint> {
  AppScreen _currentScreen = AppScreen.loading;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final onboardingComplete = await OnboardingService.isOnboardingComplete();

    setState(() {
      if (!onboardingComplete) {
        _currentScreen = AppScreen.onboarding;
      } else {
        // Always show star registration for returning users
        _currentScreen = AppScreen.starRegistration;
      }
    });
  }

  void _onOnboardingComplete() {
    // After onboarding, show star registration
    setState(() {
      _currentScreen = AppScreen.starRegistration;
    });
  }

  Future<void> _onStarRegistrationComplete({bool starFound = false}) async {
    // If a star was found, skip subscription and go directly to home
    if (starFound) {
      setState(() {
        _currentScreen = AppScreen.home;
      });
      return;
    }

    // Check if user has already subscribed
    final subscriptionShown = await OnboardingService.isSubscriptionShown();

    // Check if engagement paywall was already triggered (user exceeded 2-min free time)
    await EngagementTrackingService.instance.load();
    final engagementPaywallTriggered = EngagementTrackingService.instance.paywallTriggered;

    // PAYWALL COORDINATION:
    // We have two paywall entry points with different placement IDs:
    // 1. SubscriptionScreen ('night_sky_view') - skippable, shown to new users after onboarding
    // 2. SubscriptionRequiredScreen ('non_skippable_paywall') - forced, shown after 2-min free time
    //
    // Problem: Without coordination, returning users who exceeded free time would see BOTH:
    // - First 'night_sky_view' (from this flow)
    // - Then 'non_skippable_paywall' (from HomeScreen._checkAndShowPaywallIfNeeded)
    //
    // Solution: If engagementPaywallTriggered is true, skip SubscriptionScreen here.
    // HomeScreen will handle showing the forced paywall via _checkAndShowPaywallIfNeeded.
    setState(() {
      if (!kIsWeb && !subscriptionShown && !engagementPaywallTriggered) {
        _currentScreen = AppScreen.subscription;
      } else {
        _currentScreen = AppScreen.home;
      }
    });
  }

  void _onSubscriptionComplete() {
    // After subscription, go to home
    setState(() {
      _currentScreen = AppScreen.home;
    });
  }

  void _onStarFound(StarInfo starInfo) {
    // Save the found star info for later use
    OnboardingService.saveFoundStar(starInfo);
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentScreen) {
      case AppScreen.loading:
        return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: CircularProgressIndicator(
              color: Color(0xFF33B4E8),
            ),
          ),
        );

      case AppScreen.onboarding:
        return OnboardingScreen(
          onComplete: _onOnboardingComplete,
        );

      case AppScreen.subscription:
        return SubscriptionScreen(
          onComplete: _onSubscriptionComplete,
        );

      case AppScreen.starRegistration:
        return Scaffold(
          backgroundColor: Colors.black,
          body: StarRegistrationPage(
            onContinue: _onStarRegistrationComplete,
            onSkip: () => _onStarRegistrationComplete(),
            onStarFound: _onStarFound,
          ),
        );

      case AppScreen.home:
        return const HomeScreen();
    }
  }
}
