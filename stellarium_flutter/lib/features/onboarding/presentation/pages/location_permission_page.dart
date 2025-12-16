import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../../../l10n/app_localizations.dart';
import '../../../../services/analytics_service.dart';
import '../../../../services/locale_service.dart';
import '../widgets/permission_page_template.dart';

/// Location permission page - requests location access during onboarding
class LocationPermissionPage extends StatefulWidget {
  final VoidCallback onContinue;
  final void Function(double latitude, double longitude)? onLocationObtained;
  final int? currentPage;
  final int? totalPages;

  const LocationPermissionPage({
    super.key,
    required this.onContinue,
    this.onLocationObtained,
    this.currentPage,
    this.totalPages,
  });

  @override
  State<LocationPermissionPage> createState() => _LocationPermissionPageState();
}

class _LocationPermissionPageState extends State<LocationPermissionPage> {
  bool _isLoading = false;
  bool _locationConfirmed = false;
  Position? _position;
  String? _locationName;


  Future<void> _requestLocationPermission() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      // For web, we use a different approach
      if (kIsWeb) {
        await _getWebLocation();
        return;
      }

      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services disabled, continue without location
        AnalyticsService.instance.logPermissionSkipped(permission: 'location');
        widget.onContinue();
        return;
      }

      // Check permission status
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Permission denied, continue without location
          AnalyticsService.instance.logPermissionSkipped(permission: 'location');
          widget.onContinue();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permission permanently denied, continue without location
        AnalyticsService.instance.logPermissionSkipped(permission: 'location');
        widget.onContinue();
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Always save location even if widget unmounted (user skipped while loading)
      widget.onLocationObtained?.call(position.latitude, position.longitude);

      // Track permission granted
      AnalyticsService.instance.logPermissionGranted(permission: 'location');

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _locationConfirmed = true;
        _position = position;
      });

      // Reverse geocode to get location name
      _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      // Location failed, continue without location
      AnalyticsService.instance.logPermissionSkipped(permission: 'location');
      widget.onContinue();
    }
  }

  Future<void> _getWebLocation() async {
    try {
      // For web, geolocator should still work
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      // Always save location even if widget unmounted (user skipped while loading)
      widget.onLocationObtained?.call(position.latitude, position.longitude);

      // Track permission granted
      AnalyticsService.instance.logPermissionGranted(permission: 'location');

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _locationConfirmed = true;
        _position = position;
      });

      // Reverse geocode to get location name
      _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      // Location failed on web, continue without location
      AnalyticsService.instance.logPermissionSkipped(permission: 'location');
      widget.onContinue();
    }
  }

  static const String _googleApiKey = 'AIzaSyCc4LPIozIoEHVAMFz5uyQ_LrT1nAlbmfc';

  Future<void> _reverseGeocode(double latitude, double longitude) async {
    // Get current language for localized results
    final locale = LocaleService.instance.locale ?? ui.PlatformDispatcher.instance.locale;
    final language = locale.languageCode;

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&language=$language&key=$_googleApiKey',
      );
      final response = await http.get(url);

      if (response.statusCode == 200 && mounted) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final results = json['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          final addressComponents = (results[0] as Map<String, dynamic>)['address_components'] as List<dynamic>?;

          String? city;
          String? country;

          if (addressComponents != null) {
            for (final component in addressComponents) {
              final types = (component['types'] as List<dynamic>?)?.cast<String>() ?? [];
              if (types.contains('locality')) {
                city = component['long_name'] as String?;
              } else if (types.contains('administrative_area_level_1') && city == null) {
                city = component['long_name'] as String?;
              }
              if (types.contains('country')) {
                country = component['long_name'] as String?;
              }
            }
          }

          final locationParts = [city, country].where((s) => s != null && s.isNotEmpty).toList();

          if (locationParts.isNotEmpty) {
            setState(() {
              _locationName = locationParts.join(', ');
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Reverse geocoding failed: $e');
    }
  }

  String _formatCoordinate(double value, bool isLatitude) {
    final direction = isLatitude
        ? (value >= 0 ? 'N' : 'S')
        : (value >= 0 ? 'E' : 'W');
    return '${value.abs().toStringAsFixed(4)}° $direction';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_locationConfirmed && _position != null) {
      return _buildConfirmationView(l10n);
    }

    return PermissionPageTemplate(
      iconImagePath: 'assets/icons/location.png',
      title: l10n.locationAccessTitle,
      subtitle: l10n.locationAccessSubtitle,
      features: const [],
      primaryButtonText: _isLoading ? l10n.locationGettingLocation : l10n.locationAllowAccess,
      onPrimaryPressed: _requestLocationPermission,
      isLoading: _isLoading,
      currentPage: widget.currentPage,
      totalPages: widget.totalPages,
    );
  }

  Widget _buildConfirmationView(AppLocalizations l10n) {
    return PermissionPageTemplate(
      iconImagePath: 'assets/icons/location.png',
      title: l10n.locationConfirmedTitle,
      subtitle: l10n.locationConfirmedSubtitle,
      features: const [],
      primaryButtonText: l10n.onboardingContinue,
      onPrimaryPressed: widget.onContinue,
      customContent: _buildLocationDisplay(),
      currentPage: widget.currentPage,
      totalPages: widget.totalPages,
    );
  }

  Widget _buildLocationDisplay() {
    if (_position == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.location_on,
            color: primaryBlue,
            size: 32,
          ),
          const SizedBox(height: 12),
          if (_locationName != null)
            Text(
              _locationName!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            )
          else
            // Show coordinates while loading location name
            Column(
              children: [
                Text(
                  _formatCoordinate(_position!.latitude, true),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCoordinate(_position!.longitude, false),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
