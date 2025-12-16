import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing app locale/language settings
class LocaleService extends ChangeNotifier {
  static const String _localeKey = 'app_locale';
  static LocaleService? _instance;

  Locale? _locale; // null means system default
  bool _isLoaded = false;

  LocaleService._();

  /// Get the singleton instance
  static LocaleService get instance {
    _instance ??= LocaleService._();
    return _instance!;
  }

  /// Current locale (null = system default)
  Locale? get locale => _locale;

  /// Whether the service has loaded
  bool get isLoaded => _isLoaded;

  /// Load saved locale preference
  Future<void> load() async {
    if (_isLoaded) return;

    final prefs = await SharedPreferences.getInstance();
    final localeCode = prefs.getString(_localeKey);

    if (localeCode != null && localeCode.isNotEmpty) {
      _locale = Locale(localeCode);
    } else {
      // Default behavior: follow system locale.
      //
      // Exception: for Chinese device locales, default the app language to English
      // (unless the user explicitly chose a language in app settings).
      final systemLanguageCode =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      if (systemLanguageCode.toLowerCase().startsWith('zh')) {
        _locale = const Locale('en');
      } else {
        _locale = null; // System default
      }
    }

    _isLoaded = true;
    notifyListeners();
  }

  /// Set the app locale
  Future<void> setLocale(Locale? locale) async {
    if (_locale == locale) return;

    _locale = locale;

    final prefs = await SharedPreferences.getInstance();
    if (locale != null) {
      await prefs.setString(_localeKey, locale.languageCode);
    } else {
      await prefs.remove(_localeKey);
    }

    notifyListeners();
  }

  /// Get display name for a locale
  static String getLocaleName(Locale? locale, BuildContext context) {
    if (locale == null) {
      return 'System Default';
    }
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'de':
        return 'Deutsch';
      case 'zh':
        return '中文';
      default:
        return locale.languageCode;
    }
  }

  /// Supported locales
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('de'),
    Locale('zh'),
  ];
}
