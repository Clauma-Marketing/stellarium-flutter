import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing in-app review prompts.
///
/// Shows a review prompt after the user has been viewing the sky for a
/// specified duration. Only prompts once per install to avoid annoying users.
class AppReviewService {
  static const String _hasRequestedReviewKey = 'has_requested_app_review';

  /// Duration of sky viewing before showing review prompt (1 minute 30 seconds)
  static const Duration reviewTriggerDuration = Duration(minutes: 1, seconds: 30);

  static AppReviewService? _instance;

  final InAppReview _inAppReview = InAppReview.instance;
  Timer? _reviewTimer;
  DateTime? _viewingStartTime;
  bool _hasRequestedReview = false;
  bool _isLoaded = false;

  AppReviewService._();

  /// Get the singleton instance
  static AppReviewService get instance {
    _instance ??= AppReviewService._();
    return _instance!;
  }

  /// Load saved state from preferences
  Future<void> load() async {
    if (_isLoaded) return;

    final prefs = await SharedPreferences.getInstance();
    _hasRequestedReview = prefs.getBool(_hasRequestedReviewKey) ?? false;
    _isLoaded = true;

    debugPrint('AppReviewService: loaded, hasRequestedReview=$_hasRequestedReview');
  }

  /// Start tracking sky viewing time.
  /// Call this when the user enters the home screen with sky view.
  void startTracking() {
    // Don't track on web (no app store review available)
    if (kIsWeb) return;

    // Don't track if already requested review
    if (_hasRequestedReview) {
      debugPrint('AppReviewService: already requested review, not tracking');
      return;
    }

    _viewingStartTime = DateTime.now();
    _startReviewTimer();

    debugPrint('AppReviewService: started tracking sky viewing time');
  }

  /// Stop tracking sky viewing time.
  /// Call this when the user leaves the home screen.
  void stopTracking() {
    _cancelReviewTimer();
    _viewingStartTime = null;
    debugPrint('AppReviewService: stopped tracking');
  }

  /// Pause tracking (e.g., when app goes to background)
  void pauseTracking() {
    _cancelReviewTimer();
    debugPrint('AppReviewService: paused tracking');
  }

  /// Resume tracking (e.g., when app comes to foreground)
  void resumeTracking() {
    if (kIsWeb || _hasRequestedReview || _viewingStartTime == null) return;

    // Check if we've already exceeded the duration while paused
    final elapsed = DateTime.now().difference(_viewingStartTime!);
    if (elapsed >= reviewTriggerDuration) {
      _requestReview();
    } else {
      // Restart timer for remaining time
      _startReviewTimer();
    }

    debugPrint('AppReviewService: resumed tracking, elapsed=${elapsed.inSeconds}s');
  }

  void _startReviewTimer() {
    _cancelReviewTimer();

    if (_viewingStartTime == null) return;

    final elapsed = DateTime.now().difference(_viewingStartTime!);
    final remaining = reviewTriggerDuration - elapsed;

    if (remaining.isNegative || remaining == Duration.zero) {
      // Already exceeded duration
      _requestReview();
      return;
    }

    _reviewTimer = Timer(remaining, _requestReview);
    debugPrint('AppReviewService: timer set for ${remaining.inSeconds}s');
  }

  void _cancelReviewTimer() {
    _reviewTimer?.cancel();
    _reviewTimer = null;
  }

  Future<void> _requestReview() async {
    if (_hasRequestedReview) return;

    _cancelReviewTimer();

    try {
      // Check if the device supports in-app review
      final isAvailable = await _inAppReview.isAvailable();

      if (isAvailable) {
        debugPrint('AppReviewService: requesting in-app review');
        await _inAppReview.requestReview();

        // Mark as requested (regardless of whether user actually reviewed)
        // The system controls whether the dialog actually shows
        await _markReviewRequested();
      } else {
        debugPrint('AppReviewService: in-app review not available');
        // Still mark as requested to avoid retrying
        await _markReviewRequested();
      }
    } catch (e) {
      debugPrint('AppReviewService: error requesting review: $e');
      // Don't mark as requested on error, so it can retry next time
    }
  }

  Future<void> _markReviewRequested() async {
    _hasRequestedReview = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasRequestedReviewKey, true);
    debugPrint('AppReviewService: marked review as requested');
  }

  /// Reset the review state (for testing purposes)
  Future<void> resetForTesting() async {
    _hasRequestedReview = false;
    _viewingStartTime = null;
    _cancelReviewTimer();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hasRequestedReviewKey);

    debugPrint('AppReviewService: reset for testing');
  }
}
