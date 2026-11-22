import 'package:Night_Sky_Guide/services/sky_time_tracking_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SkyTimeTrackingService.milestonesReached', () {
    test('nothing before the first minute', () {
      expect(
        SkyTimeTrackingService.milestonesReached(
            lastReportedMinutes: 0, totalSeconds: 59),
        isEmpty,
      );
    });

    test('reports a milestone exactly when it is reached', () {
      expect(
        SkyTimeTrackingService.milestonesReached(
            lastReportedMinutes: 0, totalSeconds: 60),
        [1],
      );
    });

    test('reports every milestone passed since the last report', () {
      expect(
        SkyTimeTrackingService.milestonesReached(
            lastReportedMinutes: 1, totalSeconds: 11 * 60),
        [2, 5, 10],
      );
    });

    test('never repeats a reported milestone', () {
      expect(
        SkyTimeTrackingService.milestonesReached(
            lastReportedMinutes: 10, totalSeconds: 11 * 60),
        isEmpty,
      );
    });

    test('stops after the last milestone', () {
      expect(
        SkyTimeTrackingService.milestonesReached(
            lastReportedMinutes: 60, totalSeconds: 100000),
        isEmpty,
      );
    });
  });
}
