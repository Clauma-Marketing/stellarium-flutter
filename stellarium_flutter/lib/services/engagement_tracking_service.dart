import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';

/// Service for tracking user engagement time and logging Firebase Analytics events
/// at specific milestones to trigger Firebase In-App Messaging campaigns.
///
/// Tracks cumulative viewing time across sessions and fires events only once per install.
class EngagementTrackingService {
  static const String _accumulatedSecondsKey = 'engagement_accumulated_seconds';
  static const String _triggeredMilestonesKey = 'engagement_triggered_milestones';

  /// Milestones at which to fire Analytics events
  static const List<int> milestoneMinutes = [2, 5, 10];

  static EngagementTrackingService? _instance;

  Duration _accumulatedTime = Duration.zero;
  Set<int> _triggeredMilestones = {};
  DateTime? _sessionStart;
  Timer? _checkTimer;
  bool _isLoaded = false;
  bool _isTracking = false;

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

    // Load triggered milestones
    final triggeredList = prefs.getStringList(_triggeredMilestonesKey) ?? [];
    _triggeredMilestones = triggeredList.map((s) => int.parse(s)).toSet();

    _isLoaded = true;

    debugPrint('EngagementTrackingService: loaded, '
        'accumulated=${_accumulatedTime.inSeconds}s, '
        'triggered=$_triggeredMilestones');
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

    // Check if all milestones already triggered
    if (_allMilestonesTriggered()) {
      debugPrint('EngagementTrackingService: all milestones already triggered, not tracking');
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
    if (kIsWeb || !_isLoaded || _allMilestonesTriggered()) return;
    if (!_isTracking) return;

    _sessionStart = DateTime.now();
    _startCheckTimer();

    debugPrint('EngagementTrackingService: resumed tracking');
  }

  bool _allMilestonesTriggered() {
    return milestoneMinutes.every((m) => _triggeredMilestones.contains(m));
  }

  void _startCheckTimer() {
    _cancelCheckTimer();

    // Check every 10 seconds for milestone triggers
    _checkTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkMilestones();
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

  void _checkMilestones() {
    // Calculate current total time including current session
    Duration totalTime = _accumulatedTime;
    if (_sessionStart != null) {
      totalTime += DateTime.now().difference(_sessionStart!);
    }

    final totalMinutes = totalTime.inMinutes;

    // Check each milestone
    for (final milestone in milestoneMinutes) {
      if (totalMinutes >= milestone && !_triggeredMilestones.contains(milestone)) {
        _triggerMilestone(milestone);
      }
    }

    // Stop tracking if all milestones triggered
    if (_allMilestonesTriggered()) {
      _cancelCheckTimer();
      debugPrint('EngagementTrackingService: all milestones triggered, stopping checks');
    }
  }

  Future<void> _triggerMilestone(int minutes) async {
    debugPrint('EngagementTrackingService: triggering milestone ${minutes}min');

    // Log Firebase Analytics event
    await AnalyticsService.instance.logSkyViewMilestone(minutes: minutes);

    // Mark as triggered
    _triggeredMilestones.add(minutes);

    // Persist triggered milestones
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _triggeredMilestonesKey,
      _triggeredMilestones.map((m) => m.toString()).toList(),
    );

    debugPrint('EngagementTrackingService: milestone ${minutes}min triggered and saved');
  }

  /// Reset all tracking data (for testing purposes)
  Future<void> resetForTesting() async {
    _accumulatedTime = Duration.zero;
    _triggeredMilestones = {};
    _sessionStart = null;
    _isTracking = false;
    _cancelCheckTimer();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accumulatedSecondsKey);
    await prefs.remove(_triggeredMilestonesKey);

    debugPrint('EngagementTrackingService: reset for testing');
  }

  /// Get current accumulated time (for debugging)
  Duration get accumulatedTime {
    Duration total = _accumulatedTime;
    if (_sessionStart != null) {
      total += DateTime.now().difference(_sessionStart!);
    }
    return total;
  }

  /// Get triggered milestones (for debugging)
  Set<int> get triggeredMilestones => Set.from(_triggeredMilestones);
}
