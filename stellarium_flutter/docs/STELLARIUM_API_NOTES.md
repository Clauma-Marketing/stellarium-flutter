# Stellarium Web Engine API Notes

This document captures key learnings about the Stellarium Web Engine API discovered during development.

## Core Objects

```javascript
window.stellarium = stel;  // Main engine instance
stel.core;                  // Core module
stel.observer;              // Observer/camera settings
```

## Observer Properties

| Property | Type | Description |
|----------|------|-------------|
| `stel.observer.longitude` | radians | Observer longitude |
| `stel.observer.latitude` | radians | Observer latitude |
| `stel.observer.elevation` | meters | Observer altitude above sea level |
| `stel.observer.utc` | MJD | Current time as Modified Julian Date |
| `stel.observer.fov` | radians | Current field of view |
| `stel.observer.azimuth` | radians | Current view azimuth direction |
| `stel.observer.altitude` | radians | Current view altitude/elevation angle |
| `stel.observer.pitch` | radians | Camera pitch |
| `stel.observer.yaw` | radians | Camera yaw |
| `stel.observer.roll` | radians | Camera roll |
| `stel.observer.view_offset_alt` | radians | **IMPORTANT**: Altitude offset from locked object |
| `stel.observer.azalt` | array? | Current az/alt (unclear usage) |

## View Offset for Pointing

To position a star at a specific screen location (e.g., 25% from top instead of center):

```javascript
// Get current FOV
const fov = stel.observer.fov || (60 * Math.PI / 180);

// Set view_offset_alt BEFORE pointAndLock
// Positive value = star appears HIGHER on screen
// 0.35 * FOV positions star at roughly 25% from top
stel.observer.view_offset_alt = fov * 0.35;

// Then point at the object
stel.pointAndLock(obj, duration);
```

## Coordinate Conversions

```javascript
// Spherical (azimuth, altitude) to Cartesian direction vector
const pos = stel.s2c(azimuthRad, altitudeRad);

// Cartesian to Spherical
const spherical = stel.c2s(pos);  // Returns [azimuth, altitude]

// Degrees to Radians conversion constants
stel.D2R  // Degrees to radians multiplier
stel.R2D  // Radians to degrees multiplier
```

## Looking at Directions (Compass/Gyroscope)

For AR/gyroscope mode where you have device orientation:

```javascript
// Convert azimuth and altitude to direction vector
const pos = stel.s2c(azimuthRad, altitudeRad);

// Look at that direction (duration=0 for immediate)
stel.lookAt(pos, duration);
```

**Azimuth convention**: 0 = North, increases clockwise (East = 90°, South = 180°, West = 270°)

## Touch/Mouse Event Handling via WASM Module

For panning, zooming, and object selection:

```javascript
// Mouse/Touch events (handled by WASM)
Module._core_on_mouse(id, action, x, y, button);
// id: unique touch identifier
// action: 1 = down, -1 = move, 0 = up
// x, y: screen coordinates
// button: 1 = pressed, 0 = released

// Zoom (pinch-to-zoom)
Module._core_on_zoom(scale, centerX, centerY);
```

### Tap Detection for Object Selection

Taps are distinguished from pans by tracking movement and duration:

```javascript
const TAP_THRESHOLD = 15;      // Max pixels moved
const TAP_MAX_DURATION = 300;  // Max milliseconds

// On touchstart: record start position and time
touchStartX = e.touches[0].clientX;
touchStartY = e.touches[0].clientY;
touchStartTime = Date.now();

// On touchend: check if it was a tap
const dx = Math.abs(touch.clientX - touchStartX);
const dy = Math.abs(touch.clientY - touchStartY);
const duration = Date.now() - touchStartTime;

if (dx < TAP_THRESHOLD && dy < TAP_THRESHOLD && duration < TAP_MAX_DURATION) {
    // This is a tap - select object at position
    // Send click via Module._core_on_mouse to trigger selection
    const dpr = window.devicePixelRatio || 1;
    Module._core_on_mouse(99, 1, x * dpr, y * dpr, 1);  // down
    Module._core_on_mouse(99, 0, x * dpr, y * dpr, 0);  // up

    // Read the selection
    const selection = stel.core.selection;
}
```

## Object Selection

```javascript
// Select an object (shows crosshair)
stel.core.selection = obj;

// Get current selection
const selection = stel.core.selection;

// Selection properties (if available)
selection.names       // Array of names
selection.designations // Alternative names array
selection.type        // Object type string
selection.vmag        // Visual magnitude
selection.ra          // Right ascension (radians)
selection.de          // Declination (radians)
selection.distance    // Distance (if known)
```

## Finding Objects

```javascript
// Search by name (try with and without 'NAME ' prefix)
var obj = stel.getObj('NAME ' + name);
if (!obj) obj = stel.getObj(name);

// Example: "HIP 14778" or "NAME Sirius"
```

## Pointing at Objects

```javascript
// Point and lock camera to object (centers it)
stel.pointAndLock(obj, duration);

// To unlock after pointing:
stel.core.lock = null;

// To point with offset (star not centered):
stel.observer.view_offset_alt = fov * 0.35;  // Set BEFORE pointAndLock
stel.pointAndLock(obj, duration);
```

## Zooming

```javascript
// Zoom to specific FOV
stel.zoomTo(fovRadians, duration);
```

## Disabling Touch Panning (for Gyroscope Mode)

When gyroscope is enabled, you want to disable touch panning but keep pinch-to-zoom:

```javascript
window.gyroscopeEnabled = true;  // Flag to check in touch handlers

// In touchstart/touchmove handlers:
if (!window.gyroscopeEnabled) {
    // Only send pan events if gyroscope is disabled
    Module._core_on_mouse(id, action, x, y, button);
}

// Pinch-to-zoom can still work regardless of gyroscope mode
```

## Settings (Display Options)

```javascript
stel.core.constellations.lines_visible = true/false;
stel.core.constellations.labels_visible = true/false;
stel.core.constellations.images_visible = true/false;  // Constellation art
stel.core.atmosphere.visible = true/false;
stel.core.landscapes.visible = true/false;
stel.core.landscapes.fog_visible = true/false;
stel.core.milkyway.visible = true/false;
stel.core.stars.visible = true/false;
stel.core.planets.visible = true/false;
stel.core.dsos.visible = true/false;
stel.core.lines.azimuthal.visible = true/false;
stel.core.lines.equatorial_jnow.visible = true/false;
stel.core.lines.equatorial.visible = true/false;  // J2000
stel.core.lines.meridian.visible = true/false;
stel.core.lines.ecliptic.visible = true/false;
```

## Flutter-to-JS Communication

Using InAppWebView JavaScript handlers:

```javascript
// Send message to Flutter
function sendToFlutter(type, data) {
    if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('onMessage', JSON.stringify({
            type: type,
            data: data
        }));
    }
}

// Example: notify Flutter of selected object
sendToFlutter('objectSelected', {
    name: obj.name,
    type: obj.type,
    vmag: obj.vmag,
    ra: obj.ra * stel.R2D,
    dec: obj.de * stel.R2D
});
```

## Important Notes

1. **Coordinate System**: Stellarium uses radians internally. Use `stel.D2R` and `stel.R2D` for conversions.

2. **Object Properties**: Objects from `getObj()` have limited direct properties (`v`, `swe_`). Use the selection object for more data.

3. **view_offset_alt**: This is the key to positioning stars off-center. Set it BEFORE calling `pointAndLock`.

4. **Device Pixel Ratio**: When passing screen coordinates to WASM functions, multiply by `window.devicePixelRatio`.

5. **Gyroscope Integration**: Use accelerometer for altitude (device tilt) and compass for azimuth (heading). Apply low-pass filtering for smooth movement.
