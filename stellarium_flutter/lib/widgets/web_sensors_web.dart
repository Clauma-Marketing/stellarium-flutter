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
  /// iOS Safari: compass heading (0 = north, 90 = east, increases clockwise)
  /// This is the actual compass heading on iOS, unlike alpha which is arbitrary
  external double? get webkitCompassHeading;
  /// iOS Safari: compass accuracy in degrees (lower is better)
  external double? get webkitCompassAccuracy;
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

// Track if we're receiving absolute orientation events
bool _receivingAbsoluteEvents = false;
int _absoluteEventCount = 0;

/// Add a deviceorientation event listener and return the listener for cleanup
/// Uses 'deviceorientationabsolute' for true compass heading (Android Chrome),
/// falls back to 'deviceorientation' for iOS Safari which doesn't support absolute.
WebEventListener? addDeviceOrientationListener(void Function(dynamic) callback) {
  _receivingAbsoluteEvents = false;
  _absoluteEventCount = 0;

  final listener = ((JSAny event) {
    // Check if this is an absolute event by checking the 'absolute' property
    try {
      final jsEvent = event as DeviceOrientationEventJS;
      final isAbsolute = jsEvent.absolute == true;

      if (isAbsolute) {
        _absoluteEventCount++;
        _receivingAbsoluteEvents = true;
        callback(event);
      } else if (!_receivingAbsoluteEvents || _absoluteEventCount < 5) {
        // Use non-absolute events only if we haven't started receiving absolute ones
        // or we're still in the initial period (first 5 events)
        callback(event);
      }
      // Otherwise ignore non-absolute events since we have absolute ones
    } catch (_) {
      callback(event);
    }
  }).toJS;

  // Listen for both event types - the callback filters based on absolute property
  web.window.addEventListener('deviceorientationabsolute', listener);
  web.window.addEventListener('deviceorientation', listener);
  return listener;
}

/// Remove a deviceorientation event listener
void removeDeviceOrientationListener(WebEventListener? listener) {
  if (listener != null) {
    web.window.removeEventListener('deviceorientationabsolute', listener);
    web.window.removeEventListener('deviceorientation', listener);
  }
  _receivingAbsoluteEvents = false;
  _absoluteEventCount = 0;
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

/// Get webkitCompassHeading (iOS Safari only) from DeviceOrientationEvent
/// Returns the actual compass heading on iOS (0 = north, 90 = east)
double? getEventWebkitCompassHeading(dynamic event) {
  try {
    final jsEvent = event as DeviceOrientationEventJS;
    return jsEvent.webkitCompassHeading;
  } catch (_) {
    return null;
  }
}

/// Get webkitCompassAccuracy (iOS Safari only) from DeviceOrientationEvent
double? getEventWebkitCompassAccuracy(dynamic event) {
  try {
    final jsEvent = event as DeviceOrientationEventJS;
    return jsEvent.webkitCompassAccuracy;
  } catch (_) {
    return null;
  }
}

/// Check if this event has absolute orientation data
/// Returns true if either absolute property is true OR webkitCompassHeading is available
bool hasAbsoluteOrientation(dynamic event) {
  try {
    final jsEvent = event as DeviceOrientationEventJS;
    // Check for Android absolute orientation or iOS webkitCompassHeading
    return jsEvent.absolute == true || jsEvent.webkitCompassHeading != null;
  } catch (_) {
    return false;
  }
}

/// Get the best available compass heading from the event
/// Uses webkitCompassHeading on iOS, alpha on Android with absolute orientation
double? getBestCompassHeading(dynamic event) {
  try {
    final jsEvent = event as DeviceOrientationEventJS;

    // iOS Safari: use webkitCompassHeading (more reliable)
    final webkitHeading = jsEvent.webkitCompassHeading;
    if (webkitHeading != null && webkitHeading >= 0) {
      return webkitHeading;
    }

    // Android/other: use alpha if this is an absolute orientation event
    if (jsEvent.absolute == true && jsEvent.alpha != null) {
      // DeviceOrientation alpha: 0 = device top points north
      // We need compass heading: 0 = looking north
      // When device top points north (alpha=0), the back of phone faces north
      // So compass heading = alpha (they're the same convention)
      return jsEvent.alpha;
    }

    return null;
  } catch (_) {
    return null;
  }
}
