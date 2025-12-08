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
}
