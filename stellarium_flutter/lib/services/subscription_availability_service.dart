import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/foundation.dart';

/// Service to check if subscription services (Adapty/Play Store) are available.
/// If unavailable (e.g., in China where Google services are blocked),
/// paywalls should be bypassed to allow users to use the app.
class SubscriptionAvailabilityService {
  static SubscriptionAvailabilityService? _instance;

  bool _isChecked = false;
  bool _isAvailable = true; // Default to true, set to false if check fails

  SubscriptionAvailabilityService._();

  static SubscriptionAvailabilityService get instance {
    _instance ??= SubscriptionAvailabilityService._();
    return _instance!;
  }

  /// Whether subscription services are available
  bool get isAvailable => _isAvailable;

  /// Whether the availability check has completed
  bool get isChecked => _isChecked;

  /// Check if subscription services (Adapty) are reachable.
  /// This should be called once at app startup.
  /// Returns true if available, false if unavailable.
  Future<bool> checkAvailability() async {
    if (_isChecked) return _isAvailable;

    // Skip check on web
    if (kIsWeb) {
      _isChecked = true;
      _isAvailable = false; // Subscriptions not supported on web
      return _isAvailable;
    }

    debugPrint('SubscriptionAvailability: Checking if Adapty is reachable...');

    try {
      // Try to get profile from Adapty with a timeout
      // This will fail if Google Play Services / Adapty is unreachable
      await Adapty().getProfile()
          .timeout(const Duration(seconds: 5));

      // If we get here, Adapty is reachable
      _isAvailable = true;
      _isChecked = true;
      debugPrint('SubscriptionAvailability: Adapty is available');
      return true;
    } on TimeoutException {
      // Timeout - likely blocked or very slow connection
      debugPrint('SubscriptionAvailability: Adapty timeout - services unavailable');
      _isAvailable = false;
      _isChecked = true;
      return false;
    } catch (e) {
      // Check if error indicates unavailability vs just no subscription
      final errorString = e.toString().toLowerCase();

      // These errors indicate the service itself is unavailable
      if (errorString.contains('network') ||
          errorString.contains('connection') ||
          errorString.contains('timeout') ||
          errorString.contains('unreachable') ||
          errorString.contains('play services') ||
          errorString.contains('billing') ||
          errorString.contains('unavailable')) {
        debugPrint('SubscriptionAvailability: Adapty unavailable - $e');
        _isAvailable = false;
        _isChecked = true;
        return false;
      }

      // Other errors (e.g., no active subscription) mean the service is working
      debugPrint('SubscriptionAvailability: Adapty reachable (error: $e)');
      _isAvailable = true;
      _isChecked = true;
      return true;
    }
  }

  /// Mark subscription services as unavailable.
  /// Call this when Adapty fails to initialize entirely.
  void markUnavailable() {
    _isAvailable = false;
    _isChecked = true;
    debugPrint('SubscriptionAvailability: Marked as unavailable');
  }

  /// Reset the check (for testing purposes)
  void reset() {
    _isChecked = false;
    _isAvailable = true;
  }
}
