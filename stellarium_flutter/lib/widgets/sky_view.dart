import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:motion_core/motion_core.dart';
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

  /// Callback when the sky view is tapped (for dismissing overlays)
  final VoidCallback? onTap;

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
    this.onTap,
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

  // Current field of view in degrees (used to scale gyro sensitivity on zoom).
  double _currentFovDeg = 60.0;

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
  StreamSubscription<MotionData>? _motionSubscription;
  bool _gyroscopeAvailable = false;
  bool _compassAvailable = false;
  bool _isCalibrated = false;
  bool _useMotionCore = false;

  // When interacting with the screen in gyroscope mode, we temporarily damp
  // orientation updates to avoid tap-induced shake, especially when zoomed in.
  static const int _touchStabilizeAfterMs = 300;
  bool _touchActive = false;
  int? _lastTouchChangeMs;

  // Track current view direction (radians)
  double _currentAzimuth = 0.0;
  double _currentAltitude = math.pi / 4; // Start looking at 45 degrees up

  // Compass heading from flutter_compass (degrees, 0 = North, 90 = East)
  double _compassHeading = 0.0;
  double _filteredCompassHeading = 0.0;
  bool _compassInitialized = false;
  double _compassAzimuthRad = 0.0;
  double _gyroHeadingRad = 0.0;
  bool _gyroHeadingInitialized = false;
  int? _lastGyroTimestampMicros;

  // MotionCore on iOS uses an arbitrary reference frame for yaw. We align it to
  // magnetic north using the filtered compass heading.
  double _motionYawOffsetRad = 0.0;
  bool _motionYawOffsetInitialized = false;

  // Compass accuracy tracking (Android only) for calibration UX and yaw seeding.
  double? _compassAccuracyDeg;
  bool _compassNeedsCalibration = false;
  int? _compassBadSinceMs;
  static const double _compassGoodThresholdDeg = 30.0; // high/medium
  static const double _compassBadThresholdDeg = 45.0; // low/unreliable
  // Some Android devices report very large/unstable accuracy values; don't
  // show the calibration overlay beyond this limit.
  static const double _compassPopupMaxAccuracyDeg = 50.0;
  static const int _compassBadHoldMs = 800;

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

  // Dead zone thresholds - set to 0 so we forward every change to the engine
  static const double _compassDeadZone = 0.0;
  static const double _altitudeDeadZone = 0.0;
  static const double _compassFusionGainStill = 0.0; // Gyro-only while running
  static const double _compassFusionGainMoving =
      0.0; // No compass correction while turning
  static const double _maxGyroDtSeconds = 0.25;
  static const double _motionStillYawRadPerSec = 0.03; // ~1.7°/s
  static const double _correctionDeadZoneRad = 0.01; // ~0.57°
  static const double _yawStartThresholdRadPerSec =
      0.07; // Require >4.0°/s to start motion
  static const double _yawStopThresholdRadPerSec =
      0.03; // Drop below 1.7°/s to stop
  static const int _yawStartHoldMs = 90; // Require sustained motion to engage
  static const int _yawStopHoldMs =
      140; // Require sustained stillness to disengage
  static const double _stillHeadingDamp =
      0.1; // Light smoothing when effectively still

  // Output smoothing to reduce jitter when holding still.
  // We smooth the azimuth/altitude we send to the engine, and apply a small
  // dead-zone for micro-movements.
  static const double _azimuthOutputDeadZoneRad = 0.0012; // ~0.07°
  static const double _altitudeOutputDeadZoneRad = 0.0012; // ~0.07°
  static const double _gyroMotionThresholdRadPerSec =
      0.035; // ~2.0°/s overall motion

  // Last applied values (for dead zone comparison)
  double _lastAppliedAzimuth = 0.0;
  double _lastAppliedAltitude = 0.0;
  double _smoothedAzimuth = 0.0;
  double _smoothedAltitude = math.pi / 4;
  bool _smoothedOrientationInitialized = false;
  bool _yawActive = false;
  int? _yawAboveSinceMs;
  int? _yawBelowSinceMs;

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

    // Prefer native fused attitude if available
    try {
      final motionAvailable = await MotionCore.isAvailable();
      if (motionAvailable) {
        _useMotionCore = true;
        _gyroscopeAvailable = true;
        debugPrint('MotionCore: available = true');
      } else {
        _useMotionCore = false;
        debugPrint(
            'MotionCore: available = false, falling back to raw sensors');
      }
    } catch (e, stackTrace) {
      _useMotionCore = false;
      debugPrint('MotionCore availability error: $e');
      FirebaseCrashlytics.instance.recordError(e, stackTrace);
    }

    if (_useMotionCore) {
      widget.onGyroscopeAvailabilityChanged?.call(_gyroscopeAvailable);
      if (widget.gyroscopeEnabled && _gyroscopeAvailable) {
        _startGyroscope();
      }
      return;
    }

    // Test gyroscope
    try {
      bool gyroError = false;
      final testSub = gyroscopeEventStream().listen(
        (event) {
          debugPrint(
              'Gyroscope: test event received: x=${event.x}, y=${event.y}, z=${event.z}');
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
          debugPrint(
              'Compass: test heading received: ${event.heading!.toStringAsFixed(1)}°');
        }
      }, onError: (e) {
        debugPrint('Compass: test error: $e');
      });
      await Future.delayed(const Duration(milliseconds: 500));
      await compassTestSub?.cancel();
      debugPrint('Compass: available = $compassReceived');
      if (!compassReceived) {
        debugPrint(
            'Compass: WARNING - No heading received! AR mode may not work correctly.');
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
    _gyroHeadingInitialized = false;
    _gyroHeadingRad = 0.0;
    _compassAzimuthRad = 0.0;
    _lastGyroTimestampMicros = null;
    _lastAppliedAzimuth = 0.0;
    _lastAppliedAltitude = 0.0;
    _smoothedAzimuth = 0.0;
    _smoothedAltitude = _currentAltitude;
    _smoothedOrientationInitialized = false;
    _touchActive = false;
    _lastTouchChangeMs = null;
    _motionYawOffsetInitialized = false;
    _motionYawOffsetRad = 0.0;
    _compassAccuracyDeg = null;
    _compassNeedsCalibration = false;
    _compassBadSinceMs = null;

    if (_useMotionCore) {
      // Ensure raw-sensor subscriptions are stopped. Keep compass running for
      // yaw alignment to north.
      _gyroSubscription?.cancel();
      _gyroSubscription = null;
      _accelerometerSubscription?.cancel();
      _accelerometerSubscription = null;

      _motionSubscription?.cancel();
      _motionSubscription = MotionCore.motionStream.listen(
        _onMotionData,
        onError: (e, stackTrace) {
          debugPrint('MotionCore stream error: $e');
          FirebaseCrashlytics.instance.recordError(e, stackTrace);
        },
      );
    }

    // Start compass for heading (uses Core Location on iOS for reliable compass)
    _compassSubscription?.cancel();
    _compassInitialized = false;
    _compassFlipped = false;
    debugPrint('Compass: starting subscription...');
    _compassSubscription = FlutterCompass.events?.listen((event) {
      _compassAccuracyDeg = event.accuracy;
      _updateCompassCalibrationState(_compassAccuracyDeg);
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
          final double alpha =
              absDiff < 2.0 ? 0.1 : (absDiff < 8.0 ? 0.25 : 0.4);

          _filteredCompassHeading += alpha * diff;
          // Normalize to 0-360 range
          if (_filteredCompassHeading < 0) _filteredCompassHeading += 360;
          if (_filteredCompassHeading >= 360) _filteredCompassHeading -= 360;
        }

        if (!_compassAvailable) {
          _compassAvailable = true;
          debugPrint(
              'Compass: first heading received: ${_compassHeading.toStringAsFixed(1)}°');
        }
      }
    }, onError: (e) {
      debugPrint('Compass error: $e');
    });

    if (_useMotionCore) return;

    // Start accelerometer for device tilt (altitude)
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((event) {
      final ax = event.x;
      final ay = event.y;
      final az = event.z;
      // Initialize filter with first reading, then apply adaptive filter
      if (_filteredAccX == 0.0 &&
          _filteredAccY == 0.0 &&
          _filteredAccZ == 0.0) {
        _filteredAccX = ax;
        _filteredAccY = ay;
        _filteredAccZ = az;
      } else {
        // Adaptive filtering based on movement magnitude
        final diffX = ax - _filteredAccX;
        final diffY = ay - _filteredAccY;
        final diffZ = az - _filteredAccZ;
        final diffMag = diffX.abs() + diffY.abs() + diffZ.abs();
        final double alpha =
            diffMag < 0.5 ? 0.08 : (diffMag < 2.0 ? 0.18 : 0.3);

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

    // Track compass heading (radians) and use it to seed the gyro integrator
    _compassAzimuthRad = _filteredCompassHeading * math.pi / 180.0;
    if (!_gyroHeadingInitialized) {
      _gyroHeadingRad = _compassAzimuthRad;
      _gyroHeadingInitialized = true;
    }

    if (!_isCalibrated) {
      _isCalibrated = true;
      debugPrint('AR Mode: calibrated');
    }

    // Periodic debug output (every 60 frames ≈ 1 second)
    _debugFrameCount++;
    if (_debugFrameCount % 60 == 0) {
      debugPrint(
          'DEBUG: compass=${_filteredCompassHeading.toStringAsFixed(1)}° (raw=${_compassHeading.toStringAsFixed(1)}°), alt=${altitudeDeg.toStringAsFixed(1)}°, fov=${_currentFovDeg.toStringAsFixed(1)}°${_compassFlipped ? " FLIP" : ""}');
    }
  }

  void _stopGyroscope() {
    _motionSubscription?.cancel();
    _motionSubscription = null;
    _gyroSubscription?.cancel();
    _gyroSubscription = null;
    _compassSubscription?.cancel();
    _compassSubscription = null;
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _isCalibrated = false;
    _compassAvailable = false;
    _gyroHeadingInitialized = false;
    _lastGyroTimestampMicros = null;
    _touchActive = false;
    _lastTouchChangeMs = null;
    _compassAccuracyDeg = null;
    _compassNeedsCalibration = false;
    _compassBadSinceMs = null;

    // Re-enable touch panning in the WebView
    _webViewKey.currentState?.setGyroscopeEnabled(false);
  }

  void _onGyroscopeEvent(GyroscopeEvent event) {
    if (!_isInitialized) return;

    // Update orientation from accelerometer/compass
    _updateOrientationFromSensors();

    if (!_isCalibrated || !_gyroHeadingInitialized) {
      _lastGyroTimestampMicros ??= DateTime.now().microsecondsSinceEpoch;
      _currentAzimuth = _gyroHeadingRad;
      return;
    }

    // Integrate gyroscope (z = yaw) for responsiveness, correct drift toward compass
    final nowMicros = DateTime.now().microsecondsSinceEpoch;
    if (_lastGyroTimestampMicros == null) {
      _lastGyroTimestampMicros = nowMicros;
      _currentAzimuth = _gyroHeadingRad;
      return;
    }
    final dt = (nowMicros - _lastGyroTimestampMicros!) / 1000000.0;
    _lastGyroTimestampMicros = nowMicros;
    if (dt <= 0 || dt > _maxGyroDtSeconds) {
      _currentAzimuth = _gyroHeadingRad;
      return;
    }

    // Project gyro onto gravity/up vector so yaw tracks correctly regardless of phone tilt
    double yawRate = event.z;
    final accNorm = math.sqrt(_filteredAccX * _filteredAccX +
        _filteredAccY * _filteredAccY +
        _filteredAccZ * _filteredAccZ);
    if (accNorm > 0.1) {
      final upX = _filteredAccX / accNorm;
      final upY = _filteredAccY / accNorm;
      final upZ = _filteredAccZ / accNorm;
      yawRate = event.x * upX + event.y * upY + event.z * upZ;
    }
    double absYawRate = yawRate.abs();

    final nowMs = nowMicros ~/ 1000;

    // Hysteresis with hold times: only treat as moving if above start threshold for a bit,
    // and require sustained stillness before stopping.
    if (_yawActive) {
      if (absYawRate < _yawStopThresholdRadPerSec) {
        _yawBelowSinceMs ??= nowMs;
        if (nowMs - _yawBelowSinceMs! >= _yawStopHoldMs) {
          _yawActive = false;
          _yawAboveSinceMs = null;
          _yawBelowSinceMs = null;
        }
      } else {
        _yawBelowSinceMs = null;
      }
    } else {
      if (absYawRate > _yawStartThresholdRadPerSec) {
        _yawAboveSinceMs ??= nowMs;
        if (nowMs - _yawAboveSinceMs! >= _yawStartHoldMs) {
          _yawActive = true;
          _yawBelowSinceMs = null;
        }
      } else {
        _yawAboveSinceMs = null;
      }
    }

    if (!_yawActive) {
      yawRate = 0.0;
      absYawRate = 0.0;
    }

    // Gyro coordinates are right-handed; negate yaw so clockwise turns increase heading like the compass
    _gyroHeadingRad = _normalizeRadians(_gyroHeadingRad - yawRate * dt);

    // Compass is only used for initial seeding; no ongoing correction while running

    // Light damping when effectively still to avoid micro jitter
    if (!_yawActive) {
      _gyroHeadingRad = _lerpAngleRadians(
          _currentAzimuth, _gyroHeadingRad, _stillHeadingDamp);
    }
    _currentAzimuth = _gyroHeadingRad;

    final gyroMag =
        math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    final deviceMoving = _yawActive || gyroMag > _gyroMotionThresholdRadPerSec;
    _applySmoothedOrientation(
      targetAzimuth: _currentAzimuth,
      targetAltitude: _currentAltitude,
      deviceMoving: deviceMoving,
    );
  }

  void _onMotionData(MotionData data) {
    if (!_isInitialized) return;

    final gravity = data.gravity;
    final gNorm = gravity.length;
    if (gNorm < 0.1) return;

    final upZ = gravity.z / gNorm;
    // MotionCore gravity axis differs per platform. iOS CoreMotion reports
    // gravity.z with opposite sign to Android's TYPE_GRAVITY. Match the
    // previous behavior: tilt up => look up.
    final altitudeSign =
        defaultTargetPlatform == TargetPlatform.android ? -1.0 : 1.0;
    final altitude = math.asin((altitudeSign * upZ).clamp(-1.0, 1.0));

    final yaw = data.yaw;

    // Align MotionCore yaw to magnetic north using the filtered compass heading.
    // iOS MotionCore uses an arbitrary reference frame, so we compute an offset.
    if (!_motionYawOffsetInitialized &&
        _compassAvailable &&
        _isCompassAccurate) {
      final compassAzimuthRad = _filteredCompassHeading * math.pi / 180.0;
      _motionYawOffsetRad = _normalizeRadians(compassAzimuthRad + yaw);
      _motionYawOffsetInitialized = true;
      debugPrint(
          '[SKYVIEW] MotionCore yaw calibrated to compass (offset=${_motionYawOffsetRad.toStringAsFixed(3)} rad)');
    }

    // MotionCore yaw uses right-hand rule (positive CCW). Negate so clockwise
    // turns increase azimuth like the engine expects, then apply offset if known.
    final azimuth = _normalizeRadians(
        -yaw + (_motionYawOffsetInitialized ? _motionYawOffsetRad : 0.0));

    final zoomFactor = _zoomFactorForFovDeg(_currentFovDeg);
    final movementThresholdRad = 0.005 * zoomFactor;
    final azDelta = _shortestAngleRadians(azimuth - _smoothedAzimuth).abs();
    final altDelta = (altitude - _smoothedAltitude).abs();

    _applySmoothedOrientation(
      targetAzimuth: azimuth,
      targetAltitude: altitude,
      // Require a larger angular change to enter "moving" mode when zoomed in,
      // so micro hand jitter stays in the heavy-still filter.
      deviceMoving: !_smoothedOrientationInitialized ||
          azDelta > movementThresholdRad ||
          altDelta > movementThresholdRad,
    );
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

    final obs = _engine?.observer ?? _observer;
    setState(() {
      _fps = _engine?.fps ?? 0.0;
      _observer = obs;
      _currentFovDeg = Observer.rad2deg(obs.fov);
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
            if (widget.gyroscopeEnabled) {
              _touchActive = true;
              _lastTouchChangeMs = DateTime.now().millisecondsSinceEpoch;
            }
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
            if (widget.gyroscopeEnabled) {
              _touchActive = _pointerSlots.isNotEmpty;
              _lastTouchChangeMs = DateTime.now().millisecondsSinceEpoch;
            }

            // Tap detection - check if this was a tap (small movement, short duration)
            if (_touchStartX != null &&
                _touchStartY != null &&
                _touchStartTime != null) {
              final dx = (x - _touchStartX!).abs();
              final dy = (y - _touchStartY!).abs();
              final duration =
                  DateTime.now().millisecondsSinceEpoch - _touchStartTime!;
              const tapThreshold = 15.0;
              const tapMaxDuration = 300;

              if (dx < tapThreshold &&
                  dy < tapThreshold &&
                  duration < tapMaxDuration) {
                debugPrint('[SKYVIEW] Tap detected at ($x, $y)');
                // Notify parent of tap (for dismissing overlays like time slider)
                widget.onTap?.call();
                // Tap detection is handled by the WebView's JavaScript
              }
            }
            _touchStartX = null;
            _touchStartY = null;
            _touchStartTime = null;
          },
          onPointerCancel: (event) {
            _releaseSlot(event.pointer);
            if (widget.gyroscopeEnabled) {
              _touchActive = _pointerSlots.isNotEmpty;
              _lastTouchChangeMs = DateTime.now().millisecondsSinceEpoch;
            }
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
                  onFovChanged: (fovDeg) {
                    _currentFovDeg = fovDeg;
                    debugPrint(
                        '[SKYVIEW] FOV changed: ${fovDeg.toStringAsFixed(2)}° (zoomFactor=${_zoomFactorForFovDeg(fovDeg).toStringAsFixed(2)})');
                  },
                ),
              ),
              // Overlays
              if (widget.showFps || widget.showCoordinates) _buildOverlays(),
              if (_compassNeedsCalibration &&
                  widget.gyroscopeEnabled &&
                  defaultTargetPlatform == TargetPlatform.android)
                Positioned.fill(child: _buildCompassCalibrationOverlay()),
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
            debugPrint(
                '[SKYVIEW] onPointerDown at (${event.localPosition.dx.toStringAsFixed(0)}, ${event.localPosition.dy.toStringAsFixed(0)}) - touchBlocked=$_touchBlocked');
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
            if (widget.gyroscopeEnabled) {
              return; // Web doesn't track multi-touch the same way
            }
            _engine?.onPointerMove(
              event.pointer,
              event.localPosition.dx * dpr,
              event.localPosition.dy * dpr,
            );
          },
          onPointerUp: (event) {
            debugPrint(
                '[SKYVIEW] onPointerUp at (${event.localPosition.dx.toStringAsFixed(0)}, ${event.localPosition.dy.toStringAsFixed(0)}) - touchBlocked=$_touchBlocked');
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

  bool get _isCompassAccurate {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    return _compassAccuracyDeg != null &&
        _compassAccuracyDeg! <= _compassGoodThresholdDeg;
  }

  void _updateCompassCalibrationState(double? accuracyDeg) {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (!widget.gyroscopeEnabled) {
      _compassBadSinceMs = null;
      if (_compassNeedsCalibration && mounted) {
        setState(() => _compassNeedsCalibration = false);
      }
      return;
    }

    final isBad = accuracyDeg == null ||
        (accuracyDeg >= _compassBadThresholdDeg &&
            accuracyDeg <= _compassPopupMaxAccuracyDeg);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (isBad) {
      _compassBadSinceMs ??= nowMs;
      if (!_compassNeedsCalibration &&
          nowMs - _compassBadSinceMs! >= _compassBadHoldMs &&
          mounted) {
        setState(() => _compassNeedsCalibration = true);
      }
    } else {
      _compassBadSinceMs = null;
      if (_compassNeedsCalibration && mounted) {
        setState(() => _compassNeedsCalibration = false);
      }
    }
  }

  Widget _buildCompassCalibrationOverlay() {
    final accuracyText = _compassAccuracyDeg != null
        ? 'Accuracy: ±${_compassAccuracyDeg!.toStringAsFixed(0)}°'
        : 'Accuracy: unknown';

    return AbsorbPointer(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Compass calibration needed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Image.asset(
                  'assets/compass-calibration.gif',
                  width: 220,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Move your phone in a figure‑8 motion until the compass stabilizes.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  accuracyText,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _touchStabilizing {
    if (_touchActive) return true;
    if (_lastTouchChangeMs == null) return false;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return nowMs - _lastTouchChangeMs! < _touchStabilizeAfterMs;
  }

  void _applySmoothedOrientation({
    required double targetAzimuth,
    required double targetAltitude,
    required bool deviceMoving,
  }) {
    if (!_smoothedOrientationInitialized) {
      _smoothedAzimuth = targetAzimuth;
      _smoothedAltitude = targetAltitude;
      _smoothedOrientationInitialized = true;
    } else {
      final azDelta =
          _shortestAngleRadians(targetAzimuth - _smoothedAzimuth).abs();
      final altDelta = (targetAltitude - _smoothedAltitude).abs();

      final touchStabilizing = _touchStabilizing;
      final movingForFilter = deviceMoving && !touchStabilizing;

      final azAlpha = _adaptiveOutputAlpha(azDelta, moving: movingForFilter);
      final altAlpha = _adaptiveOutputAlpha(altDelta, moving: movingForFilter);

      // When zoomed in (small FOV), make tilt less sensitive by increasing
      // dead-zone and slowing the smoothing toward the target angles.
      final zoomFactor = _zoomFactorForFovDeg(_currentFovDeg);
      final stabilizationFactor = touchStabilizing ? 2.0 : 1.0;
      final deadZoneZoomExp = movingForFilter ? 1.0 : 1.4;
      final zoomDeadZoneScale =
          math.pow(zoomFactor, deadZoneZoomExp).toDouble();
      final effectiveAzDeadZone =
          _azimuthOutputDeadZoneRad * zoomDeadZoneScale * stabilizationFactor;
      final effectiveAzAlpha =
          (azAlpha / (math.pow(zoomFactor, 1.0) * stabilizationFactor))
              .clamp(0.005, 0.8)
              .toDouble();
      final effectiveAltDeadZone =
          _altitudeOutputDeadZoneRad * zoomDeadZoneScale * stabilizationFactor;
      final effectiveAltAlpha =
          (altAlpha / (math.pow(zoomFactor, 1.3) * stabilizationFactor))
              .clamp(0.005, 0.6)
              .toDouble();

      if (azDelta > effectiveAzDeadZone) {
        _smoothedAzimuth = _lerpAngleRadians(
            _smoothedAzimuth, targetAzimuth, effectiveAzAlpha);
      }
      if (altDelta > effectiveAltDeadZone) {
        _smoothedAltitude = _smoothedAltitude +
            (targetAltitude - _smoothedAltitude) * effectiveAltAlpha;
      }
    }

    _lastAppliedAzimuth = _smoothedAzimuth;
    _lastAppliedAltitude = _smoothedAltitude;

    if (!kIsWeb) {
      _webViewKey.currentState
          ?.lookAt(_lastAppliedAzimuth, _lastAppliedAltitude, 0.0);
    } else {
      _engine?.lookAt(
        azimuth: _lastAppliedAzimuth,
        altitude: _lastAppliedAltitude,
        animationDuration: 0.0,
      );
    }
  }

  double _adaptiveOutputAlpha(double deltaRad, {required bool moving}) {
    // Adaptive exponential smoothing:
    // - When moving, follow quickly to feel responsive.
    // - When still, heavily smooth small deltas to kill jitter.
    if (moving) {
      if (deltaRad < 0.0087) return 0.25; // <0.5°
      if (deltaRad < 0.0349) return 0.40; // <2°
      return 0.55;
    }
    if (deltaRad < 0.0035) return 0.04; // <0.2°
    if (deltaRad < 0.0175) return 0.08; // <1°
    if (deltaRad < 0.0524) return 0.12; // <3°
    return 0.20;
  }

  double _zoomFactorForFovDeg(double fovDeg) {
    // Base sensitivity tuned for ~60° FOV.
    // As FOV shrinks (zoom in), return a factor >1 to damp tilt sensitivity.
    final clampedFov = fovDeg.clamp(5.0, 80.0);
    final factor = 60.0 / clampedFov;
    return factor.clamp(1.0, 8.0).toDouble();
  }

  double _normalizeRadians(double value) {
    final twoPi = math.pi * 2;
    value %= twoPi;
    if (value < 0) value += twoPi;
    return value;
  }

  double _shortestAngleRadians(double angle) {
    final twoPi = math.pi * 2;
    angle = (angle + math.pi) % twoPi;
    if (angle < 0) angle += twoPi;
    return angle - math.pi;
  }

  double _lerpAngleRadians(double from, double to, double alpha) {
    final delta = _shortestAngleRadians(to - from);
    return _normalizeRadians(from + delta * alpha);
  }
}
