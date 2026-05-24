import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freshloop/app/app.dart';
import 'package:freshloop/app/dependencies.dart';
import 'package:freshloop/data/air/open_meteo_air_client.dart';
import 'package:freshloop/data/greenery/overpass_client.dart';
import 'package:freshloop/data/routing/ors_route_client.dart';
import 'package:freshloop/features/candidates/candidate_card.dart';
import 'package:freshloop/services/route_generator.dart';

/// A fully hermetic RouteGenerator: every client is a MockClient returning
/// canned ORS / air / greenery responses. Adapted from the `_okGenerator()`
/// helper in test/state/route_gen_cubit_test.dart so the app's generation flow
/// touches no real network.
RouteGenerator _okGenerator() => RouteGenerator(
      ors: OrsRouteClient(
        apiKey: 'k',
        client: MockClient((req) async => http.Response(
            jsonEncode({
              'features': [
                {
                  'geometry': {
                    'coordinates': [
                      [9.18, 45.46, 100.0],
                      [9.18, 45.46, 100.0],
                    ],
                  },
                  'properties': {
                    'ascent': 10.0,
                    'summary': {'distance': 3000.0},
                  },
                },
              ],
            }),
            200)),
      ),
      air: OpenMeteoAirClient(
        client: MockClient((req) async =>
            http.Response(jsonEncode([
              {'current': {'european_aqi': 30}}
            ]), 200)),
      ),
      overpass: OverpassClient(
        userAgent: 'ua',
        client: MockClient((req) async => http.Response(jsonEncode({'elements': []}), 200)),
      ),
    );

void main() {
  setUp(() async {
    // Local mode — no auth gate, no Firebase singletons touched.
    firebaseReady = false;
    SharedPreferences.setMockInitialValues({});
    appPrefs = await SharedPreferences.getInstance();
  });

  testWidgets('home → generate → navigates to ranked candidates', (tester) async {
    await tester.pumpWidget(FreshLoopApp(generator: _okGenerator()));
    await tester.pumpAndSettle();

    // The primary CTA on the params sheet.
    final generate = find.text('Generate routes');
    expect(generate, findsOneWidget);
    await tester.tap(generate);

    // Drive the async generation to completion. pumpAndSettle would hang if a
    // periodic timer were running; the map has none here, but fall back to
    // bounded timed pumps if it ever does.
    try {
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    } on FlutterError {
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    // Landed on the candidates screen with at least one ranked card.
    expect(find.text('Choose your route'), findsOneWidget);
    expect(find.byType(CandidateCard), findsWidgets);
  });
}
