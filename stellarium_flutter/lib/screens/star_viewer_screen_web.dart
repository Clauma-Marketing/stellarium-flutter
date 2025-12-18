// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

String? _iframeViewType;
html.IFrameElement? _iframe;
html.EventListener? _messageListener;

/// Creates the star viewer widget for web platform using an iframe
Future<Widget> createViewer({
  required Map<String, String> params,
  required VoidCallback onClose,
}) async {
  // Build URL with query parameters
  final queryString = params.entries
      .map((e) =>
          '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');

  // Create unique view type for this instance
  _iframeViewType =
      'star-viewer-iframe-${DateTime.now().millisecondsSinceEpoch}';

  // Create the iframe element
  _iframe = html.IFrameElement()
    ..src = 'assets/assets/star_viewer/star_viewer.html?$queryString'
    ..style.border = 'none'
    ..style.width = '100%'
    ..style.height = '100%'
    ..allow = 'accelerometer; autoplay; encrypted-media; gyroscope';

  // Listen for messages from the iframe
  _messageListener = (html.Event event) {
    if (event is html.MessageEvent && event.data == 'close') {
      onClose();
    }
  };
  html.window.addEventListener('message', _messageListener);

  // Register the view factory
  ui_web.platformViewRegistry.registerViewFactory(
    _iframeViewType!,
    (int viewId) => _iframe!,
  );

  debugPrint('Star viewer iframe created for web');

  return HtmlElementView(viewType: _iframeViewType!);
}

/// Disposes resources used by the viewer
void disposeViewer() {
  if (_messageListener != null) {
    html.window.removeEventListener('message', _messageListener);
    _messageListener = null;
  }
  _iframe?.remove();
  _iframe = null;
  _iframeViewType = null;
}
