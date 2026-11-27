import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

/// Service for managing Klaviyo email and push marketing, on Klaviyo's
/// official Flutter SDK. Uses different API keys for German and English users.
///
/// The native SDKs report "Opened Push" to Klaviyo and open a push's link on
/// their own (see AppDelegate.swift and the SDK's Android plugin). This class
/// sets up the profile and push token, and passes tapped pushes on to the app
/// for analytics and in-app routing.
class KlaviyoService {
  static final KlaviyoService _instance = KlaviyoService._internal();
  static KlaviyoService get instance => _instance;

  KlaviyoService._internal();

  static const String _apiKeyEnglish = 'YjQbgj';
  static const String _apiKeyGerman = 'Y9TagB';

  /// Channel to MainActivity / AppDelegate, which hold the payload of a tapped
  /// Klaviyo notification until Dart collects it.
  static const MethodChannel _pushOpenChannel =
      MethodChannel('com.starregistration.planetarium/klaviyo_push');

  bool _isInitialized = false;
  String? _currentLocale;
  bool _pushTokenRegistered = false;
  bool _pushOpenChannelReady = false;
  StreamSubscription<String>? _tokenRefreshSubscription;

  /// Called with the data of a tapped Klaviyo notification. Set once at
  /// startup.
  Future<void> Function(Map<String, dynamic> data)? onPushOpened;

  /// Initialize Klaviyo with the appropriate API key based on locale.
  /// [languageCode] should be 'de' for German or any other value for English.
  Future<void> initialize(String languageCode) async {
    if (kIsWeb) return; // Klaviyo not supported on web

    final apiKey = languageCode == 'de' ? _apiKeyGerman : _apiKeyEnglish;
    _currentLocale = languageCode;

    try {
      await KlaviyoSDK().initialize(apiKey: apiKey);
      _isInitialized = true;
      debugPrint('Klaviyo initialized for locale: $languageCode');
      _setupPushOpenChannel();
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
      await KlaviyoSDK().createEvent(
        KlaviyoEvent.custom(metric: eventName, properties: properties),
      );
    } catch (e) {
      debugPrint('Klaviyo logEvent error: $e');
    }
  }

  /// Set external ID for the user
  Future<void> setExternalId(String externalId) async {
    if (!_isInitialized) return;

    try {
      await KlaviyoSDK().setExternalId(externalId);
    } catch (e) {
      debugPrint('Klaviyo setExternalId error: $e');
    }
  }

  /// Set user email
  Future<void> setEmail(String email) async {
    if (!_isInitialized) return;

    try {
      await KlaviyoSDK().setEmail(email);
    } catch (e) {
      debugPrint('Klaviyo setEmail error: $e');
    }
  }

  /// Set user phone number
  Future<void> setPhoneNumber(String phoneNumber) async {
    if (!_isInitialized) return;

    try {
      await KlaviyoSDK().setPhoneNumber(phoneNumber);
    } catch (e) {
      debugPrint('Klaviyo setPhoneNumber error: $e');
    }
  }

  /// Reset profile (e.g., on logout)
  Future<void> resetProfile() async {
    if (!_isInitialized) return;

    try {
      await KlaviyoSDK().resetProfile();
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
  ///
  /// The SDK also forwards the token by itself when the system hands one out,
  /// but on Android it drops a token that arrives before [initialize] has run,
  /// so the token is still sent from here. Sending the same token twice costs
  /// nothing: the native SDK only makes a request when something changed.
  Future<bool> registerPushToken() async {
    if (!_isInitialized || kIsWeb) return false;

    try {
      final token = await _platformPushToken();

      if (token != null && token.isNotEmpty) {
        await KlaviyoSDK().setPushToken(token);
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

  /// Register the push token if the user has already allowed notifications.
  ///
  /// Call on every launch: the token is otherwise only sent once, at the
  /// moment permission is granted during onboarding, so a failed first
  /// attempt or a permission granted later in system settings would leave the
  /// device unregistered. Never shows a permission prompt.
  Future<bool> registerPushTokenIfPermitted() async {
    if (!_isInitialized || kIsWeb) return false;

    try {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      final permitted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!permitted) return false;
    } catch (e) {
      debugPrint('Klaviyo: could not read notification settings: $e');
      return false;
    }

    return registerPushToken();
  }

  /// The token Klaviyo needs on this platform: the APNs token on iOS (Klaviyo
  /// sends through APNs directly), the FCM token on Android.
  Future<String?> _platformPushToken() async {
    final firebaseMessaging = FirebaseMessaging.instance;
    if (!Platform.isIOS) return firebaseMessaging.getToken();

    // APNs can take a moment to hand out the token after launch.
    for (var attempt = 0; attempt < 3; attempt++) {
      final token = await firebaseMessaging.getAPNSToken();
      if (token != null && token.isNotEmpty) return token;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return null;
  }

  /// Check if push token is registered
  bool get isPushTokenRegistered => _pushTokenRegistered;

  /// Listen for token refresh and update Klaviyo
  void setupTokenRefreshListener() {
    if (kIsWeb || _tokenRefreshSubscription != null) return;

    // The stream carries the FCM token, which is only what Klaviyo wants on
    // Android. Re-read the platform token instead of forwarding the value, so
    // iOS keeps sending its APNs token.
    _tokenRefreshSubscription =
        FirebaseMessaging.instance.onTokenRefresh.listen((_) async {
      if (!_isInitialized) return;
      final sent = await registerPushTokenIfPermitted();
      if (sent) debugPrint('Klaviyo: Token refreshed and sent');
    });
  }

  /// Start collecting tapped Klaviyo notifications from the native side.
  ///
  /// Android: Klaviyo's SDK shows the notification itself and reopens the app
  /// with the payload as intent extras, which firebase_messaging does not
  /// report as an opened message. iOS: the app delegate handles the tap
  /// natively and passes the payload on. Both keep it until it is taken
  /// here, so cold starts are covered as well.
  ///
  /// The SDK's own `onPushNotification` stream is not used for this: on
  /// Android it loses the tap that starts the app, which is the common case.
  void _setupPushOpenChannel() {
    if (kIsWeb || _pushOpenChannelReady) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    _pushOpenChannelReady = true;

    _pushOpenChannel.setMethodCallHandler((call) async {
      if (call.method == 'onPushOpened') {
        await _takePendingPushOpen();
      }
    });
    unawaited(_takePendingPushOpen());
  }

  Future<void> _takePendingPushOpen() async {
    try {
      final payload = await _pushOpenChannel
          .invokeMapMethod<String, String>('takePendingPush');
      if (payload == null || !payload.containsKey('_k')) return;

      // Klaviyo itself has already been told about the open natively.
      await onPushOpened?.call(routingDataFromKlaviyoPush(payload));
    } catch (e) {
      debugPrint('Klaviyo push open handling error: $e');
    }
  }

  /// What analytics should record about a tapped Klaviyo push, read from
  /// Klaviyo's tracking block (`_k`): which campaign or flow message it was.
  static Map<String, Object> pushOpenProperties(Map<String, dynamic> payload) {
    final properties = <String, Object>{};

    void put(String key, Object? value) {
      if (value == null) return;
      final text = '$value';
      if (text.isNotEmpty) properties[key] = text;
    }

    put('title', payload['title']);

    final rawTracking = payload['_k'];
    if (rawTracking is! String || rawTracking.isEmpty) return properties;
    try {
      final tracking = jsonDecode(rawTracking);
      if (tracking is Map) {
        put('campaign_name', tracking['Message Name']);
        put('message_type', tracking['Message Type']);
        put('message_id', tracking[r'$message']);
        put('flow_id', tracking[r'$flow']);
      }
    } catch (e) {
      debugPrint('Klaviyo: unreadable push tracking block: $e');
    }
    return properties;
  }

  /// Flatten a Klaviyo push payload into the keys notification routing reads
  /// (`link`, `registration_number`, `screen`, ...). The key-value pairs set
  /// on a push in Klaviyo arrive as one JSON string under `key_value_pairs`.
  ///
  /// Klaviyo's own `url` (its deep-link field) is dropped: the native side
  /// has already opened it by the time the payload gets here, and routing it
  /// again would open the link twice.
  @visibleForTesting
  static Map<String, dynamic> routingDataFromKlaviyoPush(
      Map<String, String> payload) {
    final data = <String, dynamic>{...payload}..remove('url');
    final rawPairs = payload['key_value_pairs'];
    if (rawPairs == null || rawPairs.isEmpty) return data;

    try {
      final decoded = jsonDecode(rawPairs);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          if (value != null) data['$key'] = '$value';
        });
      }
    } catch (e) {
      debugPrint('Klaviyo: unreadable key_value_pairs: $e');
    }
    return data;
  }
}
