import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing star visibility notification preferences
class NotificationPreferences {
  static const String _keyEnabled = 'star_notifications_enabled';
  static const String _keyLeadTimeMinutes = 'star_notification_lead_time';
  static const String _keyQuietHoursEnabled = 'quiet_hours_enabled';
  static const String _keyQuietHoursStart = 'quiet_hours_start';
  static const String _keyQuietHoursEnd = 'quiet_hours_end';
  static const String _keyPerStarPrefix = 'star_notification_';
  static const String _keyLastCalculation = 'last_visibility_calculation';

  /// Default lead time before star becomes visible (30 minutes)
  static const int defaultLeadTimeMinutes = 30;

  /// Enable/disable star visibility notifications globally
  static Future<void> setStarNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
  }

  /// Check if star visibility notifications are enabled
  static Future<bool> getStarNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? true; // Default: enabled
  }

  /// Set notification lead time (how many minutes before visibility to notify)
  static Future<void> setNotificationLeadTime(Duration leadTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLeadTimeMinutes, leadTime.inMinutes);
  }

  /// Get notification lead time
  static Future<Duration> getNotificationLeadTime() async {
    final prefs = await SharedPreferences.getInstance();
    final minutes = prefs.getInt(_keyLeadTimeMinutes) ?? defaultLeadTimeMinutes;
    return Duration(minutes: minutes);
  }

  /// Enable/disable quiet hours
  static Future<void> setQuietHoursEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyQuietHoursEnabled, enabled);
  }

  /// Check if quiet hours are enabled
  static Future<bool> getQuietHoursEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyQuietHoursEnabled) ?? false;
  }

  /// Set quiet hours (don't send notifications during this time)
  static Future<void> setQuietHours(TimeOfDay start, TimeOfDay end) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyQuietHoursStart, start.hour * 60 + start.minute);
    await prefs.setInt(_keyQuietHoursEnd, end.hour * 60 + end.minute);
  }

  /// Get quiet hours start time
  static Future<TimeOfDay> getQuietHoursStart() async {
    final prefs = await SharedPreferences.getInstance();
    final minutes = prefs.getInt(_keyQuietHoursStart) ?? 22 * 60; // Default: 22:00
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  /// Get quiet hours end time
  static Future<TimeOfDay> getQuietHoursEnd() async {
    final prefs = await SharedPreferences.getInstance();
    final minutes = prefs.getInt(_keyQuietHoursEnd) ?? 7 * 60; // Default: 07:00
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  /// Check if current time is within quiet hours
  static Future<bool> isInQuietHours() async {
    if (!await getQuietHoursEnabled()) return false;

    final now = TimeOfDay.now();
    final start = await getQuietHoursStart();
    final end = await getQuietHoursEnd();

    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (startMinutes <= endMinutes) {
      // Quiet hours don't span midnight
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    } else {
      // Quiet hours span midnight (e.g., 22:00 to 07:00)
      return nowMinutes >= startMinutes || nowMinutes < endMinutes;
    }
  }

  /// Enable/disable notifications for a specific star
  static Future<void> setStarNotificationEnabled(
    String starId,
    bool enabled,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_keyPerStarPrefix$starId', enabled);
  }

  /// Check if notifications are enabled for a specific star
  static Future<bool> getStarNotificationEnabled(String starId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_keyPerStarPrefix$starId') ?? true; // Default: enabled
  }

  /// Remove notification preference for a star (when star is unsaved)
  static Future<void> removeStarNotificationPreference(String starId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPerStarPrefix$starId');
  }

  /// Get last visibility calculation time
  static Future<DateTime?> getLastCalculationTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_keyLastCalculation);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Set last visibility calculation time
  static Future<void> setLastCalculationTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastCalculation, time.millisecondsSinceEpoch);
  }
}
