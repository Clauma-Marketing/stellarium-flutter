import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:http/http.dart' as http;

/// A reverse-geocoding result reduced to the two fields the app displays.
class ReverseGeocodeResult {
  final String? city;
  final String? country;

  const ReverseGeocodeResult({this.city, this.country});

  bool get hasValue =>
      (city?.isNotEmpty ?? false) || (country?.isNotEmpty ?? false);

  /// "City, Country" (omitting whichever part is missing), or null if empty.
  String? get formatted {
    final parts =
        [city, country].where((s) => s != null && s.isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(', ');
  }
}

/// Reverse-geocode [latitude]/[longitude] to a city + country.
///
/// Prefers the **free native OS geocoder** (iOS `CLGeocoder` / Android
/// `Geocoder`) and only falls back to the **billed Google Geocoding API** when
/// the OS returns nothing — e.g. an Android device without Google Play Services,
/// or a transient platform error. This keeps the common case off the Google
/// bill while preserving the previous behaviour as a safety net.
Future<ReverseGeocodeResult?> reverseGeocode({
  required double latitude,
  required double longitude,
  required String language,
  required String googleApiKey,
}) async {
  final native = await _reverseGeocodeNative(latitude, longitude, language);
  if (native != null && native.hasValue) {
    if (kDebugMode) {
      debugPrint('reverseGeocode: native OS -> ${native.formatted}');
    }
    return native;
  }
  final google =
      await _reverseGeocodeGoogle(latitude, longitude, language, googleApiKey);
  if (kDebugMode) {
    debugPrint('reverseGeocode: Google fallback -> ${google?.formatted}');
  }
  return google;
}

Future<ReverseGeocodeResult?> _reverseGeocodeNative(
    double lat, double lng, String language) async {
  try {
    // Localize results to the app language where the platform supports it.
    try {
      await geo.setLocaleIdentifier(language);
    } catch (_) {
      // Non-fatal: fall back to the device default locale.
    }

    final placemarks = await geo.placemarkFromCoordinates(lat, lng);
    if (placemarks.isEmpty) return null;

    final p = placemarks.first;
    // locality is the city; fall back to sub-/admin-area to mirror the previous
    // Google parsing (locality -> administrative_area_level_1).
    final city = _firstNonEmpty(
        [p.locality, p.subAdministrativeArea, p.administrativeArea]);
    final country = (p.country?.isNotEmpty ?? false) ? p.country : null;

    if (city == null && country == null) return null;
    return ReverseGeocodeResult(city: city, country: country);
  } catch (_) {
    return null;
  }
}

Future<ReverseGeocodeResult?> _reverseGeocodeGoogle(
    double lat, double lng, String language, String googleApiKey) async {
  try {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&language=$language&key=$googleApiKey',
    );
    final response = await http.get(url);
    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final results = json['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return null;

    final addressComponents =
        (results[0] as Map<String, dynamic>)['address_components']
            as List<dynamic>?;
    String? city;
    String? country;
    if (addressComponents != null) {
      for (final component in addressComponents) {
        final types =
            (component['types'] as List<dynamic>?)?.cast<String>() ?? [];
        if (types.contains('locality')) {
          city = component['long_name'] as String?;
        } else if (types.contains('administrative_area_level_1') &&
            city == null) {
          city = component['long_name'] as String?;
        }
        if (types.contains('country')) {
          country = component['long_name'] as String?;
        }
      }
    }
    return ReverseGeocodeResult(city: city, country: country);
  } catch (_) {
    return null;
  }
}

String? _firstNonEmpty(List<String?> values) {
  for (final v in values) {
    if (v != null && v.isNotEmpty) return v;
  }
  return null;
}
