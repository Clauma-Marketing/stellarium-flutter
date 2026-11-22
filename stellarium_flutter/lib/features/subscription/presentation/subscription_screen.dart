import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/analytics_service.dart';
import '../../../services/locale_service.dart';
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
    implements AdaptyUIFlowsEventsObserver {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    AdaptyUI().setFlowsEventsObserver(this);
    // Track subscription screen view
    AnalyticsService.instance.logSubscriptionScreenView();
    AnalyticsService.instance.logPaywallViewed(placement: 'onboarding');
    _loadAndShowPaywall();
  }

  Future<void> _loadAndShowPaywall() async {
    try {
      // Get the flow for the night_sky_view placement
      final flow = await Adapty().getFlow(placementId: 'night_sky_view');

      // Check if it has a view configuration (created in Flow Builder)
      if (!flow.hasViewConfiguration) {
        debugPrint('Flow does not have view configuration');
        _completeAndContinue();
        return;
      }

      // Create the flow view in the app language
      final view = await AdaptyUI().createFlowView(
        flow: flow,
        locale: LocaleService.instance.adaptyLocale,
      );

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

  void _completeAndContinue() {
    // Just continue without marking as shown - paywall will show again next launch
    widget.onComplete();
  }

  Future<void> _completeWithSubscription() async {
    // Mark subscription as shown only when user actually subscribes/restores
    await OnboardingService.markSubscriptionShown();
    widget.onComplete();
  }

  Future<void> _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  // AdaptyUIFlowsEventsObserver implementation

  @override
  void flowViewDidPerformAction(
      AdaptyUIFlowView view, AdaptyUIAction action) {
    switch (action) {
      case CloseAction():
      case AndroidSystemBackAction():
        AnalyticsService.instance.logSubscriptionDismissed();
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
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) {
    switch (purchaseResult) {
      case AdaptyPurchaseResultSuccess():
        debugPrint('Purchase successful');
        AnalyticsService.instance.logSubscriptionStart(
          productId: product.vendorProductId,
          placement: 'onboarding',
        );
        view.dismiss();
        _completeWithSubscription();
        break;
      case AdaptyPurchaseResultPending():
        debugPrint('Purchase pending');
        break;
      case AdaptyPurchaseResultUserCancelled():
        debugPrint('Purchase cancelled by user');
        AnalyticsService.instance.logPurchaseCancelled(
          productId: product.vendorProductId,
          placement: 'onboarding',
        );
        break;
      default:
        break;
    }
  }

  @override
  void flowViewDidFailPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyError error,
  ) {
    debugPrint('Purchase failed: ${error.message}');
    AnalyticsService.instance.logPurchaseFailed(
      productId: product.vendorProductId,
      placement: 'onboarding',
      errorCode: error.code,
      errorMessage: error.message,
    );
    // Don't close - let user try again or close manually
  }

  @override
  void flowViewDidFinishRestore(
    AdaptyUIFlowView view,
    AdaptyProfile profile,
  ) {
    final hasAccess = profile.accessLevels.values.any((level) => level.isActive);
    if (hasAccess) {
      debugPrint('Restore completed with active subscription');
      AnalyticsService.instance.logSubscriptionRestored(placement: 'onboarding');
      view.dismiss();
      _completeWithSubscription();
    } else {
      debugPrint('Restore completed but no active subscription found');
    }
  }

  @override
  void flowViewDidFailRestore(
    AdaptyUIFlowView view,
    AdaptyError error,
  ) {
    debugPrint('Restore failed: ${error.message}');
    // Don't close - let user try again or close manually
  }

  @override
  void flowViewDidReceiveError(
    AdaptyUIFlowView view,
    AdaptyError error,
  ) {
    debugPrint('Paywall rendering failed: ${error.message}');
    view.dismiss();
    _completeAndContinue();
  }

  @override
  void flowViewDidFailLoadingProducts(
    AdaptyUIFlowView view,
    AdaptyError error,
  ) {
    debugPrint('Failed to load products: ${error.message}');
    // Don't close - paywall might still be usable
  }

  @override
  void flowViewDidSelectProduct(
    AdaptyUIFlowView view,
    String productId,
  ) {
    debugPrint('Product selected: $productId');
    AnalyticsService.instance.logPaywallProductSelected(
      productId: productId,
      placement: 'onboarding',
    );
  }

  @override
  void flowViewDidStartPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
  ) {
    debugPrint('Purchase started: ${product.vendorProductId}');
    AnalyticsService.instance.logPurchaseStarted(
      productId: product.vendorProductId,
      placement: 'onboarding',
    );
  }

  @override
  void flowViewDidStartRestore(AdaptyUIFlowView view) {
    debugPrint('Restore started');
  }

  @override
  void flowViewDidAppear(AdaptyUIFlowView view) {
    debugPrint('Paywall appeared');
  }

  @override
  void flowViewDidDisappear(AdaptyUIFlowView view) {
    debugPrint('Paywall disappeared');
  }

  @override
  void flowViewDidReceiveAnalyticEvent(
    AdaptyUIFlowView view,
    String name,
    Map<String, dynamic> params,
  ) {
    debugPrint('Flow analytic event: $name');
  }

  @override
  void flowViewDidFinishWebPaymentNavigation(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct? product,
    AdaptyError? error,
  ) {
    debugPrint('Web payment navigation finished');
    if (error == null && product != null) {
      view.dismiss();
      _completeWithSubscription();
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
