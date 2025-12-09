import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../l10n/app_localizations.dart';

/// Screen for scanning star certificates to extract registration numbers
class CertificateScannerScreen extends StatefulWidget {
  const CertificateScannerScreen({super.key});

  @override
  State<CertificateScannerScreen> createState() => _CertificateScannerScreenState();
}

class _CertificateScannerScreenState extends State<CertificateScannerScreen> {
  CameraController? _cameraController;
  final TextRecognizer _textRecognizer = TextRecognizer();

  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _hasDetected = false;
  String? _detectedNumber;
  String? _errorMessage;

  // Detection confirmation tracking
  final Map<String, int> _detectionCounts = {};
  DateTime? _lastProcessTime;
  static const int _requiredConfirmations = 3;
  static const Duration _processingInterval = Duration(milliseconds: 300);

  // Multiple regex patterns to catch different OCR interpretations
  // Format: 4218-54467-5146661 (4-5-7 digits)
  final List<RegExp> _registrationPatterns = [
    // Standard pattern with optional separators
    RegExp(r'\d{4}[-\s.]?\d{5}[-\s.]?\d{7}'),
    // Pattern allowing O for 0 and I/l for 1
    RegExp(r'[\dOoIl]{4}[-\s.]?[\dOoIl]{5}[-\s.]?[\dOoIl]{7}'),
  ];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No camera available';
        });
        return;
      }

      // Find back camera
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
      });

      // Start continuous image processing
      _cameraController!.startImageStream(_processFrame);
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      setState(() {
        _errorMessage = 'Error initializing camera: $e';
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  void _processFrame(CameraImage image) async {
    // Skip if already processing or detected
    if (_isProcessing || _hasDetected) return;

    // Throttle frame processing to reduce load and improve accuracy
    final now = DateTime.now();
    if (_lastProcessTime != null &&
        now.difference(_lastProcessTime!) < _processingInterval) {
      return;
    }
    _lastProcessTime = now;

    _isProcessing = true;

    try {
      // Convert CameraImage to InputImage
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      // Recognize text
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // Calculate scan region in image coordinates
      final scanRegionInImage = _calculateScanRegionInImageCoords(
        Size(image.width.toDouble(), image.height.toDouble()),
      );

      // Try to find the pattern in text blocks WITHIN the scan region only
      String? foundNumber;

      for (final block in recognizedText.blocks) {
        // Check if block is within scan region
        if (!_isWithinScanRegion(block.boundingBox, scanRegionInImage)) {
          continue;
        }

        for (final line in block.lines) {
          // Also check line bounding box
          if (!_isWithinScanRegion(line.boundingBox, scanRegionInImage)) {
            continue;
          }

          final lineText = line.text;
          foundNumber = _findRegistrationNumber(lineText);
          if (foundNumber != null) break;
        }
        if (foundNumber != null) break;
      }

      // If not found in individual lines, try combining text from blocks within region
      if (foundNumber == null) {
        final textsInRegion = <String>[];

        for (final block in recognizedText.blocks) {
          if (_isWithinScanRegion(block.boundingBox, scanRegionInImage)) {
            textsInRegion.add(block.text);
          }
        }

        if (textsInRegion.isNotEmpty) {
          final combinedText = textsInRegion.join(' ').replaceAll('\n', ' ');
          foundNumber = _findRegistrationNumber(combinedText);
        }
      }

      if (foundNumber != null && mounted) {
        final normalizedNumber = _normalizeRegistrationNumber(foundNumber);

        // Increment detection count for this number
        _detectionCounts[normalizedNumber] = (_detectionCounts[normalizedNumber] ?? 0) + 1;

        // Check if we have enough confirmations
        if (_detectionCounts[normalizedNumber]! >= _requiredConfirmations) {
          // Confirmed detection!
          setState(() {
            _hasDetected = true;
            _detectedNumber = normalizedNumber;
          });

          // Stop the camera stream
          await _cameraController?.stopImageStream();

          // Vibrate feedback
          HapticFeedback.mediumImpact();

          // Wait 3 seconds so user can see the result
          await Future.delayed(const Duration(seconds: 3));
          if (mounted) {
            Navigator.of(context).pop(normalizedNumber);
          }
        }
      }
    } catch (e) {
      // Silently ignore processing errors
      debugPrint('Frame processing error: $e');
    }

    _isProcessing = false;
  }

  /// Find registration number in text using multiple patterns
  String? _findRegistrationNumber(String text) {
    for (final pattern in _registrationPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(0);
      }
    }
    return null;
  }

  /// Calculate the scan region in image coordinates
  /// The scan overlay is 85% of screen width, centered, slightly above center
  Rect _calculateScanRegionInImageCoords(Size imageSize) {
    // The image is rotated 90° from camera sensor
    // The scan box on screen is ~85% width square, centered

    final imageWidth = imageSize.width;
    final imageHeight = imageSize.height;

    // Use center 65% of the image to closely match the scan box overlay
    // This excludes the edges where random numbers might appear
    const margin = 0.175; // 17.5% margin on each side = 65% center
    return Rect.fromLTRB(
      imageWidth * margin,
      imageHeight * margin,
      imageWidth * (1 - margin),
      imageHeight * (1 - margin),
    );
  }

  /// Check if a bounding box is within or overlaps the scan region
  bool _isWithinScanRegion(Rect boundingBox, Rect scanRegion) {
    // Check if the bounding box overlaps with the scan region
    // We use overlaps instead of contains to be more lenient
    return scanRegion.overlaps(boundingBox);
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final camera = _cameraController!.description;
      final rotation = _getInputImageRotation(camera.sensorOrientation);
      if (rotation == null) return null;

      final format = Platform.isIOS
          ? InputImageFormat.bgra8888
          : InputImageFormat.nv21;

      final plane = image.planes.first;

      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (e) {
      debugPrint('Error converting image: $e');
      return null;
    }
  }

  InputImageRotation? _getInputImageRotation(int sensorOrientation) {
    switch (sensorOrientation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return null;
    }
  }

  String _normalizeRegistrationNumber(String number) {
    // First, fix common OCR mistakes: O->0, I/l->1
    var corrected = number
        .replaceAll('O', '0')
        .replaceAll('o', '0')
        .replaceAll('I', '1')
        .replaceAll('l', '1');

    // Remove separators
    final digitsOnly = corrected.replaceAll(RegExp(r'[-\s.]'), '');

    // Format as XXXX-XXXXX-XXXXXXX if we have 16 digits
    if (digitsOnly.length == 16) {
      return '${digitsOnly.substring(0, 4)}-${digitsOnly.substring(4, 9)}-${digitsOnly.substring(9)}';
    }

    // If not exactly 16 digits, return with original separators replaced
    return corrected.replaceAll(RegExp(r'[\s.]'), '-');
  }

  void _onTapToFocus(TapDownDetails details) async {
    if (_cameraController == null || !_isInitialized) return;

    try {
      final size = MediaQuery.of(context).size;
      final x = details.localPosition.dx / size.width;
      final y = details.localPosition.dy / size.height;

      await _cameraController!.setFocusPoint(Offset(x, y));
      await _cameraController!.setExposurePoint(Offset(x, y));
    } catch (e) {
      // Ignore focus errors - not all devices support tap-to-focus
      debugPrint('Focus error: $e');
    }
  }

  void _showManualEntryDialog() {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.enterRegistrationNumber,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.text,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: l10n.registrationNumberHint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              final number = controller.text.trim();
              if (number.isNotEmpty) {
                Navigator.of(context).pop();
                Navigator.of(context).pop(number);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.search),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.scanCertificate, style: const TextStyle(color: Colors.white)),
        actions: [
          if (_cameraController != null && _isInitialized)
            IconButton(
              icon: Icon(
                _cameraController!.value.flashMode == FlashMode.torch
                    ? Icons.flash_on
                    : Icons.flash_off,
                color: Colors.white,
              ),
              onPressed: () {
                final newMode = _cameraController!.value.flashMode == FlashMode.torch
                    ? FlashMode.off
                    : FlashMode.torch;
                _cameraController!.setFlashMode(newMode);
                setState(() {});
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          // Camera preview with tap-to-focus
          if (_isInitialized && _cameraController != null)
            Positioned.fill(
              child: GestureDetector(
                onTapDown: (details) => _onTapToFocus(details),
                child: CameraPreview(_cameraController!),
              ),
            )
          else if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Scan overlay
          if (_isInitialized) _buildScanOverlay(),

          // Detection indicator - prominent overlay when number is found
          if (_hasDetected && _detectedNumber != null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Success icon with animation
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.5),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // "Number Found" label
                      Text(
                        AppLocalizations.of(context)!.registrationNumberFound,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // The detected number - prominent display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: Text(
                          _detectedNumber!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Loading indicator showing it will proceed
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            AppLocalizations.of(context)!.searchStar,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                24 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.9),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.pointCameraAtCertificate,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.registrationNumberWillBeDetected,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: _showManualEntryDialog,
                    icon: const Icon(Icons.edit, size: 18),
                    label: Text(l10n.enterManually),
                    style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth * 0.85;
        final left = (constraints.maxWidth - size) / 2;
        final top = (constraints.maxHeight - size) / 2 - 60;

        return Stack(
          children: [
            // Darkened areas
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.5),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Positioned(
                    left: left,
                    top: top,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Border
            Positioned(
              left: left,
              top: top,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _hasDetected ? Colors.green : Colors.white,
                    width: _hasDetected ? 4 : 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    _buildCorner(Alignment.topLeft),
                    _buildCorner(Alignment.topRight),
                    _buildCorner(Alignment.bottomLeft),
                    _buildCorner(Alignment.bottomRight),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCorner(Alignment alignment) {
    final color = _hasDetected ? Colors.green : Colors.white;
    const size = 28.0;
    const thickness = 4.0;

    return Positioned(
      left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft ? 0 : null,
      right: alignment == Alignment.topRight || alignment == Alignment.bottomRight ? 0 : null,
      top: alignment == Alignment.topLeft || alignment == Alignment.topRight ? 0 : null,
      bottom: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight ? 0 : null,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _CornerPainter(color: color, thickness: thickness, alignment: alignment),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final Alignment alignment;

  _CornerPainter({required this.color, required this.thickness, required this.alignment});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    if (alignment == Alignment.topLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (alignment == Alignment.topRight) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (alignment == Alignment.bottomLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else if (alignment == Alignment.bottomRight) {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
