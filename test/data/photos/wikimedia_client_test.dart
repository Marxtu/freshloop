import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:freshloop/data/api_exception.dart';
import 'package:freshloop/data/photos/scene_photo.dart';
import 'package:freshloop/data/photos/wikimedia_client.dart';

void main() {
  group('WikimediaPhotoClient.photosNear', () {
    test('sends geosearch params + User-Agent and parses photos', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'query': {
              'geosearch': [
                {'pageid': 1, 'title': 'File:Gate.jpg', 'lat': 52.5163, 'lon': 13.3777, 'dist': 0},
              ],
            },
          }),
          200,
        );
      });
      final client = WikimediaPhotoClient(userAgent: 'FreshLoop/0.1 test', client: mock);

      final photos = await client.photosNear(lat: 52.5163, lng: 13.3777, radiusM: 500, limit: 3);

      expect(photos.length, 1);
      expect(photos.first.source, PhotoSource.wikimedia);
      expect(photos.first.caption, 'Gate.jpg');
      expect(photos.first.url, contains('Special:FilePath/Gate.jpg'));
      expect(captured.headers['User-Agent'], 'FreshLoop/0.1 test');
      expect(captured.url.queryParameters['list'], 'geosearch');
      expect(captured.url.queryParameters['gscoord'], '52.5163|13.3777');
      expect(captured.url.queryParameters['gsnamespace'], '6');
    });

    test('returns empty list when there are no results', () async {
      final mock = MockClient((req) async =>
          http.Response(jsonEncode({'query': {'geosearch': []}}), 200));
      final client = WikimediaPhotoClient(userAgent: 'ua', client: mock);
      expect(await client.photosNear(lat: 0, lng: 0), isEmpty);
    });

    test('throws ApiException on non-200', () async {
      final mock = MockClient((req) async => http.Response('err', 503));
      final client = WikimediaPhotoClient(userAgent: 'ua', client: mock);
      expect(() => client.photosNear(lat: 0, lng: 0), throwsA(isA<ApiException>()));
    });
  });
}
