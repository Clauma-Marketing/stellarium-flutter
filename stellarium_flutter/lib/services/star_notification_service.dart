import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Service for managing star visibility notification permissions
/// Actual notifications are sent by Firebase Cloud Functions via FCM
class StarNotificationService {
  static final StarNotificationService instance = StarNotificationService._();

  StarNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  bool _isInitialized = false;

  /// Initialize the notification system
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isInitialized = true;
    debugPrint('StarNotificationService initialized (FCM-based)');
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      debugPrint('Notification permission: ${settings.authorizationStatus}');
      return granted;
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      return false;
    }
  }

  /// Check if notifications are enabled at the system level
  Future<bool> areNotificationsEnabled() async {
    try {
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('Error checking notification status: $e');
      return false;
    }
  }

  /// Get the FCM token for this device
  Future<String?> getToken() async {
    try {
      if (Platform.isIOS) {
        // On iOS, we need to get the APNs token first
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('APNs token not available yet');
          return null;
        }
      }
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }
}
