import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';

/// Which onboarding-to-paywall flow the user is in.
enum PaywallFlow {
  /// Show the skippable paywall right after the star-registration step (default)
  immediate,

  /// Skip the post-onboarding paywall; the user explores the sky and the
  /// 2-minute engagement gate (or the warning banner CTA) shows the paywall
  exploreFirst,
}

/// Resolves the onboarding paywall flow from the Adapty paywall's remote
/// config, so an A/B test between flows can be run - and the winner rolled
/// out - entirely from the Adapty dashboard.
///
/// Setup in Adapty: run an A/B test on the `night_sky_view` placement with
/// two paywalls whose remote config contains `"onboarding_flow": "immediate"`
/// and `"onboarding_flow": "explore_first"`. To ship the winner, stop the
/// test and serve only the winning paywall.
class PaywallFlowService {
  static const String _flowKey = 'paywall_flow_variant';
  static const String _assignedLoggedKey = 'paywall_flow_assigned_logged';
  static const String _remoteConfigFlowKey = 'onboarding_flow';
  static const String _exploreFirstValue = 'explore_first';

  static PaywallFlowService? _instance;

  PaywallFlow _flow = PaywallFlow.immediate;
  bool _isLoaded = false;

  PaywallFlowService._();

  static PaywallFlowService get instance {
    _instance ??= PaywallFlowService._();
    return _instance!;
  }

  PaywallFlow get flow => _flow;
  bool get isExploreFirst => _flow == PaywallFlow.exploreFirst;

  /// Fetch the assigned variant from Adapty. Falls back to the last known
  /// value (offline) and defaults to [PaywallFlow.immediate], so a fetch
  /// failure can never strand a user without any paywall flow.
  Future<void> load() async {
    if (kIsWeb || _isLoaded) return;
    _isLoaded = true;

    final prefs = await SharedPreferences.getInstance();
    // Last-known assignment as offline fallback
    final cached = prefs.getString(_flowKey);
    if (cached == _exploreFirstValue) {
      _flow = PaywallFlow.exploreFirst;
    }

    try {
      final paywall = await Adapty()
          .getFlow(placementId: 'night_sky_view')
          .timeout(const Duration(seconds: 5));

      final configFlow =
          paywall.remoteConfig?.dictionary?[_remoteConfigFlowKey] as String?;
      _flow = configFlow == _exploreFirstValue
          ? PaywallFlow.exploreFirst
          : PaywallFlow.immediate;

      await prefs.setString(
          _flowKey, isExploreFirst ? _exploreFirstValue : 'immediate');

      debugPrint('PaywallFlowService: flow=$_flow '
          '(paywall=${paywall.name}, variation=${paywall.variationId})');

      await _registerVariantForAnalytics(prefs, paywall);
    } catch (e) {
      debugPrint('PaywallFlowService: failed to fetch flow, using $_flow: $e');
    }
  }

  /// Attach the variant to analytics so funnels can be split per flow, and
  /// log the assignment once per install.
  Future<void> _registerVariantForAnalytics(
      SharedPreferences prefs, AdaptyFlow paywall) async {
    final flowName = isExploreFirst ? _exploreFirstValue : 'immediate';

    unawaited(AnalyticsService.instance
        .setUserProperty(name: 'paywall_flow', value: flowName));
    unawaited(Posthog().register('paywall_flow', flowName));

    if (prefs.getBool(_assignedLoggedKey) != true) {
      await prefs.setBool(_assignedLoggedKey, true);
      unawaited(AnalyticsService.instance.logEvent(
        name: 'paywall_flow_assigned',
        parameters: {'flow': flowName, 'variation_id': paywall.variationId},
        mirrorToPosthog: false,
      ));
      unawaited(Posthog().capture(
        eventName: 'paywall_flow_assigned',
        properties: {'flow': flowName, 'variation_id': paywall.variationId},
      ));
    }
  }
}
