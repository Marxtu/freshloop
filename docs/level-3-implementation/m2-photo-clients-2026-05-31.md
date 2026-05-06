# FreshLoop M2.3 — Photo Clients (Mapillary + Wikimedia) · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Build the along-route scenery-photo clients — **Mapillary** (street-level imagery in a bbox) and **Wikimedia Commons** (geolocated File: media near a point) — each returning a common `ScenePhoto` model, TDD'd with mocked HTTP.

**Architecture:** Same as M2.1/M2.2 — `lib/data/` clients take an injectable `http.Client`, parse into pure-Dart models, throw `ApiException` on non-200. No new dependencies.

**Tech Stack:** Flutter, `http` (+ `package:http/testing.dart`).

**Design SSOT:** [FreshLoop system design](../level-2-architecture/running-route-generator-2026-05-30.md) §5 (photo services), §8 (`ScenePhoto`), §11 (graceful degradation — no photos → empty list).

**Verified API shapes:**
- **Wikimedia Commons geosearch** (keyless, live-verified): `GET https://commons.wikimedia.org/w/api.php?action=query&list=geosearch&gscoord=<lat>|<lng>&gsradius=<m>&gslimit=<n>&gsnamespace=6&format=json` → `{"query":{"geosearch":[{"pageid":..,"title":"File:Name.jpg","lat":..,"lon":..,"dist":..}]}}`. A displayable thumbnail is built directly from the title via `https://commons.wikimedia.org/wiki/Special:FilePath/<urlencoded filename>?width=<w>` (verified to 200 → real image). Requires a `User-Agent`.
- **Mapillary** (token via `Authorization: OAuth` header; shape from docs — live API was intermittently returning transient 5xx during dev, so it is mock-tested here and live-validated at M3): `GET https://graph.mapillary.com/images?bbox=<west,south,east,north>&fields=id,thumb_256_url,computed_geometry&limit=<n>` → `{"data":[{"id":"..","thumb_256_url":"https://..","computed_geometry":{"type":"Point","coordinates":[lng,lat]}}]}`.

**Notes for the implementer:** Flutter at `$HOME/flutter/bin/flutter` if not on PATH. English, Conventional Commits, no AI/tooling attribution, per-task commits. Touch only the files named. No `package:flutter/` import under `lib/data/`.

---

## File Structure (created in M2.3)

```
lib/data/photos/
  scene_photo.dart                  # PhotoSource enum + ScenePhoto (fromMapillaryJson, fromWikimediaGeosearch)
  mapillary_client.dart             # MapillaryPhotoClient.photosInBbox(...)
  wikimedia_client.dart             # WikimediaPhotoClient.photosNear(...)
test/data/photos/
  scene_photo_test.dart
  mapillary_client_test.dart
  wikimedia_client_test.dart
```

---

## Task 1: ScenePhoto model

**Files:** Create `lib/data/photos/scene_photo.dart`, `test/data/photos/scene_photo_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/data/photos/scene_photo_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/data/photos/scene_photo.dart';

void main() {
  group('ScenePhoto.fromMapillaryJson', () {
    test('parses thumb url and coordinates ([lng, lat])', () {
      final p = ScenePhoto.fromMapillaryJson({
        'id': '123',
        'thumb_256_url': 'https://img.example/256.jpg',
        'computed_geometry': {'type': 'Point', 'coordinates': [13.38, 52.51]},
      });
      expect(p.url, 'https://img.example/256.jpg');
      expect(p.source, PhotoSource.mapillary);
      expect(p.lng, 13.38);
      expect(p.lat, 52.51);
    });
  });

  group('ScenePhoto.fromWikimediaGeosearch', () {
    test('builds a Special:FilePath thumbnail url from the File title', () {
      final p = ScenePhoto.fromWikimediaGeosearch(
        {'title': 'File:Brandenburg Gate.jpg', 'lat': 52.5163, 'lon': 13.3777},
        width: 400,
      );
      expect(p.source, PhotoSource.wikimedia);
      expect(p.lat, 52.5163);
      expect(p.lng, 13.3777);
      expect(p.caption, 'Brandenburg Gate.jpg');
      expect(
        p.url,
        'https://commons.wikimedia.org/wiki/Special:FilePath/Brandenburg%20Gate.jpg?width=400',
      );
    });
  });
}
```

- [ ] **Step 2: Run to verify failure** — `flutter test test/data/photos/scene_photo_test.dart` → FAIL.

- [ ] **Step 3: Implement**

Create `lib/data/photos/scene_photo.dart`:
```dart
/// Where a scenery photo came from.
enum PhotoSource { mapillary, wikimedia }

/// A photo shown along a route (design doc §8). [url] is a directly displayable
/// thumbnail; [lat]/[lng] locate it; [caption] is optional.
class ScenePhoto {
  final String url;
  final PhotoSource source;
  final double lat;
  final double lng;
  final String? caption;

  const ScenePhoto({
    required this.url,
    required this.source,
    required this.lat,
    required this.lng,
    this.caption,
  });

  /// Parses one Mapillary `images` entry. `computed_geometry.coordinates` is
  /// `[lng, lat]`.
  factory ScenePhoto.fromMapillaryJson(Map<String, dynamic> json) {
    final coords = ((json['computed_geometry'] as Map<String, dynamic>?)?['coordinates']
            as List?) ??
        const [0, 0];
    return ScenePhoto(
      url: json['thumb_256_url'] as String,
      source: PhotoSource.mapillary,
      lng: (coords[0] as num).toDouble(),
      lat: (coords[1] as num).toDouble(),
    );
  }

  /// Builds a photo from one Wikimedia Commons geosearch result. The thumbnail
  /// URL is derived from the File title via Special:FilePath (no extra request).
  factory ScenePhoto.fromWikimediaGeosearch(Map<String, dynamic> json, {int width = 400}) {
    final filename = (json['title'] as String).replaceFirst('File:', '');
    final encoded = Uri.encodeComponent(filename);
    return ScenePhoto(
      url: 'https://commons.wikimedia.org/wiki/Special:FilePath/$encoded?width=$width',
      source: PhotoSource.wikimedia,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lon'] as num).toDouble(),
      caption: filename,
    );
  }
}
```

- [ ] **Step 4: Run to verify pass** — PASS (2).

- [ ] **Step 5: Analyze + commit**
```bash
flutter analyze
git add lib/data/photos/scene_photo.dart test/data/photos/scene_photo_test.dart
git commit -m "feat: add ScenePhoto model with Mapillary/Wikimedia factories

Common photo model for along-route scenery; build a displayable thumbnail URL
from a Wikimedia File title via Special:FilePath, and parse Mapillary geometry."
```

---

## Task 2: Mapillary photo client

**Files:** Create `lib/data/photos/mapillary_client.dart`, `test/data/photos/mapillary_client_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/data/photos/mapillary_client_test.dart`:
```dart
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
```

- [ ] **Step 2: Run to verify failure** — FAIL.

- [ ] **Step 3: Implement**

Create `lib/data/photos/mapillary_client.dart`:
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_exception.dart';
import 'scene_photo.dart';

/// Client for Mapillary street-level imagery (design doc §5). The token goes in
/// the `Authorization: OAuth <token>` header. Inject [client] in tests.
class MapillaryPhotoClient {
  final http.Client _client;
  final String accessToken;

  MapillaryPhotoClient({required this.accessToken, http.Client? client})
      : _client = client ?? http.Client();

  /// Fetches up to [limit] photos within the bbox. Throws [ApiException] on non-200.
  Future<List<ScenePhoto>> photosInBbox({
    required double south,
    required double west,
    required double north,
    required double east,
    int limit = 5,
  }) async {
    final uri = Uri.https('graph.mapillary.com', '/images', {
      'bbox': '$west,$south,$east,$north',
      'fields': 'id,thumb_256_url,computed_geometry',
      'limit': '$limit',
    });
    final resp = await _client.get(uri, headers: {'Authorization': 'OAuth $accessToken'});
    if (resp.statusCode != 200) {
      throw ApiException('Mapillary', resp.statusCode, resp.body);
    }
    final data = ((jsonDecode(resp.body) as Map<String, dynamic>)['data'] as List?) ?? const [];
    return data
        .map((e) => ScenePhoto.fromMapillaryJson(e as Map<String, dynamic>))
        .toList();
  }
}
```

- [ ] **Step 4: Run to verify pass** — PASS (3).

- [ ] **Step 5: Analyze + commit**
```bash
flutter analyze
git add lib/data/photos/mapillary_client.dart test/data/photos/mapillary_client_test.dart
git commit -m "feat: add Mapillary street-level photo client

Query images in a bbox with the OAuth token header and parse them into
ScenePhoto; throw ApiException on non-200."
```

---

## Task 3: Wikimedia Commons photo client

**Files:** Create `lib/data/photos/wikimedia_client.dart`, `test/data/photos/wikimedia_client_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/data/photos/wikimedia_client_test.dart`:
```dart
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
```

- [ ] **Step 2: Run to verify failure** — FAIL.

- [ ] **Step 3: Implement**

Create `lib/data/photos/wikimedia_client.dart`:
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_exception.dart';
import 'scene_photo.dart';

/// Client for Wikimedia Commons geosearch (design doc §5). Finds geolocated
/// File: media near a point; thumbnails are derived from titles (see
/// [ScenePhoto.fromWikimediaGeosearch]). Requires a descriptive User-Agent.
class WikimediaPhotoClient {
  final http.Client _client;
  final String userAgent;

  WikimediaPhotoClient({required this.userAgent, http.Client? client})
      : _client = client ?? http.Client();

  /// Fetches up to [limit] geolocated photos within [radiusM] of ([lat],[lng]).
  /// Returns an empty list when none are found; throws [ApiException] on non-200.
  Future<List<ScenePhoto>> photosNear({
    required double lat,
    required double lng,
    int radiusM = 500,
    int limit = 5,
  }) async {
    final uri = Uri.https('commons.wikimedia.org', '/w/api.php', {
      'action': 'query',
      'list': 'geosearch',
      'gscoord': '$lat|$lng',
      'gsradius': '$radiusM',
      'gslimit': '$limit',
      'gsnamespace': '6',
      'format': 'json',
    });
    final resp = await _client.get(uri, headers: {'User-Agent': userAgent});
    if (resp.statusCode != 200) {
      throw ApiException('Wikimedia', resp.statusCode, resp.body);
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final results = ((decoded['query'] as Map<String, dynamic>?)?['geosearch'] as List?) ?? const [];
    return results
        .map((e) => ScenePhoto.fromWikimediaGeosearch(e as Map<String, dynamic>))
        .toList();
  }
}
```

- [ ] **Step 4: Run to verify pass** — PASS (3).

- [ ] **Step 5: Analyze + commit**
```bash
flutter analyze
git add lib/data/photos/wikimedia_client.dart test/data/photos/wikimedia_client_test.dart
git commit -m "feat: add Wikimedia Commons photo client

Geosearch File: media near a point and map results to ScenePhoto (thumbnail via
Special:FilePath); return empty on none, throw ApiException on non-200."
```

---

## Task 4: Final verification

- [ ] **Step 1:** `flutter test` → expect 43 (after M2.2) + 8 new (scene_photo 2 + mapillary 3 + wikimedia 3) = **51 tests**, all passing.
- [ ] **Step 2:** `flutter analyze` → clean.
- [ ] **Step 3:** `git status` clean; no `package:flutter/` under `lib/data/`; no real secrets tracked.

---

## Self-Review (completed by author)

**Spec coverage:** §5 Mapillary → Task 2; §5 Wikimedia → Task 3; §8 `ScenePhoto` → Task 1; §11 degradation (no photos → empty list; non-200 → ApiException) → Tasks 2-3. With this, the full external-service stack from design §5 is implemented except live wiring (M3).

**Placeholder scan:** none — complete code, live-verified Wikimedia shape (incl. Special:FilePath thumbnail), documented Mapillary shape, exact expected values.

**Type consistency:** `PhotoSource` enum + `ScenePhoto` factories (Task 1) used by both clients (Tasks 2-3); `MapillaryPhotoClient({accessToken, client})`/`photosInBbox({south,west,north,east,limit})` and `WikimediaPhotoClient({userAgent, client})`/`photosNear({lat,lng,radiusM,limit})` match their tests; `ApiException` reused from M2.1; Mapillary bbox order `west,south,east,north` consistent between client and test.

**Live-validation note:** Wikimedia geosearch + Special:FilePath are live-verified; Mapillary is mock-tested (transient live 5xx during dev) and validated at M3.
