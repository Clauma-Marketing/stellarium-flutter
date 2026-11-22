import 'package:flutter_test/flutter_test.dart';
import 'package:Night_Sky_Guide/services/klaviyo_service.dart';

void main() {
  group('KlaviyoService.routingDataFromKlaviyoPush', () {
    test('lifts key-value pairs to the top level', () {
      final data = KlaviyoService.routingDataFromKlaviyoPush({
        '_k': '{"m":"abc"}',
        'title': 'Black Friday',
        'key_value_pairs':
            '{"link":"https://www.star-registration.com/","screen":"subscription"}',
      });

      expect(data['link'], 'https://www.star-registration.com/');
      expect(data['screen'], 'subscription');
      expect(data['title'], 'Black Friday');
      expect(data['_k'], '{"m":"abc"}');
    });

    test('stringifies non-string values', () {
      final data = KlaviyoService.routingDataFromKlaviyoPush({
        '_k': 'x',
        'key_value_pairs': '{"registration_number":123456}',
      });

      expect(data['registration_number'], '123456');
    });

    test('keeps the payload when there are no key-value pairs', () {
      final data = KlaviyoService.routingDataFromKlaviyoPush({'_k': 'x'});

      expect(data, {'_k': 'x'});
    });

    test('ignores key-value pairs that are not a JSON object', () {
      final data = KlaviyoService.routingDataFromKlaviyoPush({
        '_k': 'x',
        'key_value_pairs': 'not json',
      });

      expect(data['_k'], 'x');
      expect(data.containsKey('link'), isFalse);
    });
  });

  group('KlaviyoService.pushOpenProperties', () {
    test('reads the campaign from the tracking block', () {
      final properties = KlaviyoService.pushOpenProperties({
        'title': 'Black Friday Week is here!',
        '_k': '{"Message Name":"2026-11-23 | Black Friday Week | App Push | EN",'
            '"Message Type":"campaign","\$message":"01ABC","\$flow":""}',
      });

      expect(properties, {
        'title': 'Black Friday Week is here!',
        'campaign_name': '2026-11-23 | Black Friday Week | App Push | EN',
        'message_type': 'campaign',
        'message_id': '01ABC',
      });
    });

    test('keeps the flow id for flow messages', () {
      final properties = KlaviyoService.pushOpenProperties({
        '_k': '{"Message Name":"Welcome 1","Message Type":"flow",'
            '"\$message":"01XYZ","\$flow":"AbC123"}',
      });

      expect(properties['message_type'], 'flow');
      expect(properties['flow_id'], 'AbC123');
    });

    test('survives a tracking block it cannot read', () {
      expect(
        KlaviyoService.pushOpenProperties({'_k': 'not json', 'title': 'Hi'}),
        {'title': 'Hi'},
      );
      expect(KlaviyoService.pushOpenProperties({}), isEmpty);
    });
  });
}
