import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';

/// Full-screen 3D star viewer using Three.js
class StarViewerScreen extends StatefulWidget {
  final String starName;
  final String? spectralType;

  const StarViewerScreen({
    super.key,
    required this.starName,
    this.spectralType,
  });

  @override
  State<StarViewerScreen> createState() => _StarViewerScreenState();
}

class _StarViewerScreenState extends State<StarViewerScreen> {
  String? _localServerUrl;
  HttpServer? _server;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startLocalServer();
  }

  @override
  void dispose() {
    _server?.close();
    super.dispose();
  }

  Future<void> _startLocalServer() async {
    try {
      // Copy HTML to temp directory
      final tempDir = await getTemporaryDirectory();
      final viewerDir = Directory('${tempDir.path}/star_viewer');

      if (!await viewerDir.exists()) {
        await viewerDir.create(recursive: true);
      }

      // Copy HTML file from assets
      final htmlContent = await rootBundle.loadString('assets/star_viewer/star_viewer.html');
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
      final params = <String, String>{
        'name': widget.starName,
      };
      if (widget.spectralType != null && widget.spectralType!.isNotEmpty) {
        params['spectralType'] = widget.spectralType!;
      }

      final queryString = params.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      setState(() {
        _localServerUrl = 'http://127.0.0.1:$port/star_viewer.html?$queryString';
        _isLoading = false;
      });

      debugPrint('Star viewer server started at: $_localServerUrl');
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to start viewer: $e';
        _isLoading = false;
      });
    }
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    // Set up close handler
    controller.addJavaScriptHandler(
      handlerName: 'onClose',
      callback: (args) {
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            )
          else if (_isLoading || _localServerUrl == null)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.amber),
                  SizedBox(height: 16),
                  Text(
                    'Loading 3D Star...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          else
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_localServerUrl!)),
              initialSettings: InAppWebViewSettings(
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                javaScriptEnabled: true,
                domStorageEnabled: true,
                supportZoom: false,
                verticalScrollBarEnabled: false,
                horizontalScrollBarEnabled: false,
                transparentBackground: true,
                disableContextMenu: true,
                allowsBackForwardNavigationGestures: false,
                useHybridComposition: true,
                hardwareAcceleration: true,
              ),
              onWebViewCreated: _onWebViewCreated,
              onConsoleMessage: (controller, consoleMessage) {
                debugPrint('StarViewer console: ${consoleMessage.message}');
              },
            ),

          // Fallback close button (in case WebView doesn't load)
          if (_isLoading || _errorMessage != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
        ],
      ),
    );
  }
}
