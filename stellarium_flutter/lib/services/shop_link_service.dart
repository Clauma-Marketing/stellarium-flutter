import 'dart:ui' as ui;

import 'locale_service.dart';

/// Where in the app a "Name a star" button lives. Sent as `utm_content` and
/// as the `placement` analytics property so clicks and shop orders can be
/// split per entry point.
class ShopLinkPlacement {
  ShopLinkPlacement._();

  /// "Name this Star" card on the info sheet of an unnamed star
  static const String starSheet = 'star_sheet';

  /// "Name a Star" button on the onboarding Find Your Star step
  static const String onboarding = 'onboarding';

  /// Same button, shown behind the forced (2-minute) paywall
  static const String paywallGate = 'paywall_gate';
}

/// Single source of truth for links from the app into the star-naming shops.
///
/// Every "Name a star" button must build its URL here so that store routing
/// and campaign tagging stay consistent across placements.
class ShopLinkService {
  ShopLinkService._();

  static const String utmSource = 'night-sky-guide-app';
  static const String utmMedium = 'app';
  static const String utmCampaign = 'name-a-star';

  static final Uri _germanShop =
      Uri.parse('https://www.sterntaufe-deutschland.de/products/sterntaufe');
  static final Uri _internationalShop =
      Uri.parse('https://www.star-registration.com/products/standard');

  /// Language the shop link should be routed by: the in-app language override
  /// if set, otherwise the device language.
  static String currentLanguageCode() {
    final locale =
        LocaleService.instance.locale ?? ui.PlatformDispatcher.instance.locale;
    return locale.languageCode;
  }

  /// Product page a user should land on to name a star.
  ///
  /// German goes to the German store; every other language goes to the
  /// international store. [hipNumber] preselects the star the user was
  /// looking at. [placement] is one of [ShopLinkPlacement].
  static Uri nameStarUri({
    required String languageCode,
    required String placement,
    String? hipNumber,
  }) {
    final base = languageCode == 'de' ? _germanShop : _internationalShop;
    final hip = hipNumber?.trim();

    return base.replace(
      queryParameters: {
        if (hip != null && hip.isNotEmpty) 'hip': hip,
        'utm_source': utmSource,
        'utm_medium': utmMedium,
        'utm_campaign': utmCampaign,
        'utm_content': placement,
      },
    );
  }
}
