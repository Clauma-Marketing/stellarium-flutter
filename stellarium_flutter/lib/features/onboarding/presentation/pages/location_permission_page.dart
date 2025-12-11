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
  final VoidCallback onSkip;
  final void Function(double latitude, double longitude)? onLocationObtained;
  final int? currentPage;
  final int? totalPages;

  const LocationPermissionPage({
    super.key,
    required this.onContinue,
    required this.onSkip,
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
  String? _errorMessage;
  Position? _position;
  String? _locationName;


  Future<void> _requestLocationPermission() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
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
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'LOCATION_SERVICES_DISABLED';
        });
        return;
      }

      // Check permission status
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _errorMessage = 'LOCATION_PERMISSION_DENIED';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'LOCATION_PERMISSION_PERMANENTLY_DENIED';
        });
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
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'LOCATION_FAILED';
      });
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
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'LOCATION_FAILED_BROWSER';
      });
    }
  }

  void _skipPermission() {
    AnalyticsService.instance.logPermissionSkipped(permission: 'location');
    widget.onSkip();
  }

  void _openSettings() {
    Geolocator.openAppSettings();
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

  String _getLocalizedError(AppLocalizations l10n) {
    switch (_errorMessage) {
      case 'LOCATION_SERVICES_DISABLED':
        return l10n.locationServicesDisabled;
      case 'LOCATION_PERMISSION_DENIED':
        return l10n.locationPermissionDenied;
      case 'LOCATION_PERMISSION_PERMANENTLY_DENIED':
        return l10n.locationPermissionPermanentlyDenied;
      case 'LOCATION_FAILED_BROWSER':
        return l10n.locationFailedBrowser;
      case 'LOCATION_FAILED':
      default:
        return l10n.errorGettingLocation(_errorMessage ?? '');
    }
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
      primaryButtonText: _errorMessage == 'LOCATION_PERMISSION_PERMANENTLY_DENIED'
          ? l10n.locationOpenSettings
          : (_isLoading ? l10n.locationGettingLocation : l10n.locationAllowAccess),
      secondaryButtonText: l10n.onboardingSkipForNow,
      onPrimaryPressed: _errorMessage == 'LOCATION_PERMISSION_PERMANENTLY_DENIED'
          ? _openSettings
          : _requestLocationPermission,
      onSecondaryPressed: _isLoading ? null : _skipPermission,
      isLoading: _isLoading,
      customContent: _errorMessage != null ? _buildErrorWidget(l10n) : null,
      currentPage: widget.currentPage,
      totalPages: widget.totalPages,
    );
  }

  Widget _buildErrorWidget(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getLocalizedError(l10n),
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
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
