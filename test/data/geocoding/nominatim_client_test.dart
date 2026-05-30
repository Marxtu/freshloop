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
}
