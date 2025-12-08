import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:klaviyo_flutter/klaviyo_flutter.dart';

/// Service for managing Klaviyo email marketing integration.
/// Uses different API keys for German and English users.
class KlaviyoService {
  static final KlaviyoService _instance = KlaviyoService._internal();
  static KlaviyoService get instance => _instance;

  KlaviyoService._internal();

  static const String _apiKeyEnglish = 'YjQbgj';
  static const String _apiKeyGerman = 'Y9TagB';

  bool _isInitialized = false;
  String? _currentLocale;
  bool _pushTokenRegistered = false;

  /// Initialize Klaviyo with the appropriate API key based on locale.
  /// [languageCode] should be 'de' for German or any other value for English.
  Future<void> initialize(String languageCode) async {
    if (kIsWeb) return; // Klaviyo not supported on web

    final apiKey = languageCode == 'de' ? _apiKeyGerman : _apiKeyEnglish;
    _currentLocale = languageCode;

    try {
      await Klaviyo.instance.initialize(apiKey);
      _isInitialized = true;
      debugPrint('Klaviyo initialized for locale: $languageCode');
    } catch (e) {
      debugPrint('Klaviyo initialization error: $e');
    }
  }

  /// Check if Klaviyo is initialized
  bool get isInitialized => _isInitialized;

  /// Get current locale
  String? get currentLocale => _currentLocale;

  /// Log a custom event to Klaviyo
  Future<void> logEvent(String eventName, [Map<String, dynamic>? properties]) async {
    if (!_isInitialized) return;

    try {
      await Klaviyo.instance.logEvent(eventName, properties ?? {});
    } catch (e) {
      debugPrint('Klaviyo logEvent error: $e');
    }
  }

  /// Set external ID for the user
  Future<void> setExternalId(String externalId) async {
    if (!_isInitialized) return;

    try {
      await Klaviyo.instance.setExternalId(externalId);
    } catch (e) {
      debugPrint('Klaviyo setExternalId error: $e');
    }
  }

  /// Set user email
  Future<void> setEmail(String email) async {
    if (!_isInitialized) return;

    try {
      await Klaviyo.instance.setEmail(email);
    } catch (e) {
      debugPrint('Klaviyo setEmail error: $e');
    }
  }

  /// Set user phone number
  Future<void> setPhoneNumber(String phoneNumber) async {
    if (!_isInitialized) return;

    try {
      await Klaviyo.instance.setPhoneNumber(phoneNumber);
    } catch (e) {
      debugPrint('Klaviyo setPhoneNumber error: $e');
    }
  }

  /// Reset profile (e.g., on logout)
  Future<void> resetProfile() async {
    if (!_isInitialized) return;

    try {
      await Klaviyo.instance.resetProfile();
    } catch (e) {
      debugPrint('Klaviyo resetProfile error: $e');
    }
  }

  /// Log when user completes onboarding
  Future<void> logOnboardingComplete() async {
    await logEvent('Onboarding Complete');
  }

  /// Log when user starts subscription
  Future<void> logSubscriptionStarted({String? productId}) async {
    await logEvent('Subscription Started', {
      if (productId != null) 'product_id': productId,
    });
  }

  /// Log when user searches for a star
  Future<void> logStarSearch({required String query}) async {
    await logEvent('Star Search', {'query': query});
  }

  /// Log when user views a star
  Future<void> logStarViewed({required String starName}) async {
    await logEvent('Star Viewed', {'star_name': starName});
  }

  /// Register push token with Klaviyo after user grants notification permission.
  /// This subscribes the user's device for push notifications in Klaviyo.
  Future<bool> registerPushToken() async {
    if (!_isInitialized || kIsWeb) return false;

    try {
      final firebaseMessaging = FirebaseMessaging.instance;

      // Get the appropriate token based on platform
      String? token;
      if (Platform.isIOS) {
        // For iOS, we need the APNS token
        token = await firebaseMessaging.getAPNSToken();
      } else {
        // For Android, we use the FCM token
        token = await firebaseMessaging.getToken();
      }

      if (token != null && token.isNotEmpty) {
        await Klaviyo.instance.sendTokenToKlaviyo(token);
        _pushTokenRegistered = true;
        debugPrint('Klaviyo push token registered successfully');
        return true;
      } else {
        debugPrint('Klaviyo: No push token available');
        return false;
      }
    } catch (e) {
      debugPrint('Klaviyo registerPushToken error: $e');
      return false;
    }
  }

  /// Check if push token is registered
  bool get isPushTokenRegistered => _pushTokenRegistered;

  /// Handle incoming push notification (for tracking opens)
  Future<void> handlePush(Map<String, dynamic> data) async {
    if (!_isInitialized) return;

    try {
      await Klaviyo.instance.handlePush(data);
    } catch (e) {
      debugPrint('Klaviyo handlePush error: $e');
    }
  }

  /// Listen for token refresh and update Klaviyo
  void setupTokenRefreshListener() {
    if (kIsWeb) return;

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      if (_isInitialized && newToken.isNotEmpty) {
        try {
          await Klaviyo.instance.sendTokenToKlaviyo(newToken);
          debugPrint('Klaviyo: Token refreshed and sent');
        } catch (e) {
          debugPrint('Klaviyo token refresh error: $e');
        }
      }
    });
  }
}
