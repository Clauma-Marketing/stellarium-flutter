import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';

/// Measures how long a user has spent looking at the sky, in total across
/// sessions, and reports each milestone once per install.
///
/// Separate from [EngagementTrackingService], which stops counting as soon as
/// the paywall gate is reached and exists to trigger that gate, not to
/// measure engagement.
class SkyTimeTrackingService {
  /// Total sky-viewing minutes worth reporting.
  static const List<int> milestoneMinutes = [1, 2, 5, 10, 30, 60];

  static const String _accumulatedSecondsKey = 'sky_time_accumulated_seconds';
  static const String _lastMilestoneKey = 'sky_time_last_milestone_minutes';
  static const Duration _checkInterval = Duration(seconds: 15);

  static SkyTimeTrackingService? _instance;

  SkyTimeTrackingService._();

  static SkyTimeTrackingService get instance {
    _instance ??= SkyTimeTrackingService._();
    return _instance!;
  }

  Duration _accumulated = Duration.zero;
  int _lastMilestone = 0;
  DateTime? _segmentStart;
  Timer? _timer;
  bool _isLoaded = false;
  bool _isActive = false;

  bool get _allMilestonesReached => _lastMilestone >= milestoneMinutes.last;

  Future<void> load() async {
    if (_isLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    _accumulated = Duration(seconds: prefs.getInt(_accumulatedSecondsKey) ?? 0);
    _lastMilestone = prefs.getInt(_lastMilestoneKey) ?? 0;
    _isLoaded = true;
  }

  /// Call when the sky becomes visible.
  Future<void> start() async {
    await load();
    if (_isActive || _allMilestonesReached) return;
    _isActive = true;
    _beginSegment();
  }

  /// Call when the app goes to the background.
  Future<void> pause() async {
    if (!_isActive) return;
    await _endSegment();
  }

  /// Call when the app returns to the foreground.
  void resume() {
    if (!_isActive || _segmentStart != null || _allMilestonesReached) return;
    _beginSegment();
  }

  /// Call when the sky screen is closed.
  Future<void> stop() async {
    if (!_isActive) return;
    _isActive = false;
    await _endSegment();
  }

  void _beginSegment() {
    _segmentStart = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(_checkInterval, (_) => _reportMilestones());
  }

  Future<void> _endSegment() async {
    _timer?.cancel();
    _timer = null;
    final start = _segmentStart;
    if (start == null) return;
    _segmentStart = null;
    _accumulated += DateTime.now().difference(start);
    await _reportMilestones();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accumulatedSecondsKey, _accumulated.inSeconds);
  }

  Future<void> _reportMilestones() async {
    var total = _accumulated;
    final start = _segmentStart;
    if (start != null) total += DateTime.now().difference(start);

    final reached = milestonesReached(
      lastReportedMinutes: _lastMilestone,
      totalSeconds: total.inSeconds,
    );
    if (reached.isEmpty) return;

    _lastMilestone = reached.last;
    for (final minutes in reached) {
      unawaited(AnalyticsService.instance.logSkyTimeMilestone(minutes: minutes));
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastMilestoneKey, _lastMilestone);

    if (_allMilestonesReached) {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Milestones passed at [totalSeconds] that are above [lastReportedMinutes].
  @visibleForTesting
  static List<int> milestonesReached({
    required int lastReportedMinutes,
    required int totalSeconds,
  }) {
    return [
      for (final minutes in milestoneMinutes)
        if (minutes > lastReportedMinutes && totalSeconds >= minutes * 60)
          minutes,
    ];
  }
}
