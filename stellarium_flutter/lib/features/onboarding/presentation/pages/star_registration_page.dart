import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../screens/certificate_scanner_factory.dart';
import '../../../../services/analytics_service.dart';
import '../../../../services/saved_stars_service.dart';
import '../../../../services/shop_link_service.dart';
import '../../../../widgets/star_info_sheet.dart';
import '../widgets/animated_starfield.dart';
import '../widgets/permission_page_template.dart';

/// Star registration page - allows users to enter their star registration number
class StarRegistrationPage extends StatefulWidget {
  final void Function({bool starFound}) onContinue;
  final VoidCallback onSkip;
  final void Function(StarInfo starInfo)? onStarFound;
  final int? currentPage;
  final int? totalPages;

  /// When true, the page opens directly on the registration form instead of
  /// the "Have you named a star?" question (used by the subscription paywall).
  final bool startInRegistrationMode;

  /// Where this page is shown, one of [ShopLinkPlacement]. Tags the
  /// "Name a Star" shop link and its click event.
  final String placement;

  const StarRegistrationPage({
    super.key,
    required this.onContinue,
    required this.onSkip,
    this.onStarFound,
    this.currentPage,
    this.totalPages,
    this.startInRegistrationMode = false,
    this.placement = ShopLinkPlacement.onboarding,
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
  List<SavedStar> _savedStarsWithRegistration = [];
  bool _showRegistrationForm = false;

  @override
  void initState() {
    super.initState();
    _showRegistrationForm = widget.startInRegistrationMode;
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
    _loadSavedStars();
  }

  Future<void> _loadSavedStars() async {
    await SavedStarsService.instance.load();
    setState(() {
      // Filter to only show stars with registration numbers
      _savedStarsWithRegistration = SavedStarsService.instance.savedStars
          .where((star) => star.registrationNumber != null && star.registrationNumber!.isNotEmpty)
          .toList();
      // Users who already saved a registered star are star owners - show the
      // registration form directly instead of asking.
      if (_savedStarsWithRegistration.isNotEmpty) {
        _showRegistrationForm = true;
      }
    });
  }

  void _enterRegistrationMode() {
    AnalyticsService.instance.logHaveNamedStarClicked();
    setState(() {
      _showRegistrationForm = true;
      _errorMessage = null;
    });
  }

  void _exitRegistrationMode() {
    setState(() {
      _showRegistrationForm = false;
      _errorMessage = null;
      _registrationController.clear();
    });
  }

  void _startExploring() {
    AnalyticsService.instance.logStartExploringClicked();
    widget.onSkip();
  }

  Future<void> _selectSavedStar(SavedStar star) async {
    if (star.registrationNumber == null) return;

    _registrationController.text = star.registrationNumber!;
    await _searchRegistrationNumber();
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

    // Track registration search
    AnalyticsService.instance.logRegistrationSearch(registrationNumber: query);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final starInfo = await StarRegistryService.searchByRegistrationNumber(query);

      if (starInfo != null && starInfo.found) {
        // Track successful registration find
        AnalyticsService.instance.logRegistrationFound(
          registrationNumber: query,
          starName: starInfo.shortName,
        );
        setState(() {
          _isLoading = false;
        });
        widget.onStarFound?.call(starInfo);
        // Continue directly to the sky view (skip subscription since star was found)
        widget.onContinue(starFound: true);
      } else if (starInfo != null && starInfo.removalReason != null) {
        // Track not found (removed)
        AnalyticsService.instance.logRegistrationNotFound(registrationNumber: query);
        // Star was removed from registry
        setState(() {
          _isLoading = false;
          _errorMessage = 'REMOVED:${starInfo.removalReason}';
        });
      } else {
        // Track not found
        AnalyticsService.instance.logRegistrationNotFound(registrationNumber: query);
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
    // Track name a star click
    final languageCode = ShopLinkService.currentLanguageCode();
    final uri = ShopLinkService.nameStarUri(
      languageCode: languageCode,
      placement: widget.placement,
    );
    AnalyticsService.instance.logNameStarClicked(
      placement: widget.placement,
      languageCode: languageCode,
      destination: uri,
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Failed to launch URL: $e');
    }
  }

  Future<void> _openCertificateScanner() async {
    // Track scanner opened
    AnalyticsService.instance.logScannerOpened();
    // CertificateScannerScreen is conditionally exported - uses native camera on mobile, web scanner on web
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const CertificateScannerScreen(),
      ),
    );

    if (result != null && mounted) {
      // Set the scanned registration number in the text field
      _registrationController.text = result;
      // Automatically search for the star
      _searchRegistrationNumber();
    }
  }

  String _getLocalizedError(AppLocalizations l10n) {
    if (_errorMessage == null) return '';

    // Check for REMOVED:reason format
    if (_errorMessage!.startsWith('REMOVED:')) {
      final reason = _errorMessage!.substring(8); // Remove 'REMOVED:' prefix
      return l10n.starRegRemoved(reason);
    }

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      // Pulsating icon with radial gradient background
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: SizedBox(
                          width: 120,
                          height: 120,
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              // Radial gradient background (overflows container)
                              Positioned(
                                top: (120 - 144) / 2,
                                left: (120 - 144) / 2,
                                child: Container(
                                  width: 144, // icon size (120) * 1.2
                                  height: 144,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        Colors.black.withValues(alpha: 0.95),
                                        Colors.black.withValues(alpha: 0.9),
                                        Colors.black.withValues(alpha: 0.7),
                                        Colors.black.withValues(alpha: 0.5),
                                        Colors.black.withValues(alpha: 0.3),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.3, 0.5, 0.7, 0.85, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              // Icon image
                              Image.asset(
                                'assets/icons/find_star.png',
                                width: 120,
                                height: 120,
                                fit: BoxFit.contain,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Title
                      Text(
                        _showRegistrationForm
                            ? l10n.starRegTitle
                            : l10n.starRegQuestionTitle,
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
                          _showRegistrationForm
                              ? l10n.starRegSubtitle
                              : l10n.starRegQuestionSubtitle,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Spacer pushes everything below to the bottom (works with IntrinsicHeight)
                      const Spacer(),
              // Bottom section
              if (_showRegistrationForm) ...[
                // Saved stars quick select
                if (_savedStarsWithRegistration.isNotEmpty) ...[
                  _buildSavedStarsSection(l10n),
                  const SizedBox(height: 24),
                ],
                // Registration number input
                _buildRegistrationInput(),
                // Error message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _buildErrorWidget(l10n),
                ],
              ],
              const SizedBox(height: 32),
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
              if (_showRegistrationForm) ...[
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
                const SizedBox(height: 16),
                // Scan certificate button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _openCertificateScanner,
                    icon: const Icon(Icons.qr_code_scanner, size: 20),
                    label: Text(
                      l10n.scanCertificate,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: primaryBlue.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                  ),
                ),
                // Back to the question for users who got here by mistake
                if (_savedStarsWithRegistration.isEmpty) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading ? null : _exitRegistrationMode,
                    child: Text(
                      l10n.starRegNoStarYet,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ] else ...[
                // Explore card (primary path for most users)
                _buildChoiceCard(
                  icon: Icons.explore,
                  title: l10n.starRegExploreCardTitle,
                  body: l10n.starRegExploreCardBody,
                  onTap: _startExploring,
                  highlighted: true,
                ),
                const SizedBox(height: 16),
                // Named star card
                _buildChoiceCard(
                  icon: Icons.star,
                  title: l10n.starRegHaveStarCardTitle,
                  body: l10n.starRegHaveStarCardBody,
                  onTap: _enterRegistrationMode,
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
              ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildChoiceCard({
    required IconData icon,
    required String title,
    required String body,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: highlighted
                ? primaryBlue.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              gradient: highlighted
                  ? const LinearGradient(
                      colors: [primaryBlue, Color(0xFF64B5F6)],
                    )
                  : null,
              color: highlighted ? null : Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: highlighted
                  ? null
                  : Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: highlighted ? Colors.white : primaryBlue,
                    size: 26,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          body,
                          style: TextStyle(
                            color: Colors.white
                                .withValues(alpha: highlighted ? 0.85 : 0.7),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white
                          .withValues(alpha: highlighted ? 0.25 : 0.12),
                    ),
                    child: const Icon(
                      Icons.arrow_forward,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrationInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _errorMessage != null
              ? Colors.red.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
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
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.red.shade300, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getLocalizedError(l10n),
              style: TextStyle(color: Colors.red.shade300, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedStarsSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            l10n.myStars,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _savedStarsWithRegistration.map((star) {
            return GestureDetector(
              onTap: _isLoading ? null : () => _selectSavedStar(star),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: primaryBlue.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      size: 16,
                      color: primaryBlue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      star.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

}
