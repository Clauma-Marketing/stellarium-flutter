import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/analytics_service.dart';
import '../../onboarding/onboarding_service.dart';

/// Screen that displays the Adapty paywall after onboarding
class SubscriptionScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SubscriptionScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    implements AdaptyUIPaywallsEventsObserver {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    AdaptyUI().setPaywallsEventsObserver(this);
    // Track subscription screen view
    AnalyticsService.instance.logSubscriptionScreenView();
    _loadAndShowPaywall();
  }

  Future<void> _loadAndShowPaywall() async {
    try {
      // Get the paywall for the night_sky_view placement
      // Use device locale for paywall localization
      final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      final paywall = await Adapty().getPaywall(
        placementId: 'night_sky_view',
        locale: deviceLocale,
      );

      // Check if it has a view configuration (created in Paywall Builder)
      if (!paywall.hasViewConfiguration) {
        debugPrint('Paywall does not have view configuration');
        _completeAndContinue();
        return;
      }

      // Create the paywall view
      final view = await AdaptyUI().createPaywallView(paywall: paywall);

      setState(() {
        _isLoading = false;
      });

      // Present the paywall
      await view.present();
    } on AdaptyError catch (e) {
      debugPrint('Adapty error: ${e.message}');
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
      // If there's an error, allow user to continue after a delay
      Future.delayed(const Duration(seconds: 2), _completeAndContinue);
    } catch (e) {
      debugPrint('Error loading paywall: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load subscription options';
      });
      // If there's an error, allow user to continue after a delay
      Future.delayed(const Duration(seconds: 2), _completeAndContinue);
    }
  }

  Future<void> _completeAndContinue() async {
    // Mark subscription screen as shown so it won't appear again
    await OnboardingService.markSubscriptionShown();
    widget.onComplete();
  }

  Future<void> _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch $url');
      }
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
        // Track paywall dismissal
        AnalyticsService.instance.logEvent(name: 'subscription_dismissed');
        view.dismiss();
        _completeAndContinue();
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
    debugPrint('Purchase completed');
    // Track successful subscription
    AnalyticsService.instance.logSubscriptionStart(productId: product.vendorProductId);
    view.dismiss();
    _completeAndContinue();
  }

  @override
  void paywallViewDidFailPurchase(
    AdaptyUIPaywallView view,
    AdaptyPaywallProduct product,
    AdaptyError error,
  ) {
    debugPrint('Purchase failed: ${error.message}');
    // Don't close - let user try again or close manually
  }

  @override
  void paywallViewDidFinishRestore(
    AdaptyUIPaywallView view,
    AdaptyProfile profile,
  ) {
    debugPrint('Restore completed');
    view.dismiss();
    _completeAndContinue();
  }

  @override
  void paywallViewDidFailRestore(
    AdaptyUIPaywallView view,
    AdaptyError error,
  ) {
    debugPrint('Restore failed: ${error.message}');
    // Don't close - let user try again or close manually
  }

  @override
  void paywallViewDidFailRendering(
    AdaptyUIPaywallView view,
    AdaptyError error,
  ) {
    debugPrint('Paywall rendering failed: ${error.message}');
    view.dismiss();
    _completeAndContinue();
  }

  @override
  void paywallViewDidFailLoadingProducts(
    AdaptyUIPaywallView view,
    AdaptyError error,
  ) {
    debugPrint('Failed to load products: ${error.message}');
    // Don't close - paywall might still be usable
  }

  @override
  void paywallViewDidSelectProduct(
    AdaptyUIPaywallView view,
    String productId,
  ) {
    debugPrint('Product selected: $productId');
  }

  @override
  void paywallViewDidStartPurchase(
    AdaptyUIPaywallView view,
    AdaptyPaywallProduct product,
  ) {
    debugPrint('Purchase started: ${product.vendorProductId}');
  }

  @override
  void paywallViewDidStartRestore(AdaptyUIPaywallView view) {
    debugPrint('Restore started');
  }

  @override
  void paywallViewDidAppear(AdaptyUIPaywallView view) {
    debugPrint('Paywall appeared');
  }

  @override
  void paywallViewDidDisappear(AdaptyUIPaywallView view) {
    debugPrint('Paywall disappeared');
  }

  @override
  void paywallViewDidFinishWebPaymentNavigation(
    AdaptyUIPaywallView view,
    AdaptyPaywallProduct? product,
    AdaptyError? error,
  ) {
    debugPrint('Web payment navigation finished');
    if (error == null && product != null) {
      view.dismiss();
      _completeAndContinue();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _isLoading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF33B4E8),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Loading subscription options...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              )
            : _errorMessage != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.white54,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: _completeAndContinue,
                        child: const Text(
                          'Continue to App',
                          style: TextStyle(
                            color: Color(0xFF33B4E8),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
      ),
    );
  }
}
