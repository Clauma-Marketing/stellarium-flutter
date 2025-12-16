import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Service for tracking analytics events with Firebase Analytics.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  static AnalyticsService get instance => _instance;

  AnalyticsService._internal();

  FirebaseAnalytics? _analytics;
  FirebaseAnalyticsObserver? _observer;

  /// Initialize analytics (call after Firebase.initializeApp)
  void initialize() {
    if (kIsWeb) return; // Skip on web for now
    _analytics = FirebaseAnalytics.instance;
    _observer = FirebaseAnalyticsObserver(analytics: _analytics!);
  }

  /// Get the analytics observer for navigation tracking
  FirebaseAnalyticsObserver? get observer => _observer;

  /// Log a custom event
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (_analytics == null) return;
    try {
      await _analytics!.logEvent(name: name, parameters: parameters);
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Log screen view
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    if (_analytics == null) return;
    try {
      await _analytics!.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Log when user completes onboarding
  Future<void> logOnboardingComplete() async {
    await logEvent(name: 'onboarding_complete');
  }

  /// Log when user views subscription screen
  Future<void> logSubscriptionScreenView() async {
    await logScreenView(screenName: 'subscription_screen');
  }

  /// Log when user starts a subscription
  Future<void> logSubscriptionStart({String? productId}) async {
    await logEvent(
      name: 'subscription_start',
      parameters: productId != null ? {'product_id': productId} : null,
    );
  }

  /// Log when user searches for a star
  Future<void> logStarSearch({required String query}) async {
    await logEvent(
      name: 'star_search',
      parameters: {'query': query},
    );
  }

  /// Log when user selects a star
  Future<void> logStarSelect({required String starName}) async {
    await logEvent(
      name: 'star_select',
      parameters: {'star_name': starName},
    );
  }

  /// Log when user saves a star
  Future<void> logStarSave({required String starName}) async {
    await logEvent(
      name: 'star_save',
      parameters: {'star_name': starName},
    );
  }

  /// Log when user changes location
  Future<void> logLocationChange() async {
    await logEvent(name: 'location_change');
  }

  /// Set user property
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    if (_analytics == null) return;
    try {
      await _analytics!.setUserProperty(name: name, value: value);
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  // ==================== Registration Number Search ====================

  /// Log when user searches by registration number
  Future<void> logRegistrationSearch({required String registrationNumber}) async {
    await logEvent(
      name: 'registration_search',
      parameters: {'registration_number': registrationNumber},
    );
  }

  /// Log when registration search finds a star
  Future<void> logRegistrationFound({required String registrationNumber, String? starName}) async {
    await logEvent(
      name: 'registration_found',
      parameters: {
        'registration_number': registrationNumber,
        if (starName != null) 'star_name': starName,
      },
    );
  }

  /// Log when registration search fails
  Future<void> logRegistrationNotFound({required String registrationNumber}) async {
    await logEvent(
      name: 'registration_not_found',
      parameters: {'registration_number': registrationNumber},
    );
  }

  // ==================== Certificate Scanner ====================

  /// Log when user opens certificate scanner
  Future<void> logScannerOpened() async {
    await logEvent(name: 'scanner_opened');
  }

  /// Log when scanner detects a registration number
  Future<void> logScannerDetected({required String registrationNumber}) async {
    await logEvent(
      name: 'scanner_detected',
      parameters: {'registration_number': registrationNumber},
    );
  }

  /// Log when user cancels scanner
  Future<void> logScannerCancelled() async {
    await logEvent(name: 'scanner_cancelled');
  }

  // ==================== Star Actions ====================

  /// Log when user removes a saved star
  Future<void> logStarRemove({required String starName}) async {
    await logEvent(
      name: 'star_remove',
      parameters: {'star_name': starName},
    );
  }

  /// Log when user points at a star
  Future<void> logStarPointAt({required String starName}) async {
    await logEvent(
      name: 'star_point_at',
      parameters: {'star_name': starName},
    );
  }

  /// Log when user views star in 3D
  Future<void> logStarView3D({required String starName}) async {
    await logEvent(
      name: 'star_view_3d',
      parameters: {'star_name': starName},
    );
  }

  /// Log when user toggles 24h star path
  Future<void> logStarPathToggle({required String starName, required bool enabled}) async {
    await logEvent(
      name: 'star_path_toggle',
      parameters: {'star_name': starName, 'enabled': enabled.toString()},
    );
  }

  /// Log when user toggles star notifications
  Future<void> logStarNotificationToggle({required String starName, required bool enabled}) async {
    await logEvent(
      name: 'star_notification_toggle',
      parameters: {'star_name': starName, 'enabled': enabled.toString()},
    );
  }

  /// Log when user clicks to name a star (external link)
  Future<void> logNameStarClicked() async {
    await logEvent(name: 'name_star_clicked');
  }

  // ==================== Bottom Bar Actions ====================

  /// Log when user focuses on search bar
  Future<void> logSearchFocused() async {
    await logEvent(name: 'search_focused');
  }

  /// Log when user selects a search suggestion
  Future<void> logSearchSuggestionSelected({required String suggestion}) async {
    await logEvent(
      name: 'search_suggestion_selected',
      parameters: {'suggestion': suggestion},
    );
  }

  /// Log when user toggles atmosphere
  Future<void> logAtmosphereToggle({required bool enabled}) async {
    await logEvent(
      name: 'atmosphere_toggle',
      parameters: {'enabled': enabled.toString()},
    );
  }

  /// Log when user toggles gyroscope
  Future<void> logGyroscopeToggle({required bool enabled}) async {
    await logEvent(
      name: 'gyroscope_toggle',
      parameters: {'enabled': enabled.toString()},
    );
  }

  /// Log when user opens menu
  Future<void> logMenuOpened() async {
    await logEvent(name: 'menu_opened');
  }

  // ==================== Settings Actions ====================

  /// Log when user changes a visual setting
  Future<void> logSettingChanged({required String setting, required bool enabled}) async {
    await logEvent(
      name: 'setting_changed',
      parameters: {'setting': setting, 'enabled': enabled.toString()},
    );
  }

  /// Log when user opens My Stars
  Future<void> logMyStarsOpened() async {
    await logEvent(name: 'my_stars_opened');
  }

  /// Log when user opens Time/Location sheet
  Future<void> logTimeLocationOpened() async {
    await logEvent(name: 'time_location_opened');
  }

  /// Log when user opens Visual Effects
  Future<void> logVisualEffectsOpened() async {
    await logEvent(name: 'visual_effects_opened');
  }

  /// Log when user opens App Settings
  Future<void> logAppSettingsOpened() async {
    await logEvent(name: 'app_settings_opened');
  }

  /// Log when user restores purchases
  Future<void> logRestorePurchases({required bool success}) async {
    await logEvent(
      name: 'restore_purchases',
      parameters: {'success': success.toString()},
    );
  }

  /// Log when user changes language
  Future<void> logLanguageChanged({required String language}) async {
    await logEvent(
      name: 'language_changed',
      parameters: {'language': language},
    );
  }

  /// Log when user toggles global notifications
  Future<void> logGlobalNotificationToggle({required bool enabled}) async {
    await logEvent(
      name: 'global_notification_toggle',
      parameters: {'enabled': enabled.toString()},
    );
  }

  // ==================== Time Controls ====================

  /// Log when user changes time
  Future<void> logTimeChanged() async {
    await logEvent(name: 'time_changed');
  }

  /// Log when user plays/pauses time animation
  Future<void> logTimeAnimationToggle({required bool playing}) async {
    await logEvent(
      name: 'time_animation_toggle',
      parameters: {'playing': playing.toString()},
    );
  }

  // ==================== Onboarding ====================

  /// Log when user grants a permission
  Future<void> logPermissionGranted({required String permission}) async {
    await logEvent(
      name: 'permission_granted',
      parameters: {'permission': permission},
    );
  }

  /// Log when user skips a permission
  Future<void> logPermissionSkipped({required String permission}) async {
    await logEvent(
      name: 'permission_skipped',
      parameters: {'permission': permission},
    );
  }

  /// Log onboarding page view
  Future<void> logOnboardingPageView({required String page, required int pageIndex}) async {
    await logEvent(
      name: 'onboarding_page_view',
      parameters: {'page': page, 'page_index': pageIndex},
    );
  }
}
