import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../features/onboarding/onboarding_service.dart';
import '../l10n/app_localizations.dart';
import '../services/analytics_service.dart';
import '../services/app_review_service.dart';
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
import 'certificate_scanner_screen.dart';
import 'certificate_scanner_screen_web.dart';
import 'star_viewer_screen.dart';

const String _googleApiKey = 'AIzaSyCc4LPIozIoEHVAMFz5uyQ_LrT1nAlbmfc';

/// The main screen displaying the sky view with controls.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final GlobalKey<SkyViewState> _skyViewKey = GlobalKey<SkyViewState>();
  final TextEditingController _searchController = TextEditingController();

  // Default observer - will be updated with saved location
  Observer _observer = Observer.now(
    latitude: Observer.deg2rad(OnboardingService.defaultLatitude),
    longitude: Observer.deg2rad(OnboardingService.defaultLongitude),
  );

  @override
  void initState() {
    super.initState();
    // Register for app lifecycle events
    WidgetsBinding.instance.addObserver(this);
    // Track home screen view
    AnalyticsService.instance.logScreenView(screenName: 'home');
    // Load saved stars and search history
    SavedStarsService.instance.load();
    SearchHistoryService.instance.load();
    // Load saved location from onboarding
    _loadSavedLocation();
    // Initialize and start app review tracking
    _initAppReviewTracking();
  }

  Future<void> _initAppReviewTracking() async {
    await AppReviewService.instance.load();
    AppReviewService.instance.startTracking();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Handle app lifecycle for review tracking
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        AppReviewService.instance.pauseTracking();
        break;
      case AppLifecycleState.resumed:
        AppReviewService.instance.resumeTracking();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _loadSavedLocation() async {
    final location = await OnboardingService.getUserLocationOrDefault();
    setState(() {
      _observer = Observer.now(
        latitude: Observer.deg2rad(location.latitude),
        longitude: Observer.deg2rad(location.longitude),
      );
    });
    // Also update the engine/webview location
    _skyViewKey.currentState?.webView?.setLocation(
      location.latitude,
      location.longitude,
    );
    _skyViewKey.currentState?.engine?.setLocation(
      latitude: Observer.deg2rad(location.latitude),
      longitude: Observer.deg2rad(location.longitude),
    );
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
    WidgetsBinding.instance.removeObserver(this);
    AppReviewService.instance.stopTracking();
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
  bool _gyroscopeEnabled = false; // Start disabled, enable when gyroscope is confirmed available
  bool _gyroscopeAvailable = false;
  bool _subMenuOpening = false; // Track if sub-menu is about to open
  StarInfo? _selectedStarInfo; // Currently selected star info (shown inline, not modal)
  Future<StarInfo?>? _registryFuture; // Future for loading registry data
  SelectedObjectInfo? _selectedObjectInfo; // Selection info for callbacks
  List<SearchSuggestion> _searchSuggestions = []; // Search history suggestions
  String? _locationName; // Display name for current location
  bool _showTimeSlider = false; // Track if time slider is visible
  bool _isTimePaused = false; // Track if time is paused
  DateTime? _sliderDate; // The date (year, month, day) shown on slider - only changes with day arrows
  Timer? _timeUpdateTimer; // Timer to refresh time display
  String _lastDisplayedTime = ''; // Track last displayed time to avoid unnecessary rebuilds
  bool _starTrackEnabled = false; // Track if star 24h path is visible
  bool _isEngineReady = false; // Track if Stellarium engine has loaded


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
    final hasStarInfo = _selectedStarInfo != null;

    // Simple Stack layout - Flutter's hit-testing naturally blocks touches on UI elements.
    // SkyView has its own Listener that forwards non-blocked touches to the WebView.
    return Scaffold(
      backgroundColor: Colors.transparent,
      // GestureDetector to unfocus search field, hide suggestions, and close time slider when tapping elsewhere
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          if (_searchSuggestions.isNotEmpty || _showTimeSlider) {
            setState(() {
              _searchSuggestions = [];
              _showTimeSlider = false;
            });
          }
        },
        behavior: HitTestBehavior.translucent,
        child: Stack(
        children: [
          // Sky view with night mode filter (full screen, at bottom of stack)
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
                  // Auto-enable gyroscope when it becomes available (mobile only)
                  // On web, require explicit user tap to trigger permission request
                  if (!kIsWeb && available && !_gyroscopeEnabled) {
                    _gyroscopeEnabled = true;
                  }
                });
              },
              onObjectSelected: _onObjectSelected,
              onEngineReady: _onEngineReady,
              onTimeChanged: _onEngineTimeChanged,
              onTap: () {
                // Close time slider when tapping on sky view
                if (_showTimeSlider) {
                  setState(() {
                    _showTimeSlider = false;
                  });
                }
              },
            ),
          ),

          // Top bar with location and time (only when engine is ready)
          if (_isEngineReady)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _buildTopBar(context),
            ),

          // Time slider (appears below top bar when time is tapped)
          if (_isEngineReady && _showTimeSlider)
            Positioned(
              left: 0,
              right: 0,
              top: MediaQuery.of(context).padding.top + 52,
              child: _buildTimeSlider(context),
            ),

          // Bottom bar with buttons and search (only when star info not shown and engine is ready)
          if (_isEngineReady && !hasStarInfo)
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
                  final newValue = !_settings.atmosphere;
                  AnalyticsService.instance.logAtmosphereToggle(enabled: newValue);
                  _onSettingChanged('atmosphere', newValue);
                },
                onGyroscopeTap: () async {
                  // On web iOS, must request permission directly from user tap
                  if (kIsWeb && !_gyroscopeEnabled) {
                    final granted = await _skyViewKey.currentState?.requestMotionPermission() ?? false;
                    if (!granted) {
                      debugPrint('Motion permission denied');
                      return;
                    }
                  }
                  setState(() {
                    _gyroscopeEnabled = !_gyroscopeEnabled;
                    AnalyticsService.instance.logGyroscopeToggle(enabled: _gyroscopeEnabled);
                  });
                },
                onSearchTap: () {
                  AnalyticsService.instance.logSearchFocused();
                  _showSearchHistory();
                },
                onSearchSubmitted: _searchAndPoint,
                onSearchChanged: _onSearchChanged,
                onHamburgerTap: () {
                  AnalyticsService.instance.logMenuOpened();
                  _showSettingsBottomSheet();
                },
                onScanTap: _openScanner,
                searchSuggestions: _searchSuggestions,
                onSuggestionTap: _onSuggestionTap,
              ),
            ),

          // Star info panel overlay (only when engine is ready)
          if (_isEngineReady && hasStarInfo)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildStarInfoPanel(),
            ),
        ],
        ),
      ),
    );
  }

  Widget _buildStarInfoPanel() {
    final maxHeight = MediaQuery.of(context).size.height * 0.4;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: StarInfoBottomSheet(
        // Key ensures widget rebuilds when star changes
        key: ValueKey(_selectedStarInfo!.shortName),
        starInfo: _selectedStarInfo!,
      registryFuture: _registryFuture,
      onClose: _closeStarInfo,
      onPointAt: () {
        // Track point at action
        AnalyticsService.instance.logStarPointAt(starName: _selectedStarInfo!.shortName);
        // Use searchQuery which returns registration number for registered stars
        final query = _selectedStarInfo!.searchQuery;
        if (query.isNotEmpty) {
          _pointAtOrSelect(query);
        }
      },
      onNameStar: () async {
        // Track name star click
        AnalyticsService.instance.logNameStarClicked();
        final locale = LocaleService.instance.locale ?? ui.PlatformDispatcher.instance.locale;
        final languageCode = locale.languageCode;

        // Get the HIP number from multiple sources
        String? hipNumber;
        final modelData = _selectedStarInfo?.modelData;

        // Try from modelData.identifier first
        if (modelData != null && modelData.identifier.isNotEmpty) {
          debugPrint('onNameStar: modelData.identifier = ${modelData.identifier}');
          final hipMatch = RegExp(r'HIP\s*(\d+)', caseSensitive: false).firstMatch(modelData.identifier);
          if (hipMatch != null) {
            hipNumber = hipMatch.group(1);
            debugPrint('onNameStar: Found HIP from identifier: $hipNumber');
          }
        }

        // If not found, try from _selectedObjectInfo.names
        if (hipNumber == null && _selectedObjectInfo != null) {
          debugPrint('onNameStar: _selectedObjectInfo.names = ${_selectedObjectInfo!.names}');
          for (final name in _selectedObjectInfo!.names) {
            final hipMatch = RegExp(r'HIP\s*(\d+)', caseSensitive: false).firstMatch(name);
            if (hipMatch != null) {
              hipNumber = hipMatch.group(1);
              debugPrint('onNameStar: Found HIP from names list: $hipNumber');
              break;
            }
          }
        }

        // Also try _selectedObjectInfo.name as fallback
        if (hipNumber == null && _selectedObjectInfo != null) {
          debugPrint('onNameStar: _selectedObjectInfo.name = ${_selectedObjectInfo!.name}');
          final hipMatch = RegExp(r'HIP\s*(\d+)', caseSensitive: false).firstMatch(_selectedObjectInfo!.name);
          if (hipMatch != null) {
            hipNumber = hipMatch.group(1);
            debugPrint('onNameStar: Found HIP from name: $hipNumber');
          }
        }

        // Build URL based on language
        final baseUrl = languageCode == 'de'
            ? 'https://www.sterntaufe-deutschland.de/products/sterntaufe'
            : 'https://www.star-registration.com/products/standard';

        // Add HIP number as query parameter if available
        final uri = hipNumber != null
            ? Uri.parse('$baseUrl?hip=$hipNumber')
            : Uri.parse(baseUrl);

        debugPrint('onNameStar: Opening URL: $uri');

        // Launch URL first, then close the info panel
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint('onNameStar: Failed to launch URL: $e');
        }

        _closeStarInfo();
      },
      onViewIn3D: (effectiveName) {
        // Track 3D view action
        AnalyticsService.instance.logStarView3D(starName: effectiveName);
        final starInfo = _selectedStarInfo!;
        final selectionInfo = _selectedObjectInfo;
        _closeStarInfo();

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => StarViewerScreen(
              starName: effectiveName,
              spectralType: starInfo.modelData?.spectralType,
            ),
          ),
        ).then((_) {
          // Reopen the info panel when returning from 3D viewer
          if (selectionInfo != null) {
            setState(() {
              _selectedStarInfo = starInfo;
              _registryFuture = _fetchRegistryInfo(selectionInfo);
              _selectedObjectInfo = selectionInfo;
            });
          }
        });
      },
      starTrackEnabled: _starTrackEnabled,
      onToggleStarTrack: (enabled) {
        // Track star path toggle
        AnalyticsService.instance.logStarPathToggle(
          starName: _selectedStarInfo!.shortName,
          enabled: enabled,
        );
        setState(() {
          _starTrackEnabled = enabled;
        });
        _skyViewKey.currentState?.webView?.setStarTrackVisible(enabled);
      },
      ),
    );
  }

  void _closeStarInfo() {
    setState(() {
      _selectedStarInfo = null;
      _registryFuture = null;
      _selectedObjectInfo = null;
      _starTrackEnabled = false;
    });
    // Clear custom label, stop guidance, and disable star tracking
    _skyViewKey.currentState?.webView?.clearCustomLabel();
    _skyViewKey.currentState?.webView?.stopGuidance();
    _skyViewKey.currentState?.webView?.setStarTrackVisible(false);
  }

  /// Helper to point at or select a star based on gyroscope mode.
  void _pointAtOrSelect(String searchId) {
    if (_gyroscopeEnabled) {
      // Gyroscope mode: start guidance (finds object, notifies Flutter, shows arrow)
      _skyViewKey.currentState?.webView?.setGyroscopeEnabled(true);
      _skyViewKey.currentState?.webView?.startGuidance(searchId);
    } else {
      // Normal mode: animate camera to the star
      _skyViewKey.currentState?.webView?.pointAt(searchId);
      // On web, use pointAtByName which calls JS API with registry lookup
      if (kIsWeb) {
        final engine = _skyViewKey.currentState?.engine;
        if (engine != null) {
          (engine as dynamic).pointAtByName(searchId);
        }
      } else {
        _skyViewKey.currentState?.engine?.search(searchId).then((obj) {
          if (obj != null) {
            _skyViewKey.currentState?.engine?.pointAt(obj);
          }
        });
      }
    }
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

    // No Listener wrapper needed - event blocking is handled at HomeScreen level
    // via _isPositionOnUI() check before forwarding to SkyView.
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

    // Wrap in GestureDetector to absorb taps and prevent closing when interacting with the slider
    return GestureDetector(
      onTap: () {}, // Absorb taps to prevent the parent GestureDetector from closing the slider
      child: Container(
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
              _setTimeSpeed(0.0);
            },
            onChangeEnd: (_) {
              // Resume time if it wasn't paused before, or keep it paused
              if (!_isTimePaused) {
                _setTimeSpeed(1.0);
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
                      _setTimeSpeed(1.0);
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
                      _setTimeSpeed(newPausedState ? 0.0 : 1.0);
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

    // Update engine ready state
    setState(() {
      _isEngineReady = true;
    });

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

      // Wait for gyroscope state to be determined (up to 2 seconds)
      // This ensures _gyroscopeEnabled is correctly set before _pointAtOrSelect
      int waitMs = 0;
      while (!_gyroscopeAvailable && waitMs < 2000 && mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitMs += 100;
      }

      // Additional small delay to ensure everything is ready
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
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
        // Try to use HIP identifier if available (engine looks up by HIP)
        String labelId = star.scientificName!;
        final hipMatch = RegExp(r'^HIP\s*(\d+)', caseSensitive: false).firstMatch(star.id);
        if (hipMatch != null) {
          labelId = 'HIP ${hipMatch.group(1)}';
        } else {
          final hipMatch2 = RegExp(r'^HIP\s*(\d+)', caseSensitive: false).firstMatch(star.scientificName!);
          if (hipMatch2 != null) {
            labelId = 'HIP ${hipMatch2.group(1)}';
          }
        }
        debugPrint('_loadPersistentLabels: Adding label with ID: $labelId for ${star.displayName}');
        _skyViewKey.currentState?.webView?.addPersistentLabel(
          labelId,
          star.displayName,
        );
        // Web support
        if (kIsWeb) {
          final engine = _skyViewKey.currentState?.engine;
          if (engine != null) {
            (engine as dynamic).addPersistentLabel(labelId, star.displayName);
          }
        }
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
        currentTime: _currentTime, // Pass engine time for visibility calculations
        onSubMenuOpening: () {
          // Sub-menu is about to open, keep touch disabled
          _subMenuOpening = true;
        },
        onSubMenuClosed: () {
          // Sub-menu closed, re-enable touch
          _skyViewKey.currentState?.webView?.setTouchEnabled(true);
        },
        onSelectStar: (star) {
          _pointAtOrSelect(star.searchQuery);
          // Create SelectedObjectInfo to use the same flow as clicking on a star
          // This ensures the registry API is called and coordinates are fetched
          final names = <String>[star.id];
          if (star.scientificName != null && star.scientificName != star.id) {
            names.add(star.scientificName!);
          }
          final selectionInfo = SelectedObjectInfo(
            name: star.scientificName ?? star.id,
            displayName: star.displayName,
            names: names,
            type: 'Star',
            magnitude: star.magnitude,
            ra: star.ra,
            dec: star.dec,
          );
          // Use the same flow as _onObjectSelected to get registry info
          _onObjectSelected(selectionInfo);
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

  void _setTimeSpeed(double speed) {
    final skyView = _skyViewKey.currentState;
    // Web engine (web builds)
    skyView?.engine?.setTimeSpeed(speed);
    // WebView JS engine (mobile builds)
    skyView?.webView?.setTimeSpeed(speed);
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
    // Track suggestion selection
    AnalyticsService.instance.logSearchSuggestionSelected(suggestion: suggestion.value);
    // Execute the search from history
    setState(() {
      _searchSuggestions = [];
    });
    _searchAndPoint(suggestion.value);
  }

  /// Opens the certificate scanner and searches for the detected registration number
  Future<void> _openScanner() async {
    // Track scanner opened
    AnalyticsService.instance.logScannerOpened();

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => kIsWeb
            ? const CertificateScannerScreenWeb()
            : const CertificateScannerScreen(),
      ),
    );

    // If a registration number was detected and returned, search for it
    if (result != null && result.isNotEmpty && mounted) {
      _searchAndPoint(result);
    }
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

    _pointAtOrSelect(trimmedQuery);
  }

  Future<void> _searchRegistrationNumber(String registrationNumber) async {
    // Show loading indicator
    if (!mounted) return;

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
        // Use searchQuery which returns registration number for registered stars
        final query = starInfo.searchQuery;
        final modelData = starInfo.modelData;
        if (query.isNotEmpty) {
          _pointAtOrSelect(query);

          // Show registered name as custom label if available and auto-save
          if (starInfo.isRegistered && starInfo.registryInfo != null && modelData != null) {
            final registeredName = starInfo.registryInfo!.name;
            // Set temporary selection label (will be cleared when panel closes)
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
            // Use HIP identifier if available, as engine looks up by HIP
            final labelId = starInfo.hipIdentifier ?? modelData.identifier;
            debugPrint('Adding persistent label with ID: $labelId for $registeredName');
            _skyViewKey.currentState?.webView?.addPersistentLabel(
              labelId,
              registeredName,
            );
            // Web support
            if (kIsWeb) {
              final engine = _skyViewKey.currentState?.engine;
              if (engine != null) {
                (engine as dynamic).addPersistentLabel(labelId, registeredName);
              }
            }
          }
        }

        // Show star info panel
        _showStarInfo(starInfo);
      } else if (mounted) {
        // Show not found message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration number "$registrationNumber" not found'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
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

    setState(() {
      _selectedStarInfo = starInfo;
      _registryFuture = null;
      _selectedObjectInfo = null;
    });
  }

  void _onObjectSelected(SelectedObjectInfo info) {
    debugPrint('HomeScreen: _onObjectSelected called with name: ${info.name}, type: ${info.type}');
    debugPrint('HomeScreen: HIP: ${info.hip}, GAIA: ${info.gaia}');
    debugPrint('HomeScreen: hasFullRegistryInfo: ${info.hasFullRegistryInfo}');

    // Always clear the selection custom label - persistent labels handle saved star names
    _skyViewKey.currentState?.webView?.clearCustomLabel();

    // Only show info sheet if we have meaningful data about the star
    if (info.name.isEmpty || info.name == 'Unknown') {
      debugPrint('HomeScreen: skipping - name is empty or Unknown');
      return;
    }

    // Track star selection
    AnalyticsService.instance.logStarSelect(starName: info.displayName);

    // If we already have full registry info from skySource (from registration number lookup),
    // use it directly instead of making another API call
    if (info.hasFullRegistryInfo && info.skySource != null) {
      debugPrint('HomeScreen: Using skySource data directly, skipping API lookup');
      final starInfo = StarInfo.fromApiResponse(info.skySource!);
      _showStarInfo(starInfo);
      return;
    }

    // Create basic star info immediately from selection data
    final basicStarInfo = StarInfo.fromBasicData(
      name: info.displayName,
      ra: info.ra,
      dec: info.dec,
      magnitude: info.magnitude,
      names: info.names,
      hip: info.hip, // Direct HIP from engine (most reliable)
    );

    // Create a future for the registry lookup (runs in background)
    final registryFuture = _fetchRegistryInfo(info);

    // Show the sheet immediately with basic info, registry data will load async
    _showStarInfoWithRegistry(basicStarInfo, registryFuture, info);
  }

  /// Fetch registry info trying multiple identifiers
  Future<StarInfo?> _fetchRegistryInfo(SelectedObjectInfo info) async {
    // Helper to normalize identifiers for comparison
    String normalize(String s) => s.toLowerCase().replaceAll(' ', '');

    // Helper to extract HIP number from string like "HIP90156" or "HIP 90156"
    int? extractHip(String s) {
      final match = RegExp(r'HIP\s*(\d+)', caseSensitive: false).firstMatch(s);
      return match != null ? int.tryParse(match.group(1)!) : null;
    }

    // 1. Check if we have a saved registration number for this star
    final savedStars = SavedStarsService.instance.savedStars;
    for (final saved in savedStars) {
      if (saved.registrationNumber == null || saved.registrationNumber!.isEmpty) continue;

      final savedIdNorm = normalize(saved.id);
      final savedScientificNorm = normalize(saved.scientificName ?? '');
      final infoNameNorm = normalize(info.name);

      // Check by HIP number if available (most reliable)
      final savedHip = extractHip(saved.id) ?? extractHip(saved.scientificName ?? '');
      final hipMatches = info.hip != null && savedHip != null && info.hip == savedHip;

      final nameMatches = savedIdNorm == infoNameNorm ||
          savedScientificNorm == infoNameNorm ||
          info.names.any((n) => normalize(n) == savedIdNorm || normalize(n) == savedScientificNorm);

      if (hipMatches || nameMatches) {
        final result = await StarRegistryService.searchByRegistrationNumber(saved.registrationNumber!);
        if (result != null && result.found) {
          _handleRegisteredStar(result);
          return result;
        }
      }
    }

    // 2. Build ordered list of identifiers to try: HIP first, then HD, then others
    final validIdentifiers = info.names.isNotEmpty ? info.names : [info.name];
    final identifiersToTry = <String>[];

    // Direct HIP from engine has highest priority
    if (info.hip != null) {
      identifiersToTry.add('HIP ${info.hip}');
    }

    // Add HIP and HD from names first, then everything else
    for (final name in validIdentifiers) {
      if (name.startsWith('HIP ') || name.startsWith('HD ')) {
        if (!identifiersToTry.contains(name)) identifiersToTry.add(name);
      }
    }
    for (final name in validIdentifiers) {
      if (!identifiersToTry.contains(name)) identifiersToTry.add(name);
    }

    // 3. Try each identifier until we find a match
    for (final identifier in identifiersToTry) {
      final result = await StarRegistryService.searchByName(identifier, validIdentifiers: validIdentifiers);
      if (result != null && result.found) {
        if (result.isRegistered) {
          _handleRegisteredStar(result);
        }
        return result;
      }
    }

    return null;
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
      // Use HIP identifier if available, as engine looks up by HIP
      final labelId = registryInfo.hipIdentifier ?? modelData.identifier;
      debugPrint('_handleRegisteredStar: Adding persistent label with ID: $labelId for $registeredName');
      _skyViewKey.currentState?.webView?.addPersistentLabel(
        labelId,
        registeredName,
      );
      // Web support
      if (kIsWeb) {
        final engine = _skyViewKey.currentState?.engine;
        if (engine != null) {
          (engine as dynamic).addPersistentLabel(labelId, registeredName);
        }
      }
    }
  }

  void _showStarInfoWithRegistry(StarInfo basicInfo, Future<StarInfo?> registryFuture, SelectedObjectInfo selectionInfo) {
    debugPrint('HomeScreen: _showStarInfoWithRegistry called for: ${basicInfo.shortName}');

    setState(() {
      _selectedStarInfo = basicInfo;
      _registryFuture = registryFuture;
      _selectedObjectInfo = selectionInfo;
    });
  }
}
