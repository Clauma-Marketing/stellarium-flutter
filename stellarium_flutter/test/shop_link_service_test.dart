import 'package:flutter_test/flutter_test.dart';
import 'package:Night_Sky_Guide/services/shop_link_service.dart';

void main() {
  group('ShopLinkService.nameStarUri', () {
    test('routes German to the German store', () {
      final uri = ShopLinkService.nameStarUri(
        languageCode: 'de',
        placement: ShopLinkPlacement.starSheet,
      );

      expect(uri.host, 'www.sterntaufe-deutschland.de');
      expect(uri.path, '/products/sterntaufe');
    });

    test('routes every other language to the international store', () {
      for (final language in ['en', 'es', 'fr', 'it', 'pl', 'ro', 'tr', 'zh']) {
        final uri = ShopLinkService.nameStarUri(
          languageCode: language,
          placement: ShopLinkPlacement.onboarding,
        );

        expect(uri.host, 'www.star-registration.com', reason: language);
        expect(uri.path, '/products/standard', reason: language);
      }
    });

    test('tags the link with campaign parameters and the placement', () {
      final uri = ShopLinkService.nameStarUri(
        languageCode: 'en',
        placement: ShopLinkPlacement.paywallGate,
      );

      expect(uri.queryParameters, {
        'utm_source': 'night-sky-guide-app',
        'utm_medium': 'app',
        'utm_campaign': 'name-a-star',
        'utm_content': 'paywall_gate',
      });
    });

    test('keeps the HIP number when a star is selected', () {
      final uri = ShopLinkService.nameStarUri(
        languageCode: 'en',
        placement: ShopLinkPlacement.starSheet,
        hipNumber: '677',
      );

      expect(uri.queryParameters['hip'], '677');
      expect(uri.queryParameters['utm_content'], 'star_sheet');
      expect(
        uri.toString(),
        'https://www.star-registration.com/products/standard'
        '?hip=677&utm_source=night-sky-guide-app&utm_medium=app'
        '&utm_campaign=name-a-star&utm_content=star_sheet',
      );
    });

    test('omits hip when no star number is known', () {
      for (final hip in [null, '', '  ']) {
        final uri = ShopLinkService.nameStarUri(
          languageCode: 'de',
          placement: ShopLinkPlacement.starSheet,
          hipNumber: hip,
        );

        expect(uri.queryParameters.containsKey('hip'), isFalse);
      }
    });

    test('carries the analytics ID to the shop when one is given', () {
      final uri = ShopLinkService.nameStarUri(
        languageCode: 'en',
        placement: ShopLinkPlacement.starSheet,
        hipNumber: '677',
        analyticsId: '0193a7c2-5f0e-7c3a-9d1b-2f4e6a8c0b1d',
      );

      expect(
        uri.queryParameters['ph_did'],
        '0193a7c2-5f0e-7c3a-9d1b-2f4e6a8c0b1d',
      );
      expect(uri.queryParameters['hip'], '677');
      expect(uri.queryParameters['utm_content'], 'star_sheet');
    });

    test('leaves the analytics ID out when there is none to share', () {
      for (final id in [null, '', 'short', 'someone@example.com', 'has space']) {
        final uri = ShopLinkService.nameStarUri(
          languageCode: 'en',
          placement: ShopLinkPlacement.onboarding,
          analyticsId: id,
        );

        expect(uri.queryParameters.containsKey('ph_did'), isFalse, reason: '$id');
      }
    });
  });

  group('ShopLinkService.isShareableAnalyticsId', () {
    test('accepts PostHog and Firebase style IDs only', () {
      expect(
        ShopLinkService.isShareableAnalyticsId(
            '0193a7c2-5f0e-7c3a-9d1b-2f4e6a8c0b1d'),
        isTrue,
      );
      expect(
        ShopLinkService.isShareableAnalyticsId('aB3dE6gH9jK2mN5pQ8sT1vW4yZ7x'),
        isTrue,
      );
      expect(ShopLinkService.isShareableAnalyticsId(null), isFalse);
      expect(
        ShopLinkService.isShareableAnalyticsId('someone@example.com'),
        isFalse,
      );
    });
  });
}
