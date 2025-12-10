import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'star_notification_service.dart';

/// Task name for star visibility calculations
const String starVisibilityTask = 'calculateStarVisibility';

/// Unique task name for periodic background work
const String starVisibilityPeriodicTask = 'starVisibilityPeriodic';

/// Background task callback dispatcher
/// This must be a top-level function
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('Background task executing: $task');

    try {
      switch (task) {
        case starVisibilityTask:
        case starVisibilityPeriodicTask:
          // Initialize notification service
          await StarNotificationService.instance.initialize();
          // Calculate and schedule notifications
          await StarNotificationService.instance.scheduleAllStarNotifications();
          debugPrint('Background star visibility calculation completed');
          return true;

        default:
          debugPrint('Unknown background task: $task');
          return false;
      }
    } catch (e, stackTrace) {
      debugPrint('Background task error: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  });
}

/// Service for managing background tasks
class BackgroundService {
  /// Initialize WorkManager
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
    debugPrint('BackgroundService initialized');
  }

  /// Register periodic background task for star visibility calculations
  /// Runs every 6 hours to recalculate visibility and schedule notifications
  static Future<void> registerPeriodicTask() async {
    // Cancel any existing tasks first
    await Workmanager().cancelByUniqueName(starVisibilityPeriodicTask);

    // Register new periodic task
    await Workmanager().registerPeriodicTask(
      starVisibilityPeriodicTask,
      starVisibilityTask,
      frequency: const Duration(hours: 6),
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 15),
    );

    debugPrint('Registered periodic star visibility task (every 6 hours)');
  }

  /// Run immediate one-time calculation
  static Future<void> runImmediateCalculation() async {
    await Workmanager().registerOneOffTask(
      'immediateStarVisibility_${DateTime.now().millisecondsSinceEpoch}',
      starVisibilityTask,
      constraints: Constraints(
        networkType: NetworkType.not_required,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

    debugPrint('Scheduled immediate star visibility calculation');
  }

  /// Cancel all background tasks
  static Future<void> cancelAllTasks() async {
    await Workmanager().cancelAll();
    debugPrint('Cancelled all background tasks');
  }

  /// Cancel the periodic star visibility task
  static Future<void> cancelPeriodicTask() async {
    await Workmanager().cancelByUniqueName(starVisibilityPeriodicTask);
    debugPrint('Cancelled periodic star visibility task');
  }
}
