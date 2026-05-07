import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:freshloop/data/api_exception.dart';
import 'package:freshloop/data/photos/mapillary_client.dart';
import 'package:freshloop/data/photos/scene_photo.dart';

void main() {
  group('MapillaryPhotoClient.photosInBbox', () {
    test('sends OAuth header + bbox and parses photos', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': '1',
                'thumb_256_url': 'https://img/1.jpg',
                'computed_geometry': {'coordinates': [13.38, 52.51]},
              },
            ],
          }),
          200,
        );
      });
      final client = MapillaryPhotoClient(accessToken: 'MLY|x|y', client: mock);

      final photos = await client.photosInBbox(south: 52.5, west: 13.3, north: 52.6, east: 13.4, limit: 5);

      expect(photos.length, 1);
      expect(photos.first.url, 'https://img/1.jpg');
      expect(photos.first.source, PhotoSource.mapillary);
      expect(captured.headers['Authorization'], 'OAuth MLY|x|y');
      // Mapillary bbox order is west,south,east,north
      expect(captured.url.queryParameters['bbox'], '13.3,52.5,13.4,52.6');
      expect(captured.url.queryParameters['limit'], '5');
    });

    test('returns empty list when data is empty', () async {
      final mock = MockClient((req) async => http.Response(jsonEncode({'data': []}), 200));
      final client = MapillaryPhotoClient(accessToken: 't', client: mock);
      expect(await client.photosInBbox(south: 0, west: 0, north: 1, east: 1), isEmpty);
    });

    test('throws ApiException on non-200', () async {
      final mock = MockClient((req) async => http.Response('err', 500));
      final client = MapillaryPhotoClient(accessToken: 't', client: mock);
      expect(
        () => client.photosInBbox(south: 0, west: 0, north: 1, east: 1),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
