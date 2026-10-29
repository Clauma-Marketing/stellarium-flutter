import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Implements the consent mechanism required by Google's EU User Consent
/// Policy (Google Ads "Missing consent mechanism/banner" flag) using
/// Google Consent Mode v2.
///
/// The four consent signals (analytics_storage, ad_storage, ad_user_data,
/// ad_personalization_signals) default to DENIED via meta-data entries in
/// AndroidManifest.xml and Info.plist, so nothing is collected before this
/// service runs. On startup:
/// - Users outside the EEA / UK / Switzerland are granted automatically
///   (consent is not legally required there).
/// - EEA / UK / CH users keep the denied defaults until they answer the
///   consent banner ([needsPrompt] is true); their choice is persisted and
///   re-applied on every launch.
///
/// PostHog is kept in line with the same choice so a "decline" actually
/// stops analytics collection.
class ConsentService {
  ConsentService._internal();
  static final ConsentService _instance = ConsentService._internal();
  static ConsentService get instance => _instance;

  static const _statusKey = 'ad_consent_status';
  static const _statusGranted = 'granted';
  static const _statusDenied = 'denied';
  // Auto-granted because the device is outside the EEA/UK/CH.
  static const _statusAutoGranted = 'auto_granted';

  /// EU member states + Iceland/Liechtenstein/Norway (EEA) + UK + Switzerland.
  static const _consentCountries = {
    'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR',
    'DE', 'GR', 'EL', 'HU', 'IE', 'IT', 'LV', 'LT', 'LU', 'MT',
    'NL', 'PL', 'PT', 'RO', 'SK', 'SI', 'ES', 'SE',
    'IS', 'LI', 'NO', 'GB', 'UK', 'CH',
  };

  bool _needsPrompt = false;

  /// Whether the consent banner still has to be shown to this user.
  bool get needsPrompt => _needsPrompt;

  bool _granted = false;

  /// Current effective consent state (false while undecided).
  bool get isGranted => _granted;

  /// Apply the stored consent state, or auto-grant outside the EEA/UK/CH.
  /// Call once at startup, right after Firebase is initialized.
  Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final status = prefs.getString(_statusKey);
      switch (status) {
        case _statusGranted:
        case _statusAutoGranted:
          await _apply(true);
        case _statusDenied:
          await _apply(false);
        default:
          if (_isConsentRequiredRegion()) {
            // Keep the denied manifest defaults until the banner is answered,
            // and hold PostHog too so declining is meaningful.
            _needsPrompt = true;
            await _applyPostHog(false);
          } else {
            await _apply(true);
            await prefs.setString(_statusKey, _statusAutoGranted);
          }
      }
    } catch (e) {
      debugPrint('ConsentService initialization error: $e');
    }
  }

  /// Record the user's choice (from the consent banner or settings toggle).
  Future<void> setChoice({required bool granted}) async {
    if (kIsWeb) return;
    _needsPrompt = false;
    await _apply(granted);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _statusKey, granted ? _statusGranted : _statusDenied);
    } catch (e) {
      debugPrint('ConsentService persistence error: $e');
    }
  }

  Future<void> _apply(bool granted) async {
    _granted = granted;
    try {
      await FirebaseAnalytics.instance.setConsent(
        analyticsStorageConsentGranted: granted,
        adStorageConsentGranted: granted,
        adUserDataConsentGranted: granted,
        adPersonalizationSignalsConsentGranted: granted,
      );
    } catch (e) {
      debugPrint('ConsentService setConsent error: $e');
    }
    await _applyPostHog(granted);
  }

  Future<void> _applyPostHog(bool granted) async {
    try {
      if (granted) {
        await Posthog().enable();
      } else {
        await Posthog().disable();
      }
    } catch (e) {
      debugPrint('ConsentService PostHog toggle error: $e');
    }
  }

  bool _isConsentRequiredRegion() {
    final country = _deviceCountryCode();
    // Unknown region: be safe and ask.
    if (country == null) return true;
    return _consentCountries.contains(country);
  }

  String? _deviceCountryCode() {
    for (final locale in PlatformDispatcher.instance.locales) {
      final countryCode = locale.countryCode;
      if (countryCode != null && countryCode.length == 2) {
        return countryCode.toUpperCase();
      }
    }
    try {
      // e.g. "en_DE" or "de_DE.UTF-8"
      final match =
          RegExp(r'[_-]([A-Za-z]{2})\b').firstMatch(Platform.localeName);
      if (match != null) return match.group(1)!.toUpperCase();
    } catch (_) {}
    return null;
  }
}
