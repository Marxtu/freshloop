// One-off manual live check: exercises the REAL clients against the REAL APIs
// using the keys in the gitignored secrets.json. Not part of the test suite
// (unit tests stay mocked and deterministic). Run: dart run tool/live_api_check.dart
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:freshloop/data/air/open_meteo_air_client.dart';
import 'package:freshloop/data/geocoding/nominatim_client.dart';
import 'package:freshloop/data/greenery/overpass_client.dart';
import 'package:freshloop/data/photos/mapillary_client.dart';
import 'package:freshloop/data/photos/wikimedia_client.dart';
import 'package:freshloop/data/routing/ors_route_client.dart';
import 'package:freshloop/data/routing/route_geometry.dart';

Future<void> main() async {
  final secrets = jsonDecode(File('secrets.json').readAsStringSync()) as Map<String, dynamic>;
  final ors = secrets['ORS_API_KEY'] as String;
  final mly = secrets['MAPILLARY_TOKEN'] as String;
  const ua = 'FreshLoop/0.1 (course project)';

  Future<void> check(String name, Future<String> Function() fn) async {
    try {
      final r = await fn();
      print('PASS  $name  ->  $r');
    } catch (e) {
      print('FAIL  $name  ->  ${e.toString().split('\n').first}');
    }
  }

  await check('Nominatim geocode "Milano"', () async {
    final p = await NominatimClient(userAgent: ua).search('Milano');
    return p == null ? 'no result' : '${p.label.split(',').first} (${p.lat}, ${p.lng})';
  });
  await check('ORS round-trip ~3km @ Milano', () async {
    final g = await OrsRouteClient(apiKey: ors).roundTrip(lat: 45.464, lng: 9.190, lengthM: 3000, seed: 3);
    return '${g.points.length} pts, ${g.distanceM.toStringAsFixed(0)} m, ascent ${g.ascentM.toStringAsFixed(0)} m';
  });
  await check('Open-Meteo AQI (2 pts)', () async {
    final a = await OpenMeteoAirClient()
        .sampleAqi(const [RoutePoint(lat: 45.46, lng: 9.19), RoutePoint(lat: 45.47, lng: 9.20)]);
    return 'aqi = $a';
  });
  await check('Overpass greenery bbox', () async {
    final g = await OverpassClient(userAgent: ua)
        .fetchGreenery(south: 45.46, west: 9.18, north: 45.47, east: 9.20);
    return 'green=${g.greenCount} scenic=${g.scenicCount} ratio=${g.greenRatio.toStringAsFixed(2)}';
  });
  await check('Mapillary photos bbox', () async {
    final ph = await MapillaryPhotoClient(accessToken: mly)
        .photosInBbox(south: 45.46, west: 9.18, north: 45.47, east: 9.20, limit: 3);
    return '${ph.length} photos';
  });
  await check('Wikimedia photos near Duomo', () async {
    final ph = await WikimediaPhotoClient(userAgent: ua)
        .photosNear(lat: 45.4641, lng: 9.1919, radiusM: 500, limit: 3);
    return '${ph.length} photos, first = ${ph.isEmpty ? "-" : ph.first.caption}';
  });
}
