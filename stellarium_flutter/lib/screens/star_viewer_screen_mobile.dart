import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

HttpServer? _server;
WebViewController? _webViewController;

/// Creates the star viewer widget for mobile platforms (iOS/Android)
Future<Widget> createViewer({
  required Map<String, String> params,
  required VoidCallback onClose,
}) async {
  // Copy HTML to temp directory
  final tempDir = await getTemporaryDirectory();
  final viewerDir = Directory('${tempDir.path}/star_viewer');

  if (!await viewerDir.exists()) {
    await viewerDir.create(recursive: true);
  }

  // Copy HTML file from assets
  final htmlContent =
      await rootBundle.loadString('assets/star_viewer/star_viewer.html');
  final htmlFile = File('${viewerDir.path}/star_viewer.html');
  await htmlFile.writeAsString(htmlContent);

  // Start local HTTP server
  _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final port = _server!.port;

  _server!.listen((request) async {
    var path = request.uri.path;
    if (path == '/') path = '/star_viewer.html';

    final file = File('${viewerDir.path}$path');
    if (await file.exists()) {
      String contentType = 'text/html';
      if (path.endsWith('.js')) {
        contentType = 'application/javascript';
      }

      request.response.headers.set('Content-Type', contentType);
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      await request.response.addStream(file.openRead());
    } else {
      request.response.statusCode = HttpStatus.notFound;
    }
    await request.response.close();
  });

  // Build URL with query parameters
  final queryString = params.entries
      .map((e) =>
          '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');

  final localServerUrl = 'http://127.0.0.1:$port/star_viewer.html?$queryString';
  debugPrint('Star viewer server started at: $localServerUrl');

  // Initialize WebViewController
  final controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(Colors.black)
    ..addJavaScriptChannel(
      'FlutterChannel',
      onMessageReceived: (JavaScriptMessage message) {
        if (message.message == 'close') {
          onClose();
        }
      },
    )
    ..setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (url) {
          debugPrint('Star viewer loaded: $url');
        },
        onWebResourceError: (error) {
          debugPrint('Star viewer error: ${error.description}');
        },
      ),
    )
    ..loadRequest(Uri.parse(localServerUrl));

  _webViewController = controller;

  return WebViewWidget(controller: controller);
}

/// Disposes resources used by the viewer
void disposeViewer() {
  _server?.close();
  _server = null;
  _webViewController = null;
}
