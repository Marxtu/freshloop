import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:freshloop/data/api_exception.dart';
import 'package:freshloop/data/geocoding/photon_client.dart';

String _fc(List<Map<String, dynamic>> features) =>
    jsonEncode({'type': 'FeatureCollection', 'features': features});

Map<String, dynamic> _feat(double lng, double lat, Map<String, dynamic> props) => {
      'type': 'Feature',
      'geometry': {'type': 'Point', 'coordinates': [lng, lat]},
      'properties': props,
    };

void main() {
  group('PhotonClient.suggest', () {
    test('parses GeoJSON features, builds labels, sends q/limit/lang + bias', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          _fc([
            _feat(9.19, 45.46, {
              'name': 'Carrefour Express',
              'street': 'Corso di Porta Romana',
              'city': 'Milan',
              'country': 'Italy',
              'osm_value': 'convenience',
            }),
            _feat(11.55, 45.55, {'name': 'Carrè', 'state': 'Veneto', 'country': 'Italy'}),
          ]),
          200,
        );
      });
      final client = PhotonClient(userAgent: 'FreshLoop/test', client: mock);

      final places = await client.suggest('Carre', lat: 45.46, lng: 9.19, limit: 6);

      expect(places.length, 2);
      // GeoJSON coordinates are [lng, lat] — make sure we didn't swap them.
      expect(places.first.lat, closeTo(45.46, 1e-9));
      expect(places.first.lng, closeTo(9.19, 1e-9));
      expect(places.first.label, 'Carrefour Express, Corso di Porta Romana, Milan, Italy');
      expect(captured.headers['User-Agent'], 'FreshLoop/test');
      expect(captured.url.queryParameters['q'], 'Carre');
      expect(captured.url.queryParameters['limit'], '6');
      expect(captured.url.queryParameters['lang'], 'en');
      expect(captured.url.queryParameters['lat'], '45.46');
      expect(captured.url.queryParameters['lon'], '9.19');
    });

    test('omits the location bias when no lat/lng is given', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(_fc(const []), 200);
      });
      final client = PhotonClient(userAgent: 'ua', client: mock);
      await client.suggest('Berlin');
      expect(captured.url.queryParameters.containsKey('lat'), isFalse);
      expect(captured.url.queryParameters.containsKey('lon'), isFalse);
    });

    test('skips features with malformed geometry', () async {
      final mock = MockClient((req) async => http.Response(
            _fc([
              {'type': 'Feature', 'geometry': null, 'properties': {'name': 'broken'}},
              _feat(9.0, 45.0, {'name': 'ok'}),
            ]),
            200,
          ));
      final client = PhotonClient(userAgent: 'ua', client: mock);
      final places = await client.suggest('x');
      expect(places.length, 1);
      expect(places.first.label, 'ok');
    });

    test('throws ApiException on non-200', () async {
      final mock = MockClient((req) async => http.Response('boom', 503));
      final client = PhotonClient(userAgent: 'ua', client: mock);
      expect(() => client.suggest('x'), throwsA(isA<ApiException>()));
    });
  });

  group('PhotonClient.search', () {
    test('returns the first match, or null when empty', () async {
      final hit = MockClient((req) async => http.Response(
            _fc([_feat(9.19, 45.46, {'name': 'Carrefour'})]), 200));
      expect((await PhotonClient(userAgent: 'ua', client: hit).search('Carrefour'))?.label, 'Carrefour');

      final empty = MockClient((req) async => http.Response(_fc(const []), 200));
      expect(await PhotonClient(userAgent: 'ua', client: empty).search('nowhere'), isNull);
    });
  });
}
