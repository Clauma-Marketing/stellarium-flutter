// Stub implementation for mobile platforms (iOS/Android)
// These types and functions are only used on web, so we provide no-op stubs.

/// Stub for web EventListener type
typedef WebEventListener = void Function(dynamic);

/// Stub check for DeviceOrientationEvent permission API
bool hasDeviceOrientationPermissionApi() => false;

/// Stub for requesting orientation permission
Future<bool> requestOrientationPermission() async => true;

/// Stub for adding deviceorientation listener
WebEventListener? addDeviceOrientationListener(void Function(dynamic) callback) => null;

/// Stub for removing deviceorientation listener
void removeDeviceOrientationListener(WebEventListener? listener) {}

/// Get alpha (compass heading) from event - stub returns null
double? getEventAlpha(dynamic event) => null;

/// Get beta (front-back tilt) from event - stub returns null
double? getEventBeta(dynamic event) => null;

/// Get gamma (left-right tilt) from event - stub returns null
double? getEventGamma(dynamic event) => null;

/// Get webkitCompassHeading (iOS Safari) from event - stub returns null
double? getEventWebkitCompassHeading(dynamic event) => null;

/// Get webkitCompassAccuracy (iOS Safari) from event - stub returns null
double? getEventWebkitCompassAccuracy(dynamic event) => null;

/// Check if event has absolute orientation - stub returns false
bool hasAbsoluteOrientation(dynamic event) => false;

/// Get best available compass heading - stub returns null
double? getBestCompassHeading(dynamic event) => null;
