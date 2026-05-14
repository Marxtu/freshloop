import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:freshloop/data/photos/mapillary_client.dart';
import 'package:freshloop/data/photos/wikimedia_client.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/services/photo_service.dart';

const _geo = RouteGeometry(
  points: [RoutePoint(lat: 45.46, lng: 9.19), RoutePoint(lat: 45.47, lng: 9.20)],
  distanceM: 5000,
  ascentM: 40,
);

void main() {
  group('PhotoService.photosForRoute', () {
    test('merges Mapillary + Wikimedia photos and dedups by url', () async {
      final mapillary = MapillaryPhotoClient(
        accessToken: 't',
        client: MockClient((req) async => http.Response(
            jsonEncode({'data': [
              {'id': '1', 'thumb_256_url': 'https://img/dup.jpg', 'computed_geometry': {'coordinates': [9.19, 45.46]}},
            ]}), 200)),
      );
      final wikimedia = WikimediaPhotoClient(
        userAgent: 'ua',
        client: MockClient((req) async => http.Response(
            jsonEncode({'query': {'geosearch': [
              {'title': 'File:Park.jpg', 'lat': 45.46, 'lon': 9.19},
            ]}}), 200)),
      );
      final svc = PhotoService(mapillary: mapillary, wikimedia: wikimedia);

      final photos = await svc.photosForRoute(_geo, maxWaypoints: 1, perSource: 2);

      expect(photos, isNotEmpty);
      final urls = photos.map((p) => p.url).toList();
      expect(urls.toSet().length, urls.length); // no duplicate urls
    });

    test('degrades to whatever succeeds when a source fails', () async {
      final mapillary = MapillaryPhotoClient(
        accessToken: 't',
        client: MockClient((req) async => http.Response('boom', 500)),
      );
      final wikimedia = WikimediaPhotoClient(
        userAgent: 'ua',
        client: MockClient((req) async => http.Response(
            jsonEncode({'query': {'geosearch': [
              {'title': 'File:Park.jpg', 'lat': 45.46, 'lon': 9.19},
            ]}}), 200)),
      );
      final svc = PhotoService(mapillary: mapillary, wikimedia: wikimedia);
      final photos = await svc.photosForRoute(_geo, maxWaypoints: 1);
      expect(photos.length, 1); // Mapillary failed; Wikimedia still returned one
    });
  });
}
