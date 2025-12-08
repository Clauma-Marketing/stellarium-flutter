import 'observer.dart';
import 'stellarium_settings.dart';

/// Callback for when the engine requests a redraw
typedef OnRenderCallback = void Function();

/// Abstract interface for the Stellarium rendering engine.
///
/// This provides a platform-agnostic API that can be implemented
/// differently for web (WASM/JS) and mobile (FFI).
abstract class StellariumEngine {
  /// Whether the engine has been initialized
  bool get isInitialized;

  /// The current observer settings
  Observer get observer;

  /// Initialize the engine with the given canvas/surface dimensions
  Future<void> initialize({
    required double width,
    required double height,
    required double pixelRatio,
  });

  /// Dispose of the engine and release resources
  void dispose();

  /// Update the engine state (call each frame before render)
  void update();

  /// Render the current frame
  void render({
    required double width,
    required double height,
    required double pixelRatio,
  });

  /// Resize the rendering surface
  void resize({
    required double width,
    required double height,
    required double pixelRatio,
  });

  /// Handle mouse/touch down event
  void onPointerDown(int pointerId, double x, double y);

  /// Handle mouse/touch move event
  void onPointerMove(int pointerId, double x, double y);

  /// Handle mouse/touch up event
  void onPointerUp(int pointerId, double x, double y);

  /// Handle zoom gesture (pinch or scroll wheel)
  void onZoom(double delta, double x, double y);

  /// Handle pinch gesture for mobile
  void onPinch(int state, double x, double y, double scale, int pointerCount);

  /// Set the observer's geographic location
  void setLocation({
    required double longitude,
    required double latitude,
    double altitude = 0.0,
  });

  /// Set the observation time
  void setTime(DateTime time, {double animationDuration = 0.0});

  /// Set the time progression speed (1.0 = real time, 0.0 = paused)
  void setTimeSpeed(double speed);

  /// Get the current time speed
  double get timeSpeed;

  /// Look at a specific position in the sky
  void lookAt({
    required double azimuth,
    required double altitude,
    double animationDuration = 1.0,
  });

  /// Set the field of view
  void setFieldOfView(double fovRadians, {double animationDuration = 1.0});

  /// Search for a celestial object by name
  Future<CelestialObject?> search(String query);

  /// Point the view at a celestial object
  void pointAt(CelestialObject object, {double animationDuration = 1.0});

  /// Set a callback for when the engine needs to redraw
  set onRender(OnRenderCallback? callback);

  /// Get the current frames per second
  double get fps;

  /// Get the current display settings
  StellariumSettings get settings;

  /// Apply display settings to the engine
  void applySettings(StellariumSettings settings);

  /// Set a single setting by key
  void setSetting(String key, bool value);
}

/// Represents a celestial object (star, planet, etc.)
class CelestialObject {
  final String id;
  final String name;
  final String type;
  final double? magnitude;
  final double? azimuth;
  final double? altitude;

  CelestialObject({
    required this.id,
    required this.name,
    required this.type,
    this.magnitude,
    this.azimuth,
    this.altitude,
  });

  @override
  String toString() => 'CelestialObject($name, type: $type)';
}

/// Factory to create the appropriate engine implementation
/// based on the current platform
class StellariumEngineFactory {
  static StellariumEngine? _instance;

  /// Get or create the engine instance
  static StellariumEngine get instance {
    _instance ??= _createEngine();
    return _instance!;
  }

  static StellariumEngine _createEngine() {
    // This will be replaced by conditional imports
    throw UnimplementedError(
      'StellariumEngine not implemented for this platform. '
      'Use stellarium_engine_stub.dart with conditional imports.',
    );
  }

  /// Reset the engine instance (for testing)
  static void reset() {
    _instance?.dispose();
    _instance = null;
  }
}
