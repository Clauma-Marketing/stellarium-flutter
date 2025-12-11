import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'animated_starfield.dart';

/// A feature item displayed on permission pages
class FeatureItem {
  final IconData icon;
  final String title;
  final String description;

  const FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}

/// Primary blue color used throughout onboarding
const Color primaryBlue = Color(0xFF3355FF);

/// Template widget for permission request pages during onboarding
class PermissionPageTemplate extends StatefulWidget {
  final IconData? icon;
  final String? iconImagePath;
  final String title;
  final String subtitle;
  final List<FeatureItem> features;
  final String primaryButtonText;
  final String? secondaryButtonText;
  final VoidCallback onPrimaryPressed;
  final VoidCallback? onSecondaryPressed;
  final String? privacyNotice;
  final bool isLoading;
  final Widget? customContent;
  final int starCount;
  final int? currentPage;
  final int? totalPages;

  const PermissionPageTemplate({
    super.key,
    this.icon,
    this.iconImagePath,
    required this.title,
    required this.subtitle,
    required this.features,
    required this.primaryButtonText,
    this.secondaryButtonText,
    required this.onPrimaryPressed,
    this.onSecondaryPressed,
    this.privacyNotice,
    this.isLoading = false,
    this.customContent,
    this.starCount = 50,
    this.currentPage,
    this.totalPages,
  });

  @override
  State<PermissionPageTemplate> createState() => _PermissionPageTemplateState();
}

class _PermissionPageTemplateState extends State<PermissionPageTemplate> {

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return AnimatedStarfield(
      starCount: widget.starCount,
      child: Stack(
        children: [
          // Large icon with radial fade background - center at 30% from top
          Positioned(
            top: screenHeight * 0.30 - (screenWidth * 0.7 / 2), // 30% minus half container height
            left: 0,
            right: 0,
            child: _buildIconWithBackground(screenWidth, screenHeight),
          ),
          // Content overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // Logo header
                  SvgPicture.asset(
                    locale == 'de' ? 'assets/logo_de.svg' : 'assets/star-reg_logo.svg',
                    height: 32,
                  ),
                  const Spacer(flex: 8),
                  // Title with shadow for readability
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.8),
                              blurRadius: 20,
                            ),
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 40,
                            ),
                          ],
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Subtitle with shadow for readability
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      widget.subtitle,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                            height: 1.4,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.8),
                                blurRadius: 15,
                              ),
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.6),
                                blurRadius: 30,
                              ),
                            ],
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Custom content or features
                  if (widget.customContent != null) ...[
                    const SizedBox(height: 24),
                    widget.customContent!,
                  ],
                  if (widget.features.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    ...widget.features.map((feature) => _buildFeatureItem(feature)),
                  ],
                  const Spacer(flex: 1),
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
                  // Primary button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: widget.isLoading ? null : widget.onPrimaryPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: widget.isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              widget.primaryButtonText,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),
                  // Secondary button
                  if (widget.secondaryButtonText != null && widget.onSecondaryPressed != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton(
                        onPressed: widget.onSecondaryPressed,
                        child: Text(
                          widget.secondaryButtonText!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.6),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: widget.secondaryButtonText != null ? 24 : 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconWithBackground(double screenWidth, double screenHeight) {
    // Icon size relative to screen
    final double iconSize = screenWidth * 0.55;
    // Background gradient - size of icon + 20%
    final double backgroundSize = iconSize * 1.4;
    // Container size for layout (smaller, based on icon)
    final double containerSize = screenWidth * 0.7;

    return SizedBox(
      width: screenWidth,
      height: containerSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Radial gradient background (black circle fading out) - larger than container
          Positioned(
            top: (containerSize - backgroundSize) / 2,
            left: (screenWidth - backgroundSize) / 2,
            child: Container(
              width: backgroundSize,
              height: backgroundSize,
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
          // Icon image or fallback icon - centered in container
          if (widget.iconImagePath != null)
            Image.asset(
              widget.iconImagePath!,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
            )
          else if (widget.icon != null)
            Icon(
              widget.icon,
              size: iconSize * 0.5,
              color: primaryBlue,
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(FeatureItem feature) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              feature.icon,
              color: primaryBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  feature.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
