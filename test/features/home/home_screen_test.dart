import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:freshloop/data/air/open_meteo_air_client.dart';
import 'package:freshloop/data/geocoding/nominatim_client.dart';
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

void main() {
  testWidgets('autocomplete suggestions show a distance from the user', (tester) async {
    // Geocoder returns two Milan places: ~1 km and ~6 km from the fix.
    final geocoder = NominatimClient(
      userAgent: 'ua',
      client: MockClient((req) async => http.Response(
            jsonEncode([
              {'lat': '45.47', 'lon': '9.19', 'display_name': 'Carrefour, Via Soderini, Milano'},
              {'lat': '45.50', 'lon': '9.25', 'display_name': 'Carrefour Express, Via Ponte, Milano'},
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

    await tester.enterText(find.byType(TextField), 'carrefour');
    await tester.pump(); // register onChanged
    await tester.pump(const Duration(milliseconds: 450)); // fire the 400ms debounce
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50)); // resolve suggest + rebuild
    }

    // Suggestions render (title + subtitle both mention the street)…
    expect(find.textContaining('Via Soderini'), findsWidgets);
    // …each with a straight-line distance label (km), measured from the fix.
    // Test passing also means the trailing label caused no layout overflow.
    expect(find.textContaining('km'), findsWidgets);
    expect(find.text('1.1 km'), findsOneWidget); // ~0.01° lat ≈ 1.1 km
  });
}
