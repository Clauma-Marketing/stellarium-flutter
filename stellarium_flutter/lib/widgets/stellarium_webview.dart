import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../stellarium/stellarium_settings.dart';

/// Selected object info from WebView
class SelectedObjectInfo {
  final String name;
  final String displayName;
  final List<String> names;
  final String type;
  final double? magnitude;
  final double? ra;
  final double? dec;
  final double? distance;

  SelectedObjectInfo({
    required this.name,
    required this.displayName,
    required this.names,
    required this.type,
    this.magnitude,
    this.ra,
    this.dec,
    this.distance,
  });

  factory SelectedObjectInfo.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'Unknown';
    return SelectedObjectInfo(
      name: name,
      displayName: json['displayName'] as String? ?? name,
      names: (json['names'] as List<dynamic>?)?.cast<String>() ?? [],
      type: json['type'] as String? ?? 'unknown',
      magnitude: (json['vmag'] as num?)?.toDouble(),
      ra: (json['ra'] as num?)?.toDouble(),
      dec: (json['dec'] as num?)?.toDouble(),
      distance: (json['distance'] as num?)?.toDouble(),
    );
  }
}

/// WebView-based Stellarium viewer for iOS/Android
class StellariumWebView extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final StellariumSettings? initialSettings;
  final void Function(bool ready)? onReady;
  final void Function(String error)? onError;
  final void Function(SelectedObjectInfo info)? onObjectSelected;
  final void Function(double utc)? onTimeChanged;

  const StellariumWebView({
    super.key,
    this.latitude,
    this.longitude,
    this.initialSettings,
    this.onReady,
    this.onError,
    this.onObjectSelected,
    this.onTimeChanged,
  });

  @override
  State<StellariumWebView> createState() => StellariumWebViewState();
}

class StellariumWebViewState extends State<StellariumWebView>
    with SingleTickerProviderStateMixin {
  WebViewController? _webViewController;
  bool _isReady = false;
  bool _isLoading = true;
  String? _errorMessage;
  String? _localServerUrl;
  HttpServer? _server;
  bool _isDisposed = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
    _startLocalServer();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pulseController.dispose();
    _server?.close();
    super.dispose();
  }

  /// Safely execute JavaScript, only if controller is valid
  Future<void> _safeRunJavaScript(String source) async {
    if (_isDisposed || _webViewController == null || !_isReady) return;
    try {
      await _webViewController!.runJavaScript(source);
    } catch (e) {
      debugPrint('JavaScript execution error: $e');
    }
  }

  Future<void> _startLocalServer() async {
    try {
      // Copy assets to a temp directory that can be served
      final tempDir = await getTemporaryDirectory();
      final stellariumDir = Directory('${tempDir.path}/stellarium');

      if (!await stellariumDir.exists()) {
        await stellariumDir.create(recursive: true);
      }

      // Copy HTML file
      final htmlContent = await rootBundle.loadString('assets/stellarium/stellarium.html');
      final htmlFile = File('${stellariumDir.path}/stellarium.html');
      await htmlFile.writeAsString(htmlContent);

      // Copy JS file
      final jsData = await rootBundle.load('assets/stellarium/stellarium-web-engine.js');
      final jsFile = File('${stellariumDir.path}/stellarium-web-engine.js');
      await jsFile.writeAsBytes(jsData.buffer.asUint8List());

      // Copy WASM file
      final wasmData = await rootBundle.load('assets/stellarium/stellarium-web-engine.wasm');
      final wasmFile = File('${stellariumDir.path}/stellarium-web-engine.wasm');
      await wasmFile.writeAsBytes(wasmData.buffer.asUint8List());

      // Start local HTTP server
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = _server!.port;

      _server!.listen((request) async {
        var path = request.uri.path;
        if (path == '/') path = '/stellarium.html';

        final file = File('${stellariumDir.path}$path');
        if (await file.exists()) {
          // Set appropriate content type
          String contentType = 'text/html';
          if (path.endsWith('.js')) {
            contentType = 'application/javascript';
          } else if (path.endsWith('.wasm')) {
            contentType = 'application/wasm';
          }

          request.response.headers.set('Content-Type', contentType);
          request.response.headers.set('Access-Control-Allow-Origin', '*');
          await request.response.addStream(file.openRead());
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });

      _localServerUrl = 'http://127.0.0.1:$port/stellarium.html';
      debugPrint('Stellarium local server started at: $_localServerUrl');

      // Initialize the WebViewController
      _initWebViewController();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to start local server: $e';
        _isLoading = false;
      });
      widget.onError?.call(_errorMessage!);
    }
  }

  void _initWebViewController() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0a1628))
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final data = jsonDecode(message.message);
            _handleMessage(data);
          } catch (e) {
            debugPrint('Error parsing message: $e');
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            debugPrint('WebView loaded: $url');
          },
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      );

    // Enable mixed content on Android (HTTP page loading HTTPS resources)
    if (Platform.isAndroid) {
      final androidController =
          controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      // Allow mixed content (HTTP origin loading HTTPS resources)
      androidController.setMixedContentMode(MixedContentMode.alwaysAllow);
    }

    // Clear WebView cache to ensure fresh responses (fixes stale CORS headers)
    controller.clearCache();

    controller.loadRequest(Uri.parse(_localServerUrl!));

    _webViewController = controller;
  }

  void _handleMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    final data = message['data'] as Map<String, dynamic>?;

    switch (type) {
      case 'ready':
        setState(() {
          _isReady = true;
        });
        widget.onReady?.call(true);
        _applyInitialSettings();
        break;
      case 'error':
        final error = data?['message'] as String? ?? 'Unknown error';
        setState(() {
          _errorMessage = error;
        });
        widget.onError?.call(error);
        break;
      case 'objectSelected':
        debugPrint('WebView: objectSelected event received: $data');
        if (data != null) {
          final info = SelectedObjectInfo.fromJson(data);
          debugPrint('WebView: calling onObjectSelected with name: ${info.name}');
          widget.onObjectSelected?.call(info);
        }
        break;
      case 'timeChanged':
        final utc = (data?['utc'] as num?)?.toDouble();
        if (utc != null) {
          widget.onTimeChanged?.call(utc);
        }
        break;
      case 'debugFetch':
        final url = data?['url'] as String?;
        if (url != null) {
          _debugFetchUrl(url);
        }
        break;
    }
  }

  Future<void> _debugFetchUrl(String url) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('Origin', 'http://127.0.0.1');
      final response = await request.close();

      debugPrint('=== Flutter Debug Fetch: $url ===');
      debugPrint('Status: ${response.statusCode}');
      debugPrint('All Response Headers:');
      response.headers.forEach((name, values) {
        debugPrint('  $name: ${values.join(", ")}');
      });
      client.close();
    } catch (e) {
      debugPrint('Flutter Debug Fetch Error: $e');
    }
  }

  void _applyInitialSettings() {
    // IMPORTANT: Keep native touch handling ENABLED.
    // Native WebView touches bypass Flutter's hit-testing, so we filter them
    // in the HTML layer using UI bounds sent from Flutter.
    // Flutter's event forwarding is now redundant but harmless.
    setTouchEnabled(true);

    // Set initial location if provided
    if (widget.latitude != null && widget.longitude != null) {
      setLocation(widget.latitude!, widget.longitude!);
    }

    // Apply initial settings
    if (widget.initialSettings != null) {
      applySettings(widget.initialSettings!);
    }
  }

  /// Set the observer's location
  void setLocation(double latitude, double longitude, [double altitude = 0]) {
    _safeRunJavaScript('stellariumAPI.setLocation($latitude, $longitude, $altitude)');
  }

  /// Set a single display setting
  void setSetting(String key, bool value) {
    _safeRunJavaScript('stellariumAPI.setSetting("$key", $value)');
  }

  /// Apply all settings
  void applySettings(StellariumSettings settings) {
    final map = settings.toMap();
    for (final entry in map.entries) {
      setSetting(entry.key, entry.value);
    }
  }

  /// Set the observation time (MJD)
  void setTime(double mjd) {
    _safeRunJavaScript('stellariumAPI.setTime($mjd)');
  }

  /// Set the time progression speed (1.0 = real-time, 0.0 = paused)
  void setTimeSpeed(double speed) {
    _safeRunJavaScript('stellariumAPI.setTimeSpeed($speed)');
  }

  /// Set field of view in degrees
  void setFov(double fovDeg, [double duration = 1.0]) {
    _safeRunJavaScript('stellariumAPI.setFov($fovDeg, $duration)');
  }

  /// Point at a celestial object by name
  void pointAt(String name, [double duration = 1.0]) {
    _safeRunJavaScript('stellariumAPI.pointAt("$name", $duration)');
  }

  /// Look at a specific direction (azimuth/altitude in radians)
  void lookAt(double azimuthRad, double altitudeRad, [double duration = 0.0]) {
    _safeRunJavaScript('stellariumAPI.lookAtRadians($azimuthRad, $altitudeRad, $duration)');
  }

  /// Enable or disable gyroscope mode (disables touch panning when enabled)
  void setGyroscopeEnabled(bool enabled) {
    _safeRunJavaScript('stellariumAPI.setGyroscopeEnabled($enabled)');
  }

  /// Enable or disable all touch handling (use when modals are open)
  void setTouchEnabled(bool enabled) {
    // Set JavaScript flag
    _safeRunJavaScript('stellariumAPI.setTouchEnabled($enabled)');
  }

  /// Forward a pointer down event to Stellarium
  void onPointerDown(int pointerId, double x, double y) {
    _safeRunJavaScript('stellariumAPI.onTouchStart($pointerId, $x, $y)');
  }

  /// Forward a pointer move event to Stellarium
  void onPointerMove(int pointerId, double x, double y) {
    _safeRunJavaScript('stellariumAPI.onTouchMove($pointerId, $x, $y)');
  }

  /// Forward a pointer up event to Stellarium
  void onPointerUp(int pointerId, double x, double y) {
    _safeRunJavaScript('stellariumAPI.onTouchEnd($pointerId, $x, $y)');
  }

  /// Set a custom label to display near the selected star
  void setCustomLabel(String? label) {
    if (label != null && label.isNotEmpty) {
      // Escape quotes in the label
      final escaped = label.replaceAll('"', '\\"').replaceAll("'", "\\'");
      _safeRunJavaScript('stellariumAPI.setCustomLabel("$escaped")');
    } else {
      _safeRunJavaScript('stellariumAPI.clearCustomLabel()');
    }
  }

  /// Clear the custom label
  void clearCustomLabel() {
    _safeRunJavaScript('stellariumAPI.clearCustomLabel()');
  }

  /// Add a persistent label for a star (shown without selection)
  void addPersistentLabel(String identifier, String label) {
    final escapedId = identifier.replaceAll('"', '\\"').replaceAll("'", "\\'");
    final escapedLabel = label.replaceAll('"', '\\"').replaceAll("'", "\\'");
    _safeRunJavaScript('stellariumAPI.addPersistentLabel("$escapedId", "$escapedLabel")');
  }

  /// Remove a persistent label for a star
  void removePersistentLabel(String identifier) {
    final escapedId = identifier.replaceAll('"', '\\"').replaceAll("'", "\\'");
    _safeRunJavaScript('stellariumAPI.removePersistentLabel("$escapedId")');
  }

  /// Clear all persistent labels
  void clearPersistentLabels() {
    _safeRunJavaScript('stellariumAPI.clearPersistentLabels()');
  }

  /// Start gyroscope guidance to a star by name
  /// Shows an arrow pointing to the star without changing FOV
  void startGuidance(String name) {
    final escaped = name.replaceAll('"', '\\"').replaceAll("'", "\\'");
    _safeRunJavaScript('stellariumAPI.startGuidance("$escaped")');
  }

  /// Stop gyroscope guidance
  void stopGuidance() {
    _safeRunJavaScript('stellariumAPI.stopGuidance()');
  }

  /// Whether the engine is ready
  bool get isReady => _isReady;

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    if (_isLoading || _localServerUrl == null || _webViewController == null) {
      return _buildLoadingWidget();
    }

    // Disable ALL native gesture handling on the WebView.
    // This makes the WebView purely visual - it won't respond to any touches.
    // Touch events are forwarded via JavaScript from a Flutter Listener in SkyView.
    // This allows Flutter's hit-testing to work naturally: UI elements block touches,
    // and only touches in the sky area get forwarded to Stellarium.
    return WebViewWidget(
      controller: _webViewController!,
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      color: const Color(0xFF0a1628),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF33B4E8),
                      const Color(0xFF33B4E8).withValues(alpha: 0.7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF33B4E8).withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.star,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Loading Stellarium...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: const Color(0xFF0a1628),
      child: Center(
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
              const Text(
                'Failed to load Stellarium',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Unknown error',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
