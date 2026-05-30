import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:freshloop/data/air/open_meteo_air_client.dart';
import 'package:freshloop/data/greenery/overpass_client.dart';
import 'package:freshloop/data/routing/ors_route_client.dart';
import 'package:freshloop/domain/models/run_params.dart';
import 'package:freshloop/services/route_generator.dart';
import 'package:freshloop/state/route_gen_cubit.dart';
import 'package:freshloop/state/route_gen_state.dart';

RouteGenerator _okGenerator() => RouteGenerator(
      ors: OrsRouteClient(
        apiKey: 'k',
        client: MockClient((req) async => http.Response(
            jsonEncode({
              'features': [
                {
                  'geometry': {'coordinates': [[9.18, 45.46, 100.0], [9.18, 45.46, 100.0]]},
                  'properties': {'ascent': 10.0, 'summary': {'distance': 3000.0}},
                },
              ],
            }),
            200)),
      ),
      air: OpenMeteoAirClient(
        client: MockClient((req) async =>
            http.Response(jsonEncode([{'current': {'european_aqi': 30}}]), 200)),
      ),
      overpass: OverpassClient(
        userAgent: 'ua',
        client: MockClient((req) async => http.Response(jsonEncode({'elements': []}), 200)),
      ),
    );

const _params = RunParams(startLat: 45.46, startLng: 9.19, targetDistanceM: 3000);

void main() {
  group('RouteGenCubit', () {
    test('starts in initial state', () {
      expect(_okGenerator, returnsNormally);
      final cubit = RouteGenCubit(_okGenerator());
      expect(cubit.state, isA<RouteGenInitial>());
      cubit.close();
    });

    test('emits loading then loaded with routes on success', () async {
      final cubit = RouteGenCubit(_okGenerator());
      // Set up the expectation before acting so both emissions are caught
      // regardless of microtask delivery timing.
      final expectation = expectLater(
        cubit.stream,
        emitsInOrder([isA<RouteGenLoading>(), isA<RouteGenLoaded>()]),
      );

      await cubit.generate(_params, candidates: 2);
      await expectation;

      expect(cubit.state, isA<RouteGenLoaded>());
      expect((cubit.state as RouteGenLoaded).routes.length, 2);
      await cubit.close();
    });

    test('emits error when routing fails', () async {
      final gen = RouteGenerator(
        ors: OrsRouteClient(apiKey: 'k', client: MockClient((req) async => http.Response('quota', 403))),
        air: OpenMeteoAirClient(client: MockClient((req) async => http.Response('[]', 200))),
        overpass: OverpassClient(userAgent: 'ua', client: MockClient((req) async => http.Response('{}', 200))),
      );
      final cubit = RouteGenCubit(gen);

      await cubit.generate(_params, candidates: 1);

      expect(cubit.state, isA<RouteGenError>());
      await cubit.close();
    });
  });
}
