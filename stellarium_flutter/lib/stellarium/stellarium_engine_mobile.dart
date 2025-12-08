import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import 'observer.dart';
import 'stellarium_engine.dart';
import 'stellarium_settings.dart';

/// Create the mobile (FFI) implementation of the engine
StellariumEngine createStellariumEngine() {
  // Check if native library is available
  if (!_isNativeLibraryAvailable()) {
    return StellariumEngineUnavailable();
  }
  return StellariumEngineMobile();
}

bool _isNativeLibraryAvailable() {
  try {
    if (Platform.isAndroid) {
      DynamicLibrary.open('libstellarium_engine.so');
      return true;
    } else if (Platform.isIOS) {
      // On iOS, try to look up a symbol to verify library is linked
      final lib = DynamicLibrary.process();
      lib.lookup<NativeFunction<Void Function()>>('core_init');
      return true;
    }
    return false;
  } catch (e) {
    debugPrint('Native Stellarium library not available: $e');
    return false;
  }
}

/// Placeholder engine when native library is not available
class StellariumEngineUnavailable implements StellariumEngine {
  final Observer _observer = Observer.now();
  final StellariumSettings _settings = StellariumSettings();

  @override
  bool get isInitialized => false;

  @override
  Observer get observer => _observer;

  @override
  double get fps => 0.0;

  @override
  set onRender(OnRenderCallback? callback) {
    // Not used - engine unavailable
  }

  @override
  Future<void> initialize({
    required double width,
    required double height,
    required double pixelRatio,
  }) async {
    // Cannot initialize - native library not available
    debugPrint('Stellarium native engine not available on this platform');
  }

  @override
  void dispose() {}

  @override
  void update() {}

  @override
  void render({
    required double width,
    required double height,
    required double pixelRatio,
  }) {}

  @override
  void resize({
    required double width,
    required double height,
    required double pixelRatio,
  }) {}

  @override
  void onPointerDown(int pointerId, double x, double y) {}

  @override
  void onPointerMove(int pointerId, double x, double y) {}

  @override
  void onPointerUp(int pointerId, double x, double y) {}

  @override
  void onZoom(double delta, double x, double y) {}

  @override
  void onPinch(int state, double x, double y, double scale, int pointerCount) {}

  @override
  void setLocation({
    required double longitude,
    required double latitude,
    double altitude = 0.0,
  }) {
    _observer.longitude = longitude;
    _observer.latitude = latitude;
    _observer.altitude = altitude;
  }

  @override
  void setTime(DateTime time, {double animationDuration = 0.0}) {
    _observer.utc = Observer.dateTimeToMjd(time.toUtc());
  }

  @override
  void setTimeSpeed(double speed) {}

  @override
  double get timeSpeed => 0.0;

  @override
  void lookAt({
    required double azimuth,
    required double altitude,
    double animationDuration = 1.0,
  }) {}

  @override
  void setFieldOfView(double fovRadians, {double animationDuration = 1.0}) {}

  @override
  Future<CelestialObject?> search(String query) async => null;

  @override
  void pointAt(CelestialObject object, {double animationDuration = 1.0}) {}

  @override
  StellariumSettings get settings => _settings;

  @override
  void applySettings(StellariumSettings newSettings) {}

  @override
  void setSetting(String key, bool value) {}
}

// FFI type definitions for the Stellarium engine
typedef CoreInitNative = Void Function(Double w, Double h, Double scale);
typedef CoreInitDart = void Function(double w, double h, double scale);

typedef CoreUpdateNative = Int32 Function();
typedef CoreUpdateDart = int Function();

typedef CoreRenderNative = Int32 Function(Double w, Double h, Double scale);
typedef CoreRenderDart = int Function(double w, double h, double scale);

typedef CoreOnMouseNative = Void Function(
    Int32 id, Int32 state, Double x, Double y, Int32 buttons);
typedef CoreOnMouseDart = void Function(
    int id, int state, double x, double y, int buttons);

typedef CoreOnZoomNative = Void Function(Double k, Double x, Double y);
typedef CoreOnZoomDart = void Function(double k, double x, double y);

typedef CoreOnPinchNative = Void Function(
    Int32 state, Double x, Double y, Double scale, Int32 count);
typedef CoreOnPinchDart = void Function(
    int state, double x, double y, double scale, int count);

typedef ObjGetAttrNative = Int32 Function(
    Pointer<Void> obj, Pointer<Utf8> attr, Pointer<Double> value);
typedef ObjGetAttrDart = int Function(
    Pointer<Void> obj, Pointer<Utf8> attr, Pointer<Double> value);

typedef ObjSetAttrNative = Int32 Function(
    Pointer<Void> obj, Pointer<Utf8> attr, Double value);
typedef ObjSetAttrDart = int Function(
    Pointer<Void> obj, Pointer<Utf8> attr, double value);

typedef CoreGetObserverNative = Pointer<Void> Function();
typedef CoreGetObserverDart = Pointer<Void> Function();

typedef CoreSearchNative = Pointer<Void> Function(Pointer<Utf8> query);
typedef CoreSearchDart = Pointer<Void> Function(Pointer<Utf8> query);

typedef CoreLookatNative = Void Function(Pointer<Double> pos, Double duration);
typedef CoreLookatDart = void Function(Pointer<Double> pos, double duration);

typedef CoreZoomtoNative = Void Function(Double fov, Double duration);
typedef CoreZoomtoDart = void Function(double fov, double duration);

/// Mobile (FFI) implementation of the Stellarium engine
class StellariumEngineMobile implements StellariumEngine {
  DynamicLibrary? _lib;
  final Observer _observer = Observer.now();
  final StellariumSettings _settings = StellariumSettings();
  OnRenderCallback? _onRender;
  bool _initialized = false;
  Timer? _renderTimer;
  double _fps = 0.0;
  int _frameCount = 0;
  DateTime _fpsUpdateTime = DateTime.now();

  // FFI function pointers
  late CoreInitDart _coreInit;
  late CoreUpdateDart _coreUpdate;
  late CoreRenderDart _coreRender;
  late CoreOnMouseDart _coreOnMouse;
  late CoreOnZoomDart _coreOnZoom;
  late CoreOnPinchDart _coreOnPinch;
  late CoreGetObserverDart _coreGetObserver;
  late ObjGetAttrDart _objGetAttr;
  late ObjSetAttrDart _objSetAttr;
  late CoreSearchDart _coreSearch;
  late CoreLookatDart _coreLookat;
  late CoreZoomtoDart _coreZoomto;

  Pointer<Void>? _observerPtr;

  @override
  bool get isInitialized => _initialized;

  @override
  Observer get observer => _observer;

  @override
  double get fps => _fps;

  @override
  set onRender(OnRenderCallback? callback) {
    _onRender = callback;
  }

  DynamicLibrary _loadLibrary() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libstellarium_engine.so');
    } else if (Platform.isIOS) {
      return DynamicLibrary.process();
    } else {
      throw UnsupportedError(
        'Platform ${Platform.operatingSystem} is not supported',
      );
    }
  }

  void _bindFunctions() {
    _coreInit = _lib!
        .lookup<NativeFunction<CoreInitNative>>('core_init')
        .asFunction<CoreInitDart>();

    _coreUpdate = _lib!
        .lookup<NativeFunction<CoreUpdateNative>>('core_update')
        .asFunction<CoreUpdateDart>();

    _coreRender = _lib!
        .lookup<NativeFunction<CoreRenderNative>>('core_render')
        .asFunction<CoreRenderDart>();

    _coreOnMouse = _lib!
        .lookup<NativeFunction<CoreOnMouseNative>>('core_on_mouse')
        .asFunction<CoreOnMouseDart>();

    _coreOnZoom = _lib!
        .lookup<NativeFunction<CoreOnZoomNative>>('core_on_zoom')
        .asFunction<CoreOnZoomDart>();

    _coreOnPinch = _lib!
        .lookup<NativeFunction<CoreOnPinchNative>>('core_on_pinch')
        .asFunction<CoreOnPinchDart>();

    _coreGetObserver = _lib!
        .lookup<NativeFunction<CoreGetObserverNative>>('core_get_observer')
        .asFunction<CoreGetObserverDart>();

    _objGetAttr = _lib!
        .lookup<NativeFunction<ObjGetAttrNative>>('obj_get_attr_f')
        .asFunction<ObjGetAttrDart>();

    _objSetAttr = _lib!
        .lookup<NativeFunction<ObjSetAttrNative>>('obj_set_attr_f')
        .asFunction<ObjSetAttrDart>();

    _coreSearch = _lib!
        .lookup<NativeFunction<CoreSearchNative>>('core_search')
        .asFunction<CoreSearchDart>();

    _coreLookat = _lib!
        .lookup<NativeFunction<CoreLookatNative>>('core_lookat')
        .asFunction<CoreLookatDart>();

    _coreZoomto = _lib!
        .lookup<NativeFunction<CoreZoomtoNative>>('core_zoomto')
        .asFunction<CoreZoomtoDart>();
  }

  @override
  Future<void> initialize({
    required double width,
    required double height,
    required double pixelRatio,
  }) async {
    if (_initialized) return;

    _lib = _loadLibrary();
    _bindFunctions();

    _coreInit(width * pixelRatio, height * pixelRatio, pixelRatio);
    _observerPtr = _coreGetObserver();

    _initialized = true;
    _syncObserverFromEngine();
    _startRenderLoop();
  }

  void _syncObserverFromEngine() {
    if (_observerPtr == null) return;

    _observer.longitude = _getObserverAttr('longitude');
    _observer.latitude = _getObserverAttr('latitude');
    _observer.altitude = _getObserverAttr('elevation');
    _observer.utc = _getObserverAttr('utc');
    _observer.azimuth = _getObserverAttr('azimuth');
    _observer.elevation = _getObserverAttr('altitude');
    _observer.fov = _getObserverAttr('fov');
  }

  double _getObserverAttr(String attr) {
    final attrPtr = attr.toNativeUtf8();
    final valuePtr = calloc<Double>();
    try {
      _objGetAttr(_observerPtr!, attrPtr, valuePtr);
      return valuePtr.value;
    } finally {
      calloc.free(attrPtr);
      calloc.free(valuePtr);
    }
  }

  void _setObserverAttr(String attr, double value) {
    final attrPtr = attr.toNativeUtf8();
    try {
      _objSetAttr(_observerPtr!, attrPtr, value);
    } finally {
      calloc.free(attrPtr);
    }
  }

  void _startRenderLoop() {
    // Use a timer for ~60fps render loop
    _renderTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_initialized) return;

      // Update FPS
      _frameCount++;
      final now = DateTime.now();
      final elapsed = now.difference(_fpsUpdateTime).inMilliseconds;
      if (elapsed >= 1000) {
        _fps = _frameCount * 1000.0 / elapsed;
        _frameCount = 0;
        _fpsUpdateTime = now;
      }

      // Update and render
      update();

      // Sync observer
      _syncObserverFromEngine();

      // Notify listeners
      _onRender?.call();
    });
  }

  @override
  void dispose() {
    _renderTimer?.cancel();
    _renderTimer = null;
    _initialized = false;
    _lib = null;
    _observerPtr = null;
  }

  @override
  void update() {
    if (!_initialized) return;
    _coreUpdate();
  }

  @override
  void render({
    required double width,
    required double height,
    required double pixelRatio,
  }) {
    if (!_initialized) return;
    _coreRender(width * pixelRatio, height * pixelRatio, pixelRatio);
  }

  @override
  void resize({
    required double width,
    required double height,
    required double pixelRatio,
  }) {
    // The engine handles resize through render parameters
  }

  @override
  void onPointerDown(int pointerId, double x, double y) {
    _coreOnMouse(pointerId, 1, x, y, 1); // state 1 = down
  }

  @override
  void onPointerMove(int pointerId, double x, double y) {
    _coreOnMouse(pointerId, 0, x, y, 1); // state 0 = move
  }

  @override
  void onPointerUp(int pointerId, double x, double y) {
    _coreOnMouse(pointerId, -1, x, y, 0); // state -1 = up
  }

  @override
  void onZoom(double delta, double x, double y) {
    _coreOnZoom(delta, x, y);
  }

  @override
  void onPinch(int state, double x, double y, double scale, int pointerCount) {
    _coreOnPinch(state, x, y, scale, pointerCount);
  }

  @override
  void setLocation({
    required double longitude,
    required double latitude,
    double altitude = 0.0,
  }) {
    _setObserverAttr('longitude', longitude);
    _setObserverAttr('latitude', latitude);
    _setObserverAttr('elevation', altitude);
    _observer.longitude = longitude;
    _observer.latitude = latitude;
    _observer.altitude = altitude;
  }

  @override
  void setTime(DateTime time, {double animationDuration = 0.0}) {
    final mjd = Observer.dateTimeToMjd(time.toUtc());
    _setObserverAttr('utc', mjd);
    _observer.utc = mjd;
  }

  @override
  void setTimeSpeed(double speed) {
    // TODO: Implement via FFI
  }

  @override
  double get timeSpeed => 1.0; // TODO: Implement via FFI

  @override
  void lookAt({
    required double azimuth,
    required double altitude,
    double animationDuration = 1.0,
  }) {
    final posPtr = calloc<Double>(3);
    try {
      posPtr[0] = azimuth;
      posPtr[1] = altitude;
      posPtr[2] = 1.0;
      _coreLookat(posPtr, animationDuration);
    } finally {
      calloc.free(posPtr);
    }
  }

  @override
  void setFieldOfView(double fovRadians, {double animationDuration = 1.0}) {
    _coreZoomto(fovRadians, animationDuration);
  }

  @override
  Future<CelestialObject?> search(String query) async {
    final queryPtr = query.toNativeUtf8();
    try {
      final objPtr = _coreSearch(queryPtr);
      if (objPtr == nullptr) return null;

      // TODO: Extract object properties via FFI
      return CelestialObject(
        id: query,
        name: query,
        type: 'unknown',
      );
    } finally {
      calloc.free(queryPtr);
    }
  }

  @override
  void pointAt(CelestialObject object, {double animationDuration = 1.0}) {
    // TODO: Implement point at object via FFI
  }

  @override
  StellariumSettings get settings => _settings;

  @override
  void applySettings(StellariumSettings newSettings) {
    // TODO: Implement settings via FFI when native bindings are available
    // For now, just update the local settings state
    _settings.constellationsLines = newSettings.constellationsLines;
    _settings.constellationsLabels = newSettings.constellationsLabels;
    _settings.constellationsArt = newSettings.constellationsArt;
    _settings.atmosphere = newSettings.atmosphere;
    _settings.landscape = newSettings.landscape;
    _settings.landscapeFog = newSettings.landscapeFog;
    _settings.milkyWay = newSettings.milkyWay;
    _settings.dss = newSettings.dss;
    _settings.stars = newSettings.stars;
    _settings.planets = newSettings.planets;
    _settings.dsos = newSettings.dsos;
    _settings.satellites = newSettings.satellites;
    _settings.gridAzimuthal = newSettings.gridAzimuthal;
    _settings.gridEquatorial = newSettings.gridEquatorial;
    _settings.gridEquatorialJ2000 = newSettings.gridEquatorialJ2000;
    _settings.lineMeridian = newSettings.lineMeridian;
    _settings.lineEcliptic = newSettings.lineEcliptic;
    _settings.nightMode = newSettings.nightMode;
  }

  @override
  void setSetting(String key, bool value) {
    // TODO: Implement individual setting via FFI when native bindings are available
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
  }
}
