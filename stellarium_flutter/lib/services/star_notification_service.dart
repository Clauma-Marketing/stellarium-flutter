import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../features/onboarding/onboarding_service.dart';
import '../utils/star_visibility.dart';
import 'notification_preferences.dart';
import 'saved_stars_service.dart';

/// Service for scheduling star visibility notifications
class StarNotificationService {
  static final StarNotificationService instance = StarNotificationService._();

  StarNotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Notification channel for Android
  static const String _channelId = 'star_visibility';
  static const String _channelName = 'Star Visibility';
  static const String _channelDescription =
      'Notifications when your saved stars become visible';

  /// Callback for when a notification is tapped
  static void Function(String starId)? onNotificationTap;

  /// Initialize the notification system
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone data
    tz_data.initializeTimeZones();

    // Android initialization
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.high,
            ),
          );
    }

    _isInitialized = true;
    debugPrint('StarNotificationService initialized');
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    } else if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidPlugin?.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  /// Handle notification tap
  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && onNotificationTap != null) {
      onNotificationTap!(payload);
    }
  }

  /// Schedule notifications for all saved stars
  Future<void> scheduleAllStarNotifications() async {
    if (!await NotificationPreferences.getStarNotificationsEnabled()) {
      debugPrint('Star notifications disabled globally');
      return;
    }

    final savedStarsService = SavedStarsService.instance;
    if (!savedStarsService.isLoaded) {
      await savedStarsService.load();
    }

    final location = await OnboardingService.getUserLocation();
    if (location.latitude == null || location.longitude == null) {
      debugPrint('No user location available for star visibility calculations');
      return;
    }

    // Cancel all existing star notifications first
    await cancelAllNotifications();

    final stars = savedStarsService.savedStars;
    final leadTime = await NotificationPreferences.getNotificationLeadTime();

    int scheduledCount = 0;
    for (final star in stars) {
      if (star.ra == null || star.dec == null) continue;

      final isEnabled =
          await NotificationPreferences.getStarNotificationEnabled(star.id);
      if (!isEnabled) continue;

      final scheduled = await scheduleStarNotification(
        star,
        latitude: location.latitude!,
        longitude: location.longitude!,
        leadTime: leadTime,
      );

      if (scheduled) scheduledCount++;
    }

    await NotificationPreferences.setLastCalculationTime(DateTime.now());
    debugPrint('Scheduled $scheduledCount star visibility notifications');
  }

  /// Schedule notification for a single star
  /// Returns true if notification was scheduled
  Future<bool> scheduleStarNotification(
    SavedStar star, {
    required double latitude,
    required double longitude,
    Duration leadTime = const Duration(minutes: 30),
  }) async {
    if (star.ra == null || star.dec == null) return false;

    // Get next visibility window
    final visibilityStart = StarVisibility.getNextVisibilityStart(
      starRaDeg: star.ra!,
      starDecDeg: star.dec!,
      latitudeDeg: latitude,
      longitudeDeg: longitude,
    );

    if (visibilityStart == null) {
      debugPrint('No visibility window found for ${star.displayName}');
      return false;
    }

    // Calculate notification time (lead time before visibility)
    final notificationTime = visibilityStart.subtract(leadTime);

    // Don't schedule if it's in the past
    if (notificationTime.isBefore(DateTime.now())) {
      debugPrint('Notification time for ${star.displayName} is in the past');
      return false;
    }

    // Check quiet hours
    if (await NotificationPreferences.isInQuietHours()) {
      debugPrint('Currently in quiet hours, skipping ${star.displayName}');
      return false;
    }

    // Get direction for notification text
    final azimuth = StarVisibility.getStarAzimuth(
      starRaDeg: star.ra!,
      starDecDeg: star.dec!,
      latitudeDeg: latitude,
      longitudeDeg: longitude,
      dateTime: visibilityStart,
    );
    final direction = StarVisibility.getDirectionName(azimuth);

    // Get end time for the notification message
    final (_, windowEnd) = StarVisibility.getTonightViewingWindow(
      starRaDeg: star.ra!,
      starDecDeg: star.dec!,
      latitudeDeg: latitude,
      longitudeDeg: longitude,
      date: visibilityStart,
    );

    String body;
    if (windowEnd != null) {
      final endTimeStr =
          '${windowEnd.hour.toString().padLeft(2, '0')}:${windowEnd.minute.toString().padLeft(2, '0')}';
      body =
          'Your star is now visible in the $direction sky. Best viewing until $endTimeStr.';
    } else {
      body = 'Your star is now visible in the $direction sky.';
    }

    // Schedule the notification
    final notificationId = star.id.hashCode.abs() % 2147483647;

    await _notifications.zonedSchedule(
      notificationId,
      '${star.displayName} is rising!',
      body,
      tz.TZDateTime.from(notificationTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: star.id,
    );

    debugPrint(
        'Scheduled notification for ${star.displayName} at $notificationTime');
    return true;
  }

  /// Cancel notification for a specific star
  Future<void> cancelStarNotification(String starId) async {
    final notificationId = starId.hashCode.abs() % 2147483647;
    await _notifications.cancel(notificationId);
    debugPrint('Cancelled notification for star: $starId');
  }

  /// Cancel all star notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    debugPrint('Cancelled all star notifications');
  }

  /// Check if notifications are currently scheduled
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// TEST: Send a test notification immediately
  /// Call this from debug menu or console to verify notifications work
  Future<void> sendTestNotification() async {
    await _notifications.show(
      999999,
      'Test: Star Rising!',
      'This is a test notification. Your star visibility alerts are working!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'test',
    );
    debugPrint('Test notification sent!');
  }

  /// TEST: Schedule a notification for 10 seconds from now
  Future<void> scheduleTestNotification() async {
    final scheduledTime = DateTime.now().add(const Duration(seconds: 10));

    await _notifications.zonedSchedule(
      999998,
      'Test: Scheduled Star Alert',
      'This notification was scheduled 10 seconds ago. It works!',
      tz.TZDateTime.from(scheduledTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'test_scheduled',
    );
    debugPrint('Test notification scheduled for: $scheduledTime');
  }
}
