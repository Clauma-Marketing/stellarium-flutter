import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../widgets/permission_page_template.dart';

/// Welcome page - first screen of the onboarding flow
class WelcomePage extends StatelessWidget {
  final VoidCallback onGetStarted;
  final int? currentPage;
  final int? totalPages;

  const WelcomePage({
    super.key,
    required this.onGetStarted,
    this.currentPage,
    this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PermissionPageTemplate(
      iconImagePath: 'assets/icons/welcome.png',
      title: l10n.welcomeTitle,
      subtitle: l10n.onboardingExploreUniverse,
      features: const [],
      primaryButtonText: l10n.onboardingGetStarted,
      onPrimaryPressed: onGetStarted,
      currentPage: currentPage,
      totalPages: totalPages,
    );
  }
}
