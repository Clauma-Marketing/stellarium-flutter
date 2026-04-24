import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../services/analytics_service.dart';
import '../../../../stellarium/observer.dart';
import '../../../../stellarium/stellarium_settings.dart';
import '../../../../widgets/stellarium_webview.dart';
import '../widgets/permission_page_template.dart';

/// Sky preview page shown during onboarding after location permission.
/// Gives users their first "aha moment" with a live interactive sky.
/// Starts 18 hours in the past and fast-forwards to the current time.
class SkyPreviewPage extends StatefulWidget {
  final VoidCallback onContinue;
  final double latitude;
  final double longitude;
  final String? locationName;
  final int? currentPage;
  final int? totalPages;

  const SkyPreviewPage({
    super.key,
    required this.onContinue,
    required this.latitude,
    required this.longitude,
    this.locationName,
    this.currentPage,
    this.totalPages,
  });

  @override
  State<SkyPreviewPage> createState() => _SkyPreviewPageState();
}

class _SkyPreviewPageState extends State<SkyPreviewPage>
    with SingleTickerProviderStateMixin {
  SelectedObjectInfo? _selectedObject;
  Timer? _infoDismissTimer;
  final GlobalKey<StellariumWebViewState> _webViewKey = GlobalKey();
  bool _animationStarted = false;
  bool _animationDone = false;

  // Fade-in controller for the viewer
  late AnimationController _fadeController;

  /// Duration of the time-lapse animation.
  static const _animationDuration = Duration(seconds: 6);

  /// How many hours of sky rotation to show.
  static const _hoursToAnimate = 18.0;

  // Settings optimized for a beautiful preview
  final _previewSettings = StellariumSettings(
    constellationsLines: true,
    constellationsLabels: true,
    constellationsArt: true,
    atmosphere: false,
    landscape: false,
    landscapeFog: false,
    milkyWay: true,
    dss: false,
    stars: true,
    planets: true,
    dsos: false,
    satellites: false,
  );

  void _onStarTapped(SelectedObjectInfo info) {
    HapticFeedback.lightImpact();
    AnalyticsService.instance.logSkyPreviewStarTap(starName: info.displayName);

    _infoDismissTimer?.cancel();

    setState(() {
      _selectedObject = info;
    });

    _infoDismissTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _selectedObject = null;
        });
      }
    });
  }

  void _onViewerReady(bool ready) {
    if (!ready || !mounted) return;
    // Fade in the viewer
    _fadeController.forward();
    _startTimeLapse();
  }

  void _startTimeLapse() {
    if (_animationStarted) return;
    _animationStarted = true;

    final webView = _webViewKey.currentState;
    if (webView == null) return;

    // Set time to 18 hours ago
    final startTime = DateTime.now().toUtc().subtract(
          Duration(hours: _hoursToAnimate.toInt()),
        );
    final startMjd = Observer.dateTimeToMjd(startTime);
    webView.setTime(startMjd);

    // Calculate speed: cover _hoursToAnimate in _animationDuration
    final speed = (_hoursToAnimate * 3600) / _animationDuration.inSeconds;
    webView.setTimeSpeed(speed);

    // Stop at current time and show final title
    Timer(_animationDuration, () {
      if (!mounted) return;
      final webView = _webViewKey.currentState;
      if (webView == null) return;
      webView.setTimeSpeed(1.0);
      setState(() => _animationDone = true);
    });
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    AnalyticsService.instance
        .logScreenView(screenName: 'onboarding_sky_preview');
  }

  @override
  void dispose() {
    _infoDismissTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final finalTitle = widget.locationName != null
        ? l10n.skyPreviewTitleWithLocation(widget.locationName!)
        : l10n.skyPreviewTitle;
    final calculatingTitle = widget.locationName != null
        ? l10n.skyPreviewCalculatingWithLocation(widget.locationName!)
        : l10n.skyPreviewCalculating;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Title with checkmark + animated text transition
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: Row(
                  key: ValueKey(_animationDone),
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_animationDone) ...[
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        _animationDone ? finalTitle : calculatingTitle,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Sky viewer with glow border and fade-in
              Expanded(
                child: FadeTransition(
                  opacity: _fadeController,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _animationDone
                            ? Colors.green.withValues(alpha: 0.5)
                            : primaryBlue.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _animationDone
                              ? Colors.green.withValues(alpha: 0.2)
                              : primaryBlue.withValues(alpha: 0.15),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(19),
                      child: Stack(
                        children: [
                          // Stellarium WebView
                          Positioned.fill(
                            child: StellariumWebView(
                              key: _webViewKey,
                              latitude: widget.latitude,
                              longitude: widget.longitude,
                              initialSettings: _previewSettings,
                              showLoadingOverlay: false,
                              onReady: _onViewerReady,
                              onObjectSelected: _onStarTapped,
                            ),
                          ),
                          // Top vignette for depth
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 60,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.5),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Bottom vignette
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 80,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.6),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Bottom info bar for selected star
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: AnimatedSlide(
                              offset: _selectedObject != null
                                  ? Offset.zero
                                  : const Offset(0, 1),
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                              child: AnimatedOpacity(
                                opacity: _selectedObject != null ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 250),
                                child: Container(
                                  margin: const EdgeInsets.all(10),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: 0.1),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        color: primaryBlue,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _selectedObject?.displayName ?? '',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (_selectedObject?.magnitude != null)
                                        Text(
                                          'mag ${_selectedObject!.magnitude!.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.6),
                                            fontSize: 13,
                                          ),
                                        ),
                                      const SizedBox(width: 12),
                                      Text(
                                        _selectedObject?.type ?? '',
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.5),
                                          fontSize: 13,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Page indicator
              if (widget.currentPage != null && widget.totalPages != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.totalPages!, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: widget.currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: widget.currentPage == index
                              ? primaryBlue
                              : Colors.white.withValues(alpha: 0.3),
                        ),
                      );
                    }),
                  ),
                ),
              // Continue button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: widget.onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    l10n.skyPreviewContinue,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
