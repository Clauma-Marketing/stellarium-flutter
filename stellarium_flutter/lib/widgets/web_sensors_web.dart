// Web-specific implementation using dart:js_interop and package:web
// This file is only imported when building for web.

import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web show window, EventListener;

/// JS interop for DeviceOrientationEvent (web only)
@JS()
extension type DeviceOrientationEventJS._(JSObject _) implements JSObject {
  /// Compass heading: 0-360 degrees (0 = north, 90 = east)
  external double? get alpha;
  /// Front-to-back tilt: -180 to 180 degrees
  external double? get beta;
  /// Left-to-right tilt: -90 to 90 degrees
  external double? get gamma;
  /// Whether the orientation is absolute (relative to Earth) or arbitrary
  external bool? get absolute;
}

/// JS interop for DeviceOrientationEvent class (to access static methods)
@JS('DeviceOrientationEvent')
extension type DeviceOrientationEventClass._(JSObject _) implements JSObject {
  external static JSPromise<JSString> requestPermission();
}

/// Check if DeviceOrientationEvent.requestPermission exists (iOS 13+)
@JS('DeviceOrientationEvent.requestPermission')
external JSFunction? get _deviceOrientationRequestPermission;

/// Type alias for web EventListener
typedef WebEventListener = web.EventListener;

/// Check if DeviceOrientationEvent permission API exists
bool hasDeviceOrientationPermissionApi() {
  return _deviceOrientationRequestPermission != null;
}

/// Request permission for DeviceOrientationEvent (iOS 13+)
Future<bool> requestOrientationPermission() async {
  try {
    final result = await DeviceOrientationEventClass.requestPermission().toDart;
    return result.toDart == 'granted';
  } catch (e) {
    debugPrint('DeviceOrientationEvent.requestPermission error: $e');
    return false;
  }
}

/// Add a deviceorientation event listener and return the listener for cleanup
WebEventListener? addDeviceOrientationListener(void Function(dynamic) callback) {
  final listener = ((JSAny event) {
    callback(event);
  }).toJS;

  web.window.addEventListener('deviceorientation', listener);
  return listener;
}

/// Remove a deviceorientation event listener
void removeDeviceOrientationListener(WebEventListener? listener) {
  if (listener != null) {
    web.window.removeEventListener('deviceorientation', listener);
  }
}

/// Get alpha (compass heading) from DeviceOrientationEvent
double? getEventAlpha(dynamic event) {
  try {
    final jsEvent = event as DeviceOrientationEventJS;
    return jsEvent.alpha;
  } catch (_) {
    return null;
  }
}

/// Get beta (front-back tilt) from DeviceOrientationEvent
double? getEventBeta(dynamic event) {
  try {
    final jsEvent = event as DeviceOrientationEventJS;
    return jsEvent.beta;
  } catch (_) {
    return null;
  }
}

/// Get gamma (left-right tilt) from DeviceOrientationEvent
double? getEventGamma(dynamic event) {
  try {
    final jsEvent = event as DeviceOrientationEventJS;
    return jsEvent.gamma;
  } catch (_) {
    return null;
  }
}
