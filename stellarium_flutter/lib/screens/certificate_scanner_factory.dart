// Conditional export for certificate scanner screen
// Uses native camera/ML Kit on mobile, web-based scanner on web.

export 'certificate_scanner_screen.dart'
    if (dart.library.js_interop) 'certificate_scanner_screen_web.dart';
