import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:freshloop/data/api_exception.dart';
import 'package:freshloop/data/geocoding/geo_place.dart';
import 'package:freshloop/data/geocoding/nominatim_client.dart';

void main() {
  group('NominatimClient.search', () {
    test('parses the first result and sends required headers/params', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode([
            {'lat': '52.5170', 'lon': '13.3889', 'display_name': 'Berlin, Germany'},
          ]),
          200,
        );
      });
      final client = NominatimClient(userAgent: 'FreshLoop/0.1 test', client: mock);

      final place = await client.search('Berlin');

      expect(place, isA<GeoPlace>());
      expect(place!.lat, closeTo(52.5170, 1e-9));
      expect(place.lng, closeTo(13.3889, 1e-9));
      expect(place.label, 'Berlin, Germany');
      expect(captured.headers['User-Agent'], 'FreshLoop/0.1 test');
      expect(captured.url.queryParameters['q'], 'Berlin');
      expect(captured.url.queryParameters['format'], 'jsonv2');
    });

    test('returns null when there are no results', () async {
      final mock = MockClient((req) async => http.Response('[]', 200));
      final client = NominatimClient(userAgent: 'ua', client: mock);
      expect(await client.search('nowhere-xyz'), isNull);
    });

    test('throws ApiException on non-200', () async {
      final mock = MockClient((req) async => http.Response('rate limited', 429));
      final client = NominatimClient(userAgent: 'ua', client: mock);
      expect(() => client.search('Berlin'), throwsA(isA<ApiException>()));
    });
  });

  group('NominatimClient.suggest', () {
    test('returns multiple results and biases to a nearby viewbox', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode([
            {'lat': '45.46', 'lon': '9.18', 'display_name': 'Carrefour, Via A, Milano'},
            {'lat': '45.47', 'lon': '9.20', 'display_name': 'Carrefour Express, Via B, Milano'},
          ]),
          200,
        );
      });
      final client = NominatimClient(userAgent: 'ua', client: mock);

      final places = await client.suggest('Carrefour', lat: 45.4642, lng: 9.19, limit: 5);

      expect(places.length, 2);
      expect(places.first.label, startsWith('Carrefour'));
      expect(captured.url.queryParameters['limit'], '5');
      // viewbox biases toward the start location, not bounded to it
      expect(captured.url.queryParameters['viewbox'], isNotNull);
      expect(captured.url.queryParameters['bounded'], '0');
    });

    test('omits the viewbox when no location is given', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response('[]', 200);
      });
      final client = NominatimClient(userAgent: 'ua', client: mock);
      await client.suggest('Berlin');
      expect(captured.url.queryParameters.containsKey('viewbox'), isFalse);
    });
  });
}
