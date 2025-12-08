import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

/// Registers the Stellarium platform view factory.
///
/// This tells Flutter that when we ask for a view of type 'stellarium-container',
/// it should use the existing HTML element with id 'stellarium-container'.
void registerStellariumViewFactory() {
  ui_web.platformViewRegistry.registerViewFactory(
    'stellarium-container',
    (int viewId) {
      final element = web.document.getElementById('stellarium-container');
      if (element == null) {
        throw Exception('Element with id "stellarium-container" not found in index.html');
      }
      return element;
    },
  );
}
