import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../l10n/app_localizations.dart';
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
  final void Function(double fovDeg)? onFovChanged;

  const StellariumWebView({
    super.key,
    this.latitude,
    this.longitude,
    this.initialSettings,
    this.onReady,
    this.onError,
    this.onObjectSelected,
    this.onTimeChanged,
    this.onFovChanged,
  });

  @override
  State<StellariumWebView> createState() => StellariumWebViewState();
}

class StellariumWebViewState extends State<StellariumWebView>
    with TickerProviderStateMixin {
  WebViewController? _webViewController;
  bool _isReady = false;
  bool _isLoading = true;
  String? _errorMessage;
  String? _localServerUrl;
  HttpServer? _server;
  bool _isDisposed = false;

  // Unique key for WebViewWidget to prevent view ID conflicts on recreation
  // Using ValueKey with timestamp to ensure uniqueness across widget recreations
  late final Key _webViewKey =
      ValueKey('stellarium_webview_${DateTime.now().microsecondsSinceEpoch}');

  // Animation controllers
  late AnimationController _ringOuterController;
  late AnimationController _ringMiddleController;
  late AnimationController _ringInnerController;
  late AnimationController _arcController;
  late AnimationController _glowController;
  late AnimationController _particleController;
  late AnimationController _constellationController;
  late AnimationController _markerPulseController;
  late AnimationController _quoteController;
  late AnimationController _progressController;

  // Loading text management
  int _currentQuoteIndex = 0;
  int _currentStatusIndex = 0;
  bool _minLoadTimeElapsed = false;
  static const Duration _minLoadDuration = Duration(seconds: 5);

  // Quotes (shuffled on init, populated from localizations in didChangeDependencies)
  List<String> _shuffledQuotes = [];
  List<String> _shuffledStatuses = [];
  List<int> _quoteIndices = [];
  List<int> _statusIndices = [];

  /// Get localized quotes
  List<String> _getQuotes(AppLocalizations l10n) => [
        l10n.loaderQuote1,
        l10n.loaderQuote2,
        l10n.loaderQuote3,
        l10n.loaderQuote4,
        l10n.loaderQuote5,
        l10n.loaderQuote6,
        l10n.loaderQuote7,
        l10n.loaderQuote8,
      ];

  /// Get localized status messages
  List<String> _getStatusMessages(AppLocalizations l10n) => [
        l10n.loaderStatus1,
        l10n.loaderStatus2,
        l10n.loaderStatus3,
        l10n.loaderStatus4,
        l10n.loaderStatus5,
      ];

  // Color constants matching the HTML design
  static const Color _ink = Color(0xFF0a0a0f);
  static const Color _deep = Color(0xFF12121a);
  static const Color _cosmic = Color(0xFF1a1a28);
  static const Color _dust = Color(0xFF2a2a3d);
  static const Color _silver = Color(0xFF8890a8);
  static const Color _pearl = Color(0xFFc8cde0);
  static const Color _gold = Color(0xFFd4a853);
  static const Color _goldDim = Color(0x66d4a853);

  @override
  void initState() {
    super.initState();

    // Prepare shuffled indices (actual strings populated in didChangeDependencies)
    _quoteIndices = List.generate(8, (i) => i)..shuffle();
    _statusIndices = List.generate(5, (i) => i)..shuffle();

    // Ring rotations (matching HTML timings)
    _ringOuterController = AnimationController(
      duration: const Duration(seconds: 40),
      vsync: this,
    )..repeat();

    _ringMiddleController = AnimationController(
      duration: const Duration(seconds: 25),
      vsync: this,
    )..repeat(reverse: true);

    _ringInnerController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _arcController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();

    // Glow breathing animation
    _glowController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    // Particle orbits
    _particleController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    // Constellation breathing
    _constellationController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat(reverse: true);

    // Marker pulse
    _markerPulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    // Quote fade animation
    _quoteController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    // Progress bar animation
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 5000),
      vsync: this,
    )..repeat(reverse: true);

    // Start cycling through quotes and statuses
    _startQuoteCycling();
    _startStatusCycling();

    // Start minimum load time timer
    Future.delayed(_minLoadDuration, () {
      if (mounted) {
        setState(() {
          _minLoadTimeElapsed = true;
        });
        if (_isReady) {
          widget.onReady?.call(true);
        }
      }
    });

    _startLocalServer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Populate shuffled lists from localizations
    final l10n = AppLocalizations.of(context);
    if (l10n != null) {
      final quotes = _getQuotes(l10n);
      final statuses = _getStatusMessages(l10n);
      _shuffledQuotes = _quoteIndices.map((i) => quotes[i]).toList();
      _shuffledStatuses = _statusIndices.map((i) => statuses[i]).toList();
    }
  }

  void _startQuoteCycling() {
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted && !_shouldHideLoader) {
        _cycleToNextQuote();
      }
    });
  }

  void _cycleToNextQuote() {
    if (!mounted || _shouldHideLoader) return;

    _quoteController.reverse().then((_) {
      if (!mounted || _shouldHideLoader) return;

      setState(() {
        _currentQuoteIndex = (_currentQuoteIndex + 1) % _shuffledQuotes.length;
      });

      _quoteController.forward().then((_) {
        Future.delayed(const Duration(milliseconds: 2800), () {
          if (mounted && !_shouldHideLoader) {
            _cycleToNextQuote();
          }
        });
      });
    });
  }

  void _startStatusCycling() {
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted && !_shouldHideLoader) {
        _cycleToNextStatus();
      }
    });
  }

  void _cycleToNextStatus() {
    if (!mounted || _shouldHideLoader) return;

    setState(() {
      _currentStatusIndex =
          (_currentStatusIndex + 1) % _shuffledStatuses.length;
    });

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted && !_shouldHideLoader) {
        _cycleToNextStatus();
      }
    });
  }

  bool get _shouldHideLoader => _isReady && _minLoadTimeElapsed;

  @override
  void dispose() {
    _isDisposed = true;
    // Clear WebView controller reference before disposing
    _webViewController = null;
    _ringOuterController.dispose();
    _ringMiddleController.dispose();
    _ringInnerController.dispose();
    _arcController.dispose();
    _glowController.dispose();
    _particleController.dispose();
    _constellationController.dispose();
    _markerPulseController.dispose();
    _quoteController.dispose();
    _progressController.dispose();
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
    if (_isDisposed) return;

    try {
      // Copy assets to a temp directory that can be served
      final tempDir = await getTemporaryDirectory();
      if (_isDisposed) return;

      final stellariumDir = Directory('${tempDir.path}/stellarium');

      if (!await stellariumDir.exists()) {
        await stellariumDir.create(recursive: true);
      }

      // Copy HTML file
      final htmlContent =
          await rootBundle.loadString('assets/stellarium/stellarium.html');
      final htmlFile = File('${stellariumDir.path}/stellarium.html');
      await htmlFile.writeAsString(htmlContent);

      // Copy JS file
      final jsData =
          await rootBundle.load('assets/stellarium/stellarium-web-engine.js');
      final jsFile = File('${stellariumDir.path}/stellarium-web-engine.js');
      await jsFile.writeAsBytes(jsData.buffer.asUint8List());

      // Copy WASM file
      final wasmData =
          await rootBundle.load('assets/stellarium/stellarium-web-engine.wasm');
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

      if (_isDisposed) {
        _server?.close();
        return;
      }

      _localServerUrl = 'http://127.0.0.1:$port/stellarium.html';
      debugPrint('Stellarium local server started at: $_localServerUrl');

      // Small delay to allow any previous platform views to fully clean up
      await Future.delayed(const Duration(milliseconds: 100));
      if (_isDisposed || !mounted) return;

      // Initialize the WebViewController
      _initWebViewController();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to start local server: $e';
        _isLoading = false;
      });
      widget.onError?.call(_errorMessage!);
    }
  }

  void _initWebViewController() {
    if (_isDisposed) return;

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
      final androidController = controller.platform as AndroidWebViewController;
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
        // Only call onReady if minimum load time has elapsed
        // Otherwise, the timer callback will call it when time is up
        if (_minLoadTimeElapsed) {
          widget.onReady?.call(true);
        }
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
          debugPrint(
              'WebView: calling onObjectSelected with name: ${info.name}');
          widget.onObjectSelected?.call(info);
        }
        break;
      case 'timeChanged':
        final utc = (data?['utc'] as num?)?.toDouble();
        if (utc != null) {
          widget.onTimeChanged?.call(utc);
        }
        break;
      case 'fovChanged':
        final fovDeg = (data?['fov'] as num?)?.toDouble();
        if (fovDeg != null) {
          widget.onFovChanged?.call(fovDeg);
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
    _safeRunJavaScript(
        'stellariumAPI.setLocation($latitude, $longitude, $altitude)');
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

  /// Point at a celestial object by name (moves camera to object)
  void pointAt(String name, [double duration = 1.0]) {
    _safeRunJavaScript('stellariumAPI.pointAt("$name", $duration)');
  }

  /// Select a celestial object by name without moving the camera
  /// Use this in gyroscope mode to show the selection marker without changing view
  void selectObject(String name) {
    _safeRunJavaScript('stellariumAPI.selectObject("$name")');
  }

  /// Look at a specific direction (azimuth/altitude in radians)
  void lookAt(double azimuthRad, double altitudeRad, [double duration = 0.0]) {
    _safeRunJavaScript(
        'stellariumAPI.lookAtRadians($azimuthRad, $altitudeRad, $duration)');
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
    _safeRunJavaScript(
        'stellariumAPI.addPersistentLabel("$escapedId", "$escapedLabel")');
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

  /// Enable or disable star tracking (24-hour path visualization)
  void setStarTrackVisible(bool visible) {
    _safeRunJavaScript('stellariumAPI.setStarTrackVisible($visible)');
  }

  /// Whether the engine is ready
  bool get isReady => _isReady;

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    // Show loader until both: server is ready AND minimum time has elapsed AND engine is ready
    final showLoader = _isLoading ||
        _localServerUrl == null ||
        _webViewController == null ||
        !_shouldHideLoader;

    if (showLoader && _webViewController == null) {
      // Still setting up the server
      return _buildLoadingWidget();
    }

    // Stack the WebView with the loader overlay
    return Stack(
      children: [
        // WebView (loads in background) - wrapped to catch platform view errors
        if (_webViewController != null && !_isDisposed)
          RepaintBoundary(
            child: WebViewWidget(
              key: _webViewKey,
              controller: _webViewController!,
              gestureRecognizers: const <
                  Factory<OneSequenceGestureRecognizer>>{},
            ),
          ),

        // Loading overlay (fades out when ready)
        if (showLoader)
          AnimatedOpacity(
            opacity: _shouldHideLoader ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 500),
            child: _buildLoadingWidget(),
          ),
      ],
    );
  }

  Widget _buildLoadingWidget() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        // Responsive frame size - smaller on shorter screens
        final frameSize = math.min(
          screenWidth * 0.75,
          screenHeight < 700 ? 240.0 : (screenHeight < 800 ? 280.0 : 320.0),
        );

        return Container(
          color: _ink,
          child: Stack(
            children: [
              // Atmospheric radial glow (very subtle)
              Center(
                child: Container(
                  width: 800,
                  height: 800,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        _cosmic.withValues(alpha: 0.2),
                        _deep.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.4, 0.7],
                    ),
                  ),
                ),
              ),

              // Starfield
              ..._buildStarField(screenWidth, screenHeight),

              // Corner decorations
              ..._buildCorners(),

              // Main loader
              Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: screenHeight < 700 ? 20 : 40,
                      bottom: MediaQuery.of(context).padding.bottom +
                          (screenHeight < 700 ? 30 : 50),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Constellation frame
                        SizedBox(
                          width: frameSize,
                          height: frameSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outermost decorative ring (dashed)
                              RotationTransition(
                                turns: Tween(begin: 0.0, end: 1.0).animate(
                                  CurvedAnimation(
                                    parent: _ringOuterController,
                                    curve: Curves.linear,
                                  ),
                                ),
                                child: CustomPaint(
                                  size: Size(frameSize, frameSize),
                                  painter: _DashedCirclePainter(
                                    color: _dust.withValues(alpha: 0.4),
                                    strokeWidth: 1,
                                    dashLength: 8,
                                    gapLength: 4,
                                  ),
                                ),
                              ),

                              // Outer ring with markers
                              RotationTransition(
                                turns: _ringOuterController,
                                child: SizedBox(
                                  width: frameSize * 0.88,
                                  height: frameSize * 0.88,
                                  child: Stack(
                                    children: [
                                      // Ring border (no fill, just border)
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: _silver, width: 2),
                                        ),
                                      ),
                                      // Top gold marker
                                      Align(
                                        alignment: Alignment.topCenter,
                                        child: Transform.translate(
                                          offset: const Offset(0, -6),
                                          child: AnimatedBuilder(
                                            animation: _markerPulseController,
                                            builder: (context, child) {
                                              final scale = 1.0 +
                                                  (_markerPulseController
                                                          .value *
                                                      0.3);
                                              return Transform.scale(
                                                scale: scale,
                                                child: Container(
                                                  width: 12,
                                                  height: 12,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: _gold,
                                                    boxShadow: [
                                                      BoxShadow(
                                                          color: _gold,
                                                          blurRadius: 15),
                                                      BoxShadow(
                                                          color: _gold,
                                                          blurRadius: 30),
                                                      BoxShadow(
                                                          color: _goldDim,
                                                          blurRadius: 45),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      // Bottom pearl marker
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Transform.translate(
                                          offset: const Offset(0, 5),
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _pearl,
                                              boxShadow: [
                                                BoxShadow(
                                                    color: _pearl,
                                                    blurRadius: 10),
                                                BoxShadow(
                                                    color: _pearl.withValues(
                                                        alpha: 0.5),
                                                    blurRadius: 20),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Arc segments
                              RotationTransition(
                                turns: _arcController,
                                child: CustomPaint(
                                  size:
                                      Size(frameSize * 0.95, frameSize * 0.95),
                                  painter: _ArcPainter(
                                      color: _goldDim, strokeWidth: 2),
                                ),
                              ),
                              RotationTransition(
                                turns: Tween(begin: 0.0, end: -1.0)
                                    .animate(_arcController),
                                child: CustomPaint(
                                  size:
                                      Size(frameSize * 0.80, frameSize * 0.80),
                                  painter: _ArcPainter(
                                      color: _pearl.withValues(alpha: 0.3),
                                      strokeWidth: 2),
                                ),
                              ),

                              // Middle ring (conic gradient effect)
                              RotationTransition(
                                turns: Tween(begin: 0.0, end: -1.0)
                                    .animate(_ringMiddleController),
                                child: CustomPaint(
                                  size:
                                      Size(frameSize * 0.72, frameSize * 0.72),
                                  painter: _ConicRingPainter(color: _dust),
                                ),
                              ),

                              // Inner ring with marker
                              RotationTransition(
                                turns: _ringInnerController,
                                child: SizedBox(
                                  width: frameSize * 0.58,
                                  height: frameSize * 0.58,
                                  child: Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: _dust, width: 1),
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Transform.translate(
                                          offset: const Offset(-4, 0),
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _pearl,
                                              boxShadow: [
                                                BoxShadow(
                                                    color: _pearl,
                                                    blurRadius: 8)
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Innermost glow ring
                              AnimatedBuilder(
                                animation: _glowController,
                                builder: (context, child) {
                                  final scale =
                                      1.0 + (_glowController.value * 0.15);
                                  final opacity =
                                      0.6 + (_glowController.value * 0.4);
                                  return Transform.scale(
                                    scale: scale,
                                    child: Opacity(
                                      opacity: opacity,
                                      child: Container(
                                        width: frameSize * 0.48,
                                        height: frameSize * 0.48,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            colors: [
                                              _gold.withValues(alpha: 0.08),
                                              Colors.transparent,
                                            ],
                                            stops: const [0.0, 0.7],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),

                              // Orbiting particles
                              ..._buildParticles(frameSize),

                              // Central constellation
                              AnimatedBuilder(
                                animation: _constellationController,
                                builder: (context, child) {
                                  final scale = 1.0 +
                                      (_constellationController.value * 0.03);
                                  final opacity = 0.9 +
                                      (_constellationController.value * 0.1);
                                  return Transform.scale(
                                    scale: scale,
                                    child: Opacity(
                                      opacity: opacity,
                                      child: CustomPaint(
                                        size: Size(
                                            frameSize * 0.44, frameSize * 0.44),
                                        painter: _ConstellationPainter(
                                          lineColor: _dust,
                                          starColor: _pearl,
                                          glowColor: _gold,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: screenHeight < 700 ? 24 : 40),

                        // Logo
                        Builder(
                          builder: (context) {
                            final locale = Localizations.maybeLocaleOf(context)
                                    ?.languageCode ??
                                ui.PlatformDispatcher.instance.locale
                                    .languageCode;
                            final isGerman = locale == 'de';
                            return SvgPicture.asset(
                              isGerman
                                  ? 'assets/logo_de.svg'
                                  : 'assets/star-reg_logo.svg',
                              height: screenHeight < 700 ? 28 : 32,
                            );
                          },
                        ),

                        SizedBox(height: screenHeight < 700 ? 20 : 32),

                        // Quote
                        SizedBox(
                          height: 50,
                          width: math.min(screenWidth - 40, 380),
                          child: FadeTransition(
                            opacity: _quoteController,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.3),
                                end: Offset.zero,
                              ).animate(_quoteController),
                              child: Text(
                                _shuffledQuotes.isNotEmpty
                                    ? _shuffledQuotes[_currentQuoteIndex %
                                        _shuffledQuotes.length]
                                    : '',
                                style: TextStyle(
                                  color: _pearl,
                                  fontSize: screenHeight < 700 ? 15 : 17,
                                  fontWeight: FontWeight.w300,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: 0.3,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: screenHeight < 700 ? 16 : 20),

                        // Status text with wave animation
                        _buildStatusText(),

                        SizedBox(height: screenHeight < 700 ? 8 : 10),

                        // Progress bar
                        _buildProgressBar(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildParticles(double frameSize) {
    return [
      // Particle 1 - gold, orbit at 130px equivalent
      AnimatedBuilder(
        animation: _particleController,
        builder: (context, child) {
          final angle = _particleController.value * 2 * math.pi;
          final radius = frameSize * 0.41;
          return Transform.translate(
            offset: Offset(
              math.cos(angle) * radius,
              math.sin(angle) * radius,
            ),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _gold,
                boxShadow: [BoxShadow(color: _gold, blurRadius: 6)],
              ),
            ),
          );
        },
      ),
      // Particle 2 - pearl, reverse orbit
      AnimatedBuilder(
        animation: _particleController,
        builder: (context, child) {
          final angle = -_particleController.value * 2 * math.pi * 0.67;
          final radius = frameSize * 0.33;
          return Transform.translate(
            offset: Offset(
              math.cos(angle) * radius,
              math.sin(angle) * radius,
            ),
            child: Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pearl,
                boxShadow: [BoxShadow(color: _pearl, blurRadius: 6)],
              ),
            ),
          );
        },
      ),
      // Particle 3 - gold, fast orbit
      AnimatedBuilder(
        animation: _particleController,
        builder: (context, child) {
          final angle = _particleController.value * 2 * math.pi * 1.33;
          final radius = frameSize * 0.27;
          return Transform.translate(
            offset: Offset(
              math.cos(angle) * radius,
              math.sin(angle) * radius,
            ),
            child: Container(
              width: 2,
              height: 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _gold,
                boxShadow: [BoxShadow(color: _gold, blurRadius: 6)],
              ),
            ),
          );
        },
      ),
    ];
  }

  Widget _buildStatusText() {
    final text = _shuffledStatuses.isNotEmpty
        ? _shuffledStatuses[_currentStatusIndex % _shuffledStatuses.length]
            .toUpperCase()
        : '';
    // Simple static text - wave animation was causing readability issues
    return Text(
      text,
      style: TextStyle(
        color: _silver.withValues(alpha: 0.7),
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 3,
      ),
    );
  }

  Widget _buildProgressBar() {
    return SizedBox(
      width: 160,
      height: 9,
      child: AnimatedBuilder(
        animation: _progressController,
        builder: (context, child) {
          final progress = _progressController.value;
          return Stack(
            children: [
              // Track
              Positioned(
                top: 4,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  color: _dust,
                ),
              ),
              // Fill
              Positioned(
                top: 4,
                left: 0,
                child: Container(
                  height: 1,
                  width: 160 * progress,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_dust, _gold, _dust],
                    ),
                  ),
                ),
              ),
              // Glow
              Positioned(
                top: 0,
                left: 160 * progress - 2,
                child: Container(
                  width: 4,
                  height: 9,
                  decoration: BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                          color: _gold.withValues(alpha: 0.8), blurRadius: 3),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildStarField(double width, double height) {
    final stars = <Widget>[];
    final random = math.Random(42); // Fixed seed for consistent layout

    for (int i = 0; i < 60; i++) {
      final x = random.nextDouble() * width;
      final y = random.nextDouble() * height;
      final isBright = random.nextDouble() > 0.85;
      final size = isBright ? 3.0 : 2.0;
      final color = isBright ? _pearl : _silver;
      final animDelay = random.nextDouble() * 4;
      final animDuration = 3 + random.nextDouble() * 3;

      stars.add(
        Positioned(
          left: x,
          top: y,
          child: _AnimatedStar(
            size: size,
            color: color,
            delay: animDelay,
            duration: animDuration,
          ),
        ),
      );
    }

    return stars;
  }

  List<Widget> _buildCorners() {
    const cornerSize = 60.0;
    const topMargin = 30.0;
    const bottomMargin =
        80.0; // Larger bottom margin to avoid overlapping progress bar

    return [
      // Top-left
      Positioned(
        top: topMargin,
        left: topMargin,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: _dust.withValues(alpha: 0.3)),
              left: BorderSide(color: _dust.withValues(alpha: 0.3)),
            ),
          ),
        ),
      ),
      // Top-right
      Positioned(
        top: topMargin,
        right: topMargin,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: _dust.withValues(alpha: 0.3)),
              right: BorderSide(color: _dust.withValues(alpha: 0.3)),
            ),
          ),
        ),
      ),
      // Bottom-left
      Positioned(
        bottom: bottomMargin,
        left: topMargin,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: _dust.withValues(alpha: 0.3)),
              left: BorderSide(color: _dust.withValues(alpha: 0.3)),
            ),
          ),
        ),
      ),
      // Bottom-right
      Positioned(
        bottom: bottomMargin,
        right: topMargin,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: _dust.withValues(alpha: 0.3)),
              right: BorderSide(color: _dust.withValues(alpha: 0.3)),
            ),
          ),
        ),
      ),
    ];
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

// Custom painter for dashed circle
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  _DashedCirclePainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final radius = size.width / 2;
    final center = Offset(radius, radius);
    final circumference = 2 * math.pi * radius;
    final dashCount = (circumference / (dashLength + gapLength)).floor();

    for (int i = 0; i < dashCount; i++) {
      final startAngle = (i * (dashLength + gapLength)) / radius;
      final sweepAngle = dashLength / radius;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom painter for arc segment
class _ArcPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _ArcPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final radius = size.width / 2;
    final center = Offset(radius, radius);

    // Draw a 60-degree arc at the top
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 - math.pi / 6, // Start 30° before top
      math.pi / 3, // 60° sweep
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom painter for conic gradient ring effect
class _ConicRingPainter extends CustomPainter {
  final Color color;

  _ConicRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(radius, radius);
    final ringWidth = radius * 0.08;

    // Draw gradient segments
    final segmentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth;

    // Segment 1: 0-40 degrees
    segmentPaint.shader = ui.Gradient.sweep(
      center,
      [Colors.transparent, color, Colors.transparent],
      [0.0, 0.5, 1.0],
      TileMode.clamp,
      0,
      math.pi / 4.5,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - ringWidth / 2),
      0,
      math.pi / 4.5,
      false,
      segmentPaint,
    );

    // Segment 2: 180-220 degrees
    segmentPaint.shader = ui.Gradient.sweep(
      center,
      [Colors.transparent, color, Colors.transparent],
      [0.0, 0.5, 1.0],
      TileMode.clamp,
      math.pi,
      math.pi + math.pi / 4.5,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - ringWidth / 2),
      math.pi,
      math.pi / 4.5,
      false,
      segmentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom painter for constellation
class _ConstellationPainter extends CustomPainter {
  final Color lineColor;
  final Color starColor;
  final Color glowColor;

  _ConstellationPainter({
    required this.lineColor,
    required this.starColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 140;

    // Star positions (scaled from HTML SVG viewBox 0-140)
    final stars = [
      Offset(70 * scale, 20 * scale), // 0: top
      Offset(45 * scale, 50 * scale), // 1: upper left
      Offset(30 * scale, 90 * scale), // 2: lower left
      Offset(95 * scale, 55 * scale), // 3: upper right
      Offset(110 * scale, 95 * scale), // 4: lower right
      Offset(70 * scale, 120 * scale), // 5: bottom
    ];

    // Connection lines
    final lines = [
      [0, 1],
      [1, 2],
      [1, 3],
      [3, 4],
      [3, 5],
    ];

    // Draw lines
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (final line in lines) {
      canvas.drawLine(stars[line[0]], stars[line[1]], linePaint);
    }

    // Draw glow behind featured stars
    final glowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(stars[0], 6 * scale, glowPaint);
    canvas.drawCircle(stars[4], 5 * scale, glowPaint);

    // Draw stars
    final starPaint = Paint()..color = starColor;
    final starSizes = [3.0, 2.5, 2.0, 2.5, 3.0, 2.0];

    for (int i = 0; i < stars.length; i++) {
      canvas.drawCircle(stars[i], starSizes[i] * scale, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Animated star widget for starfield
class _AnimatedStar extends StatefulWidget {
  final double size;
  final Color color;
  final double delay;
  final double duration;

  const _AnimatedStar({
    required this.size,
    required this.color,
    required this.delay,
    required this.duration,
  });

  @override
  State<_AnimatedStar> createState() => _AnimatedStarState();
}

class _AnimatedStarState extends State<_AnimatedStar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: (widget.duration * 1000).round()),
      vsync: this,
    );

    // Start after delay
    Future.delayed(Duration(milliseconds: (widget.delay * 1000).round()), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = 0.1 + (_controller.value * 0.4);
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: opacity),
          ),
        );
      },
    );
  }
}
