import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../widgets/star_info_sheet.dart';
import '../widgets/animated_starfield.dart';
import '../widgets/permission_page_template.dart';

/// Star registration page - allows users to enter their star registration number
class StarRegistrationPage extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final void Function(StarInfo starInfo)? onStarFound;
  final int? currentPage;
  final int? totalPages;

  const StarRegistrationPage({
    super.key,
    required this.onContinue,
    required this.onSkip,
    this.onStarFound,
    this.currentPage,
    this.totalPages,
  });

  @override
  State<StarRegistrationPage> createState() => _StarRegistrationPageState();
}

class _StarRegistrationPageState extends State<StarRegistrationPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _registrationController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _registrationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _searchRegistrationNumber() async {
    final query = _registrationController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _errorMessage = 'ENTER_NUMBER';
      });
      return;
    }

    if (!StarRegistryService.isRegistrationNumber(query)) {
      setState(() {
        _errorMessage = 'INVALID_FORMAT';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final starInfo = await StarRegistryService.searchByRegistrationNumber(query);

      if (starInfo != null && starInfo.found) {
        setState(() {
          _isLoading = false;
        });
        widget.onStarFound?.call(starInfo);
        // Continue directly to the sky view
        widget.onContinue();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'NOT_FOUND';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'SEARCH_FAILED';
      });
    }
  }

  void _onInputChanged(String value) {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  Future<void> _openNameStarWebsite() async {
    final uri = Uri.parse('https://www.star-register.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _getLocalizedError(AppLocalizations l10n) {
    switch (_errorMessage) {
      case 'ENTER_NUMBER':
        return l10n.starRegEnterNumber;
      case 'INVALID_FORMAT':
        return l10n.starRegInvalidFormat;
      case 'NOT_FOUND':
        return l10n.starRegNotFound;
      case 'SEARCH_FAILED':
        return l10n.starRegSearchFailed;
      default:
        return _errorMessage ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedStarfield(
      starCount: 60,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Pulsating icon badge
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryBlue,
                        primaryBlue.withValues(alpha: 0.7),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue.withValues(alpha: 0.5),
                        blurRadius: 25,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.star,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Title
              Text(
                l10n.starRegTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  l10n.starRegSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              // Registration number input
              _buildRegistrationInput(),
              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                _buildErrorWidget(l10n),
              ],
              const Spacer(),
              // Page indicator
              if (widget.currentPage != null && widget.totalPages != null) ...[
                Row(
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
                const SizedBox(height: 24),
              ],
              // Search button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _searchRegistrationNumber,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: primaryBlue.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [primaryBlue, Color(0xFF64B5F6)],
                      ),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              l10n.starRegFindButton,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Divider with text
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      l10n.starRegNoStarYet,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white54,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Skip for now button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: widget.onSkip,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Text(
                    l10n.onboardingSkipForNow,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Name a star link
              TextButton.icon(
                onPressed: _openNameStarWebsite,
                icon: Icon(
                  Icons.star_outline,
                  size: 18,
                  color: primaryBlue,
                ),
                label: Text(
                  l10n.starRegNameAStar,
                  style: TextStyle(
                    color: primaryBlue,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrationInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _errorMessage != null
              ? Colors.red.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: _registrationController,
        focusNode: _focusNode,
        onChanged: _onInputChanged,
        onSubmitted: (_) => _searchRegistrationNumber(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontFamily: 'monospace',
          letterSpacing: 2,
        ),
        textAlign: TextAlign.center,
        keyboardType: TextInputType.text,
        textCapitalization: TextCapitalization.none,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
          _RegistrationNumberFormatter(),
        ],
        decoration: InputDecoration(
          hintText: 'XXXX-XXXXX-XXXXXXXX',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 18,
            fontFamily: 'monospace',
            letterSpacing: 2,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getLocalizedError(l10n),
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

}

/// Input formatter for registration numbers (auto-inserts hyphens)
class _RegistrationNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove all non-digits
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Build formatted string with hyphens
    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length && i < 17; i++) {
      if (i == 4 || i == 9) {
        buffer.write('-');
      }
      buffer.write(digitsOnly[i]);
    }

    final formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
