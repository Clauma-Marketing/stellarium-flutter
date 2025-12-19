import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/analytics_service.dart';
import '../../../services/engagement_tracking_service.dart';
import '../../../widgets/star_info_sheet.dart';
import '../../onboarding/onboarding_service.dart';
import '../../onboarding/presentation/pages/star_registration_page.dart';

/// Screen shown when user has exceeded free usage time.
/// Shows paywall first, then star registration page if dismissed.
/// User can either subscribe OR enter a valid registration number to continue.
class SubscriptionRequiredScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SubscriptionRequiredScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<SubscriptionRequiredScreen> createState() => _SubscriptionRequiredScreenState();
}

class _SubscriptionRequiredScreenState extends State<SubscriptionRequiredScreen>
    implements AdaptyUIPaywallsEventsObserver {
  bool _isLoadingPaywall = true;
  bool _paywallDismissed = false;

  @override
  void initState() {
    super.initState();
    AdaptyUI().setPaywallsEventsObserver(this);
    _loadAndShowPaywall();
  }

  Future<void> _loadAndShowPaywall() async {
    try {
      final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      final paywall = await Adapty().getPaywall(
        placementId: 'non_skippable_paywall',
        locale: deviceLocale,
      );

      if (!paywall.hasViewConfiguration) {
        debugPrint('SubscriptionRequired: Paywall does not have view configuration');
        setState(() {
          _isLoadingPaywall = false;
          _paywallDismissed = true;
        });
        return;
      }

      setState(() {
        _isLoadingPaywall = false;
      });

      final view = await AdaptyUI().createPaywallView(paywall: paywall);
      await view.present();
    } on AdaptyError catch (e) {
      debugPrint('SubscriptionRequired: Adapty error: ${e.message}');
      setState(() {
        _isLoadingPaywall = false;
        _paywallDismissed = true;
      });
    } catch (e) {
      debugPrint('SubscriptionRequired: Error loading paywall: $e');
      setState(() {
        _isLoadingPaywall = false;
        _paywallDismissed = true;
      });
    }
  }

  Future<void> _showPaywallAgain() async {
    setState(() {
      _isLoadingPaywall = true;
    });
    await _loadAndShowPaywall();
  }

  void _onSubscriptionSuccess() {
    // Mark paywall as handled so it doesn't show again
    EngagementTrackingService.instance.markPaywallHandled();
    AnalyticsService.instance.logSubscriptionStart();
    widget.onComplete();
  }

  void _onStarFound(StarInfo starInfo) {
    // User found a valid star - mark paywall as handled
    EngagementTrackingService.instance.markPaywallHandled();
    // Save the star so HomeScreen can select it after navigation
    OnboardingService.saveFoundStar(starInfo);
    widget.onComplete();
  }

  void _onStarRegistrationContinue({bool starFound = false}) {
    // Note: When starFound is true, _onStarFound has already been called
    // and handled the completion, so we don't need to do anything here.
    // If no star found, user stays on this screen.
  }

  void _onStarRegistrationSkip() {
    // User tried to skip - show paywall again
    _showPaywallAgain();
  }

  Future<void> _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  // AdaptyUIPaywallsEventsObserver implementation

  @override
  void paywallViewDidPerformAction(
      AdaptyUIPaywallView view, AdaptyUIAction action) {
    switch (action) {
      case CloseAction():
      case AndroidSystemBackAction():
        AnalyticsService.instance.logEvent(name: 'subscription_required_paywall_dismissed');
        view.dismiss();
        setState(() {
          _paywallDismissed = true;
        });
        break;
      case OpenUrlAction(url: final url):
        _launchUrl(url);
        break;
      default:
        break;
    }
  }

  @override
  void paywallViewDidFinishPurchase(
    AdaptyUIPaywallView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) {
    switch (purchaseResult) {
      case AdaptyPurchaseResultSuccess():
        debugPrint('SubscriptionRequired: Purchase successful');
        view.dismiss();
        _onSubscriptionSuccess();
        break;
      case AdaptyPurchaseResultPending():
        debugPrint('SubscriptionRequired: Purchase pending');
        // Don't dismiss - let user wait or retry
        break;
      case AdaptyPurchaseResultUserCancelled():
        debugPrint('SubscriptionRequired: Purchase cancelled by user');
        // Don't dismiss - user stays on paywall
        break;
      default:
        debugPrint('SubscriptionRequired: Unknown purchase result');
        break;
    }
  }

  @override
  void paywallViewDidFailPurchase(
    AdaptyUIPaywallView view,
    AdaptyPaywallProduct product,
    AdaptyError error,
  ) {
    debugPrint('SubscriptionRequired: Purchase failed: ${error.message}');
  }

  @override
  void paywallViewDidFinishRestore(
    AdaptyUIPaywallView view,
    AdaptyProfile profile,
  ) {
    debugPrint('SubscriptionRequired: Restore completed');
    view.dismiss();
    _onSubscriptionSuccess();
  }

  @override
  void paywallViewDidFailRestore(
    AdaptyUIPaywallView view,
    AdaptyError error,
  ) {
    debugPrint('SubscriptionRequired: Restore failed: ${error.message}');
  }

  @override
  void paywallViewDidFailRendering(
    AdaptyUIPaywallView view,
    AdaptyError error,
  ) {
    debugPrint('SubscriptionRequired: Rendering failed: ${error.message}');
    view.dismiss();
    setState(() {
      _paywallDismissed = true;
    });
  }

  @override
  void paywallViewDidFailLoadingProducts(
    AdaptyUIPaywallView view,
    AdaptyError error,
  ) {
    debugPrint('SubscriptionRequired: Failed to load products: ${error.message}');
  }

  @override
  void paywallViewDidSelectProduct(
    AdaptyUIPaywallView view,
    String productId,
  ) {
    debugPrint('SubscriptionRequired: Product selected: $productId');
  }

  @override
  void paywallViewDidStartPurchase(
    AdaptyUIPaywallView view,
    AdaptyPaywallProduct product,
  ) {
    debugPrint('SubscriptionRequired: Purchase started: ${product.vendorProductId}');
  }

  @override
  void paywallViewDidStartRestore(AdaptyUIPaywallView view) {
    debugPrint('SubscriptionRequired: Restore started');
  }

  @override
  void paywallViewDidAppear(AdaptyUIPaywallView view) {
    debugPrint('SubscriptionRequired: Paywall appeared');
  }

  @override
  void paywallViewDidDisappear(AdaptyUIPaywallView view) {
    debugPrint('SubscriptionRequired: Paywall disappeared');
  }

  @override
  void paywallViewDidFinishWebPaymentNavigation(
    AdaptyUIPaywallView view,
    AdaptyPaywallProduct? product,
    AdaptyError? error,
  ) {
    debugPrint('SubscriptionRequired: Web payment navigation finished');
    if (error == null && product != null) {
      view.dismiss();
      _onSubscriptionSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Show loading while paywall is being presented
    if (_isLoadingPaywall) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF33B4E8),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.subscriptionLoading,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show star registration page after paywall is dismissed
    if (_paywallDismissed) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            // Message banner at the top
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                bottom: 16,
                left: 24,
                right: 24,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.amber.shade900.withValues(alpha: 0.9),
                    Colors.amber.shade900.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.amber.shade200,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.subscriptionRequiredMessage,
                          style: TextStyle(
                            color: Colors.amber.shade100,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Subscribe button in banner
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showPaywallAgain,
                      icon: const Icon(Icons.star, size: 18),
                      label: Text(l10n.subscriptionSubscribeButton),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Star registration page (now scrollable, so no overflow)
            Expanded(
              child: StarRegistrationPage(
                onContinue: _onStarRegistrationContinue,
                onSkip: _onStarRegistrationSkip,
                onStarFound: _onStarFound,
              ),
            ),
          ],
        ),
      );
    }

    // Fallback (shouldn't reach here normally)
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF33B4E8),
        ),
      ),
    );
  }
}
