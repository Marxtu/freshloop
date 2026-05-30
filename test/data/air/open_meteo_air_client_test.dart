import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:freshloop/data/api_exception.dart';
import 'package:freshloop/data/air/open_meteo_air_client.dart';
import 'package:freshloop/data/routing/route_geometry.dart';

void main() {
  group('OpenMeteoAirClient.sampleAqi', () {
    const points = [
      RoutePoint(lat: 52.5, lng: 13.4),
      RoutePoint(lat: 48.1, lng: 11.6),
    ];

    test('parses european_aqi from a multi-point (array) response', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode([
            {'current': {'european_aqi': 34}},
            {'current': {'european_aqi': 30}},
          ]),
          200,
        );
      });
      final client = OpenMeteoAirClient(client: mock);

      final aqi = await client.sampleAqi(points);

      expect(aqi, [34.0, 30.0]);
      expect(captured.url.queryParameters['latitude'], '52.5,48.1');
      expect(captured.url.queryParameters['longitude'], '13.4,11.6');
      expect(captured.url.queryParameters['current'], 'european_aqi');
    });

    test('normalizes a single-point (object) response into a list', () async {
      final mock = MockClient((req) async =>
          http.Response(jsonEncode({'current': {'european_aqi': 42}}), 200));
      final client = OpenMeteoAirClient(client: mock);
      final aqi = await client.sampleAqi(const [RoutePoint(lat: 1, lng: 2)]);
      expect(aqi, [42.0]);
    });

    test('returns empty list for no points without calling the network', () async {
      var called = false;
      final mock = MockClient((req) async {
        called = true;
        return http.Response('[]', 200);
      });
      final client = OpenMeteoAirClient(client: mock);
      expect(await client.sampleAqi(const []), isEmpty);
      expect(called, isFalse);
    });

    test('drops points whose AQI is null instead of failing the whole route', () async {
      final mock = MockClient((req) async => http.Response(
            jsonEncode([
              {'current': {'european_aqi': 40}},
              {'current': {'european_aqi': null}}, // a gap in the data
              {'current': {'european_aqi': 50}},
            ]),
            200,
          ));
      final client = OpenMeteoAirClient(client: mock);
      expect(await client.sampleAqi(points), [40.0, 50.0]);
    });

    test('throws ApiException on non-200', () async {
      final mock = MockClient((req) async => http.Response('boom', 500));
      final client = OpenMeteoAirClient(client: mock);
      expect(() => client.sampleAqi(points), throwsA(isA<ApiException>()));
    });
  });
}
