# FreshLoop M2.2 — Enrichment Clients (Air + Greenery) · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Build the two scoring-data clients still missing after M2.1: the **Open-Meteo Air Quality** client (AQI samples along a route) and the **OSM Overpass** greenery client (green-area and scenic-POI counts feeding the greenery ratio), each TDD'd with mocked HTTP.

**Architecture:** Same as M2.1: `lib/data/` clients take an injectable `http.Client`, return pure-Dart models with `fromJson` factories, and throw `ApiException` (from M2.1) on non-200. No new dependencies.

**Tech Stack:** Flutter, `http` (+ `package:http/testing.dart`).

**Design SSOT:** [FreshLoop system design](../level-2-architecture/running-route-generator-2026-05-30.md) §5 (external services), §6 (scoring inputs), §11 (degradation).

**Decisions baked into this plan:**
- **No elevation client.** ORS already returns per-point elevation + cumulative `ascentM` (M2.1 `RouteGeometry`, requested with `elevation:true`), so a separate Open-Meteo elevation client would be redundant. The elevation scoring input comes from ORS.
- **Greenery ratio is a documented heuristic proxy** (count of green features in the route's bounding box, normalized), not a true area-coverage computation. It is adequate for the scenery axis at this stage and refinable later.

**Verified API shapes (probed live, keyless):**
- Open-Meteo Air Quality: multiple comma-joined coords return a JSON array of `{... "current": {"european_aqi": <num>}}`; a single coord returns a JSON object of the same shape. Endpoint `https://air-quality-api.open-meteo.com/v1/air-quality`.
- Overpass (shape from docs; live calls were network-blocked in the dev container and will be validated at M3): `{"elements": [ {"type":"way|node","id":..,"tags":{...}}, ... ]}`. Overpass requires a descriptive `User-Agent`.

**Notes for the implementer:** Flutter at `$HOME/flutter/bin/flutter` if not on PATH. English, Conventional Commits, no AI/tooling attribution, small per-task commits. Touch only the files named. No `package:flutter/` import under `lib/data/`.

---

## File Structure (created in M2.2)

```
lib/data/
  air/
    open_meteo_air_client.dart          # OpenMeteoAirClient.sampleAqi(List<RoutePoint>) -> List<double>
  greenery/
    greenery_data.dart                  # GreeneryData (fromOverpassJson, greenRatio, scenicWaypoints)
    overpass_client.dart                # OverpassClient.fetchGreenery(bbox) -> GreeneryData
test/data/
  air/open_meteo_air_client_test.dart
  greenery/greenery_data_test.dart
  greenery/overpass_client_test.dart
```

---

## Task 1: Open-Meteo Air Quality client

**Files:** Create `lib/data/air/open_meteo_air_client.dart`, `test/data/air/open_meteo_air_client_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/data/air/open_meteo_air_client_test.dart`:
```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:freshloop/data/api_exception.dart';
import 'package:freshloop/data/air/open_meteo_air_client.dart';
import 'package:freshloop/data/routing/route_geometry.dart';

void main() {
  group('OpenMeteoAirClient.sampleAqi', () {
    const points = [
      RoutePoint(lat: 52.5, lng: 13.4),
      RoutePoint(lat: 48.1, lng: 11.6),
    ];

    test('parses european_aqi from a multi-point (array) response', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode([
            {'current': {'european_aqi': 34}},
            {'current': {'european_aqi': 30}},
          ]),
          200,
        );
      });
      final client = OpenMeteoAirClient(client: mock);

      final aqi = await client.sampleAqi(points);

      expect(aqi, [34.0, 30.0]);
      expect(captured.url.queryParameters['latitude'], '52.5,48.1');
      expect(captured.url.queryParameters['longitude'], '13.4,11.6');
      expect(captured.url.queryParameters['current'], 'european_aqi');
    });

    test('normalizes a single-point (object) response into a list', () async {
      final mock = MockClient((req) async =>
          http.Response(jsonEncode({'current': {'european_aqi': 42}}), 200));
      final client = OpenMeteoAirClient(client: mock);
      final aqi = await client.sampleAqi(const [RoutePoint(lat: 1, lng: 2)]);
      expect(aqi, [42.0]);
    });

    test('returns empty list for no points without calling the network', () async {
      var called = false;
      final mock = MockClient((req) async {
        called = true;
        return http.Response('[]', 200);
      });
      final client = OpenMeteoAirClient(client: mock);
      expect(await client.sampleAqi(const []), isEmpty);
      expect(called, isFalse);
    });

    test('throws ApiException on non-200', () async {
      final mock = MockClient((req) async => http.Response('boom', 500));
      final client = OpenMeteoAirClient(client: mock);
      expect(() => client.sampleAqi(points), throwsA(isA<ApiException>()));
    });
  });
}
```

- [ ] **Step 2: Run to verify failure.** Run `flutter test test/data/air/open_meteo_air_client_test.dart`; it should FAIL (URI missing).

- [ ] **Step 3: Implement**

Create `lib/data/air/open_meteo_air_client.dart`:
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_exception.dart';
import '../routing/route_geometry.dart';

/// Client for the Open-Meteo Air Quality API (design doc §5). Returns the
/// European AQI sampled at each given point (lower is better). Keyless.
/// Inject [client] in tests; defaults to a real [http.Client].
class OpenMeteoAirClient {
  final http.Client _client;

  OpenMeteoAirClient({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches the current European AQI at each of [points], aligned by index.
  /// Returns an empty list (no network call) when [points] is empty.
  /// Throws [ApiException] on a non-200 response.
  Future<List<double>> sampleAqi(List<RoutePoint> points) async {
    if (points.isEmpty) return const [];
    final uri = Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
      'latitude': points.map((p) => p.lat).join(','),
      'longitude': points.map((p) => p.lng).join(','),
      'current': 'european_aqi',
    });
    final resp = await _client.get(uri);
    if (resp.statusCode != 200) {
      throw ApiException('Open-Meteo Air', resp.statusCode, resp.body);
    }
    final decoded = jsonDecode(resp.body);
    // Multiple coords -> array; single coord -> object. Normalize to a list.
    final list = decoded is List ? decoded : [decoded];
    return list
        .map((e) => ((e as Map<String, dynamic>)['current']
            as Map<String, dynamic>)['european_aqi'] as num)
        .map((n) => n.toDouble())
        .toList();
  }
}
```

- [ ] **Step 4: Run to verify pass.** Run `flutter test test/data/air/open_meteo_air_client_test.dart`; expect PASS (4).

- [ ] **Step 5: Analyze + commit**
```bash
flutter analyze
git add lib/data/air/ test/data/air/
git commit -m "feat: add Open-Meteo air-quality client

Sample European AQI at each route point in one keyless request, normalizing
the single-point object and multi-point array response shapes."
```

---

## Task 2: GreeneryData model

**Files:** Create `lib/data/greenery/greenery_data.dart`, `test/data/greenery/greenery_data_test.dart`

Classification from OSM tags:
- **green** if tags contain `leisure=park`, or `landuse` in {forest, grass, meadow, recreation_ground, village_green}, or `natural` in {wood, water, grassland, scrub}.
- **scenic** if tags contain `tourism` in {viewpoint, attraction}, or `natural=peak`, or any `historic` key.

Proxy outputs: `greenRatio = (greenCount / 8).clamp(0, 1)`; `scenicWaypoints = scenicCount`.

- [ ] **Step 1: Write the failing test**

Create `test/data/greenery/greenery_data_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/data/greenery/greenery_data.dart';

void main() {
  group('GreeneryData.fromOverpassJson', () {
    test('counts green features and scenic POIs by tag', () {
      final json = {
        'elements': [
          {'type': 'way', 'tags': {'leisure': 'park'}},
          {'type': 'way', 'tags': {'landuse': 'forest'}},
          {'type': 'way', 'tags': {'natural': 'water'}},
          {'type': 'node', 'tags': {'tourism': 'viewpoint'}},
          {'type': 'node', 'tags': {'historic': 'monument'}},
          {'type': 'node', 'tags': {'amenity': 'bench'}}, // neither
        ],
      };
      final g = GreeneryData.fromOverpassJson(json);
      expect(g.greenCount, 3); // park, forest, water
      expect(g.scenicCount, 2); // viewpoint, monument(historic)
    });

    test('greenRatio normalizes against 8 and clamps to 1', () {
      expect(const GreeneryData(greenCount: 0, scenicCount: 0).greenRatio, 0);
      expect(const GreeneryData(greenCount: 4, scenicCount: 1).greenRatio, 0.5);
      expect(const GreeneryData(greenCount: 8, scenicCount: 0).greenRatio, 1);
      expect(const GreeneryData(greenCount: 20, scenicCount: 0).greenRatio, 1);
    });

    test('scenicWaypoints passes the scenic count through', () {
      expect(const GreeneryData(greenCount: 0, scenicCount: 3).scenicWaypoints, 3);
    });

    test('handles missing elements key', () {
      final g = GreeneryData.fromOverpassJson(const {});
      expect(g.greenCount, 0);
      expect(g.scenicCount, 0);
    });
  });
}
```

- [ ] **Step 2: Run to verify failure.** Run `flutter test test/data/greenery/greenery_data_test.dart`; it should FAIL.

- [ ] **Step 3: Implement**

Create `lib/data/greenery/greenery_data.dart`:
```dart
/// Greenery assessment for a route corridor, derived from OSM/Overpass features.
/// [greenRatio] and [scenicWaypoints] are the scoring inputs (design doc §6);
/// the ratio is a documented heuristic proxy (green-feature count normalized),
/// not a true area-coverage measurement.
class GreeneryData {
  final int greenCount;
  final int scenicCount;

  const GreeneryData({required this.greenCount, required this.scenicCount});

  /// 0..1 proxy: ~8 green features in the corridor is treated as "fully green".
  double get greenRatio => (greenCount / 8).clamp(0, 1).toDouble();

  /// Scenic points passed (the scoring layer caps the useful range).
  int get scenicWaypoints => scenicCount;

  static const _greenLanduse = {'forest', 'grass', 'meadow', 'recreation_ground', 'village_green'};
  static const _greenNatural = {'wood', 'water', 'grassland', 'scrub'};
  static const _scenicTourism = {'viewpoint', 'attraction'};

  /// Counts green features and scenic POIs from an Overpass `out:json` response.
  factory GreeneryData.fromOverpassJson(Map<String, dynamic> json) {
    final elements = (json['elements'] as List?) ?? const [];
    var green = 0;
    var scenic = 0;
    for (final e in elements) {
      final tags = ((e as Map<String, dynamic>)['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
      if (tags['leisure'] == 'park' ||
          _greenLanduse.contains(tags['landuse']) ||
          _greenNatural.contains(tags['natural'])) {
        green++;
      }
      if (_scenicTourism.contains(tags['tourism']) ||
          tags['natural'] == 'peak' ||
          tags.containsKey('historic')) {
        scenic++;
      }
    }
    return GreeneryData(greenCount: green, scenicCount: scenic);
  }
}
```

- [ ] **Step 4: Run to verify pass.** Run `flutter test test/data/greenery/greenery_data_test.dart`; expect PASS (4).

- [ ] **Step 5: Analyze + commit**
```bash
flutter analyze
git add lib/data/greenery/greenery_data.dart test/data/greenery/greenery_data_test.dart
git commit -m "feat: add GreeneryData model with green/scenic tag classification

Classify Overpass elements into green features and scenic POIs and expose the
scenery scoring inputs (greenRatio proxy + scenicWaypoints)."
```

---

## Task 3: Overpass greenery client

**Files:** Create `lib/data/greenery/overpass_client.dart`, `test/data/greenery/overpass_client_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/data/greenery/overpass_client_test.dart`:
```dart
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
      // bbox order in the query body is south,west,north,east
      expect(captured.body, contains('52.5,13.3,52.6,13.4'));
      expect(captured.body, contains('[out:json]'));
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
```

- [ ] **Step 2: Run to verify failure.** Run `flutter test test/data/greenery/overpass_client_test.dart`; it should FAIL.

- [ ] **Step 3: Implement**

Create `lib/data/greenery/overpass_client.dart`:
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_exception.dart';
import 'greenery_data.dart';

/// Client for the OSM Overpass API (design doc §5). Fetches green areas and
/// scenic POIs within a bounding box. Overpass requires a descriptive
/// User-Agent. Inject [client] in tests; defaults to a real [http.Client].
class OverpassClient {
  final http.Client _client;
  final String userAgent;

  OverpassClient({required this.userAgent, http.Client? client})
      : _client = client ?? http.Client();

  static final Uri _endpoint = Uri.parse('https://overpass-api.de/api/interpreter');

  /// Queries green/scenic features inside the bbox ([south],[west],[north],[east])
  /// and returns a [GreeneryData] count summary. Throws [ApiException] on non-200.
  Future<GreeneryData> fetchGreenery({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    final bbox = '$south,$west,$north,$east';
    final query = '[out:json][timeout:25];'
        '('
        'way["leisure"="park"]($bbox);'
        'way["landuse"~"forest|grass|meadow|recreation_ground|village_green"]($bbox);'
        'way["natural"~"wood|water|grassland|scrub"]($bbox);'
        'node["tourism"~"viewpoint|attraction"]($bbox);'
        'node["natural"="peak"]($bbox);'
        'node["historic"]($bbox);'
        ');out tags;';
    final resp = await _client.post(
      _endpoint,
      headers: {'User-Agent': userAgent, 'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'data': query},
    );
    if (resp.statusCode != 200) {
      throw ApiException('Overpass', resp.statusCode, resp.body);
    }
    return GreeneryData.fromOverpassJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }
}
```

- [ ] **Step 4: Run to verify pass.** Run `flutter test test/data/greenery/overpass_client_test.dart`; expect PASS (2).

- [ ] **Step 5: Analyze + commit**
```bash
flutter analyze
git add lib/data/greenery/overpass_client.dart test/data/greenery/overpass_client_test.dart
git commit -m "feat: add Overpass greenery client

Query green areas and scenic POIs in a bounding box (with the required
User-Agent) and parse them into GreeneryData; throw ApiException on non-200."
```

---

## Task 4: Final verification

- [ ] **Step 1:** Run `flutter test`; expect 33 (after M2.1) + 10 new (air 4 + greenery_data 4 + overpass 2) = 43 tests, all passing.
- [ ] **Step 2:** Run `flutter analyze`; expect it clean.
- [ ] **Step 3:** `git status` clean; no `package:flutter/` under `lib/data/`; no real secrets tracked.

---

## Self-Review (completed by author)

**Spec coverage:** §5 air quality → Task 1; §5 greenery/Overpass → Tasks 2-3; §6 scenery scoring inputs (greenRatio + scenicWaypoints) → Task 2 getters; §11 degradation (non-200 → ApiException; empty points → empty list) → Tasks 1-3. Elevation input intentionally sourced from ORS (M2.1), not a new client, as documented above.

**Placeholder scan:** none. Complete code, real verified Open-Meteo shape, documented Overpass shape, exact expected values.

**Type consistency:** `OpenMeteoAirClient({client})` + `sampleAqi(List<RoutePoint>)` (RoutePoint from M2.1) match tests; `GreeneryData({greenCount, scenicCount})` + `fromOverpassJson` + getters match between model, client, and tests; `OverpassClient({userAgent, client})` + `fetchGreenery({south,west,north,east})` match tests; `ApiException(service, statusCode, body)` reused from M2.1.

**Live-validation note:** clients tested against mocks only. Open-Meteo air shape is live-verified; Overpass was network-blocked in the dev container, so its live call is validated at M3 (the well-known `elements[]` shape is mocked here).
