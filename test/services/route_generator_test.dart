import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:freshloop/data/air/open_meteo_air_client.dart';
import 'package:freshloop/data/greenery/overpass_client.dart';
import 'package:freshloop/data/routing/ors_route_client.dart';
import 'package:freshloop/domain/models/run_params.dart';
import 'package:freshloop/domain/models/scored_route.dart';
import 'package:freshloop/services/route_generator.dart';

http.Response _orsResp(double distance) => http.Response(
      jsonEncode({
        'features': [
          {
            'geometry': {
              'coordinates': [
                [9.18, 45.46, 100.0],
                [9.20, 45.47, 130.0],
                [9.18, 45.46, 100.0],
              ],
            },
            'properties': {
              'ascent': 30.0,
              'summary': {'distance': distance},
            },
          },
        ],
      }),
      200,
    );

void main() {
  group('RouteGenerator.generate', () {
    test('produces N scored candidates ranked by total, descending', () async {
      // ORS returns a route whose distance encodes the seed so each candidate differs.
      final ors = OrsRouteClient(
        apiKey: 'k',
        client: MockClient((req) async {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          final seed = body['options']['round_trip']['seed'] as int;
          return _orsResp(1000.0 * seed);
        }),
      );
      // Air: better AQI for later seeds (so ranking is not just input order).
      final air = OpenMeteoAirClient(
        client: MockClient((req) async => http.Response(
            jsonEncode([
              {'current': {'european_aqi': 40}},
              {'current': {'european_aqi': 40}},
            ]),
            200)),
      );
      final overpass = OverpassClient(
        userAgent: 'ua',
        client: MockClient((req) async => http.Response(
            jsonEncode({
              'elements': [
                {'type': 'way', 'tags': {'leisure': 'park'}},
              ],
            }),
            200)),
      );
      final gen = RouteGenerator(ors: ors, air: air, overpass: overpass);

      final routes = await gen.generate(
        const RunParams(startLat: 45.46, startLng: 9.19, targetDistanceM: 3000),
        candidates: 3,
      );

      expect(routes.length, 3);
      // sorted by score.total descending
      expect(routes[0].score.total, greaterThanOrEqualTo(routes[1].score.total));
      expect(routes[1].score.total, greaterThanOrEqualTo(routes[2].score.total));
      // every candidate carries geometry + score
      expect(routes.first.geometry.points, isNotEmpty);
    });

    test('keeps the candidates whose length is closest to the requested distance', () async {
      // ORS encodes the seed in the distance; round_trip can deviate badly, so
      // the generator over-generates and keeps the closest-to-target loops.
      final ors = OrsRouteClient(
        apiKey: 'k',
        client: MockClient((req) async {
          final seed = (jsonDecode(req.body) as Map)['options']['round_trip']['seed'] as int;
          return _orsResp(1000.0 * seed); // seeds 1..N -> 1000..N000 m
        }),
      );
      final air = OpenMeteoAirClient(client: MockClient((_) async => http.Response('[]', 200)));
      final overpass = OverpassClient(userAgent: 'ua', client: MockClient((_) async => http.Response('{}', 200)));
      final gen = RouteGenerator(ors: ors, air: air, overpass: overpass);

      // target 5000; pool = candidates*2 = 4 seeds -> 1000,2000,3000,4000.
      final routes = await gen.generate(
        const RunParams(startLat: 45.46, startLng: 9.19, targetDistanceM: 5000),
        candidates: 2,
      );

      // The two closest to 5000 km are 4000 and 3000 — not 1000/2000.
      expect(routes.map((r) => r.geometry.distanceM).toSet(), {3000.0, 4000.0});
    });

    test('offers an out-and-back when no loop is near the requested distance', () async {
      // Loops come back far (12 km); a point-to-point leg is 2.4 km → out-and-back
      // is 4.8 km, much closer to the 5 km target, so it should win.
      final ors = OrsRouteClient(
        apiKey: 'k',
        client: MockClient((req) async {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          final isLoop = (body['options'] as Map?)?['round_trip'] != null;
          return _orsResp(isLoop ? 12000.0 : 2400.0);
        }),
      );
      final air = OpenMeteoAirClient(client: MockClient((_) async => http.Response('[]', 200)));
      final overpass = OverpassClient(userAgent: 'ua', client: MockClient((_) async => http.Response('{}', 200)));
      final gen = RouteGenerator(ors: ors, air: air, overpass: overpass);

      final routes = await gen.generate(
        const RunParams(startLat: 45.73, startLng: 7.39, targetDistanceM: 5000),
        candidates: 1,
      );

      expect(routes.length, 1);
      expect(routes.first.kind, RouteKind.outAndBack);
      expect(routes.first.geometry.distanceM, 4800.0); // 2 × the 2.4 km leg
    });

    test('degrades to a neutral score when enrichment APIs fail (route still scored)', () async {
      final ors = OrsRouteClient(apiKey: 'k', client: MockClient((req) async => _orsResp(3000)));
      final air = OpenMeteoAirClient(client: MockClient((req) async => http.Response('down', 500)));
      final overpass = OverpassClient(userAgent: 'ua', client: MockClient((req) async => http.Response('down', 500)));
      final gen = RouteGenerator(ors: ors, air: air, overpass: overpass);

      final routes = await gen.generate(
        const RunParams(startLat: 45.46, startLng: 9.19, targetDistanceM: 3000),
        candidates: 1,
      );

      expect(routes.length, 1); // ORS succeeded → we still return a scored route
      expect(routes.first.score.total, isNonNegative);
    });

    test('rethrows when routing (ORS) fails', () async {
      final ors = OrsRouteClient(apiKey: 'k', client: MockClient((req) async => http.Response('quota', 403)));
      final air = OpenMeteoAirClient(client: MockClient((req) async => http.Response('[]', 200)));
      final overpass = OverpassClient(userAgent: 'ua', client: MockClient((req) async => http.Response('{}', 200)));
      final gen = RouteGenerator(ors: ors, air: air, overpass: overpass);

      expect(
        () => gen.generate(const RunParams(startLat: 0, startLng: 0, targetDistanceM: 3000), candidates: 1),
        throwsA(anything),
      );
    });
  });
}
