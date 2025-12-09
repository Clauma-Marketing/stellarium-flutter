import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../l10n/app_localizations.dart';
import '../services/locale_service.dart';
import '../services/saved_stars_service.dart';
import '../stellarium/stellarium.dart';

const String _googleApiKey = 'AIzaSyCc4LPIozIoEHVAMFz5uyQ_LrT1nAlbmfc';

/// A place suggestion from geocoding search
class PlaceSuggestion {
  final String displayName;
  final String? city;
  final String? country;
  final double? latitude;
  final double? longitude;
  final String? placeId; // Google Places API place_id

  PlaceSuggestion({
    required this.displayName,
    this.city,
    this.country,
    this.latitude,
    this.longitude,
    this.placeId,
  });

  /// Create from Google Places Autocomplete API prediction
  factory PlaceSuggestion.fromGooglePrediction(Map<String, dynamic> json) {
    final structuredFormatting = json['structured_formatting'] as Map<String, dynamic>?;
    final mainText = structuredFormatting?['main_text'] as String? ?? '';
    final secondaryText = structuredFormatting?['secondary_text'] as String? ?? '';

    return PlaceSuggestion(
      displayName: json['description'] as String? ?? '',
      city: mainText.isNotEmpty ? mainText : null,
      country: secondaryText.isNotEmpty ? secondaryText : null,
      placeId: json['place_id'] as String?,
    );
  }

  /// Create from Google Geocoding API result (with coordinates)
  factory PlaceSuggestion.fromGoogleGeocode(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;

    String? city;
    String? country;

    final addressComponents = json['address_components'] as List<dynamic>?;
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

    return PlaceSuggestion(
      displayName: json['formatted_address'] as String? ?? '',
      city: city,
      country: country,
      latitude: (location?['lat'] as num?)?.toDouble(),
      longitude: (location?['lng'] as num?)?.toDouble(),
      placeId: json['place_id'] as String?,
    );
  }

  String get shortName {
    final parts = <String>[];
    if (city != null) parts.add(city!);
    if (country != null) parts.add(country!);
    if (parts.isEmpty) {
      // Use first part of display name
      final firstPart = displayName.split(',').first.trim();
      return firstPart;
    }
    return parts.join(', ');
  }
}

/// Main menu item data
class MainMenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final void Function(BuildContext context)? onTap;
  final bool isSubmenu;

  const MainMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
    this.isSubmenu = false,
  });
}

/// A bottom sheet that displays the main menu.
class SettingsBottomSheet extends StatelessWidget {
  final StellariumSettings settings;
  final void Function(String key, bool value) onSettingChanged;
  final Observer observer;
  final void Function(double latitude, double longitude, {String? locationName}) onLocationChanged;
  final VoidCallback? onSubMenuOpening;
  final VoidCallback? onSubMenuClosed;
  final void Function(SavedStar star)? onSelectStar;

  const SettingsBottomSheet({
    super.key,
    required this.settings,
    required this.onSettingChanged,
    required this.observer,
    required this.onLocationChanged,
    this.onSubMenuOpening,
    this.onSubMenuClosed,
    this.onSelectStar,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.6,
      maxChildSize: 0.6,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1a1a2e),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: [
                    const Icon(Icons.menu, color: Colors.white70, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.menu,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              // Menu items - scrollable
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    top: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                  ),
                  children: [
                    _buildMainMenuItem(
                      context,
                      MainMenuItem(
                        title: AppLocalizations.of(context)!.myStars,
                        subtitle: AppLocalizations.of(context)!.myStarsSubtitle,
                        icon: Icons.star,
                        color: Colors.amber,
                        isSubmenu: true,
                        onTap: (ctx) => _showMyStarsSheet(ctx),
                      ),
                    ),
                    _buildMainMenuItem(
                      context,
                      MainMenuItem(
                        title: AppLocalizations.of(context)!.location,
                        subtitle: AppLocalizations.of(context)!.timeLocationSubtitle,
                        icon: Icons.location_on,
                        color: Colors.green,
                        isSubmenu: true,
                        onTap: (ctx) => _showTimeLocationSheet(ctx),
                      ),
                    ),
                    _buildMainMenuItem(
                      context,
                      MainMenuItem(
                        title: AppLocalizations.of(context)!.visualEffects,
                        subtitle: AppLocalizations.of(context)!.visualEffectsSubtitle,
                        icon: Icons.auto_awesome,
                        color: Colors.blue,
                        isSubmenu: true,
                        onTap: (ctx) => _showVisualEffectsSheet(ctx),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(color: Colors.white12, indent: 20, endIndent: 20),
                    const SizedBox(height: 8),
                    _buildMainMenuItem(
                      context,
                      MainMenuItem(
                        title: AppLocalizations.of(context)!.settings,
                        subtitle: AppLocalizations.of(context)!.settingsSubtitle,
                        icon: Icons.settings,
                        color: Colors.grey,
                        isSubmenu: true,
                        onTap: (ctx) => _showAppSettingsSheet(ctx),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainMenuItem(BuildContext context, MainMenuItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (item.onTap != null) {
            item.onTap!(context);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.icon,
                  color: item.color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                item.isSubmenu ? Icons.chevron_right : Icons.arrow_forward_ios,
                color: Colors.white24,
                size: item.isSubmenu ? 28 : 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMyStarsSheet(BuildContext context) {
    Navigator.of(context).pop(); // Close main menu
    onSubMenuOpening?.call(); // Notify parent that sub-menu is opening
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MyStarsBottomSheet(
        onSelectStar: (star) {
          Navigator.of(ctx).pop(); // Close the My Stars sheet
          onSelectStar?.call(star);
        },
      ),
    ).whenComplete(() {
      onSubMenuClosed?.call(); // Notify parent that sub-menu is closed
    });
  }

  void _showVisualEffectsSheet(BuildContext context) {
    Navigator.of(context).pop(); // Close main menu
    onSubMenuOpening?.call(); // Notify parent that sub-menu is opening
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VisualEffectsBottomSheet(
        settings: settings,
        onSettingChanged: (key, value) {
          onSettingChanged(key, value);
          (ctx as Element).markNeedsBuild();
        },
      ),
    ).whenComplete(() {
      onSubMenuClosed?.call(); // Notify parent that sub-menu is closed
    });
  }

  void _showTimeLocationSheet(BuildContext context) {
    Navigator.of(context).pop(); // Close main menu
    onSubMenuOpening?.call(); // Notify parent that sub-menu is opening
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TimeLocationBottomSheet(
        observer: observer,
        onLocationChanged: onLocationChanged,
      ),
    ).whenComplete(() {
      onSubMenuClosed?.call(); // Notify parent that sub-menu is closed
    });
  }

  void _showAppSettingsSheet(BuildContext context) {
    Navigator.of(context).pop(); // Close main menu
    onSubMenuOpening?.call(); // Notify parent that sub-menu is opening
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AppSettingsBottomSheet(),
    ).whenComplete(() {
      onSubMenuClosed?.call(); // Notify parent that sub-menu is closed
    });
  }
}

/// Visual Effects sub-menu bottom sheet
class VisualEffectsBottomSheet extends StatelessWidget {
  final StellariumSettings settings;
  final void Function(String key, bool value) onSettingChanged;

  const VisualEffectsBottomSheet({
    super.key,
    required this.settings,
    required this.onSettingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.6,
      maxChildSize: 0.6,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1a1a2e),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Header with back button
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 20, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.visualEffects,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              // Settings list - scrollable
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 24,
                  ),
                  children: [
                    _buildCategorySection(SettingsCategory.skyDisplay),
                    _buildCategorySection(SettingsCategory.celestialObjects),
                    _buildCategorySection(SettingsCategory.gridLines),
                    _buildCategorySection(SettingsCategory.uiOptions),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategorySection(SettingsCategory category) {
    final categorySettings = allSettingsMetadata
        .where((s) => s.category == category)
        .toList();

    return Builder(
      builder: (context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                _getCategoryLabel(context, category),
                style: TextStyle(
                  color: Colors.blue[300],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            ...categorySettings.map((meta) => _buildSettingTile(context, meta)),
          ],
        );
      },
    );
  }

  String _getCategoryLabel(BuildContext context, SettingsCategory category) {
    final l10n = AppLocalizations.of(context)!;
    switch (category) {
      case SettingsCategory.skyDisplay:
        return l10n.skyDisplay;
      case SettingsCategory.celestialObjects:
        return l10n.celestialObjects;
      case SettingsCategory.gridLines:
        return l10n.gridLines;
      case SettingsCategory.uiOptions:
        return l10n.displayOptions;
    }
  }

  Widget _buildSettingTile(BuildContext context, SettingMetadata meta) {
    final value = _getSettingValue(meta.key);
    final icon = _getIconForType(meta.icon);
    final label = _getSettingLabel(context, meta.key);
    final description = _getSettingDescription(context, meta.key);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSettingChanged(meta.key, !value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: value
                      ? Colors.blue.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: value ? Colors.blue[300] : Colors.white38,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: value ? Colors.white : Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: (newValue) => onSettingChanged(meta.key, newValue),
                activeThumbColor: Colors.blue[400],
                activeTrackColor: Colors.blue.withValues(alpha: 0.3),
                inactiveThumbColor: Colors.grey[600],
                inactiveTrackColor: Colors.grey[800],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getSettingLabel(BuildContext context, String key) {
    final l10n = AppLocalizations.of(context)!;
    switch (key) {
      case 'constellationsLines':
        return l10n.constellationLines;
      case 'constellationsLabels':
        return l10n.constellationNames;
      case 'constellationsArt':
        return l10n.constellationArt;
      case 'atmosphere':
        return l10n.atmosphere;
      case 'landscape':
        return l10n.landscape;
      case 'landscapeFog':
        return l10n.landscapeFog;
      case 'milkyWay':
        return l10n.milkyWay;
      case 'dss':
        return l10n.dssBackground;
      case 'stars':
        return l10n.stars;
      case 'planets':
        return l10n.planets;
      case 'dsos':
        return l10n.deepSkyObjects;
      case 'satellites':
        return l10n.satellites;
      case 'gridAzimuthal':
        return l10n.azimuthalGrid;
      case 'gridEquatorial':
        return l10n.equatorialGrid;
      case 'gridEquatorialJ2000':
        return l10n.equatorialJ2000Grid;
      case 'lineMeridian':
        return l10n.meridianLine;
      case 'lineEcliptic':
        return l10n.eclipticLine;
      case 'nightMode':
        return l10n.nightMode;
      default:
        return key;
    }
  }

  String _getSettingDescription(BuildContext context, String key) {
    final l10n = AppLocalizations.of(context)!;
    switch (key) {
      case 'constellationsLines':
        return l10n.constellationLinesDesc;
      case 'constellationsLabels':
        return l10n.constellationNamesDesc;
      case 'constellationsArt':
        return l10n.constellationArtDesc;
      case 'atmosphere':
        return l10n.atmosphereDesc;
      case 'landscape':
        return l10n.landscapeDesc;
      case 'landscapeFog':
        return l10n.landscapeFogDesc;
      case 'milkyWay':
        return l10n.milkyWayDesc;
      case 'dss':
        return l10n.dssBackgroundDesc;
      case 'stars':
        return l10n.starsDesc;
      case 'planets':
        return l10n.planetsDesc;
      case 'dsos':
        return l10n.deepSkyObjectsDesc;
      case 'satellites':
        return l10n.satellitesDesc;
      case 'gridAzimuthal':
        return l10n.azimuthalGridDesc;
      case 'gridEquatorial':
        return l10n.equatorialGridDesc;
      case 'gridEquatorialJ2000':
        return l10n.equatorialJ2000GridDesc;
      case 'lineMeridian':
        return l10n.meridianLineDesc;
      case 'lineEcliptic':
        return l10n.eclipticLineDesc;
      case 'nightMode':
        return l10n.nightModeDesc;
      default:
        return '';
    }
  }

  bool _getSettingValue(String key) {
    switch (key) {
      case 'constellationsLines':
        return settings.constellationsLines;
      case 'constellationsLabels':
        return settings.constellationsLabels;
      case 'constellationsArt':
        return settings.constellationsArt;
      case 'atmosphere':
        return settings.atmosphere;
      case 'landscape':
        return settings.landscape;
      case 'landscapeFog':
        return settings.landscapeFog;
      case 'milkyWay':
        return settings.milkyWay;
      case 'dss':
        return settings.dss;
      case 'stars':
        return settings.stars;
      case 'planets':
        return settings.planets;
      case 'dsos':
        return settings.dsos;
      case 'satellites':
        return settings.satellites;
      case 'gridAzimuthal':
        return settings.gridAzimuthal;
      case 'gridEquatorial':
        return settings.gridEquatorial;
      case 'gridEquatorialJ2000':
        return settings.gridEquatorialJ2000;
      case 'lineMeridian':
        return settings.lineMeridian;
      case 'lineEcliptic':
        return settings.lineEcliptic;
      case 'nightMode':
        return settings.nightMode;
      default:
        return false;
    }
  }

  IconData _getIconForType(IconType type) {
    switch (type) {
      case IconType.constellation:
        return Icons.auto_awesome;
      case IconType.label:
        return Icons.label_outline;
      case IconType.image:
        return Icons.image_outlined;
      case IconType.cloud:
        return Icons.cloud_outlined;
      case IconType.landscape:
        return Icons.landscape_outlined;
      case IconType.foggy:
        return Icons.foggy;
      case IconType.galaxy:
        return Icons.blur_circular;
      case IconType.photo:
        return Icons.photo_library_outlined;
      case IconType.star:
        return Icons.star_outline;
      case IconType.planet:
        return Icons.public;
      case IconType.nebula:
        return Icons.blur_on;
      case IconType.satellite:
        return Icons.satellite_alt;
      case IconType.gridAzimuthal:
        return Icons.grid_4x4;
      case IconType.gridEquatorial:
        return Icons.grid_on;
      case IconType.meridian:
        return Icons.vertical_distribute;
      case IconType.ecliptic:
        return Icons.timeline;
      case IconType.nightMode:
        return Icons.nightlight;
    }
  }
}

/// Location bottom sheet with map picker
class TimeLocationBottomSheet extends StatefulWidget {
  final Observer observer;
  final void Function(double latitude, double longitude, {String? locationName}) onLocationChanged;

  const TimeLocationBottomSheet({
    super.key,
    required this.observer,
    required this.onLocationChanged,
  });

  @override
  State<TimeLocationBottomSheet> createState() => _TimeLocationBottomSheetState();
}

class _TimeLocationBottomSheetState extends State<TimeLocationBottomSheet> {
  GoogleMapController? _mapController;
  late LatLng _selectedLocation;
  final TextEditingController _searchController = TextEditingController();
  String _locationName = '';
  bool _isSearching = false;
  bool _isLoadingLocation = false;
  List<PlaceSuggestion> _searchResults = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _selectedLocation = LatLng(
      Observer.rad2deg(widget.observer.latitude),
      Observer.rad2deg(widget.observer.longitude),
    );
    _reverseGeocodeAndUpdateField(_selectedLocation);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _reverseGeocodeAndUpdateField(LatLng location) async {
    // Get current language for localized results
    final locale = LocaleService.instance.locale ?? ui.PlatformDispatcher.instance.locale;
    final language = locale.languageCode;

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${location.latitude},${location.longitude}&language=$language&key=$_googleApiKey',
      );
      final response = await http.get(url);

      if (response.statusCode == 200 && mounted) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final results = json['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          final place = PlaceSuggestion.fromGoogleGeocode(results[0] as Map<String, dynamic>);
          setState(() {
            _locationName = place.shortName;
            _searchController.text = place.shortName;
          });
        }
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    // Debounce to avoid too many API calls
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchLocation(query);
    });
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    // Get current language for localized results
    final locale = LocaleService.instance.locale ?? ui.PlatformDispatcher.instance.locale;
    final language = locale.languageCode;

    try {
      // Use Google Places Autocomplete API
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(query)}&types=(cities)&language=$language&key=$_googleApiKey',
      );
      final response = await http.get(url);

      debugPrint('Places API response status: ${response.statusCode}');
      debugPrint('Places API response body: ${response.body}');

      if (response.statusCode == 200 && mounted) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final status = json['status'] as String?;

        if (status != 'OK' && status != 'ZERO_RESULTS') {
          debugPrint('Places API error status: $status');
          debugPrint('Error message: ${json['error_message']}');
        }

        final predictions = json['predictions'] as List<dynamic>? ?? [];
        setState(() {
          _searchResults = predictions
              .map((p) => PlaceSuggestion.fromGooglePrediction(p as Map<String, dynamic>))
              .toList();
          _isSearching = false;
        });
      } else {
        debugPrint('Places API HTTP error: ${response.statusCode}');
        if (mounted) {
          setState(() {
            _searchResults = [];
            _isSearching = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _detectCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)!.locationPermissionDenied)),
            );
          }
          setState(() {
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.locationPermissionPermanentlyDenied)),
          );
        }
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final newLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        _selectedLocation = newLocation;
        _isLoadingLocation = false;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(newLocation, 10.0),
      );
      // Reverse geocode and update search field, then auto-save
      _reverseGeocodeAndUpdateField(newLocation).then((_) {
        _applyLocationChange();
      });
    } catch (e) {
      debugPrint('Location error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorGettingLocation(e.toString()))),
        );
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _selectSearchResult(PlaceSuggestion place) async {
    // Immediately clear search results and unfocus to hide suggestions
    FocusScope.of(context).unfocus();
    setState(() {
      _searchResults = [];
      _searchController.text = place.shortName;
      _locationName = place.shortName;
    });

    // If we have coordinates, use them directly
    if (place.latitude != null && place.longitude != null) {
      final newLocation = LatLng(place.latitude!, place.longitude!);
      setState(() {
        _selectedLocation = newLocation;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(newLocation, 10.0),
      );
      // Auto-save location change
      _applyLocationChange();
      return;
    }

    // Otherwise, get coordinates from place_id using Google Places Details API
    if (place.placeId != null) {
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json?place_id=${place.placeId}&fields=geometry&key=$_googleApiKey',
        );
        final response = await http.get(url);

        if (response.statusCode == 200 && mounted) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final result = json['result'] as Map<String, dynamic>?;
          final geometry = result?['geometry'] as Map<String, dynamic>?;
          final location = geometry?['location'] as Map<String, dynamic>?;

          if (location != null) {
            final lat = (location['lat'] as num).toDouble();
            final lng = (location['lng'] as num).toDouble();
            final newLocation = LatLng(lat, lng);

            setState(() {
              _selectedLocation = newLocation;
            });

            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(newLocation, 10.0),
            );
            // Auto-save location change
            _applyLocationChange();
          }
        }
      } catch (e) {
        debugPrint('Error getting place details: $e');
      }
    }
  }

  void _onMapTap(LatLng point) {
    setState(() {
      _selectedLocation = point;
    });
    _reverseGeocodeAndUpdateField(point).then((_) {
      // Auto-save after reverse geocoding completes
      _applyLocationChange();
    });
  }

  /// Apply only the location change (auto-save)
  void _applyLocationChange() {
    widget.onLocationChanged(
      _selectedLocation.latitude,
      _selectedLocation.longitude,
      locationName: _locationName.isNotEmpty ? _locationName : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = keyboardHeight > 0;

    return DraggableScrollableSheet(
      initialChildSize: isKeyboardOpen ? 0.9 : 0.6,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1a1a2e),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Header with back button
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 20, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.green,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.location,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              // Content - scrollable
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + keyboardHeight + 24,
                  ),
                  children: [
                // Location section
                _buildSectionHeader(AppLocalizations.of(context)!.location, Icons.location_on, Colors.green),

                // Search box
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.searchCityAddress,
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.green),
                                ),
                              ),
                            )
                          : _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.white54),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchResults = [];
                                      _isSearching = false;
                                    });
                                  },
                                )
                              : null,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (value) {
                      if (_searchResults.isNotEmpty) {
                        _selectSearchResult(_searchResults.first);
                      }
                    },
                  ),
                ),

                // Search results
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: _searchResults.asMap().entries.map((entry) {
                        final index = entry.key;
                        final place = entry.value;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _selectSearchResult(place),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.vertical(
                                top: index == 0 ? const Radius.circular(12) : Radius.zero,
                                bottom: index == _searchResults.length - 1 ? const Radius.circular(12) : Radius.zero,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.place, color: Colors.green, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        place.shortName,
                                        style: const TextStyle(color: Colors.white, fontSize: 16),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        place.displayName,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.5),
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                // Detect location button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: ElevatedButton.icon(
                    onPressed: _isLoadingLocation ? null : _detectCurrentLocation,
                    icon: _isLoadingLocation
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(_isLoadingLocation ? AppLocalizations.of(context)!.detecting : AppLocalizations.of(context)!.useMyLocation),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.withValues(alpha: 0.2),
                      foregroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                // Map
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _selectedLocation,
                      zoom: 5.0,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    onTap: _onMapTap,
                    markers: {
                      Marker(
                        markerId: const MarkerId('selected'),
                        position: _selectedLocation,
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                      ),
                    },
                    mapType: MapType.normal,
                    myLocationButtonEnabled: false,
                    myLocationEnabled: false,
                    zoomControlsEnabled: false,
                    compassEnabled: false,
                    mapToolbarEnabled: false,
                    rotateGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    zoomGesturesEnabled: true,
                    tiltGesturesEnabled: false,
                    liteModeEnabled: false,
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                      Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },
                  ),
                ),

                // Current location display
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _locationName.isNotEmpty ? _locationName : AppLocalizations.of(context)!.unknownLocation,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_selectedLocation.latitude.toStringAsFixed(4)}°, ${_selectedLocation.longitude.toStringAsFixed(4)}°',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// My Stars bottom sheet showing saved stars
class MyStarsBottomSheet extends StatefulWidget {
  final void Function(SavedStar star)? onSelectStar;

  const MyStarsBottomSheet({
    super.key,
    this.onSelectStar,
  });

  @override
  State<MyStarsBottomSheet> createState() => _MyStarsBottomSheetState();
}

class _MyStarsBottomSheetState extends State<MyStarsBottomSheet> {
  @override
  void initState() {
    super.initState();
    // Ensure saved stars are loaded
    SavedStarsService.instance.load();
    // Listen for changes
    SavedStarsService.instance.addListener(_onStarsChanged);
  }

  @override
  void dispose() {
    SavedStarsService.instance.removeListener(_onStarsChanged);
    super.dispose();
  }

  void _onStarsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final savedStars = SavedStarsService.instance.savedStars;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.6,
      maxChildSize: 0.6,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1a1a2e),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 20, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.myStars,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (savedStars.isNotEmpty)
                      Text(
                        '${savedStars.length}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              // Content
              Expanded(
                child: savedStars.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: scrollController,
                        padding: EdgeInsets.only(
                          top: 8,
                          bottom: MediaQuery.of(context).padding.bottom + 16,
                        ),
                        itemCount: savedStars.length,
                        itemBuilder: (context, index) {
                          return _buildStarItem(savedStars[index]);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_border,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noSavedStarsYet,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.tapStarIconHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarItem(SavedStar star) {
    return Dismissible(
      key: Key(star.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.withValues(alpha: 0.3),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      onDismissed: (_) {
        SavedStarsService.instance.removeStar(star.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.starRemoved(star.displayName)),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.star,
              color: Colors.amber,
              size: 24,
            ),
          ),
          title: Text(
            star.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (star.scientificName != null && star.scientificName!.isNotEmpty)
                Text(
                  star.scientificName!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              if (star.magnitude != null)
                Text(
                  'Mag: ${star.magnitude!.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.gps_fixed, color: Colors.amber),
            onPressed: () {
              widget.onSelectStar?.call(star);
            },
            tooltip: AppLocalizations.of(context)!.pointAtStar,
          ),
          onTap: () {
            widget.onSelectStar?.call(star);
          },
        ),
      ),
    );
  }
}

/// A sliding panel that displays all Stellarium settings organized by category.
@Deprecated('Use SettingsBottomSheet instead')
class SettingsPanel extends StatelessWidget {
  final StellariumSettings settings;
  final void Function(String key, bool value) onSettingChanged;
  final VoidCallback onClose;

  const SettingsPanel({
    super.key,
    required this.settings,
    required this.onSettingChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildCategorySection(SettingsCategory.skyDisplay),
                _buildCategorySection(SettingsCategory.celestialObjects),
                _buildCategorySection(SettingsCategory.gridLines),
                _buildCategorySection(SettingsCategory.uiOptions),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.settings, color: Colors.white70, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Display Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: onClose,
            tooltip: 'Close settings',
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(SettingsCategory category) {
    final categorySettings = allSettingsMetadata
        .where((s) => s.category == category)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            category.label,
            style: TextStyle(
              color: Colors.blue[300],
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...categorySettings.map((meta) => _buildSettingTile(meta)),
      ],
    );
  }

  Widget _buildSettingTile(SettingMetadata meta) {
    final value = _getSettingValue(meta.key);
    final icon = _getIconForType(meta.icon);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSettingChanged(meta.key, !value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: value
                      ? Colors.blue.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: value ? Colors.blue[300] : Colors.white38,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.label,
                      style: TextStyle(
                        color: value ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: (newValue) => onSettingChanged(meta.key, newValue),
                activeThumbColor: Colors.blue[400],
                activeTrackColor: Colors.blue.withValues(alpha: 0.3),
                inactiveThumbColor: Colors.grey[600],
                inactiveTrackColor: Colors.grey[800],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _getSettingValue(String key) {
    switch (key) {
      case 'constellationsLines':
        return settings.constellationsLines;
      case 'constellationsLabels':
        return settings.constellationsLabels;
      case 'constellationsArt':
        return settings.constellationsArt;
      case 'atmosphere':
        return settings.atmosphere;
      case 'landscape':
        return settings.landscape;
      case 'landscapeFog':
        return settings.landscapeFog;
      case 'milkyWay':
        return settings.milkyWay;
      case 'dss':
        return settings.dss;
      case 'stars':
        return settings.stars;
      case 'planets':
        return settings.planets;
      case 'dsos':
        return settings.dsos;
      case 'satellites':
        return settings.satellites;
      case 'gridAzimuthal':
        return settings.gridAzimuthal;
      case 'gridEquatorial':
        return settings.gridEquatorial;
      case 'gridEquatorialJ2000':
        return settings.gridEquatorialJ2000;
      case 'lineMeridian':
        return settings.lineMeridian;
      case 'lineEcliptic':
        return settings.lineEcliptic;
      case 'nightMode':
        return settings.nightMode;
      default:
        return false;
    }
  }

  IconData _getIconForType(IconType type) {
    switch (type) {
      case IconType.constellation:
        return Icons.auto_awesome;
      case IconType.label:
        return Icons.label_outline;
      case IconType.image:
        return Icons.image_outlined;
      case IconType.cloud:
        return Icons.cloud_outlined;
      case IconType.landscape:
        return Icons.landscape_outlined;
      case IconType.foggy:
        return Icons.foggy;
      case IconType.galaxy:
        return Icons.blur_circular;
      case IconType.photo:
        return Icons.photo_library_outlined;
      case IconType.star:
        return Icons.star_outline;
      case IconType.planet:
        return Icons.public;
      case IconType.nebula:
        return Icons.blur_on;
      case IconType.satellite:
        return Icons.satellite_alt;
      case IconType.gridAzimuthal:
        return Icons.grid_4x4;
      case IconType.gridEquatorial:
        return Icons.grid_on;
      case IconType.meridian:
        return Icons.vertical_distribute;
      case IconType.ecliptic:
        return Icons.timeline;
      case IconType.nightMode:
        return Icons.nightlight;
    }
  }
}

/// A quick access toolbar for the most common settings
class QuickSettingsBar extends StatelessWidget {
  final StellariumSettings settings;
  final void Function(String key, bool value) onSettingChanged;
  final VoidCallback onOpenFullSettings;

  const QuickSettingsBar({
    super.key,
    required this.settings,
    required this.onSettingChanged,
    required this.onOpenFullSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildQuickToggle(
            icon: Icons.auto_awesome,
            label: 'Lines',
            value: settings.constellationsLines,
            onTap: () => onSettingChanged(
                'constellationsLines', !settings.constellationsLines),
          ),
          _buildQuickToggle(
            icon: Icons.image_outlined,
            label: 'Art',
            value: settings.constellationsArt,
            onTap: () =>
                onSettingChanged('constellationsArt', !settings.constellationsArt),
          ),
          _buildQuickToggle(
            icon: Icons.grid_4x4,
            label: 'Grid',
            value: settings.gridAzimuthal,
            onTap: () =>
                onSettingChanged('gridAzimuthal', !settings.gridAzimuthal),
          ),
          _buildQuickToggle(
            icon: Icons.cloud_outlined,
            label: 'Atmo',
            value: settings.atmosphere,
            onTap: () => onSettingChanged('atmosphere', !settings.atmosphere),
          ),
          _buildQuickToggle(
            icon: Icons.nightlight,
            label: 'Night',
            value: settings.nightMode,
            onTap: () => onSettingChanged('nightMode', !settings.nightMode),
          ),
          const SizedBox(width: 4),
          Container(
            width: 1,
            height: 24,
            color: Colors.white24,
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white70, size: 20),
            onPressed: onOpenFullSettings,
            tooltip: 'All settings',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickToggle({
    required IconData icon,
    required String label,
    required bool value,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            color: value ? Colors.blue[300] : Colors.white38,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// App Settings bottom sheet - Language, Subscription, etc.
class AppSettingsBottomSheet extends StatefulWidget {
  const AppSettingsBottomSheet({super.key});

  @override
  State<AppSettingsBottomSheet> createState() => _AppSettingsBottomSheetState();
}

class _AppSettingsBottomSheetState extends State<AppSettingsBottomSheet> {
  bool _isRestoringPurchases = false;
  AdaptyProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionInfo();
  }

  Future<void> _loadSubscriptionInfo() async {
    if (kIsWeb) return;

    try {
      final profile = await Adapty().getProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
        });
      }
    } catch (e) {
      debugPrint('Error loading subscription info: $e');
    }
  }

  Future<void> _restorePurchases() async {
    if (kIsWeb) return;

    setState(() {
      _isRestoringPurchases = true;
    });

    try {
      final profile = await Adapty().restorePurchases();
      if (mounted) {
        setState(() {
          _profile = profile;
          _isRestoringPurchases = false;
        });

        final hasActiveSubscription = profile.accessLevels.values
            .any((level) => level.isActive);

        if (hasActiveSubscription) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.purchasesRestored),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.noPurchasesToRestore),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRestoringPurchases = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.restoreError(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getSubscriptionPlanName(BuildContext context) {
    if (_profile == null) {
      return AppLocalizations.of(context)!.freePlan;
    }

    // Check access levels for active subscriptions
    for (final entry in _profile!.accessLevels.entries) {
      final level = entry.value;
      if (level.isActive) {
        // Try to get a nice name from the access level ID
        final levelId = entry.key.toLowerCase();
        if (levelId.contains('premium')) {
          return AppLocalizations.of(context)!.premiumPlan;
        } else if (levelId.contains('pro')) {
          return AppLocalizations.of(context)!.proPlan;
        }
        // Default to the level ID capitalized
        return entry.key.substring(0, 1).toUpperCase() + entry.key.substring(1);
      }
    }

    return AppLocalizations.of(context)!.freePlan;
  }

  bool _hasActiveSubscription() {
    if (_profile == null) return false;
    return _profile!.accessLevels.values.any((level) => level.isActive);
  }

  String? _getExpirationDate() {
    if (_profile == null) return null;

    for (final level in _profile!.accessLevels.values) {
      if (level.isActive && level.expiresAt != null) {
        final date = level.expiresAt!;
        return '${date.day}/${date.month}/${date.year}';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = LocaleService.instance.locale;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.6,
      maxChildSize: 0.6,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1a1a2e),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Header with back button
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 20, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.settings,
                        color: Colors.grey,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.settings,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            l10n.settingsSubtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12),
              // Settings content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    top: 8,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                  ),
                  children: [
                    // Language Section
                    _buildSectionHeader(l10n.language),
                    _buildLanguageSelector(context, currentLocale),

                    const SizedBox(height: 16),

                    // Subscription Section (only on mobile)
                    if (!kIsWeb) ...[
                      _buildSectionHeader(l10n.subscription),
                      _buildSubscriptionInfo(context),
                      const SizedBox(height: 12),
                      _buildRestoreButton(context),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(BuildContext context, Locale? currentLocale) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // System Default option
          _buildLanguageOption(
            context: context,
            title: l10n.systemDefault,
            locale: null,
            isSelected: currentLocale == null,
          ),
          const Divider(height: 1, color: Colors.white12, indent: 56),
          // English
          _buildLanguageOption(
            context: context,
            title: l10n.english,
            locale: const Locale('en'),
            isSelected: currentLocale?.languageCode == 'en',
          ),
          const Divider(height: 1, color: Colors.white12, indent: 56),
          // German
          _buildLanguageOption(
            context: context,
            title: l10n.german,
            locale: const Locale('de'),
            isSelected: currentLocale?.languageCode == 'de',
          ),
          const Divider(height: 1, color: Colors.white12, indent: 56),
          // Chinese (Simplified)
          _buildLanguageOption(
            context: context,
            title: l10n.chinese,
            locale: const Locale('zh'),
            isSelected: currentLocale?.languageCode == 'zh',
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required String title,
    required Locale? locale,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          LocaleService.instance.setLocale(locale);
          setState(() {});
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.language,
                color: isSelected ? Colors.blue : Colors.white54,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: Colors.blue,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final planName = _getSubscriptionPlanName(context);
    final isActive = _hasActiveSubscription();
    final expirationDate = _getExpirationDate();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: Colors.green.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isActive ? Icons.star : Icons.star_border,
                  color: isActive ? Colors.green : Colors.grey,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.currentPlan,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      planName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isActive ? l10n.subscriptionActive : l10n.freePlan,
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (expirationDate != null) ...[
            const SizedBox(height: 12),
            Text(
              l10n.expiresOn(expirationDate),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ],
          if (!isActive) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  // Show the subscription screen
                  Navigator.of(context).pop();
                  // Navigate to subscription screen
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => _SubscriptionUpgradeScreen(
                        onComplete: () {
                          Navigator.of(context).pop();
                          _loadSubscriptionInfo();
                        },
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  l10n.upgradeToPremium,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRestoreButton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextButton.icon(
        onPressed: _isRestoringPurchases ? null : _restorePurchases,
        icon: _isRestoringPurchases
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              )
            : const Icon(Icons.restore, size: 20),
        label: Text(
          _isRestoringPurchases ? l10n.restoringPurchases : l10n.restorePurchases,
        ),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
    );
  }
}

/// Screen to upgrade subscription (used from Settings)
class _SubscriptionUpgradeScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const _SubscriptionUpgradeScreen({required this.onComplete});

  @override
  State<_SubscriptionUpgradeScreen> createState() => _SubscriptionUpgradeScreenState();
}

class _SubscriptionUpgradeScreenState extends State<_SubscriptionUpgradeScreen>
    implements AdaptyUIPaywallsEventsObserver {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    AdaptyUI().setPaywallsEventsObserver(this);
    _loadPaywall();
  }

  Future<void> _loadPaywall() async {
    try {
      final paywall = await Adapty().getPaywall(
        placementId: 'night_sky_view',
      );

      final view = await AdaptyUI().createPaywallView(
        paywall: paywall,
      );

      await view.present();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a1628),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: Color(0xFF33B4E8))
            : _error != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });
                          _loadPaywall();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
      ),
    );
  }

  // AdaptyUIPaywallsEventsObserver implementation

  @override
  void paywallViewDidPerformAction(AdaptyUIPaywallView view, AdaptyUIAction action) {
    switch (action) {
      case CloseAction():
      case AndroidSystemBackAction():
        view.dismiss();
        if (mounted) Navigator.of(context).pop();
        break;
      default:
        break;
    }
  }

  @override
  void paywallViewDidFinishPurchase(
    AdaptyUIPaywallView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) {
    view.dismiss();
    widget.onComplete();
  }

  @override
  void paywallViewDidFailPurchase(
    AdaptyUIPaywallView view,
    AdaptyPaywallProduct product,
    AdaptyError error,
  ) {
    debugPrint('Purchase failed: ${error.message}');
  }

  @override
  void paywallViewDidFinishRestore(AdaptyUIPaywallView view, AdaptyProfile profile) {
    final hasAccess = profile.accessLevels.values.any((level) => level.isActive);
    if (hasAccess) {
      view.dismiss();
      widget.onComplete();
    }
  }

  @override
  void paywallViewDidFailRestore(AdaptyUIPaywallView view, AdaptyError error) {
    debugPrint('Restore failed: ${error.message}');
  }

  @override
  void paywallViewDidFailRendering(AdaptyUIPaywallView view, AdaptyError error) {
    setState(() {
      _error = error.message;
    });
  }

  @override
  void paywallViewDidFailLoadingProducts(AdaptyUIPaywallView view, AdaptyError error) {
    debugPrint('Failed to load products: ${error.message}');
  }

  @override
  void paywallViewDidSelectProduct(AdaptyUIPaywallView view, String productId) {
    debugPrint('Selected product: $productId');
  }

  @override
  void paywallViewDidStartPurchase(AdaptyUIPaywallView view, AdaptyPaywallProduct product) {
    debugPrint('Starting purchase: ${product.vendorProductId}');
  }

  @override
  void paywallViewDidStartRestore(AdaptyUIPaywallView view) {
    debugPrint('Starting restore');
  }

  @override
  void paywallViewDidAppear(AdaptyUIPaywallView view) {
    debugPrint('Paywall appeared');
  }

  @override
  void paywallViewDidDisappear(AdaptyUIPaywallView view) {
    debugPrint('Paywall disappeared');
  }

  @override
  void paywallViewDidFinishWebPaymentNavigation(
    AdaptyUIPaywallView view,
    AdaptyPaywallProduct? product,
    AdaptyError? error,
  ) {
    debugPrint('Web payment navigation finished');
  }
}
