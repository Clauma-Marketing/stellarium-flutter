import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/onboarding/onboarding_service.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/onboarding/presentation/pages/star_registration_page.dart';
import 'features/subscription/presentation/subscription_screen.dart';
import 'widgets/star_info_sheet.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'services/analytics_service.dart';
import 'services/background_service.dart';
import 'services/firestore_sync_service.dart';
import 'services/klaviyo_service.dart';
import 'services/locale_service.dart';
import 'services/saved_stars_service.dart';
import 'services/star_notification_service.dart';
import 'web_utils.dart';

/// Background message handler for Firebase Messaging.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Handle push notification for Klaviyo tracking
  await KlaviyoService.instance.handlePush(message.data);
}

/// Initialize star visibility notification services
Future<void> _initializeStarNotificationServices() async {
  try {
    // Initialize WorkManager for background tasks (local fallback)
    await BackgroundService.initialize();

    // Initialize notification service
    await StarNotificationService.instance.initialize();

    // Request notification permissions
    await StarNotificationService.instance.requestPermissions();

    // Load saved stars
    await SavedStarsService.instance.load();

    // Initialize Firestore sync for cloud-based notifications
    await FirestoreSyncService.instance.initialize();

    // Sync all saved stars to Firestore
    await FirestoreSyncService.instance.syncSavedStars();

    // Register periodic background task for visibility calculations (local fallback)
    await BackgroundService.registerPeriodicTask();

    // Run initial local calculation (backup for cloud)
    await StarNotificationService.instance.scheduleAllStarNotifications();

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
        FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

        // Disable Crashlytics in debug mode (optional - remove if you want debug crashes)
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
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
          )..withLogLevel(AdaptyLogLevel.verbose)
           ..withActivateUI(true),
        );
      } catch (e) {
        debugPrint('Adapty initialization error: $e');
      }
    }

    // Initialize Klaviyo with locale-based API key (only on mobile platforms)
    if (!kIsWeb) {
      final locale = LocaleService.instance.locale;
      final languageCode = locale?.languageCode ??
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      await KlaviyoService.instance.initialize(languageCode);

      // Set up Firebase Messaging for push notifications
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Listen for token refresh to keep Klaviyo updated
      KlaviyoService.instance.setupTokenRefreshListener();

      // Handle foreground messages for Klaviyo tracking
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        KlaviyoService.instance.handlePush(message.data);
      });

      // Initialize star visibility notification services
      await _initializeStarNotificationServices();
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

enum AppScreen { loading, onboarding, subscription, starRegistration, home }

class _AppEntryPointState extends State<AppEntryPoint> {
  AppScreen _currentScreen = AppScreen.loading;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final onboardingComplete = await OnboardingService.isOnboardingComplete();
    final subscriptionShown = await OnboardingService.isSubscriptionShown();

    setState(() {
      if (!onboardingComplete) {
        _currentScreen = AppScreen.onboarding;
      } else if (!subscriptionShown && !kIsWeb) {
        _currentScreen = AppScreen.subscription;
      } else {
        // Always show star registration after onboarding/subscription
        _currentScreen = AppScreen.starRegistration;
      }
    });
  }

  void _onOnboardingComplete() {
    // After onboarding, show subscription screen (on mobile only)
    setState(() {
      if (!kIsWeb) {
        _currentScreen = AppScreen.subscription;
      } else {
        // On web, go directly to star registration
        _currentScreen = AppScreen.starRegistration;
      }
    });
  }

  void _onSubscriptionComplete() {
    // After subscription, show star registration
    setState(() {
      _currentScreen = AppScreen.starRegistration;
    });
  }

  void _onStarRegistrationComplete() {
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
            onSkip: _onStarRegistrationComplete,
            onStarFound: _onStarFound,
          ),
        );

      case AppScreen.home:
        return const HomeScreen();
    }
  }
}
