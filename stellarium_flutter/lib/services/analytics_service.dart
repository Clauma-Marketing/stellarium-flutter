import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Service for tracking analytics events.
///
/// Every event goes to Firebase Analytics and, unless a method sends its own
/// PostHog event under a different name, to PostHog as well - so PostHog
/// funnels can use the whole event set, not a hand-picked subset.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  static AnalyticsService get instance => _instance;

  AnalyticsService._internal();

  FirebaseAnalytics? _analytics;
  FirebaseAnalyticsObserver? _observer;
  Map<String, Object>? _lastUserProfile;

  /// Initialize analytics (call after Firebase.initializeApp)
  void initialize() {
    if (kIsWeb) return; // Skip on web for now
    _analytics = FirebaseAnalytics.instance;
    _observer = FirebaseAnalyticsObserver(analytics: _analytics!);
  }

  /// Get the analytics observer for navigation tracking
  FirebaseAnalyticsObserver? get observer => _observer;

  /// Log a custom event to Firebase and PostHog.
  ///
  /// Pass [mirrorToPosthog] false when the caller captures its own PostHog
  /// event for the same action, to avoid counting it twice there.
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
    bool mirrorToPosthog = true,
  }) async {
    if (mirrorToPosthog) _captureInPosthog(name, parameters);
    if (_analytics == null) return;
    try {
      await _analytics!.logEvent(name: name, parameters: parameters);
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Fire-and-forget PostHog capture; analytics must never break a user flow.
  /// PostHog itself drops the event when the user declined analytics consent.
  void _captureInPosthog(String name, Map<String, Object>? properties) {
    unawaited(
      Posthog()
          .capture(eventName: name, properties: properties)
          .catchError((Object e) => debugPrint('PostHog capture error: $e')),
    );
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
    await logEvent(name: 'onboarding_complete', mirrorToPosthog: false);
    unawaited(Posthog().capture(eventName: 'onboarding_completed'));
  }

  /// Log when user views subscription screen
  Future<void> logSubscriptionScreenView() async {
    await logScreenView(screenName: 'subscription_screen');
    unawaited(Posthog().capture(eventName: 'subscription_screen_viewed'));
  }

  /// Log that a paywall was shown. [placement] says which one: `onboarding`
  /// (skippable, after onboarding), `engagement_gate` (forced, after the free
  /// preview) or `settings` (opened by the user).
  Future<void> logPaywallViewed({required String placement}) async {
    await logEvent(
      name: 'paywall_viewed',
      parameters: {'placement': placement},
    );
  }

  /// Log a completed purchase. Not for restores - see [logSubscriptionRestored].
  Future<void> logSubscriptionStart({
    String? productId,
    String? placement,
  }) async {
    final properties = <String, Object>{
      if (productId != null) 'product_id': productId,
      if (placement != null) 'placement': placement,
    };
    await logEvent(
      name: 'subscription_start',
      parameters: properties.isEmpty ? null : properties,
      mirrorToPosthog: false,
    );
    _captureInPosthog(
      'subscription_purchased',
      properties.isEmpty ? null : properties,
    );
  }

  /// Log that the user picked a plan on a paywall.
  Future<void> logPaywallProductSelected({
    required String productId,
    required String placement,
  }) async {
    await logEvent(
      name: 'paywall_product_selected',
      parameters: {'product_id': productId, 'placement': placement},
    );
  }

  /// Log that the store purchase sheet was opened for a plan.
  Future<void> logPurchaseStarted({
    required String productId,
    required String placement,
  }) async {
    await logEvent(
      name: 'purchase_started',
      parameters: {'product_id': productId, 'placement': placement},
    );
  }

  /// Log that the user backed out of the store purchase sheet.
  Future<void> logPurchaseCancelled({
    required String productId,
    required String placement,
  }) async {
    await logEvent(
      name: 'purchase_cancelled',
      parameters: {'product_id': productId, 'placement': placement},
    );
  }

  /// Log a purchase that failed (store error, declined payment, ...).
  Future<void> logPurchaseFailed({
    required String productId,
    required String placement,
    required int errorCode,
    required String errorMessage,
  }) async {
    await logEvent(
      name: 'purchase_failed',
      parameters: {
        'product_id': productId,
        'placement': placement,
        'error_code': errorCode,
        // Firebase rejects parameter values over 100 characters.
        'error_message': errorMessage.length > 100
            ? errorMessage.substring(0, 100)
            : errorMessage,
      },
    );
  }

  /// Log that an existing purchase was restored from a paywall. Kept apart
  /// from purchases so restores do not inflate conversion numbers.
  Future<void> logSubscriptionRestored({required String placement}) async {
    await logEvent(
      name: 'subscription_restored',
      parameters: {'placement': placement},
    );
  }

  /// Log when user dismisses the subscription paywall without subscribing
  Future<void> logSubscriptionDismissed() async {
    await logEvent(name: 'subscription_dismissed');
  }

  /// Log when the free-preview-ending warning banner is shown
  Future<void> logEngagementGateWarningShown() async {
    await logEvent(name: 'engagement_gate_warning_shown');
  }

  /// Log when user taps the warning banner's CTA to see plans
  Future<void> logEngagementGateWarningCta() async {
    await logEvent(name: 'engagement_gate_warning_cta_tapped');
  }

  /// Log when user searches for a star
  Future<void> logStarSearch({required String query}) async {
    await logEvent(
      name: 'star_search',
      mirrorToPosthog: false,
      parameters: {'query': query},
    );
    unawaited(Posthog().capture(
      eventName: 'star_searched',
      properties: {'query': query},
    ));
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
      mirrorToPosthog: false,
      parameters: {'star_name': starName},
    );
    unawaited(Posthog().capture(
      eventName: 'star_saved',
      properties: {'star_name': starName},
    ));
  }

  /// Log when user changes location
  Future<void> logLocationChange() async {
    await logEvent(name: 'location_change');
  }

  /// Describe who the user is, so any event can be split by it: star owner
  /// or explorer, subscriber or not, how many stars saved, app language.
  /// Sent as PostHog person and event properties and Firebase user
  /// properties; a no-op when nothing changed since the last call.
  Future<void> setUserProfile({
    required bool isStarOwner,
    required int savedStarCount,
    bool? isSubscriber,
    String? language,
  }) async {
    final profile = <String, Object>{
      'is_star_owner': isStarOwner,
      'saved_star_count': savedStarCount,
      if (isSubscriber != null) 'is_subscriber': isSubscriber,
      if (language != null) 'app_language': language,
    };
    if (mapEquals(profile, _lastUserProfile)) return;
    _lastUserProfile = profile;

    for (final entry in profile.entries) {
      unawaited(Posthog()
          .register(entry.key, entry.value)
          .catchError((Object e) => debugPrint('PostHog register error: $e')));
      unawaited(setUserProperty(name: entry.key, value: '${entry.value}'));
    }
    unawaited(Posthog()
        .setPersonProperties(userPropertiesToSet: profile)
        .catchError((Object e) => debugPrint('PostHog profile error: $e')));
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
      mirrorToPosthog: false,
      parameters: {'star_name': starName},
    );
    unawaited(Posthog().capture(
      eventName: 'star_pointed_at',
      properties: {'star_name': starName},
    ));
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
  ///
  /// [placement] is one of `ShopLinkPlacement`, [destination] the shop URL
  /// being opened and [hipNumber] the star the user was looking at, if any.
  Future<void> logNameStarClicked({
    required String placement,
    required String languageCode,
    required Uri destination,
    String? hipNumber,
  }) async {
    final properties = <String, Object>{
      'placement': placement,
      'language': languageCode,
      'destination_host': destination.host,
      if (hipNumber != null && hipNumber.isNotEmpty) 'hip': hipNumber,
    };
    // logEvent mirrors this to PostHog as well.
    await logEvent(name: 'name_star_clicked', parameters: properties);
  }

  /// Log when user indicates they already have a named star
  Future<void> logHaveNamedStarClicked() async {
    await logEvent(name: 'have_named_star_clicked');
  }

  /// Log when user chooses to start exploring without a named star
  Future<void> logStartExploringClicked() async {
    await logEvent(name: 'start_exploring_clicked');
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

  // ==================== Push notifications ====================

  /// Log that the user tapped a push notification. [source] is `klaviyo`
  /// (marketing pushes; [properties] then carry `campaign_name`) or
  /// `firebase` (star visibility alerts from our Cloud Functions).
  Future<void> logPushOpened({
    required String source,
    Map<String, Object> properties = const {},
  }) async {
    await logEvent(
      name: 'push_opened',
      parameters: {'source': source, ...properties},
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

  /// Log sky preview star tap during onboarding
  Future<void> logSkyPreviewStarTap({required String starName}) async {
    await logEvent(
      name: 'onboarding_sky_preview_star_tap',
      parameters: {'star_name': starName},
    );
  }

  // ==================== Engagement Tracking ====================

  /// Log that the user's total sky-viewing time passed [minutes].
  /// Fired once per install for each milestone.
  Future<void> logSkyTimeMilestone({required int minutes}) async {
    await logEvent(
      name: 'sky_time_milestone',
      parameters: {'minutes': minutes},
    );
  }

  /// Log that the sky finished loading, and how long that took.
  Future<void> logSkyReady({required int loadMs}) async {
    await logEvent(name: 'sky_ready', parameters: {'load_ms': loadMs});
  }

  /// Log that the user jumped back to the current time.
  Future<void> logTimeReset() async {
    await logEvent(name: 'time_reset_to_now');
  }

  /// Log that the user picked another date to view.
  Future<void> logDateChanged() async {
    await logEvent(name: 'date_changed');
  }

  /// Log that the store review prompt was requested. [available] is false
  /// when the device cannot show it.
  Future<void> logReviewPromptRequested({required bool available}) async {
    await logEvent(
      name: 'review_prompt_requested',
      parameters: {'available': available.toString()},
    );
  }

  /// Log sky view milestone for Firebase In-App Messaging triggers.
  /// Fires events like 'sky_view_2_min', 'sky_view_5_min', 'sky_view_10_min'.
  Future<void> logSkyViewMilestone({required int minutes}) async {
    await logEvent(
      name: 'sky_view_${minutes}_min',
      parameters: {'minutes': minutes},
    );
    debugPrint('Analytics: logged sky_view_${minutes}_min event');
  }
}
