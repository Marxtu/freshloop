import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:freshloop/data/air/open_meteo_air_client.dart';
import 'package:freshloop/data/geocoding/photon_client.dart';
import 'package:freshloop/data/greenery/overpass_client.dart';
import 'package:freshloop/data/routing/ors_route_client.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/features/home/home_screen.dart';
import 'package:freshloop/services/location_source.dart';
import 'package:freshloop/services/route_generator.dart';
import 'package:freshloop/state/route_gen_cubit.dart';

/// A location source pinned to a fixed fix near the Milan centre.
class _FixedLocation implements LocationSource {
  @override
  Future<bool> ensurePermission() async => true;
  @override
  Stream<RoutePoint> positions() => const Stream<RoutePoint>.empty();
  @override
  Future<RoutePoint?> current() async => const RoutePoint(lat: 45.46, lng: 9.19);
}

// The generator is never exercised here (we don't tap Generate); its clients
// just need to exist for the RouteGenCubit.
RouteGenerator _idleGenerator() => RouteGenerator(
      ors: OrsRouteClient(apiKey: 'k', client: MockClient((_) async => http.Response('{}', 200))),
      air: OpenMeteoAirClient(client: MockClient((_) async => http.Response('[]', 200))),
      overpass: OverpassClient(userAgent: 'ua', client: MockClient((_) async => http.Response('{}', 200))),
    );

// A Photon GeoJSON feature ([lng, lat] coordinates).
Map<String, dynamic> _feat(double lng, double lat, Map<String, dynamic> props) => {
      'type': 'Feature',
      'geometry': {'type': 'Point', 'coordinates': [lng, lat]},
      'properties': props,
    };
String _fc(List<Map<String, dynamic>> features) =>
    jsonEncode({'type': 'FeatureCollection', 'features': features});

void main() {
  testWidgets('autocomplete suggestions show a distance from the user', (tester) async {
    // Photon returns two Milan places FAR-FIRST (~6 km then ~1 km) so the
    // distance sort has something to reorder.
    final geocoder = PhotonClient(
      userAgent: 'ua',
      client: MockClient((req) async => http.Response(
            _fc([
              _feat(9.25, 45.50, {'name': 'Carrefour Express', 'street': 'Via Ponte', 'city': 'Milano'}),
              _feat(9.19, 45.47, {'name': 'Carrefour', 'street': 'Via Soderini', 'city': 'Milano'}),
            ]),
            200,
          )),
    );

    await tester.pumpWidget(MaterialApp(
      home: BlocProvider(
        create: (_) => RouteGenCubit(_idleGenerator()),
        child: HomeScreen(locationSource: _FixedLocation(), geocoder: geocoder),
      ),
    ));
    await tester.pump(); // let the auto-locate fix resolve (sets the origin)
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(find.byType(TextField), 'carre');
    await tester.pump(); // register onChanged
    await tester.pump(const Duration(milliseconds: 450)); // fire the 400ms debounce
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50)); // resolve suggest + rebuild
    }

    // Suggestions render (title + subtitle both mention the street)…
    expect(find.textContaining('Via Soderini'), findsWidgets);
    // …each with a straight-line distance label, measured from the fix.
    // Test passing also means the trailing label caused no layout overflow.
    expect(find.text('1.1 km'), findsOneWidget); // ~0.01° lat ≈ 1.1 km
    expect(find.text('6.5 km'), findsOneWidget);
    // …and the list is sorted nearest-first (the 1.1 km row above the 6.5 km row),
    // even though the geocoder returned them far-first.
    expect(tester.getTopLeft(find.text('1.1 km')).dy,
        lessThan(tester.getTopLeft(find.text('6.5 km')).dy));
  });

  testWidgets('shows a "no matches" hint when a search returns nothing', (tester) async {
    final geocoder = PhotonClient(
      userAgent: 'ua',
      client: MockClient((req) async => http.Response(_fc(const []), 200)),
    );
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider(
        create: (_) => RouteGenCubit(_idleGenerator()),
        child: HomeScreen(locationSource: _FixedLocation(), geocoder: geocoder),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(find.byType(TextField), 'zzqqxx');
    await tester.pump(const Duration(milliseconds: 300)); // fire the 250ms debounce
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.textContaining('No matches'), findsOneWidget);
  });

  testWidgets('submitting the search (Enter) is location-biased, not global', (tester) async {
    final requests = <Uri>[];
    final geocoder = PhotonClient(
      userAgent: 'ua',
      client: MockClient((req) async {
        requests.add(req.url);
        return http.Response(_fc([_feat(9.19, 45.47, {'name': 'Carrefour', 'city': 'Milano'})]), 200);
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: BlocProvider(
        create: (_) => RouteGenCubit(_idleGenerator()),
        child: HomeScreen(locationSource: _FixedLocation(), geocoder: geocoder),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(find.byType(TextField), 'carre');
    // Submit immediately — before the 400ms debounce fires, so the dropdown is
    // empty and the _search() path runs (the case that used to go global).
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump(const Duration(milliseconds: 50)); // resolve the search

    expect(requests, isNotEmpty);
    // It must bias to the user's location, not do a worldwide search.
    expect(requests.first.queryParameters['lat'], isNotNull);
    expect(requests.first.queryParameters['lon'], isNotNull);

    // Flush the still-pending debounce timer so the test ends cleanly.
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 50));
  });
}
