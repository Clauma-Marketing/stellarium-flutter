import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../features/onboarding/onboarding_service.dart';
import '../l10n/app_localizations.dart';
import '../services/analytics_service.dart';
import '../services/locale_service.dart';
import '../services/saved_stars_service.dart';
import '../services/search_history_service.dart';
import '../stellarium/stellarium.dart';
import '../utils/sun_times.dart';
import '../widgets/bottom_bar.dart';
import '../widgets/settings_panel.dart';
import '../widgets/sky_view.dart';
import '../widgets/star_info_sheet.dart';
import '../widgets/stellarium_webview.dart';
import '../widgets/time_slider.dart';
import 'star_viewer_screen.dart';

const String _googleApiKey = 'AIzaSyCc4LPIozIoEHVAMFz5uyQ_LrT1nAlbmfc';

/// The main screen displaying the sky view with controls.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<SkyViewState> _skyViewKey = GlobalKey<SkyViewState>();
  final TextEditingController _searchController = TextEditingController();

  // Default observer - will be updated with saved location
  Observer _observer = Observer.now(
    latitude: Observer.deg2rad(40.7128), // New York (default)
    longitude: Observer.deg2rad(-74.0060),
  );

  @override
  void initState() {
    super.initState();
    // Track home screen view
    AnalyticsService.instance.logScreenView(screenName: 'home');
    // Load saved stars and search history
    SavedStarsService.instance.load();
    SearchHistoryService.instance.load();
    // Load saved location from onboarding
    _loadSavedLocation();
  }

  Future<void> _loadSavedLocation() async {
    final location = await OnboardingService.getUserLocation();
    if (location.latitude != null && location.longitude != null) {
      setState(() {
        _observer = Observer.now(
          latitude: Observer.deg2rad(location.latitude!),
          longitude: Observer.deg2rad(location.longitude!),
        );
      });
      // Also update the engine/webview location
      _skyViewKey.currentState?.webView?.setLocation(
        location.latitude!,
        location.longitude!,
      );
      _skyViewKey.currentState?.engine?.setLocation(
        latitude: Observer.deg2rad(location.latitude!),
        longitude: Observer.deg2rad(location.longitude!),
      );
    }
    // Reverse geocode to get location name
    _reverseGeocodeCurrentLocation();
  }

  Future<void> _reverseGeocodeCurrentLocation() async {
    final lat = Observer.rad2deg(_observer.latitude);
    final lng = Observer.rad2deg(_observer.longitude);

    // Get current language for localized results
    final locale = LocaleService.instance.locale ?? ui.PlatformDispatcher.instance.locale;
    final language = locale.languageCode;

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&language=$language&key=$_googleApiKey',
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

          if (locationParts.isNotEmpty && mounted) {
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

  @override
  void dispose() {
    _timeUpdateTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startTimeUpdateTimer() {
    _timeUpdateTimer?.cancel();
    // Update every 500ms to keep time display in sync (fallback for web)
    _timeUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      final currentTime = _currentTime;
      final timeStr = '${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}';
      // Only rebuild if displayed time has changed
      if (timeStr != _lastDisplayedTime) {
        setState(() {
          _lastDisplayedTime = timeStr;
        });
      }
    });
  }

  /// Called when the engine's time changes (from WebView listener)
  void _onEngineTimeChanged(double utc) {
    if (!mounted) return;
    final currentTime = Observer.mjdToDateTime(utc);
    final timeStr = '${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}';
    final newDate = DateTime(currentTime.year, currentTime.month, currentTime.day);

    // Check if we need to rebuild
    final needsRebuild = timeStr != _lastDisplayedTime ||
        _sliderDate?.year != newDate.year ||
        _sliderDate?.month != newDate.month ||
        _sliderDate?.day != newDate.day;

    if (needsRebuild) {
      setState(() {
        _lastDisplayedTime = timeStr;
        _sliderDate = newDate;
        // Also update observer UTC to stay in sync
        _observer = Observer(
          latitude: _observer.latitude,
          longitude: _observer.longitude,
          altitude: _observer.altitude,
          utc: utc,
          azimuth: _observer.azimuth,
          elevation: _observer.elevation,
          fov: _observer.fov,
        );
      });
    }
  }

  final StellariumSettings _settings = StellariumSettings();
  bool _gyroscopeEnabled = false;
  bool _gyroscopeAvailable = false;
  bool _subMenuOpening = false; // Track if sub-menu is about to open
  bool _starInfoSheetShowing = false; // Track if star info sheet is showing
  List<SearchSuggestion> _searchSuggestions = []; // Search history suggestions
  String? _locationName; // Display name for current location
  bool _showTimeSlider = false; // Track if time slider is visible
  bool _isTimePaused = false; // Track if time is paused
  DateTime? _sliderDate; // The date (year, month, day) shown on slider - only changes with day arrows
  Timer? _timeUpdateTimer; // Timer to refresh time display
  String _lastDisplayedTime = ''; // Track last displayed time to avoid unnecessary rebuilds

  /// Get current time from engine, falling back to observer or system time
  DateTime get _currentTime {
    // Try to get from engine first
    final engine = _skyViewKey.currentState?.engine;
    if (engine != null && engine.isInitialized) {
      return Observer.mjdToDateTime(engine.observer.utc);
    }
    // Fall back to observer
    return Observer.mjdToDateTime(_observer.utc);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Sky view with night mode filter
          ColorFiltered(
            colorFilter: _settings.nightMode
                ? const ColorFilter.matrix(<double>[
                    0.8, 0, 0, 0, 0, // Red
                    0, 0.2, 0, 0, 0, // Green (reduced)
                    0, 0, 0.2, 0, 0, // Blue (reduced)
                    0, 0, 0, 1, 0, // Alpha
                  ])
                : const ColorFilter.mode(
                    Colors.transparent,
                    BlendMode.dst,
                  ),
            child: SkyView(
              key: _skyViewKey,
              initialObserver: _observer,
              showFps: false,
              showCoordinates: false,
              gyroscopeEnabled: _gyroscopeEnabled,
              onObserverChanged: (observer) {
                setState(() {
                  _observer = observer;
                });
              },
              onGyroscopeAvailabilityChanged: (available) {
                setState(() {
                  _gyroscopeAvailable = available;
                });
              },
              onObjectSelected: _onObjectSelected,
              onEngineReady: _onEngineReady,
              onTimeChanged: _onEngineTimeChanged,
            ),
          ),

          // Top bar with location and time
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _buildTopBar(context),
          ),

          // Time slider (appears below top bar when time is tapped)
          if (_showTimeSlider)
            Positioned(
              left: 0,
              right: 0,
              top: MediaQuery.of(context).padding.top + 52,
              child: _buildTimeSlider(context),
            ),

          // Bottom bar with buttons and search
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomBar(
              atmosphereEnabled: _settings.atmosphere,
              gyroscopeEnabled: _gyroscopeEnabled,
              gyroscopeAvailable: _gyroscopeAvailable,
              searchController: _searchController,
              onAtmosphereTap: () {
                _onSettingChanged('atmosphere', !_settings.atmosphere);
              },
              onGyroscopeTap: () {
                setState(() {
                  _gyroscopeEnabled = !_gyroscopeEnabled;
                });
              },
              onSearchTap: _showSearchHistory,
              onSearchSubmitted: _searchAndPoint,
              onSearchChanged: _onSearchChanged,
              onHamburgerTap: _showSettingsBottomSheet,
              searchSuggestions: _searchSuggestions,
              onSuggestionTap: _onSuggestionTap,
            ),
          ),

        ],
      ),
    );
  }

  void _showTimeLocationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TimeLocationBottomSheet(
        observer: _observer,
        onLocationChanged: _onLocationChanged,
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    // Use location name if available, otherwise show coordinates
    final locationText = (_locationName != null && _locationName!.isNotEmpty)
        ? _locationName!
        : _formatCoordinates();

    final currentTime = _currentTime;
    final timeText = '${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}';

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Location bar (left)
            GestureDetector(
              onTap: _showTimeLocationSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.4,
                      ),
                      child: Text(
                        locationText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            // Time bar (right)
            GestureDetector(
              onTap: () {
                setState(() {
                  _showTimeSlider = !_showTimeSlider;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _showTimeSlider ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlider(BuildContext context) {
    // Get time from the engine
    final engineTime = _currentTime;

    // Initialize slider date if not set
    _sliderDate ??= DateTime(engineTime.year, engineTime.month, engineTime.day);

    // Use stable date for display, but get hour/minute from engine
    final displayDateTime = _sliderDate!;

    // Slider value: minutes since midnight (0 = 00:00, 1439 = 23:59)
    final sliderValue = (engineTime.hour * 60 + engineTime.minute).clamp(0, 1439);

    // Display time from engine
    final timeStr = '${engineTime.hour.toString().padLeft(2, '0')}:${engineTime.minute.toString().padLeft(2, '0')}';

    // Sun times for gradient (based on observer location)
    final sunTimes = SunTimes(
      latitude: Observer.rad2deg(_observer.latitude),
      longitude: Observer.rad2deg(_observer.longitude),
      date: displayDateTime,
    );

    // Format date
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dateStr = '${weekdays[displayDateTime.weekday - 1]}, ${displayDateTime.day} ${months[displayDateTime.month - 1]} ${displayDateTime.year}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Date selector row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Previous day button
              IconButton(
                onPressed: () => _changeSliderDate(-1),
                icon: const Icon(Icons.chevron_left, color: Colors.white70),
                iconSize: 24,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
              ),
              // Date display
              Text(
                dateStr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // Next day button
              IconButton(
                onPressed: () => _changeSliderDate(1),
                icon: const Icon(Icons.chevron_right, color: Colors.white70),
                iconSize: 24,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Time labels (midnight-to-midnight: 00:00 - noon - 24:00)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '00:00',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
              Text(
                timeStr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '24:00',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Midnight-to-midnight time slider (0 = 00:00, 720 = 12:00, 1439 = 23:59)
          TimeSlider(
            value: sliderValue,
            sunTimes: sunTimes,
            onChanged: (value) {
              // Create new DateTime with the slider value
              final newDateTime = DateTime(
                displayDateTime.year,
                displayDateTime.month,
                displayDateTime.day,
                value ~/ 60,  // hours
                value % 60,   // minutes
              );
              final newMjd = Observer.dateTimeToMjd(newDateTime);
              _onTimeChanged(newMjd);
            },
            onChangeStart: (_) {
              // Pause time while dragging to prevent fighting
              _skyViewKey.currentState?.engine?.setTimeSpeed(0.0);
            },
            onChangeEnd: (_) {
              // Resume time if it wasn't paused before, or keep it paused
              if (!_isTimePaused) {
                _skyViewKey.currentState?.engine?.setTimeSpeed(1.0);
              }
            },
          ),
          const SizedBox(height: 4),
          // Sunrise/sunset times and Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Sunrise time
              if (sunTimes.sunrise != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.wb_sunny_outlined,
                      size: 12,
                      color: Colors.orange.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${sunTimes.sunrise!.hour.toString().padLeft(2, '0')}:${sunTimes.sunrise!.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 10,
                      ),
                    ),
                  ],
                )
              else
                const SizedBox(width: 50),

              // Time Controls (Center)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Real Time Button
                  IconButton(
                    onPressed: () {
                      final now = DateTime.now();
                      final nowMjd = Observer.dateTimeToMjd(now);
                      _onTimeChanged(nowMjd);
                      setState(() {
                        _sliderDate = DateTime(now.year, now.month, now.day);
                        _isTimePaused = false;
                      });
                      _skyViewKey.currentState?.engine?.setTimeSpeed(1.0);
                    },
                    icon: const Icon(Icons.history, color: Colors.white70),
                    tooltip: 'Back to real time',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  const SizedBox(width: 8),
                  // Play/Pause Button
                  IconButton(
                    onPressed: () {
                      final newPausedState = !_isTimePaused;
                      setState(() {
                        _isTimePaused = newPausedState;
                      });
                      _skyViewKey.currentState?.engine?.setTimeSpeed(newPausedState ? 0.0 : 1.0);
                    },
                    icon: Icon(
                      _isTimePaused ? Icons.play_arrow : Icons.pause,
                      color: Colors.white,
                    ),
                    tooltip: _isTimePaused ? 'Resume time' : 'Pause time',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),

              // Sunset time
              if (sunTimes.sunset != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${sunTimes.sunset!.hour.toString().padLeft(2, '0')}:${sunTimes.sunset!.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.nights_stay_outlined,
                      size: 12,
                      color: Colors.blue.withValues(alpha: 0.8),
                    ),
                  ],
                )
              else
                const SizedBox(width: 50),
            ],
          ),
        ],
      ),
    );
  }

  void _changeSliderDate(int days) {
    final currentDate = _sliderDate ?? DateTime.now();
    final engineTime = _currentTime;

    // Update the slider date
    final newDate = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day + days,
    );

    setState(() {
      _sliderDate = newDate;
    });

    // Create new time with new date but same hour/minute from engine
    final newDateTime = DateTime(
      newDate.year,
      newDate.month,
      newDate.day,
      engineTime.hour,
      engineTime.minute,
    );

    final newMjd = Observer.dateTimeToMjd(newDateTime);
    _onTimeChanged(newMjd);
  }

  String _formatCoordinates() {
    final latDeg = Observer.rad2deg(_observer.latitude);
    final lonDeg = Observer.rad2deg(_observer.longitude);
    final latStr = '${latDeg.abs().toStringAsFixed(1)}°${latDeg >= 0 ? 'N' : 'S'}';
    final lonStr = '${lonDeg.abs().toStringAsFixed(1)}°${lonDeg >= 0 ? 'E' : 'W'}';
    return '$latStr $lonStr';
  }

  void _onEngineReady(bool ready) {
    if (!ready) return;

    // Start timer to keep time display in sync with engine
    _startTimeUpdateTimer();

    // Apply saved location to the engine
    _applySavedLocation();

    // Apply all current settings to the engine when it's ready
    final settingsMap = _settings.toMap();
    for (final entry in settingsMap.entries) {
      if (entry.key != 'nightMode') {
        // nightMode is handled via ColorFilter, not the engine
        _skyViewKey.currentState?.webView?.setSetting(entry.key, entry.value);
        _skyViewKey.currentState?.engine?.setSetting(entry.key, entry.value);
      }
    }

    // Load all saved star custom labels as persistent labels
    _loadPersistentLabels();

    // Check if there's a star found during onboarding to show
    _checkOnboardingFoundStar();
  }

  Future<void> _applySavedLocation() async {
    final location = await OnboardingService.getUserLocation();
    if (location.latitude != null && location.longitude != null) {
      _skyViewKey.currentState?.webView?.setLocation(
        location.latitude!,
        location.longitude!,
      );
      _skyViewKey.currentState?.engine?.setLocation(
        latitude: Observer.deg2rad(location.latitude!),
        longitude: Observer.deg2rad(location.longitude!),
      );
    }
  }

  /// Check if a star was found during onboarding and show it
  Future<void> _checkOnboardingFoundStar() async {
    final foundStar = await OnboardingService.getFoundStar();
    if (foundStar.registrationNumber != null) {
      // Clear the saved star so we don't show it again next time
      await OnboardingService.clearFoundStar();

      // Small delay to ensure the engine is fully ready
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        // Search for the star by registration number
        _searchRegistrationNumber(foundStar.registrationNumber!);
      }
    }
  }

  /// Load all saved stars with custom names as persistent labels
  void _loadPersistentLabels() {
    final savedStars = SavedStarsService.instance.savedStars;
    for (final star in savedStars) {
      // Only add persistent label if displayName is different from scientificName
      if (star.displayName != star.scientificName && star.scientificName != null) {
        _skyViewKey.currentState?.webView?.addPersistentLabel(
          star.scientificName!,
          star.displayName,
        );
      }
    }
  }

  void _showSettingsBottomSheet() {
    // Disable WebView touch handling while modal is open
    _skyViewKey.currentState?.webView?.setTouchEnabled(false);
    _subMenuOpening = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SettingsBottomSheet(
        settings: _settings,
        onSettingChanged: (key, value) {
          _onSettingChanged(key, value);
          // Force rebuild of the bottom sheet to reflect changes
          (context as Element).markNeedsBuild();
        },
        observer: _observer,
        onLocationChanged: _onLocationChanged,
        onSubMenuOpening: () {
          // Sub-menu is about to open, keep touch disabled
          _subMenuOpening = true;
        },
        onSubMenuClosed: () {
          // Sub-menu closed, re-enable touch
          _skyViewKey.currentState?.webView?.setTouchEnabled(true);
        },
        onSelectStar: (star) {
          // Point at the star from My Stars menu
          _skyViewKey.currentState?.webView?.pointAt(star.searchQuery);
          _skyViewKey.currentState?.engine?.search(star.searchQuery).then((obj) {
            if (obj != null) {
              _skyViewKey.currentState?.engine?.pointAt(obj);
            }
          });
          // Show star info directly using the saved star data
          // Construct names list from saved star identifiers
          final names = <String>[star.id];
          if (star.scientificName != null && star.scientificName != star.id) {
            names.add(star.scientificName!);
          }
          final starInfo = StarInfo.fromBasicData(
            name: star.displayName,
            ra: star.ra,
            dec: star.dec,
            magnitude: star.magnitude,
            names: names,
          );
          _showStarInfo(starInfo);
        },
      ),
    ).whenComplete(() {
      // Only re-enable touch if no sub-menu is opening
      if (!_subMenuOpening) {
        _skyViewKey.currentState?.webView?.setTouchEnabled(true);
      }
    });
  }

  void _onLocationChanged(double latitude, double longitude, {String? locationName}) {
    // Track location change
    AnalyticsService.instance.logLocationChange();

    final hasLocationName = locationName != null && locationName.isNotEmpty;

    setState(() {
      _locationName = hasLocationName ? locationName : null;
      _observer = Observer(
        latitude: Observer.deg2rad(latitude),
        longitude: Observer.deg2rad(longitude),
        altitude: _observer.altitude,
        utc: _observer.utc,
        azimuth: _observer.azimuth,
        elevation: _observer.elevation,
        fov: _observer.fov,
      );
    });

    // If no location name provided, reverse geocode to get it
    if (!hasLocationName) {
      _reverseGeocodeCurrentLocation();
    }

    // Apply to engine (web)
    _skyViewKey.currentState?.engine?.setLocation(
      longitude: Observer.deg2rad(longitude),
      latitude: Observer.deg2rad(latitude),
      altitude: _observer.altitude,
    );

    // Apply to WebView (mobile)
    _skyViewKey.currentState?.webView?.setLocation(latitude, longitude);

    // Save location for next app launch
    OnboardingService.saveUserLocation(latitude, longitude);
  }

  void _onTimeChanged(double mjd) {
    final dateTime = Observer.mjdToDateTime(mjd);

    setState(() {
      _observer = Observer(
        latitude: _observer.latitude,
        longitude: _observer.longitude,
        altitude: _observer.altitude,
        utc: mjd,
        azimuth: _observer.azimuth,
        elevation: _observer.elevation,
        fov: _observer.fov,
      );
      // Also update slider date to reflect the new date
      _sliderDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    });

    // Apply to WebView (mobile)
    _skyViewKey.currentState?.webView?.setTime(mjd);

    // Apply to engine (web)
    _skyViewKey.currentState?.engine?.setTime(dateTime);
  }

  void _onSettingChanged(String key, bool value) {
    // Update local settings state
    setState(() {
      switch (key) {
        case 'constellationsLines':
          _settings.constellationsLines = value;
          break;
        case 'constellationsLabels':
          _settings.constellationsLabels = value;
          break;
        case 'constellationsArt':
          _settings.constellationsArt = value;
          break;
        case 'atmosphere':
          _settings.atmosphere = value;
          break;
        case 'landscape':
          _settings.landscape = value;
          break;
        case 'landscapeFog':
          _settings.landscapeFog = value;
          break;
        case 'milkyWay':
          _settings.milkyWay = value;
          break;
        case 'dss':
          _settings.dss = value;
          break;
        case 'stars':
          _settings.stars = value;
          break;
        case 'planets':
          _settings.planets = value;
          break;
        case 'dsos':
          _settings.dsos = value;
          break;
        case 'satellites':
          _settings.satellites = value;
          break;
        case 'gridAzimuthal':
          _settings.gridAzimuthal = value;
          break;
        case 'gridEquatorial':
          _settings.gridEquatorial = value;
          break;
        case 'gridEquatorialJ2000':
          _settings.gridEquatorialJ2000 = value;
          break;
        case 'lineMeridian':
          _settings.lineMeridian = value;
          break;
        case 'lineEcliptic':
          _settings.lineEcliptic = value;
          break;
        case 'nightMode':
          _settings.nightMode = value;
          break;
      }
    });

    // Apply to engine (if nightMode, it's handled via the ColorFilter)
    if (key != 'nightMode') {
      // Try web engine first (for Flutter web)
      _skyViewKey.currentState?.engine?.setSetting(key, value);
      // Also try WebView (for iOS/Android)
      _skyViewKey.currentState?.webView?.setSetting(key, value);
    }
  }

  void _showSearchHistory() {
    // Show search history when search field is tapped (and empty)
    if (_searchController.text.isEmpty) {
      final history = SearchHistoryService.instance.history;
      final recentSearchText = AppLocalizations.of(context)?.recentSearch ?? 'Recent search';
      setState(() {
        _searchSuggestions = history
            .map((entry) => SearchSuggestion(
                  title: entry.query,
                  icon: Icons.history,
                  iconColor: Colors.white54,
                  value: entry.query,
                  subtitle: recentSearchText,
                ))
            .toList();
      });
    }
  }

  void _onSearchChanged(String value) {
    // Hide history when user starts typing
    if (value.isNotEmpty && _searchSuggestions.isNotEmpty) {
      setState(() {
        _searchSuggestions = [];
      });
    } else if (value.isEmpty) {
      // Show history again when text is cleared
      _showSearchHistory();
    }
  }

  void _onSuggestionTap(SearchSuggestion suggestion) {
    // Execute the search from history
    setState(() {
      _searchSuggestions = [];
    });
    _searchAndPoint(suggestion.value);
  }

  void _searchAndPoint(String query) async {
    if (query.trim().isEmpty) return;

    final trimmedQuery = query.trim();

    // Track star search
    AnalyticsService.instance.logStarSearch(query: trimmedQuery);

    // Save to search history
    SearchHistoryService.instance.addSearch(trimmedQuery);

    // Hide suggestions
    setState(() {
      _searchSuggestions = [];
    });

    // Clear the search field and hide keyboard first
    _searchController.clear();
    if (mounted) {
      FocusScope.of(context).unfocus();
    }

    // Check if it's a registration number
    if (StarRegistryService.isRegistrationNumber(trimmedQuery)) {
      await _searchRegistrationNumber(trimmedQuery);
      return;
    }

    // Clear selection custom label - persistent labels handle saved star names
    _skyViewKey.currentState?.webView?.clearCustomLabel();

    // Point at the object via WebView (mobile)
    _skyViewKey.currentState?.webView?.pointAt(trimmedQuery);

    // Point at the object via engine (web) - need to search first
    final engine = _skyViewKey.currentState?.engine;
    if (engine != null) {
      final obj = await engine.search(trimmedQuery);
      if (obj != null) {
        engine.pointAt(obj);
      }
    }
  }

  Future<void> _searchRegistrationNumber(String registrationNumber) async {
    // Show loading indicator
    if (!mounted) return;

    // Disable touch while loading
    _skyViewKey.currentState?.webView?.setTouchEnabled(false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      ),
    );

    try {
      final starInfo = await StarRegistryService.searchByRegistrationNumber(registrationNumber);

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (starInfo != null && starInfo.found && mounted) {
        // Auto-point at the star using formatted identifier (e.g., "HIP 14778")
        final modelData = starInfo.modelData;
        if (modelData != null && modelData.identifier.isNotEmpty) {
          final searchId = modelData.searchIdentifier;
          _skyViewKey.currentState?.webView?.pointAt(searchId);
          _skyViewKey.currentState?.engine?.search(searchId).then((obj) {
            if (obj != null) {
              _skyViewKey.currentState?.engine?.pointAt(obj);
            }
          });

          // Show registered name as custom label if available and auto-save
          if (starInfo.isRegistered && starInfo.registryInfo != null) {
            final registeredName = starInfo.registryInfo!.name;
            // Set temporary selection label (will be cleared when sheet closes)
            _skyViewKey.currentState?.webView?.setCustomLabel(registeredName);

            // Auto-save the star with its registered name for persistence
            final savedStar = SavedStar(
              id: modelData.identifier,
              displayName: registeredName,
              scientificName: modelData.identifier,
              registrationNumber: registrationNumber,
              ra: modelData.rightAscension,
              dec: modelData.declination,
              magnitude: modelData.vMagnitude,
            );
            SavedStarsService.instance.saveStar(savedStar);

            // Also add as persistent label so it shows without selection
            _skyViewKey.currentState?.webView?.addPersistentLabel(
              modelData.identifier,
              registeredName,
            );
          }
        }

        // Show star info bottom sheet (it will handle touch re-enable on close)
        _showStarInfo(starInfo);
      } else if (mounted) {
        // Re-enable touch since we're not showing star info
        _skyViewKey.currentState?.webView?.setTouchEnabled(true);
        // Show not found message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration number "$registrationNumber" not found'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog and re-enable touch
      if (mounted) {
        Navigator.of(context).pop();
        _skyViewKey.currentState?.webView?.setTouchEnabled(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  void _showStarInfo(StarInfo starInfo) {
    debugPrint('HomeScreen: _showStarInfo called for: ${starInfo.shortName}');

    // Don't show if already showing
    if (_starInfoSheetShowing) {
      debugPrint('HomeScreen: _showStarInfo skipped - sheet already showing');
      return;
    }

    debugPrint('HomeScreen: showing star info sheet');

    // Disable WebView touch handling while modal is open
    _skyViewKey.currentState?.webView?.setTouchEnabled(false);
    _starInfoSheetShowing = true;

    showStarInfoSheet(
      context,
      starInfo,
      onPointAt: () {
        // Point at the star using formatted identifier (e.g., "HIP 14778")
        final modelData = starInfo.modelData;
        if (modelData != null && modelData.identifier.isNotEmpty) {
          final searchId = modelData.searchIdentifier;
          _skyViewKey.currentState?.webView?.pointAt(searchId);
          _skyViewKey.currentState?.engine?.search(searchId).then((obj) {
            if (obj != null) {
              _skyViewKey.currentState?.engine?.pointAt(obj);
            }
          });
        }
      },
      onViewIn3D: () {
        Navigator.of(context).pop(); // Close the sheet first
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => StarViewerScreen(
              starName: starInfo.registryInfo?.name ?? starInfo.modelData?.shortName ?? starInfo.shortName,
              spectralType: starInfo.modelData?.spectralType,
            ),
          ),
        ).then((_) {
          // Reopen the info sheet when returning from 3D viewer
          _starInfoSheetShowing = false;
          _showStarInfo(starInfo);
        });
      },
    ).whenComplete(() {
      // Re-enable WebView touch handling when modal is closed
      _skyViewKey.currentState?.webView?.setTouchEnabled(true);
      // Always clear selection custom label - persistent labels handle saved stars
      _skyViewKey.currentState?.webView?.clearCustomLabel();
      // Stop gyroscope guidance arrow when sheet is closed
      _skyViewKey.currentState?.webView?.stopGuidance();
      // Clear the flag
      _starInfoSheetShowing = false;
    });
  }

  void _onObjectSelected(SelectedObjectInfo info) {
    debugPrint('HomeScreen: _onObjectSelected called with name: ${info.name}, type: ${info.type}');

    // Always clear the selection custom label - persistent labels handle saved star names
    _skyViewKey.currentState?.webView?.clearCustomLabel();

    // Only show info sheet if we have meaningful data about the star
    if (info.name.isEmpty || info.name == 'Unknown') {
      debugPrint('HomeScreen: skipping - name is empty or Unknown');
      return;
    }

    // Track star selection
    AnalyticsService.instance.logStarSelect(starName: info.displayName);

    debugPrint('HomeScreen: _starInfoSheetShowing = $_starInfoSheetShowing');

    // Create basic star info immediately from selection data
    final basicStarInfo = StarInfo.fromBasicData(
      name: info.displayName,
      ra: info.ra,
      dec: info.dec,
      magnitude: info.magnitude,
      names: info.names, // Pass names to extract HIP/HD for catalog ID
    );

    // Create a future for the registry lookup (runs in background)
    final registryFuture = _fetchRegistryInfo(info);

    // Show the sheet immediately with basic info, registry data will load async
    _showStarInfoWithRegistry(basicStarInfo, registryFuture, info);
  }

  /// Fetch registry info trying multiple identifiers
  Future<StarInfo?> _fetchRegistryInfo(SelectedObjectInfo info) async {
    StarInfo? registryInfo;

    // First, check if we have a saved star with a registration number
    // This handles the case where user previously looked up by registration number
    final savedStars = SavedStarsService.instance.savedStars;
    String? savedRegistrationNumber;

    // Helper to normalize identifiers for comparison (remove spaces, lowercase)
    String normalize(String s) => s.toLowerCase().replaceAll(' ', '');

    for (final saved in savedStars) {
      if (saved.registrationNumber != null && saved.registrationNumber!.isNotEmpty) {
        final savedIdNorm = normalize(saved.id);
        final savedScientificNorm = normalize(saved.scientificName ?? '');
        final infoNameNorm = normalize(info.name);

        // Match by normalized ID, scientific name, or any name in the list
        bool matches = savedIdNorm == infoNameNorm ||
            savedScientificNorm == infoNameNorm ||
            info.names.any((n) => normalize(n) == savedIdNorm) ||
            info.names.any((n) => normalize(n) == savedScientificNorm);

        if (matches) {
          savedRegistrationNumber = saved.registrationNumber;
          debugPrint('Found saved registration number: $savedRegistrationNumber for ${info.name} (matched ${saved.id})');
          break;
        }
      }
    }

    // If we have a saved registration number, use it directly
    if (savedRegistrationNumber != null) {
      registryInfo = await StarRegistryService.searchByRegistrationNumber(savedRegistrationNumber);
      if (registryInfo != null && registryInfo.found) {
        debugPrint('Found star via saved registration number');
        _handleRegisteredStar(registryInfo);
        return registryInfo;
      }
    }

    // Use the star's identifiers to validate API results (prevent fuzzy match errors)
    final validIdentifiers = info.names.isNotEmpty ? info.names : [info.name];

    // Try primary name
    registryInfo = await StarRegistryService.searchByName(info.name, validIdentifiers: validIdentifiers);

    // If not found, try HIP numbers
    if ((registryInfo == null || !registryInfo.found) && info.names.isNotEmpty) {
      for (final name in info.names) {
        if (name.startsWith('HIP ')) {
          registryInfo = await StarRegistryService.searchByName(name, validIdentifiers: validIdentifiers);
          if (registryInfo != null && registryInfo.found) break;
        }
      }
    }

    // If still not found, try HD numbers
    if ((registryInfo == null || !registryInfo.found) && info.names.isNotEmpty) {
      for (final name in info.names) {
        if (name.startsWith('HD ')) {
          registryInfo = await StarRegistryService.searchByName(name, validIdentifiers: validIdentifiers);
          if (registryInfo != null && registryInfo.found) break;
        }
      }
    }

    // If registered, handle custom label and auto-save
    if (registryInfo != null && registryInfo.found && registryInfo.isRegistered) {
      _handleRegisteredStar(registryInfo);
    }

    return registryInfo;
  }

  /// Handle a registered star - set label and save
  void _handleRegisteredStar(StarInfo registryInfo) {
    if (registryInfo.registryInfo == null) return;

    final registeredName = registryInfo.registryInfo!.name;
    _skyViewKey.currentState?.webView?.setCustomLabel(registeredName);

    final modelData = registryInfo.modelData;
    if (modelData != null) {
      final savedStar = SavedStar(
        id: modelData.identifier,
        displayName: registeredName,
        scientificName: modelData.identifier,
        registrationNumber: registryInfo.registryInfo!.registrationNumber,
        ra: modelData.rightAscension,
        dec: modelData.declination,
        magnitude: modelData.vMagnitude,
      );
      SavedStarsService.instance.saveStar(savedStar);
      _skyViewKey.currentState?.webView?.addPersistentLabel(
        modelData.identifier,
        registeredName,
      );
    }
  }

  void _showStarInfoWithRegistry(StarInfo basicInfo, Future<StarInfo?> registryFuture, SelectedObjectInfo selectionInfo) {
    debugPrint('HomeScreen: _showStarInfoWithRegistry called for: ${basicInfo.shortName}');

    if (_starInfoSheetShowing) {
      debugPrint('HomeScreen: sheet already showing, skipping');
      return;
    }

    _skyViewKey.currentState?.webView?.setTouchEnabled(false);
    _starInfoSheetShowing = true;

    showStarInfoSheet(
      context,
      basicInfo,
      registryFuture: registryFuture,
      onPointAt: () {
        final modelData = basicInfo.modelData;
        if (modelData != null && modelData.identifier.isNotEmpty) {
          final searchId = modelData.searchIdentifier;
          _skyViewKey.currentState?.webView?.pointAt(searchId);
          _skyViewKey.currentState?.engine?.search(searchId).then((obj) {
            if (obj != null) {
              _skyViewKey.currentState?.engine?.pointAt(obj);
            }
          });
        }
      },
      onNameStar: () async {
        Navigator.of(context).pop(); // Close the sheet first

        // Get current locale to determine which site to open
        final locale = LocaleService.instance.locale ?? ui.PlatformDispatcher.instance.locale;
        final isGerman = locale.languageCode == 'de';

        final url = isGerman
            ? 'https://sterntaufe-deutschland.de'
            : 'https://star-registration.com';

        debugPrint('Name this star tapped, opening: $url');

        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      onViewIn3D: () {
        Navigator.of(context).pop(); // Close the sheet first
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => StarViewerScreen(
              starName: selectionInfo.displayName,
              spectralType: basicInfo.modelData?.spectralType,
            ),
          ),
        ).then((_) {
          // Reopen the info sheet when returning from 3D viewer
          _starInfoSheetShowing = false;
          _showStarInfoWithRegistry(basicInfo, _fetchRegistryInfo(selectionInfo), selectionInfo);
        });
      },
    ).whenComplete(() {
      _skyViewKey.currentState?.webView?.setTouchEnabled(true);
      _skyViewKey.currentState?.webView?.clearCustomLabel();
      _skyViewKey.currentState?.webView?.stopGuidance();
      _starInfoSheetShowing = false;
    });
  }
}
