import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:freshloop/data/api_exception.dart';
import 'package:freshloop/data/routing/ors_route_client.dart';

void main() {
  group('OrsRouteClient.roundTrip', () {
    test('posts a round-trip request and parses the geometry', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'features': [
              {
                'geometry': {
                  'coordinates': [
                    [8.681, 49.414, 110.0],
                    [8.682, 49.415, 120.0],
                  ],
                },
                'properties': {
                  'ascent': 30.0,
                  'summary': {'distance': 5000.0},
                },
              },
            ],
          }),
          200,
        );
      });
      final client = OrsRouteClient(apiKey: 'test-key', client: mock);

      final g = await client.roundTrip(lat: 49.414, lng: 8.681, lengthM: 5000, seed: 7);

      expect(g.distanceM, 5000.0);
      expect(g.ascentM, 30.0);
      expect(g.points.length, 2);
      expect(captured.method, 'POST');
      expect(captured.headers['Authorization'], 'test-key');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['coordinates'], [[8.681, 49.414]]);
      expect(body['options']['round_trip']['length'], 5000);
      expect(body['options']['round_trip']['seed'], 7);
    });

    test('throws ApiException on non-200', () async {
      final mock = MockClient((req) async => http.Response('quota exceeded', 403));
      final client = OrsRouteClient(apiKey: 'k', client: mock);
      expect(
        () => client.roundTrip(lat: 1, lng: 2, lengthM: 3000),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
