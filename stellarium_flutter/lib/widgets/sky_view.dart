import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../stellarium/stellarium.dart';
import 'stellarium_webview.dart';


/// A widget that displays the Stellarium sky view with gesture controls.
class SkyView extends StatefulWidget {
  /// Optional initial observer settings
  final Observer? initialObserver;

  /// Callback when the observer changes (location, time, view direction)
  final ValueChanged<Observer>? onObserverChanged;

  /// Whether to show the FPS counter
  final bool showFps;

  /// Whether to show the coordinates overlay
  final bool showCoordinates;

  /// Whether gyroscope navigation is enabled
  final bool gyroscopeEnabled;

  /// Callback when gyroscope mode availability changes
  final ValueChanged<bool>? onGyroscopeAvailabilityChanged;

  /// Callback when a celestial object is selected
  final void Function(SelectedObjectInfo info)? onObjectSelected;

  /// Callback when the engine is ready
  final void Function(bool ready)? onEngineReady;

  /// Callback when the engine time changes
  final void Function(double utc)? onTimeChanged;

  const SkyView({
    super.key,
    this.initialObserver,
    this.onObserverChanged,
    this.showFps = false,
    this.showCoordinates = false,
    this.gyroscopeEnabled = false,
    this.onGyroscopeAvailabilityChanged,
    this.onObjectSelected,
    this.onEngineReady,
    this.onTimeChanged,
  });

  @override
  SkyViewState createState() => SkyViewState();
}

class SkyViewState extends State<SkyView> {
  StellariumEngine? _engine;
  bool _isInitialized = false;
  bool _touchBlocked = false;

  /// Access to the underlying engine for settings changes
  StellariumEngine? get engine => _engine;
  String? _errorMessage;
  double _fps = 0.0;
  Observer _observer = Observer.now();

  // WebView for mobile platforms
  final GlobalKey<StellariumWebViewState> _webViewKey = GlobalKey();

  /// Access to the WebView for settings changes on mobile
  StellariumWebViewState? get webView => _webViewKey.currentState;

  /// Block or unblock touch events on the sky view
  void setTouchBlocked(bool blocked) {
    setState(() {
      _touchBlocked = blocked;
    });
  }

  /// Forward a pointer down event to the engine (called from parent widget)
  void onPointerDown(PointerDownEvent event, double devicePixelRatio) {
    if (_touchBlocked || !kIsWeb) return;
    _engine?.onPointerDown(
      event.pointer,
      event.localPosition.dx * devicePixelRatio,
      event.localPosition.dy * devicePixelRatio,
    );
  }

  /// Forward a pointer move event to the engine (called from parent widget)
  void onPointerMove(PointerMoveEvent event, double devicePixelRatio) {
    if (_touchBlocked || widget.gyroscopeEnabled || !kIsWeb) return;
    _engine?.onPointerMove(
      event.pointer,
      event.localPosition.dx * devicePixelRatio,
      event.localPosition.dy * devicePixelRatio,
    );
  }

  /// Forward a pointer up event to the engine (called from parent widget)
  void onPointerUp(PointerUpEvent event, double devicePixelRatio) {
    if (_touchBlocked || !kIsWeb) return;
    _engine?.onPointerUp(
      event.pointer,
      event.localPosition.dx * devicePixelRatio,
      event.localPosition.dy * devicePixelRatio,
    );
  }

  /// Forward a scroll event to the engine for zoom (called from parent widget)
  void onPointerScroll(PointerScrollEvent event, double devicePixelRatio) {
    if (_touchBlocked || !kIsWeb) return;
    _engine?.onZoom(
      event.scrollDelta.dy > 0 ? 1.1 : 0.9,
      event.localPosition.dx * devicePixelRatio,
      event.localPosition.dy * devicePixelRatio,
    );
  }

  // Gyroscope and sensors
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  bool _gyroscopeAvailable = false;
  bool _compassAvailable = false;
  bool _isCalibrated = false;

  // Track current view direction (radians)
  double _currentAzimuth = 0.0;
  double _currentAltitude = math.pi / 4; // Start looking at 45 degrees up

  // Compass heading from flutter_compass (degrees, 0 = North, 90 = East)
  double _compassHeading = 0.0;
  double _filteredCompassHeading = 0.0;
  bool _compassInitialized = false;


  // ============================================================================
  // COMPASS 180° FLIP COMPENSATION
  // ============================================================================
  // When the phone tilts past a certain angle (roughly when pointing at zenith),
  // the device's compass/magnetometer suddenly reports a heading that is 180°
  // opposite to the actual direction. This happens because the phone's internal
  // orientation reference frame changes when tilted past horizontal.
  //
  // DETECTION: We track the previous raw compass value. When the raw compass
  // suddenly jumps by approximately 180° (we use 150°-210° range to account
  // for noise), we know a flip occurred.
  //
  // COMPENSATION: We maintain a boolean `_compassFlipped` state. Each time we
  // detect a ~180° jump, we toggle this state. When flipped, we add 180° to
  // the raw compass reading before applying the low-pass filter. This way:
  // - First flip (tilting up past threshold): raw jumps 180°, we toggle ON,
  //   add 180° → result stays continuous
  // - Second flip (tilting back down): raw jumps 180° again, we toggle OFF,
  //   stop adding 180° → result stays continuous
  //
  // This approach is sensor-agnostic - it doesn't rely on specific accelerometer
  // thresholds, just detects the actual compass discontinuity when it happens.
  // ============================================================================
  bool _compassFlipped = false;
  double _lastRawCompass = 0.0;

  // Low-pass filtered accelerometer values (for stable altitude)
  double _filteredAccX = 0.0;
  double _filteredAccY = 0.0;
  double _filteredAccZ = 0.0;

  // Debug frame counter
  int _debugFrameCount = 0;

  // Dead zone thresholds - ignore micro-movements below these values (in degrees)
  static const double _compassDeadZone = 0.5; // Ignore compass changes < 0.5°
  static const double _altitudeDeadZone = 0.3; // Ignore altitude changes < 0.3°

  // Last applied values (for dead zone comparison)
  double _lastAppliedAzimuth = 0.0;
  double _lastAppliedAltitude = 0.0;

  @override
  void initState() {
    super.initState();
    _initEngine();
    _checkGyroscopeAvailability();
  }

  @override
  void didUpdateWidget(SkyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.gyroscopeEnabled != oldWidget.gyroscopeEnabled) {
      if (widget.gyroscopeEnabled) {
        _startGyroscope();
      } else {
        _stopGyroscope();
      }
    }
  }

  @override
  void dispose() {
    _stopGyroscope();
    _engine?.dispose();
    super.dispose();
  }

  Future<void> _checkGyroscopeAvailability() async {
    // Check if device has required sensors
    debugPrint('Sensors: checking availability...');

    // Test gyroscope
    try {
      bool gyroError = false;
      final testSub = gyroscopeEventStream().listen(
        (event) {
          debugPrint('Gyroscope: test event received: x=${event.x}, y=${event.y}, z=${event.z}');
        },
        onError: (error, stackTrace) {
          gyroError = true;
          // Only report unexpected errors to Crashlytics (not NO_SENSOR)
          if (error is PlatformException && error.code == 'NO_SENSOR') {
            debugPrint('Gyroscope: not available on this device');
          } else {
            debugPrint('Gyroscope: unexpected error: $error');
            FirebaseCrashlytics.instance.recordError(error, stackTrace);
          }
        },
        cancelOnError: true,
      );
      await Future.delayed(const Duration(milliseconds: 500));
      await testSub.cancel();
      _gyroscopeAvailable = !gyroError;
      debugPrint('Gyroscope: available = $_gyroscopeAvailable');
    } on PlatformException catch (e, stackTrace) {
      _gyroscopeAvailable = false;
      // Only report unexpected errors to Crashlytics (not NO_SENSOR)
      if (e.code == 'NO_SENSOR') {
        debugPrint('Gyroscope: not available on this device');
      } else {
        debugPrint('Gyroscope: unexpected error: ${e.code}');
        FirebaseCrashlytics.instance.recordError(e, stackTrace);
      }
    } catch (e, stackTrace) {
      _gyroscopeAvailable = false;
      debugPrint('Gyroscope: available = false, error: $e');
      FirebaseCrashlytics.instance.recordError(e, stackTrace);
    }

    // Test compass (flutter_compass uses Core Location on iOS for reliable heading)
    try {
      bool compassReceived = false;
      final compassTestSub = FlutterCompass.events?.listen((event) {
        if (!compassReceived && event.heading != null) {
          compassReceived = true;
          debugPrint('Compass: test heading received: ${event.heading!.toStringAsFixed(1)}°');
        }
      }, onError: (e) {
        debugPrint('Compass: test error: $e');
      });
      await Future.delayed(const Duration(milliseconds: 500));
      await compassTestSub?.cancel();
      debugPrint('Compass: available = $compassReceived');
      if (!compassReceived) {
        debugPrint('Compass: WARNING - No heading received! AR mode may not work correctly.');
      }
    } catch (e) {
      debugPrint('Compass: not available, error: $e');
    }

    widget.onGyroscopeAvailabilityChanged?.call(_gyroscopeAvailable);

    if (widget.gyroscopeEnabled && _gyroscopeAvailable) {
      _startGyroscope();
    }
  }

  void _startGyroscope() {
    if (!_gyroscopeAvailable) {
      debugPrint('Gyroscope: not available, cannot start');
      return;
    }

    debugPrint('AR Mode: starting sensors');
    _isCalibrated = false;

    // Disable touch panning in the WebView while gyroscope is active
    _webViewKey.currentState?.setGyroscopeEnabled(true);

    // Reset filtered values so they initialize from first reading
    _filteredAccX = 0.0;
    _filteredAccY = 0.0;
    _filteredAccZ = 0.0;


    // Start compass for heading (uses Core Location on iOS for reliable compass)
    _compassSubscription?.cancel();
    _compassInitialized = false;
    _compassFlipped = false;
    debugPrint('Compass: starting subscription...');
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (event.heading != null) {
        _compassHeading = event.heading!;

        // Detect 180° flip by checking if raw compass suddenly jumped ~180°
        if (_compassInitialized) {
          double rawDiff = (_compassHeading - _lastRawCompass).abs();
          // Handle wrap-around
          if (rawDiff > 180) rawDiff = 360 - rawDiff;

          // If compass jumped close to 180° (between 150° and 210°), toggle flip state
          if (rawDiff > 150 && rawDiff < 210) {
            _compassFlipped = !_compassFlipped;
          }
        }
        _lastRawCompass = _compassHeading;

        // Apply flip compensation if needed
        double correctedHeading = _compassHeading;
        if (_compassFlipped) {
          correctedHeading = (_compassHeading + 180.0) % 360.0;
        }

        // Adaptive filtering: small changes get heavy filtering (kill jitter),
        // large changes pass through quickly (responsive movement)
        if (!_compassInitialized) {
          _filteredCompassHeading = correctedHeading;
          _compassInitialized = true;
        } else {
          // Calculate the shortest angular difference
          double diff = correctedHeading - _filteredCompassHeading;
          // Handle wrap-around: if diff > 180, go the other way
          if (diff > 180) diff -= 360;
          if (diff < -180) diff += 360;

          // Adaptive filtering: heavy when still, moderate when moving for smooth motion
          final absDiff = diff.abs();
          final double alpha = absDiff < 2.0 ? 0.05 : (absDiff < 8.0 ? 0.15 : 0.3);

          _filteredCompassHeading += alpha * diff;
          // Normalize to 0-360 range
          if (_filteredCompassHeading < 0) _filteredCompassHeading += 360;
          if (_filteredCompassHeading >= 360) _filteredCompassHeading -= 360;
        }

        if (!_compassAvailable) {
          _compassAvailable = true;
          debugPrint('Compass: first heading received: ${_compassHeading.toStringAsFixed(1)}°');
        }
      }
    }, onError: (e) {
      debugPrint('Compass error: $e');
    });

    // Start accelerometer for device tilt (altitude)
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((event) {
      final ax = event.x;
      final ay = event.y;
      final az = event.z;
      // Initialize filter with first reading, then apply adaptive filter
      if (_filteredAccX == 0.0 && _filteredAccY == 0.0 && _filteredAccZ == 0.0) {
        _filteredAccX = ax;
        _filteredAccY = ay;
        _filteredAccZ = az;
      } else {
        // Adaptive filtering based on movement magnitude
        final diffX = ax - _filteredAccX;
        final diffY = ay - _filteredAccY;
        final diffZ = az - _filteredAccZ;
        final diffMag = diffX.abs() + diffY.abs() + diffZ.abs();
        final double alpha = diffMag < 0.5 ? 0.05 : (diffMag < 2.0 ? 0.12 : 0.25);

        _filteredAccX = _filteredAccX + alpha * diffX;
        _filteredAccY = _filteredAccY + alpha * diffY;
        _filteredAccZ = _filteredAccZ + alpha * diffZ;
      }
    }, onError: (e) {
      debugPrint('Accelerometer error: $e');
    });

    // Start gyroscope for triggering view updates at high frequency
    _gyroSubscription?.cancel();
    _gyroSubscription = gyroscopeEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(_onGyroscopeEvent, onError: (e) {
      debugPrint('Gyroscope error: $e');
    });
  }

  void _updateOrientationFromSensors() {
    // Need both compass and accelerometer data
    if (!_compassAvailable) return;
    if (_filteredAccX == 0 && _filteredAccY == 0 && _filteredAccZ == 0) return;

    final ax = _filteredAccX;
    final ay = _filteredAccY;
    final az = _filteredAccZ;

    // Normalize accelerometer to get gravity direction
    final accNorm = math.sqrt(ax * ax + ay * ay + az * az);
    if (accNorm < 0.1) return; // Invalid reading

    final upZ = az / accNorm;

    // Altitude: how much the camera (-Z direction) points above/below horizon
    // When phone is upright facing horizon: az ≈ 0 → upZ ≈ 0 → altitude ≈ 0
    // When phone points at zenith (screen up): az ≈ -9.8 → upZ ≈ -1 → altitude = 90°
    _currentAltitude = math.asin((-upZ).clamp(-1.0, 1.0));

    final altitudeDeg = _currentAltitude.abs() * 180.0 / math.pi;

    // Simply use compass directly - no filtering or freezing
    _currentAzimuth = _filteredCompassHeading * math.pi / 180.0;

    if (!_isCalibrated) {
      _isCalibrated = true;
      debugPrint('AR Mode: calibrated');
    }

    // Periodic debug output (every 60 frames ≈ 1 second)
    _debugFrameCount++;
    if (_debugFrameCount % 60 == 0) {
      debugPrint('DEBUG: compass=${_filteredCompassHeading.toStringAsFixed(1)}° (raw=${_compassHeading.toStringAsFixed(1)}°), alt=${altitudeDeg.toStringAsFixed(1)}°${_compassFlipped ? " FLIP" : ""}');
    }
  }

  void _stopGyroscope() {
    _gyroSubscription?.cancel();
    _gyroSubscription = null;
    _compassSubscription?.cancel();
    _compassSubscription = null;
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _isCalibrated = false;
    _compassAvailable = false;

    // Re-enable touch panning in the WebView
    _webViewKey.currentState?.setGyroscopeEnabled(false);
  }

  void _onGyroscopeEvent(GyroscopeEvent event) {
    if (!_isInitialized) return;

    // Update orientation from accelerometer/compass
    _updateOrientationFromSensors();

    if (!_isCalibrated) return;

    // Apply dead zone - ignore micro-movements to reduce jitter
    final azimuthDeg = _currentAzimuth * 180.0 / math.pi;
    final altitudeDeg = _currentAltitude * 180.0 / math.pi;
    final lastAzimuthDeg = _lastAppliedAzimuth * 180.0 / math.pi;
    final lastAltitudeDeg = _lastAppliedAltitude * 180.0 / math.pi;

    // Calculate angular difference (handle wrap-around for azimuth)
    double azimuthDiff = (azimuthDeg - lastAzimuthDeg).abs();
    if (azimuthDiff > 180) azimuthDiff = 360 - azimuthDiff;
    final altitudeDiff = (altitudeDeg - lastAltitudeDeg).abs();

    // Only update if movement exceeds dead zone
    if (azimuthDiff < _compassDeadZone && altitudeDiff < _altitudeDeadZone) {
      return; // Skip micro-movement
    }

    // Update last applied values
    _lastAppliedAzimuth = _currentAzimuth;
    _lastAppliedAltitude = _currentAltitude;

    // Apply to WebView (mobile) or engine (web)
    if (!kIsWeb) {
      _webViewKey.currentState?.lookAt(_currentAzimuth, _currentAltitude, 0.05);
    } else {
      _engine?.lookAt(
        azimuth: _currentAzimuth,
        altitude: _currentAltitude,
        animationDuration: 0.0,
      );
    }
  }

  Future<void> _initEngine() async {
    try {
      _engine = createStellariumEngine();

      // Apply initial observer if provided
      if (widget.initialObserver != null) {
        _observer = widget.initialObserver!;
      }

      // Set render callback
      _engine!.onRender = _onEngineRender;

      setState(() {});
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create engine: $e';
      });
    }
  }

  void _onEngineRender() {
    if (!mounted) return;

    setState(() {
      _fps = _engine?.fps ?? 0.0;
      _observer = _engine?.observer ?? _observer;
    });

    widget.onObserverChanged?.call(_observer);
  }

  Future<void> _initializeWithSize(Size size) async {
    if (_isInitialized || _engine == null) return;

    try {
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      await _engine!.initialize(
        width: size.width,
        height: size.height,
        pixelRatio: pixelRatio,
      );

      // Apply initial settings
      if (widget.initialObserver != null) {
        _engine!.setLocation(
          longitude: widget.initialObserver!.longitude,
          latitude: widget.initialObserver!.latitude,
          altitude: widget.initialObserver!.altitude,
        );
      }

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize engine: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // On mobile platforms, use WebView
    if (!kIsWeb) {
      return _buildMobileView();
    }

    // On web, use the native HtmlElementView
    return _buildWebView();
  }

  /// Forward a pointer down event to the WebView (called from parent widget)
  void forwardPointerDown(int pointer, double x, double y) {
    if (_touchBlocked) return;
    _webViewKey.currentState?.onPointerDown(pointer, x, y);
  }

  /// Forward a pointer move event to the WebView (called from parent widget)
  void forwardPointerMove(int pointer, double x, double y) {
    if (_touchBlocked || widget.gyroscopeEnabled) return;
    _webViewKey.currentState?.onPointerMove(pointer, x, y);
  }

  /// Forward a pointer up event to the WebView (called from parent widget)
  void forwardPointerUp(int pointer, double x, double y) {
    if (_touchBlocked) return;
    _webViewKey.currentState?.onPointerUp(pointer, x, y);
  }

  // Track active pointers and map to engine slots (engine only supports 0 and 1)
  final Map<int, int> _pointerSlots = {};
  int _nextSlot = 0;

  // Track touch start position/time for tap detection
  double? _touchStartX;
  double? _touchStartY;
  int? _touchStartTime;

  int _getSlot(int pointer) {
    return _pointerSlots.putIfAbsent(pointer, () => (_nextSlot++) % 2);
  }

  void _releaseSlot(int pointer) {
    _pointerSlots.remove(pointer);
  }

  Widget _buildMobileView() {
    // Coordinates are in CSS pixels (same as Flutter logical pixels)
    // NOT multiplied by devicePixelRatio - the engine handles DPR internally
    return LayoutBuilder(
      builder: (context, constraints) {
        // Listener forwards touches to WebView via JavaScript API.
        // Flutter's hit-testing ensures UI elements block touches naturally -
        // only touches that reach this widget (not blocked by UI) get forwarded.
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            if (_touchBlocked) return;
            final slot = _getSlot(event.pointer);
            final x = event.localPosition.dx;
            final y = event.localPosition.dy;
            _webViewKey.currentState?.onPointerDown(slot, x, y);
            // Track for tap detection
            _touchStartX = x;
            _touchStartY = y;
            _touchStartTime = DateTime.now().millisecondsSinceEpoch;
          },
          onPointerMove: (event) {
            if (_touchBlocked) return;
            // When gyroscope is enabled, block single-finger panning but allow
            // multi-finger gestures (pinch-to-zoom) by checking active pointer count
            if (widget.gyroscopeEnabled && _pointerSlots.length < 2) return;
            final slot = _pointerSlots[event.pointer];
            if (slot == null) return;
            _webViewKey.currentState?.onPointerMove(
              slot,
              event.localPosition.dx,
              event.localPosition.dy,
            );
          },
          onPointerUp: (event) {
            if (_touchBlocked) return;
            final slot = _pointerSlots[event.pointer];
            if (slot == null) return;
            final x = event.localPosition.dx;
            final y = event.localPosition.dy;
            _webViewKey.currentState?.onPointerUp(slot, x, y);
            _releaseSlot(event.pointer);

            // Tap detection - check if this was a tap (small movement, short duration)
            if (_touchStartX != null && _touchStartY != null && _touchStartTime != null) {
              final dx = (x - _touchStartX!).abs();
              final dy = (y - _touchStartY!).abs();
              final duration = DateTime.now().millisecondsSinceEpoch - _touchStartTime!;
              const tapThreshold = 15.0;
              const tapMaxDuration = 300;

              if (dx < tapThreshold && dy < tapThreshold && duration < tapMaxDuration) {
                debugPrint('[SKYVIEW] Tap detected at ($x, $y)');
                // Tap detection is handled by the WebView's JavaScript
              }
            }
            _touchStartX = null;
            _touchStartY = null;
            _touchStartTime = null;
          },
          onPointerCancel: (event) {
            _releaseSlot(event.pointer);
            _touchStartX = null;
            _touchStartY = null;
            _touchStartTime = null;
          },
          child: Stack(
            children: [
              // WebView with Stellarium - native gestures disabled, purely visual
              Positioned.fill(
                child: StellariumWebView(
                  key: _webViewKey,
                  latitude: widget.initialObserver != null
                      ? Observer.rad2deg(widget.initialObserver!.latitude)
                      : null,
                  longitude: widget.initialObserver != null
                      ? Observer.rad2deg(widget.initialObserver!.longitude)
                      : null,
                  onReady: (ready) {
                    setState(() {
                      _isInitialized = ready;
                    });
                    widget.onEngineReady?.call(ready);
                    // Set gyroscope mode on the WebView now that it's ready
                    if (ready && widget.gyroscopeEnabled) {
                      _webViewKey.currentState?.setGyroscopeEnabled(true);
                    }
                  },
                  onError: (error) {
                    setState(() {
                      _errorMessage = error;
                    });
                  },
                  onObjectSelected: widget.onObjectSelected,
                  onTimeChanged: widget.onTimeChanged,
                ),
              ),
              // Overlays
              if (widget.showFps || widget.showCoordinates) _buildOverlays(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWebView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 0 && constraints.maxHeight > 0) {
          _initializeWithSize(
            Size(constraints.maxWidth, constraints.maxHeight),
          );
        }

        final dpr = MediaQuery.of(context).devicePixelRatio;

        // Event forwarding Listener is now INSIDE SkyView.
        // This means UI elements in the parent Stack (home_screen) are hit-tested
        // BEFORE this widget. Only events that "fall through" (don't hit any UI)
        // reach this Listener and get forwarded to Stellarium.
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            debugPrint('[SKYVIEW] onPointerDown at (${event.localPosition.dx.toStringAsFixed(0)}, ${event.localPosition.dy.toStringAsFixed(0)}) - touchBlocked=$_touchBlocked');
            if (_touchBlocked) return;
            _engine?.onPointerDown(
              event.pointer,
              event.localPosition.dx * dpr,
              event.localPosition.dy * dpr,
            );
          },
          onPointerMove: (event) {
            if (_touchBlocked) return;
            // When gyroscope is enabled, block single-finger panning but allow
            // multi-finger gestures (pinch-to-zoom)
            if (widget.gyroscopeEnabled) return; // Web doesn't track multi-touch the same way
            _engine?.onPointerMove(
              event.pointer,
              event.localPosition.dx * dpr,
              event.localPosition.dy * dpr,
            );
          },
          onPointerUp: (event) {
            debugPrint('[SKYVIEW] onPointerUp at (${event.localPosition.dx.toStringAsFixed(0)}, ${event.localPosition.dy.toStringAsFixed(0)}) - touchBlocked=$_touchBlocked');
            if (_touchBlocked) return;
            _engine?.onPointerUp(
              event.pointer,
              event.localPosition.dx * dpr,
              event.localPosition.dy * dpr,
            );
          },
          onPointerSignal: (event) {
            if (_touchBlocked) return;
            if (event is PointerScrollEvent) {
              _engine?.onZoom(
                event.scrollDelta.dy > 0 ? 1.1 : 0.9,
                event.localPosition.dx * dpr,
                event.localPosition.dy * dpr,
              );
            }
          },
          child: Stack(
            children: [
              // Platform View - embeds the Stellarium canvas (pointer-events: none in CSS)
              const Positioned.fill(
                child: HtmlElementView(viewType: 'stellarium-container'),
              ),

              // Overlays
              if (widget.showFps || widget.showCoordinates) _buildOverlays(),

              // Loading indicator
              if (!_isInitialized && _errorMessage == null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: const Color(0xFF0a1628),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: Color(0xFF33B4E8),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Loading Stellarium...',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverlays() {
    return Positioned(
      top: 8,
      left: 8,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showFps)
                Text(
                  'FPS: ${_fps.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              if (widget.showCoordinates) ...[
                const SizedBox(height: 4),
                Text(
                  'Lat: ${Observer.rad2deg(_observer.latitude).toStringAsFixed(2)}°',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  'Lon: ${Observer.rad2deg(_observer.longitude).toStringAsFixed(2)}°',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  'FOV: ${Observer.rad2deg(_observer.fov).toStringAsFixed(1)}°',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

}
