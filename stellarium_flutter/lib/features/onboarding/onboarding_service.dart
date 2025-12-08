import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/star_info_sheet.dart';

/// Service to manage onboarding state
class OnboardingService {
  static const String _onboardingCompleteKey = 'onboarding_complete';
  static const String _subscriptionShownKey = 'subscription_shown';
  static const String _userLatitudeKey = 'user_latitude';
  static const String _userLongitudeKey = 'user_longitude';
  static const String _foundStarRegistrationKey = 'found_star_registration';
  static const String _foundStarNameKey = 'found_star_name';
  static const String _foundStarIdentifierKey = 'found_star_identifier';

  /// Check if onboarding has been completed
  static Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompleteKey) ?? false;
  }

  /// Mark onboarding as complete
  static Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, true);
  }

  /// Reset onboarding (for testing)
  static Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, false);
    await prefs.setBool(_subscriptionShownKey, false);
  }

  /// Check if subscription screen has been shown
  static Future<bool> isSubscriptionShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_subscriptionShownKey) ?? false;
  }

  /// Mark subscription screen as shown
  static Future<void> markSubscriptionShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_subscriptionShownKey, true);
  }

  /// Save user's location from onboarding
  static Future<void> saveUserLocation(double latitude, double longitude) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_userLatitudeKey, latitude);
    await prefs.setDouble(_userLongitudeKey, longitude);
  }

  /// Get saved user location
  static Future<({double? latitude, double? longitude})> getUserLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_userLatitudeKey);
    final lon = prefs.getDouble(_userLongitudeKey);
    return (latitude: lat, longitude: lon);
  }

  /// Save found star from onboarding
  static Future<void> saveFoundStar(StarInfo starInfo) async {
    final prefs = await SharedPreferences.getInstance();
    final regNumber = starInfo.registryInfo?.registrationNumber;
    final name = starInfo.registryInfo?.name ?? starInfo.shortName;
    final identifier = starInfo.modelData?.searchIdentifier;

    if (regNumber != null) {
      await prefs.setString(_foundStarRegistrationKey, regNumber);
    }
    if (name.isNotEmpty) {
      await prefs.setString(_foundStarNameKey, name);
    }
    if (identifier != null) {
      await prefs.setString(_foundStarIdentifierKey, identifier);
    }
  }

  /// Get saved found star info
  static Future<({String? registrationNumber, String? name, String? identifier})> getFoundStar() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      registrationNumber: prefs.getString(_foundStarRegistrationKey),
      name: prefs.getString(_foundStarNameKey),
      identifier: prefs.getString(_foundStarIdentifierKey),
    );
  }

  /// Check if a star was found during onboarding
  static Future<bool> hasFoundStar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_foundStarRegistrationKey) != null;
  }

  /// Clear found star data (after it's been shown)
  static Future<void> clearFoundStar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_foundStarRegistrationKey);
    await prefs.remove(_foundStarNameKey);
    await prefs.remove(_foundStarIdentifierKey);
  }
}
