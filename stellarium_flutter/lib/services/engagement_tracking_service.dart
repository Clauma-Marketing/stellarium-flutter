import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Callback type for triggering paywall
typedef PaywallCallback = void Function();

/// Service for tracking cumulative user engagement time and triggering paywall
/// after 2 minutes of total sky viewing time.
///
/// Tracks cumulative viewing time across all sessions and triggers paywall
/// once per install when the 2-minute threshold is reached.
class EngagementTrackingService {
  static const String _accumulatedSecondsKey = 'engagement_accumulated_seconds';
  static const String _paywallTriggeredKey = 'engagement_paywall_triggered';

  /// Milestone at which to trigger paywall (in minutes)
  static const int paywallMinutes = 2;

  static EngagementTrackingService? _instance;

  Duration _accumulatedTime = Duration.zero;
  DateTime? _sessionStart;
  Timer? _checkTimer;
  bool _isLoaded = false;
  bool _isTracking = false;
  bool _paywallTriggered = false;

  /// Callback to trigger when paywall should be shown
  PaywallCallback? onPaywallTrigger;

  EngagementTrackingService._();

  /// Get the singleton instance
  static EngagementTrackingService get instance {
    _instance ??= EngagementTrackingService._();
    return _instance!;
  }

  /// Load saved state from preferences
  Future<void> load() async {
    if (_isLoaded) return;

    final prefs = await SharedPreferences.getInstance();

    // Load accumulated time
    final seconds = prefs.getInt(_accumulatedSecondsKey) ?? 0;
    _accumulatedTime = Duration(seconds: seconds);

    // Load whether paywall was already triggered
    _paywallTriggered = prefs.getBool(_paywallTriggeredKey) ?? false;

    _isLoaded = true;

    debugPrint('EngagementTrackingService: loaded, '
        'accumulated=${_accumulatedTime.inSeconds}s, '
        'paywallTriggered=$_paywallTriggered');
  }

  /// Start tracking engagement time.
  /// Call this when the sky view becomes active.
  void startTracking() {
    // Don't track on web
    if (kIsWeb) return;

    // Ensure loaded
    if (!_isLoaded) {
      debugPrint('EngagementTrackingService: not loaded yet, skipping startTracking');
      return;
    }

    // Don't track if paywall was already triggered and handled
    if (_paywallTriggered) {
      debugPrint('EngagementTrackingService: paywall already triggered, not tracking');
      return;
    }

    if (_isTracking) return;

    _sessionStart = DateTime.now();
    _isTracking = true;
    _startCheckTimer();

    debugPrint('EngagementTrackingService: started tracking');
  }

  /// Stop tracking engagement time.
  /// Call this when leaving the sky view or app is closing.
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    _cancelCheckTimer();
    await _saveSessionTime();
    _sessionStart = null;
    _isTracking = false;

    debugPrint('EngagementTrackingService: stopped tracking, '
        'total accumulated=${_accumulatedTime.inSeconds}s');
  }

  /// Pause tracking (e.g., when app goes to background)
  Future<void> pauseTracking() async {
    if (!_isTracking) return;

    _cancelCheckTimer();
    await _saveSessionTime();

    debugPrint('EngagementTrackingService: paused tracking');
  }

  /// Resume tracking (e.g., when app comes to foreground)
  void resumeTracking() {
    if (kIsWeb || !_isLoaded || _paywallTriggered) return;
    if (!_isTracking) return;

    _sessionStart = DateTime.now();
    _startCheckTimer();

    debugPrint('EngagementTrackingService: resumed tracking');
  }

  void _startCheckTimer() {
    _cancelCheckTimer();

    // Check every 10 seconds for milestone trigger
    _checkTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkMilestone();
    });
  }

  void _cancelCheckTimer() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  Future<void> _saveSessionTime() async {
    if (_sessionStart == null) return;

    final sessionDuration = DateTime.now().difference(_sessionStart!);
    _accumulatedTime += sessionDuration;
    _sessionStart = DateTime.now(); // Reset for next accumulation

    // Persist to storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accumulatedSecondsKey, _accumulatedTime.inSeconds);

    debugPrint('EngagementTrackingService: saved session (${sessionDuration.inSeconds}s), '
        'total=${_accumulatedTime.inSeconds}s');
  }

  void _checkMilestone() {
    if (_paywallTriggered) return;

    // Calculate current total time including current session
    Duration totalTime = _accumulatedTime;
    if (_sessionStart != null) {
      totalTime += DateTime.now().difference(_sessionStart!);
    }

    final totalMinutes = totalTime.inMinutes;

    debugPrint('EngagementTrackingService: total time = ${totalTime.inSeconds}s (${totalMinutes}min)');

    if (totalMinutes >= paywallMinutes) {
      _triggerPaywall();
    }
  }

  Future<void> _triggerPaywall() async {
    if (_paywallTriggered) return;

    debugPrint('EngagementTrackingService: triggering paywall after $paywallMinutes minutes cumulative');

    _paywallTriggered = true;
    _cancelCheckTimer();

    // Persist that paywall was triggered
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_paywallTriggeredKey, true);

    // Trigger the callback
    onPaywallTrigger?.call();
  }

  /// Reset the paywall trigger state (call when user dismisses without subscribing)
  /// This allows the paywall to be shown again on next app launch
  Future<void> resetPaywallTrigger() async {
    _paywallTriggered = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_paywallTriggeredKey, false);
    debugPrint('EngagementTrackingService: paywall trigger reset');
  }

  /// Mark paywall as permanently handled (user subscribed or has registration)
  Future<void> markPaywallHandled() async {
    _paywallTriggered = true;
    _cancelCheckTimer();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_paywallTriggeredKey, true);
    debugPrint('EngagementTrackingService: paywall marked as handled');
  }

  /// Get current accumulated time (for debugging)
  Duration get accumulatedTime {
    Duration total = _accumulatedTime;
    if (_sessionStart != null) {
      total += DateTime.now().difference(_sessionStart!);
    }
    return total;
  }

  /// Check if paywall was already triggered
  bool get paywallTriggered => _paywallTriggered;

  /// Reset all tracking data (for testing purposes)
  Future<void> resetForTesting() async {
    _accumulatedTime = Duration.zero;
    _paywallTriggered = false;
    _sessionStart = null;
    _isTracking = false;
    _cancelCheckTimer();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accumulatedSecondsKey);
    await prefs.remove(_paywallTriggeredKey);

    debugPrint('EngagementTrackingService: reset for testing');
  }
}
