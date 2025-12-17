import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'observer.dart';
import 'stellarium_engine.dart';
import 'stellarium_settings.dart';

/// Create the web implementation of the engine
StellariumEngine createStellariumEngine() => StellariumEngineWeb();

// JS interop for the global stellarium instance
@JS('stellarium')
external StelJS? get _globalStellarium;

@JS('stellariumReady')
external bool get _stellariumReady;

@JS('onStellariumReady')
external void _onStellariumReady(JSFunction callback);

// Helper to call WASM functions via JavaScript
@JS('window.stelCoreOnMouse')
external void _stelCoreOnMouse(int id, int state, double x, double y, int buttons);

@JS('window.stelCoreOnZoom')
external void _stelCoreOnZoom(double factor, double x, double y);

@JS('window.stellariumAPI.lookAtRadians')
external void _stellariumApiLookAtRadians(double azimuthRad, double altitudeRad, double duration);

@JS('window.stellariumAPI.setGyroscopeEnabled')
external void _stellariumApiSetGyroscopeEnabled(bool enabled);

@JS('window.stelInputReady')
external bool? get _stelInputReady;

@JS('window.initStellariumEngine')
external JSPromise<StelJS?> _initStellariumEngine();

@JS('window.stellariumAPI.getSelectedObjectInfo')
external JSObject? _getSelectedObjectInfo();

@JS('window.stellariumAPI.pointAt')
external JSPromise<JSAny?> _stellariumApiPointAt(String name, double duration);

@JS('window.stellariumAPI.addPersistentLabel')
external void _addPersistentLabel(String identifier, String label);

@JS('window.stellariumAPI.removePersistentLabel')
external void _removePersistentLabel(String identifier);

@JS('window.stellariumAPI.clearPersistentLabels')
external void _clearPersistentLabels();

/// Main Stellarium JavaScript object
@JS()
extension type StelJS._(JSObject _) implements JSObject {
  external StelObserverJS? get observer;
  external StelCoreJS? get core;

  // ignore: non_constant_identifier_names
  external double? get D2R;
  // ignore: non_constant_identifier_names
  external double? get R2D;

  external JSPromise<StelObjectJS?> getObjByName(String name);
  external void pointAndLock(StelObjectJS? obj, [double? duration]);
  external void zoomTo(double fov, [double? duration]);

  external void change(JSFunction callback);
}

/// Stellarium core module
@JS()
extension type StelCoreJS._(JSObject _) implements JSObject {
  external StelModuleJS get stars;
  external StelModuleJS get planets;
  external StelConstellationsJS get constellations;
  external StelModuleJS get atmosphere;
  external StelLandscapesJS get landscapes;
  external StelModuleJS get dsos;
  external StelModuleJS get milkyway;
  external StelModuleJS get skycultures;
  external StelModuleJS get satellites;
  external StelModuleJS get dss;
  external StelLinesJS get lines;

  external StelObjectJS? get selection;
  external set selection(StelObjectJS? value);

  // ignore: non_constant_identifier_names
  external double get time_speed;
  // ignore: non_constant_identifier_names
  external set time_speed(double value);
}

/// Constellations module with additional properties
@JS()
extension type StelConstellationsJS._(JSObject _) implements JSObject {
  external bool get visible;
  external set visible(bool value);

  // ignore: non_constant_identifier_names
  external bool get lines_visible;
  // ignore: non_constant_identifier_names
  external set lines_visible(bool value);

  // ignore: non_constant_identifier_names
  external bool get labels_visible;
  // ignore: non_constant_identifier_names
  external set labels_visible(bool value);

  // ignore: non_constant_identifier_names
  external bool get images_visible;
  // ignore: non_constant_identifier_names
  external set images_visible(bool value);
}

/// Landscapes module with fog property
@JS()
extension type StelLandscapesJS._(JSObject _) implements JSObject {
  external bool get visible;
  external set visible(bool value);

  // ignore: non_constant_identifier_names
  external bool get fog_visible;
  // ignore: non_constant_identifier_names
  external set fog_visible(bool value);
}

/// Lines module containing various coordinate grids
@JS()
extension type StelLinesJS._(JSObject _) implements JSObject {
  external StelModuleJS get azimuthal;
  external StelModuleJS get equatorial;
  // ignore: non_constant_identifier_names
  external StelModuleJS get equatorial_jnow;
  external StelModuleJS get meridian;
  external StelModuleJS get ecliptic;
}

/// Generic module
@JS()
extension type StelModuleJS._(JSObject _) implements JSObject {
  external bool get visible;
  external set visible(bool value);

  external void addDataSource(JSObject options);
}

/// Observer object
@JS()
extension type StelObserverJS._(JSObject _) implements JSObject {
  external double? get longitude;
  external set longitude(double value);

  external double? get latitude;
  external set latitude(double value);

  external double? get elevation;
  external set elevation(double value);

  external double? get utc;
  external set utc(double value);

  external double? get azimuth;
  external double? get altitude;

  external double? get fov;
  external set fov(double value);
}

/// Celestial object
@JS()
extension type StelObjectJS._(JSObject _) implements JSObject {
  external JSArray<JSString> designations();
  external JSAny? getInfo(String key, [StelObserverJS? observer]);

  external String get type;
}

/// Callback for selection changes
typedef OnSelectionChangedCallback = void Function(Map<String, dynamic>? selectionInfo);

/// Web implementation using the global stellarium instance
class StellariumEngineWeb implements StellariumEngine {
  final Observer _observer = Observer.now();
  final StellariumSettings _settings = StellariumSettings();
  OnRenderCallback? _onRender;
  OnSelectionChangedCallback? _onSelectionChanged;
  bool _initialized = false;
  int _frameCount = 0;
  DateTime _fpsUpdateTime = DateTime.now();
  double _fps = 0.0;
  int? _animationFrameId;
  String? _lastSelectionName;

  /// Set callback for when selection changes
  set onSelectionChanged(OnSelectionChangedCallback? callback) {
    _onSelectionChanged = callback;
  }

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

  StelJS? get _stel => _globalStellarium;

  @override
  Future<void> initialize({
    required double width,
    required double height,
    required double pixelRatio,
  }) async {
    if (_initialized) return;

    // Check if already ready
    if (_stellariumReady && _stel != null) {
      _initialized = true;
      _syncObserverFromEngine();
      _startRenderLoop();
      return;
    }

    // Request initialization from JavaScript
    try {
      await _initStellariumEngine().toDart;
      _initialized = true;
      _syncObserverFromEngine();
      _startRenderLoop();
    } catch (e) {
      debugPrint('Stellarium initialization error: $e');
      // Fall back to waiting for ready callback
      final completer = Completer<void>();
      _onStellariumReady(((StelJS stel) {
        _initialized = true;
        _syncObserverFromEngine();
        _startRenderLoop();
        completer.complete();
      }).toJS);
      return completer.future;
    }
  }

  void _syncObserverFromEngine() {
    final stel = _stel;
    if (stel == null) return;

    final obs = stel.observer;
    if (obs == null) return;

    _observer.longitude = obs.longitude ?? _observer.longitude;
    _observer.latitude = obs.latitude ?? _observer.latitude;
    _observer.altitude = obs.elevation ?? _observer.altitude;
    _observer.utc = obs.utc ?? _observer.utc;
    _observer.azimuth = obs.azimuth ?? _observer.azimuth;
    _observer.elevation = obs.altitude ?? _observer.elevation;
    _observer.fov = obs.fov ?? _observer.fov;
  }

  void _checkSelectionChanged() {
    if (_onSelectionChanged == null) return;

    try {
      final jsInfo = _getSelectedObjectInfo();
      String? currentName;
      Map<String, dynamic>? selectionInfo;

      if (jsInfo != null) {
        // Convert JSObject to Dart Map
        final dartObj = jsInfo.dartify();
        if (dartObj is Map) {
          selectionInfo = Map<String, dynamic>.from(dartObj);
          currentName = selectionInfo['name'] as String?;
        }
      }

      // Only notify if selection changed
      if (currentName != _lastSelectionName) {
        _lastSelectionName = currentName;
        if (currentName != null && currentName.isNotEmpty && currentName != 'Unknown') {
          debugPrint('[WEB ENGINE] Selection changed to: $currentName');
          _onSelectionChanged?.call(selectionInfo);
        }
      }
    } catch (e) {
      // Ignore errors from JS interop
    }
  }

  void _startRenderLoop() {
    void frame(double timestamp) {
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

      // Sync observer
      _syncObserverFromEngine();

      // Check for selection changes
      _checkSelectionChanged();

      // Notify listeners
      _onRender?.call();

      // Request next frame
      _animationFrameId = web.window.requestAnimationFrame(frame.toJS);
    }

    _animationFrameId = web.window.requestAnimationFrame(frame.toJS);
  }

  @override
  void dispose() {
    if (_animationFrameId != null) {
      web.window.cancelAnimationFrame(_animationFrameId!);
    }
    _initialized = false;
  }

  @override
  void update() {
    // Engine updates itself
  }

  @override
  void render({
    required double width,
    required double height,
    required double pixelRatio,
  }) {
    // Engine handles rendering
  }

  @override
  void resize({
    required double width,
    required double height,
    required double pixelRatio,
  }) {
    // Canvas resize is handled in index.html
  }

  @override
  void onPointerDown(int pointerId, double x, double y) {
    debugPrint('[ENGINE] onPointerDown: id=$pointerId x=${x.toStringAsFixed(0)} y=${y.toStringAsFixed(0)} inputReady=$_stelInputReady');
    if (_stelInputReady != true) {
      debugPrint('[ENGINE] onPointerDown: Stellarium input not ready - SKIPPING');
      return;
    }
    // state: 1 = down, buttons: 1 = left button
    _stelCoreOnMouse(pointerId, 1, x, y, 1);
  }

  @override
  void onPointerMove(int pointerId, double x, double y) {
    if (_stelInputReady != true) return;
    // state: -1 = move (while down), buttons: 1 = left button
    _stelCoreOnMouse(pointerId, -1, x, y, 1);
  }

  @override
  void onPointerUp(int pointerId, double x, double y) {
    debugPrint('[ENGINE] onPointerUp: id=$pointerId x=${x.toStringAsFixed(0)} y=${y.toStringAsFixed(0)} inputReady=$_stelInputReady');
    if (_stelInputReady != true) {
      debugPrint('[ENGINE] onPointerUp: Stellarium input not ready - SKIPPING');
      return;
    }
    // state: 0 = up, buttons: 1 = MUST be 1 for engine to process (movements.c checks buttons==1)
    _stelCoreOnMouse(pointerId, 0, x, y, 1);
  }

  @override
  void onZoom(double delta, double x, double y) {
    if (_stelInputReady != true) {
      debugPrint('onZoom: Stellarium input not ready');
      return;
    }
    // delta > 1 means zoom out, < 1 means zoom in
    final zoomFactor = delta > 1 ? 1.1 : 0.9;
    _stelCoreOnZoom(zoomFactor, x, y);
  }

  @override
  void onPinch(int state, double x, double y, double scale, int pointerCount) {
    // Pinch is handled via touch events by the engine
  }

  @override
  void setLocation({
    required double longitude,
    required double latitude,
    double altitude = 0.0,
  }) {
    final stel = _stel;
    final obs = stel?.observer;
    if (obs == null) return;

    obs.longitude = longitude;
    obs.latitude = latitude;
    obs.elevation = altitude;

    _observer.longitude = longitude;
    _observer.latitude = latitude;
    _observer.altitude = altitude;
  }

  @override
  void setTime(DateTime time, {double animationDuration = 0.0}) {
    final stel = _stel;
    final obs = stel?.observer;
    if (obs == null) return;

    final mjd = Observer.dateTimeToMjd(time.toUtc());
    obs.utc = mjd;
    _observer.utc = mjd;
  }

  @override
  void setTimeSpeed(double speed) {
    final stel = _stel;
    final core = stel?.core;
    if (core == null) return;

    core.time_speed = speed;
  }

  @override
  double get timeSpeed {
    final stel = _stel;
    final core = stel?.core;
    if (core == null) return 1.0;

    return core.time_speed;
  }

  @override
  void lookAt({
    required double azimuth,
    required double altitude,
    double animationDuration = 1.0,
  }) {
    if (!_initialized) return;
    try {
      _stellariumApiLookAtRadians(azimuth, altitude, animationDuration);
    } catch (e) {
      debugPrint('lookAt error: $e');
    }
  }

  /// Enable or disable gyroscope mode
  void setGyroscopeEnabled(bool enabled) {
    if (!_initialized) return;
    try {
      _stellariumApiSetGyroscopeEnabled(enabled);
    } catch (e) {
      debugPrint('setGyroscopeEnabled error: $e');
    }
  }

  @override
  void setFieldOfView(double fovRadians, {double animationDuration = 1.0}) {
    _stel?.zoomTo(fovRadians, animationDuration);
  }

  @override
  Future<CelestialObject?> search(String query) async {
    final stel = _stel;
    if (stel == null) return null;

    try {
      final result = await stel.getObjByName(query).toDart;
      if (result == null) return null;

      String name = query;
      try {
        final designations = result.designations();
        if (designations.length > 0) {
          name = designations.toDart[0].toDart;
        }
      } catch (_) {}

      return CelestialObject(
        id: query,
        name: name,
        type: result.type,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  void pointAt(CelestialObject object, {double animationDuration = 1.0}) {
    // Use the JS API which has API lookup support
    try {
      _stellariumApiPointAt(object.name, animationDuration);
    } catch (e) {
      debugPrint('pointAt error: $e');
      // Fallback to direct method
      final stel = _stel;
      if (stel == null) return;
      stel.getObjByName(object.name).toDart.then((jsObj) {
        if (jsObj != null) {
          stel.pointAndLock(jsObj, animationDuration);
        }
      });
    }
  }

  /// Point at an object by name (uses JS API with registry lookup)
  void pointAtByName(String name, {double animationDuration = 1.0}) {
    try {
      _stellariumApiPointAt(name, animationDuration);
    } catch (e) {
      debugPrint('pointAtByName error: $e');
    }
  }

  /// Add a persistent label for a star (shown without selection)
  void addPersistentLabel(String identifier, String label) {
    try {
      _addPersistentLabel(identifier, label);
    } catch (e) {
      debugPrint('addPersistentLabel error: $e');
    }
  }

  /// Remove a persistent label for a star
  void removePersistentLabel(String identifier) {
    try {
      _removePersistentLabel(identifier);
    } catch (e) {
      debugPrint('removePersistentLabel error: $e');
    }
  }

  /// Clear all persistent labels
  void clearPersistentLabels() {
    try {
      _clearPersistentLabels();
    } catch (e) {
      debugPrint('clearPersistentLabels error: $e');
    }
  }

  @override
  StellariumSettings get settings => _settings;

  @override
  void applySettings(StellariumSettings newSettings) {
    final stel = _stel;
    final core = stel?.core;
    if (core == null) {
      debugPrint('applySettings: Engine core not available');
      return;
    }

    try {
      // Constellations
      core.constellations.lines_visible = newSettings.constellationsLines;
      _settings.constellationsLines = newSettings.constellationsLines;

      core.constellations.labels_visible = newSettings.constellationsLabels;
      _settings.constellationsLabels = newSettings.constellationsLabels;

      core.constellations.images_visible = newSettings.constellationsArt;
      _settings.constellationsArt = newSettings.constellationsArt;

      // Sky display
      core.atmosphere.visible = newSettings.atmosphere;
      _settings.atmosphere = newSettings.atmosphere;

      core.landscapes.visible = newSettings.landscape;
      _settings.landscape = newSettings.landscape;

      core.landscapes.fog_visible = newSettings.landscapeFog;
      _settings.landscapeFog = newSettings.landscapeFog;

      core.milkyway.visible = newSettings.milkyWay;
      _settings.milkyWay = newSettings.milkyWay;

      core.dss.visible = newSettings.dss;
      _settings.dss = newSettings.dss;

      // Celestial objects
      core.stars.visible = newSettings.stars;
      _settings.stars = newSettings.stars;

      core.planets.visible = newSettings.planets;
      _settings.planets = newSettings.planets;

      core.dsos.visible = newSettings.dsos;
      _settings.dsos = newSettings.dsos;

      core.satellites.visible = newSettings.satellites;
      _settings.satellites = newSettings.satellites;

      // Grid lines
      core.lines.azimuthal.visible = newSettings.gridAzimuthal;
      _settings.gridAzimuthal = newSettings.gridAzimuthal;

      core.lines.equatorial_jnow.visible = newSettings.gridEquatorial;
      _settings.gridEquatorial = newSettings.gridEquatorial;

      core.lines.equatorial.visible = newSettings.gridEquatorialJ2000;
      _settings.gridEquatorialJ2000 = newSettings.gridEquatorialJ2000;

      core.lines.meridian.visible = newSettings.lineMeridian;
      _settings.lineMeridian = newSettings.lineMeridian;

      core.lines.ecliptic.visible = newSettings.lineEcliptic;
      _settings.lineEcliptic = newSettings.lineEcliptic;

      // Night mode is handled via CSS filter, not engine
      _settings.nightMode = newSettings.nightMode;
    } catch (e) {
      debugPrint('applySettings error: $e');
    }
  }

  @override
  void setSetting(String key, bool value) {
    final stel = _stel;
    final core = stel?.core;
    if (core == null) {
      debugPrint('setSetting: Engine core not available');
      return;
    }

    try {
      switch (key) {
        case 'constellationsLines':
          core.constellations.lines_visible = value;
          _settings.constellationsLines = value;
          break;
        case 'constellationsLabels':
          core.constellations.labels_visible = value;
          _settings.constellationsLabels = value;
          break;
        case 'constellationsArt':
          core.constellations.images_visible = value;
          _settings.constellationsArt = value;
          break;
        case 'atmosphere':
          core.atmosphere.visible = value;
          _settings.atmosphere = value;
          break;
        case 'landscape':
          core.landscapes.visible = value;
          _settings.landscape = value;
          break;
        case 'landscapeFog':
          core.landscapes.fog_visible = value;
          _settings.landscapeFog = value;
          break;
        case 'milkyWay':
          core.milkyway.visible = value;
          _settings.milkyWay = value;
          break;
        case 'dss':
          core.dss.visible = value;
          _settings.dss = value;
          break;
        case 'stars':
          core.stars.visible = value;
          _settings.stars = value;
          break;
        case 'planets':
          core.planets.visible = value;
          _settings.planets = value;
          break;
        case 'dsos':
          core.dsos.visible = value;
          _settings.dsos = value;
          break;
        case 'satellites':
          core.satellites.visible = value;
          _settings.satellites = value;
          break;
        case 'gridAzimuthal':
          core.lines.azimuthal.visible = value;
          _settings.gridAzimuthal = value;
          break;
        case 'gridEquatorial':
          core.lines.equatorial_jnow.visible = value;
          _settings.gridEquatorial = value;
          break;
        case 'gridEquatorialJ2000':
          core.lines.equatorial.visible = value;
          _settings.gridEquatorialJ2000 = value;
          break;
        case 'lineMeridian':
          core.lines.meridian.visible = value;
          _settings.lineMeridian = value;
          break;
        case 'lineEcliptic':
          core.lines.ecliptic.visible = value;
          _settings.lineEcliptic = value;
          break;
        case 'nightMode':
          _settings.nightMode = value;
          // Night mode CSS filter is handled in the widget layer
          break;
        default:
          debugPrint('Unknown setting key: $key');
      }
    } catch (e) {
      debugPrint('setSetting error for $key: $e');
    }
  }
}
