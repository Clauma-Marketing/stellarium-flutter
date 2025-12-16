import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/onboarding/onboarding_service.dart';
import 'notification_preferences.dart';
import 'saved_stars_service.dart';

/// Service for syncing user data and saved stars to Firestore
/// This enables server-side notification scheduling via Cloud Functions
class FirestoreSyncService {
  static final FirestoreSyncService instance = FirestoreSyncService._();
  FirestoreSyncService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static const String _userIdKey = 'firestore_user_id';

  String? _userId;

  /// Get or create a unique user ID for this device
  Future<String> getUserId() async {
    if (_userId != null) return _userId!;

    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString(_userIdKey);

    if (_userId == null) {
      // Generate a new user ID based on device + timestamp
      _userId = '${DateTime.now().millisecondsSinceEpoch}_${_generateRandomId()}';
      await prefs.setString(_userIdKey, _userId!);
    }

    return _userId!;
  }

  String _generateRandomId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(12, (index) {
      final randomIndex = DateTime.now().microsecond % chars.length;
      return chars[(randomIndex + index) % chars.length];
    }).join();
  }

  /// Initialize the sync service and sync user data
  Future<void> initialize() async {
    try {
      final userId = await getUserId();
      debugPrint('FirestoreSyncService initialized with userId: $userId');

      // Sync user data on initialization
      await syncUserData();

      // Listen for FCM token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        syncUserData();
      });

      // Listen for saved stars changes
      SavedStarsService.instance.addListener(_onSavedStarsChanged);
    } catch (e) {
      debugPrint('Error initializing FirestoreSyncService: $e');
    }
  }

  void _onSavedStarsChanged() {
    syncSavedStars();
  }

  /// Sync user data (location, FCM token, preferences) to Firestore
  Future<void> syncUserData() async {
    try {
      final userId = await getUserId();
      final location = await OnboardingService.getUserLocation();
      final notificationsEnabled =
          await NotificationPreferences.getStarNotificationsEnabled();

      // Only get FCM token if notification permission has already been granted
      // to avoid triggering the permission dialog
      String? fcmToken;
      final settings = await _messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        fcmToken = await _messaging.getToken();
      }

      // Get timezone
      final timezone = DateTime.now().timeZoneName;
      final timezoneOffset = DateTime.now().timeZoneOffset.inMinutes;

      final userData = <String, dynamic>{
        'fcmToken': fcmToken,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'notificationsEnabled': notificationsEnabled,
        'timezone': timezone,
        'timezoneOffsetMinutes': timezoneOffset,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Only add location if available
      if (location.latitude != null && location.longitude != null) {
        userData['latitude'] = location.latitude;
        userData['longitude'] = location.longitude;
        userData['location'] = GeoPoint(location.latitude!, location.longitude!);
      }

      await _firestore.collection('users').doc(userId).set(
            userData,
            SetOptions(merge: true),
          );

      debugPrint('User data synced to Firestore');
    } catch (e) {
      debugPrint('Error syncing user data: $e');
    }
  }

  /// Sync all saved stars to Firestore
  Future<void> syncSavedStars() async {
    try {
      final userId = await getUserId();
      final savedStars = SavedStarsService.instance.savedStars;

      final batch = _firestore.batch();
      final starsCollection =
          _firestore.collection('users').doc(userId).collection('savedStars');

      // Get existing stars in Firestore to detect deletions
      final existingStars = await starsCollection.get();
      final existingIds = existingStars.docs.map((d) => d.id).toSet();
      final currentIds = savedStars.map((s) => s.id).toSet();

      // Delete stars that are no longer saved
      for (final existingId in existingIds) {
        if (!currentIds.contains(existingId)) {
          batch.delete(starsCollection.doc(existingId));
        }
      }

      // Add/update current stars
      for (final star in savedStars) {
        final starData = <String, dynamic>{
          'displayName': star.displayName,
          'scientificName': star.scientificName,
          'registrationNumber': star.registrationNumber,
          'ra': star.ra,
          'dec': star.dec,
          'magnitude': star.magnitude,
          'notificationsEnabled': star.notificationsEnabled,
          'savedAt': Timestamp.fromDate(star.savedAt),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        batch.set(starsCollection.doc(star.id), starData, SetOptions(merge: true));
      }

      await batch.commit();
      debugPrint('Synced ${savedStars.length} stars to Firestore');
    } catch (e) {
      debugPrint('Error syncing saved stars: $e');
    }
  }

  /// Sync a single star (call when saving/updating a star)
  Future<void> syncStar(SavedStar star) async {
    try {
      final userId = await getUserId();

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('savedStars')
          .doc(star.id)
          .set({
        'displayName': star.displayName,
        'scientificName': star.scientificName,
        'registrationNumber': star.registrationNumber,
        'ra': star.ra,
        'dec': star.dec,
        'magnitude': star.magnitude,
        'notificationsEnabled': star.notificationsEnabled,
        'savedAt': Timestamp.fromDate(star.savedAt),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Synced star ${star.displayName} to Firestore');
    } catch (e) {
      debugPrint('Error syncing star: $e');
    }
  }

  /// Remove a star from Firestore
  Future<void> removeStar(String starId) async {
    try {
      final userId = await getUserId();

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('savedStars')
          .doc(starId)
          .delete();

      debugPrint('Removed star $starId from Firestore');
    } catch (e) {
      debugPrint('Error removing star: $e');
    }
  }

  /// Update notification preference for the user
  Future<void> updateNotificationPreference(bool enabled) async {
    try {
      final userId = await getUserId();

      await _firestore.collection('users').doc(userId).update({
        'notificationsEnabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Updated notification preference: $enabled');
    } catch (e) {
      debugPrint('Error updating notification preference: $e');
    }
  }

  /// Update notification preference for a specific star
  Future<void> updateStarNotificationPreference(
      String starId, bool enabled) async {
    try {
      final userId = await getUserId();

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('savedStars')
          .doc(starId)
          .update({
        'notificationsEnabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Updated star $starId notification preference: $enabled');
    } catch (e) {
      debugPrint('Error updating star notification preference: $e');
    }
  }

  /// Update user location
  Future<void> updateLocation(double latitude, double longitude) async {
    try {
      final userId = await getUserId();

      await _firestore.collection('users').doc(userId).update({
        'latitude': latitude,
        'longitude': longitude,
        'location': GeoPoint(latitude, longitude),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Updated location: $latitude, $longitude');
    } catch (e) {
      debugPrint('Error updating location: $e');
    }
  }
}
