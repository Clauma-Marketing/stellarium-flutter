// Web-specific implementation of certificate scanner using Tesseract.js
// This file is only imported when building for web.

import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../l10n/app_localizations.dart';
import '../services/analytics_service.dart';

/// Check if Tesseract is loaded on window
@JS('window.Tesseract')
external JSObject? get _tesseractGlobal;

bool _checkTesseract() => _tesseractGlobal != null;

/// JS interop for Tesseract.js
@JS('Tesseract')
extension type TesseractJS._(JSObject _) implements JSObject {
  external static JSPromise<TesseractWorker> createWorker(String lang);
}

@JS()
extension type TesseractWorker._(JSObject _) implements JSObject {
  external JSPromise<RecognizeResult> recognize(JSAny image);
  external JSPromise<JSAny> terminate();
}

@JS()
extension type RecognizeResult._(JSObject _) implements JSObject {
  external RecognizeData get data;
}

@JS()
extension type RecognizeData._(JSObject _) implements JSObject {
  external String get text;
}

/// Web-specific screen for scanning star certificates using browser camera/file input
/// Named CertificateScannerScreen to match the mobile version for conditional exports.
class CertificateScannerScreen extends StatefulWidget {
  const CertificateScannerScreen({super.key});

  @override
  State<CertificateScannerScreen> createState() =>
      _CertificateScannerScreenState();
}

class _CertificateScannerScreenState
    extends State<CertificateScannerScreen> {
  bool _isProcessing = false;
  bool _hasDetected = false;
  String? _detectedNumber;
  String? _errorMessage;
  String? _selectedImageUrl;

  // Multiple regex patterns to catch different OCR interpretations
  // Format: 4218-54467-5146661 (4-5-7 digits)
  final List<RegExp> _registrationPatterns = [
    // Standard pattern with optional separators
    RegExp(r'\d{4}[-\s.]?\d{5}[-\s.]?\d{7}'),
    // Pattern allowing O for 0 and I/l for 1
    RegExp(r'[\dOoIl]{4}[-\s.]?[\dOoIl]{5}[-\s.]?[\dOoIl]{7}'),
  ];

  // Unique ID for the file input element
  final String _fileInputId = 'certificate-file-input-${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _setupFileInput();
    _loadTesseract();
  }

  void _setupFileInput() {
    // Register a platform view factory for the file input
    ui_web.platformViewRegistry.registerViewFactory(
      _fileInputId,
      (int viewId) {
        final input = web.document.createElement('input') as web.HTMLInputElement;
        input.type = 'file';
        input.accept = 'image/*';
        input.setAttribute('capture', 'environment'); // Use back camera on mobile
        input.style.display = 'none';
        input.id = _fileInputId;

        input.addEventListener(
          'change',
          ((web.Event event) {
            final files = input.files;
            if (files != null && files.length > 0) {
              final file = files.item(0);
              if (file != null) {
                _processSelectedFile(file);
              }
            }
          }).toJS,
        );

        return input;
      },
    );
  }

  Future<void> _loadTesseract() async {
    // Check if Tesseract is already loaded
    final tesseractLoaded = _isTesseractLoaded();
    if (!tesseractLoaded) {
      // Load Tesseract.js from CDN
      final script = web.document.createElement('script') as web.HTMLScriptElement;
      script.src = 'https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js';
      script.async = true;
      web.document.head?.appendChild(script);
    }
  }

  bool _isTesseractLoaded() {
    try {
      return _checkTesseract();
    } catch (_) {
      return false;
    }
  }

  void _triggerFileInput() {
    final input = web.document.getElementById(_fileInputId) as web.HTMLInputElement?;
    input?.click();
  }

  Future<void> _processSelectedFile(web.File file) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _hasDetected = false;
      _detectedNumber = null;
    });

    try {
      // Create object URL for preview
      final objectUrl = web.URL.createObjectURL(file);
      setState(() {
        _selectedImageUrl = objectUrl;
      });

      // Wait for Tesseract to be loaded
      int attempts = 0;
      while (!_isTesseractLoaded() && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      if (!_isTesseractLoaded()) {
        throw Exception('OCR engine failed to load');
      }

      // Process image with Tesseract
      final worker = await TesseractJS.createWorker('eng').toDart;

      try {
        final result = await worker.recognize(file as JSAny).toDart;
        final text = result.data.text;

        debugPrint('OCR Result: $text');

        // Find registration number in the text
        final foundNumber = _findRegistrationNumber(text);

        if (foundNumber != null && mounted) {
          final normalizedNumber = _normalizeRegistrationNumber(foundNumber);
          AnalyticsService.instance.logScannerDetected(registrationNumber: normalizedNumber);

          setState(() {
            _hasDetected = true;
            _detectedNumber = normalizedNumber;
            _isProcessing = false;
          });
        } else {
          setState(() {
            _errorMessage = 'noRegistrationNumberFound';
            _isProcessing = false;
          });
        }
      } finally {
        await worker.terminate().toDart;
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'processingError';
          _isProcessing = false;
        });
      }
    }
  }

  String? _findRegistrationNumber(String text) {
    for (final pattern in _registrationPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(0);
      }
    }
    return null;
  }

  String _normalizeRegistrationNumber(String number) {
    // Fix common OCR mistakes: O->0, I/l->1
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

  void _confirmAndReturn() {
    if (_detectedNumber != null) {
      Navigator.of(context).pop(_detectedNumber);
    }
  }

  void _resetScanner() {
    setState(() {
      _hasDetected = false;
      _detectedNumber = null;
      _errorMessage = null;
      _selectedImageUrl = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFF0a1628),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            AnalyticsService.instance.logScannerCancelled();
            Navigator.of(context).pop();
          },
        ),
        title: Text(l10n.scanCertificate, style: const TextStyle(color: Colors.white)),
      ),
      body: Stack(
        children: [
          // Hidden file input (needed for platform view to work)
          Positioned(
            left: -1000,
            top: -1000,
            child: SizedBox(
              width: 1,
              height: 1,
              child: HtmlElementView(viewType: _fileInputId),
            ),
          ),

          // Main content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Image preview or placeholder
                  Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _hasDetected
                            ? Colors.green
                            : Colors.white.withValues(alpha: 0.3),
                        width: _hasDetected ? 3 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: _selectedImageUrl != null
                          ? Image.network(
                              _selectedImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Status / Result
                  if (_isProcessing) ...[
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      l10n.scanningCertificate,
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ] else if (_hasDetected && _detectedNumber != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            l10n.registrationNumberFound,
                            style: const TextStyle(color: Colors.green, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _detectedNumber!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _resetScanner,
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.scanAgain),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white30),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _confirmAndReturn,
                          icon: const Icon(Icons.search),
                          label: Text(l10n.searchStar),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ] else if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage == 'noRegistrationNumberFound'
                                ? l10n.noRegistrationNumberFound
                                : 'Error processing image. Please try again.',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _triggerFileInput,
                      icon: const Icon(Icons.camera_alt),
                      label: Text(l10n.scanAgain),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF33B4E8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                  ] else ...[
                    // Initial state - show capture button
                    Text(
                      l10n.pointCameraAtCertificate,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.registrationNumberWillBeDetected,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _triggerFileInput,
                      icon: const Icon(Icons.camera_alt, size: 28),
                      label: const Text('Take Photo', style: TextStyle(fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF33B4E8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Manual entry option
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

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.document_scanner,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Tap to capture certificate',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
