// Conditional export for web sensors functionality
// Uses stub on mobile, real implementation on web.

export 'web_sensors_stub.dart'
    if (dart.library.js_interop) 'web_sensors_web.dart';
