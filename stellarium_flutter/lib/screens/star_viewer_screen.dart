import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

// Conditional imports for platform-specific implementations
import 'star_viewer_screen_stub.dart'
    if (dart.library.io) 'star_viewer_screen_mobile.dart'
    if (dart.library.html) 'star_viewer_screen_web.dart' as platform_impl;

/// Full-screen 3D star viewer using Three.js
class StarViewerScreen extends StatefulWidget {
  final String starName;
  final String? spectralType;
  final double? vMagnitude;
  final double? bMagnitude;
  final bool isDoubleOrMultiple;
  final double? distanceLightYears;

  const StarViewerScreen({
    super.key,
    required this.starName,
    this.spectralType,
    this.vMagnitude,
    this.bMagnitude,
    this.isDoubleOrMultiple = false,
    this.distanceLightYears,
  });

  @override
  State<StarViewerScreen> createState() => _StarViewerScreenState();
}

class _StarViewerScreenState extends State<StarViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  bool _initialized = false;
  Widget? _viewerWidget;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final l10n = AppLocalizations.of(context);
      _initializeViewer(l10n?.back ?? 'Back');
    }
  }

  @override
  void dispose() {
    platform_impl.disposeViewer();
    super.dispose();
  }

  Future<void> _initializeViewer(String backText) async {
    try {
      final params = <String, String>{
        'name': widget.starName,
        'backText': backText,
      };
      if (widget.spectralType != null && widget.spectralType!.isNotEmpty) {
        params['spectralType'] = widget.spectralType!;
      }
      if (widget.vMagnitude != null) {
        params['vMagnitude'] = widget.vMagnitude!.toString();
      }
      if (widget.bMagnitude != null) {
        params['bMagnitude'] = widget.bMagnitude!.toString();
      }
      if (widget.isDoubleOrMultiple) {
        params['isDouble'] = 'true';
      }
      if (widget.distanceLightYears != null) {
        params['distance'] = widget.distanceLightYears!.toStringAsFixed(1);
      }

      final viewerWidget = await platform_impl.createViewer(
        params: params,
        onClose: () => Navigator.of(context).pop(),
      );

      if (mounted) {
        setState(() {
          _viewerWidget = viewerWidget;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to start viewer: $e';
          _isLoading = false;
        });
      }
    }
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
          else if (_isLoading || _viewerWidget == null)
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
            _viewerWidget!,

          // Fallback close button (in case viewer doesn't load)
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
