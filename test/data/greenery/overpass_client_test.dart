import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:freshloop/data/api_exception.dart';
import 'package:freshloop/data/greenery/greenery_data.dart';
import 'package:freshloop/data/greenery/overpass_client.dart';

void main() {
  group('OverpassClient.fetchGreenery', () {
    test('posts an Overpass query with bbox + User-Agent and parses counts', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'elements': [
              {'type': 'way', 'tags': {'leisure': 'park'}},
              {'type': 'node', 'tags': {'tourism': 'viewpoint'}},
            ],
          }),
          200,
        );
      });
      final client = OverpassClient(userAgent: 'FreshLoop/0.1 test', client: mock);

      final g = await client.fetchGreenery(south: 52.5, west: 13.3, north: 52.6, east: 13.4);

      expect(g, isA<GreeneryData>());
      expect(g.greenCount, 1);
      expect(g.scenicCount, 1);
      expect(captured.method, 'POST');
      expect(captured.headers['User-Agent'], 'FreshLoop/0.1 test');
      // The query is sent form-encoded; decode it back before asserting on intent.
      final sentQuery = Uri.splitQueryString(captured.body)['data']!;
      expect(sentQuery, contains('52.5,13.3,52.6,13.4')); // bbox order: south,west,north,east
      expect(sentQuery, contains('[out:json]'));
    });

    test('throws ApiException on non-200', () async {
      final mock = MockClient((req) async => http.Response('429 too many', 429));
      final client = OverpassClient(userAgent: 'ua', client: mock);
      expect(
        () => client.fetchGreenery(south: 0, west: 0, north: 1, east: 1),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
