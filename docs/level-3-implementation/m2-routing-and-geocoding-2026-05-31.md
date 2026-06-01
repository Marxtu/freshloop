# FreshLoop M2.1 — Config + Routing + Geocoding · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first slice of the external data layer: app config (API keys via dart-define), a shared API-error type plus an injectable HTTP client convention, the OpenRouteService round-trip **routing** client, and the Nominatim **geocoding** client, each fully unit-tested with mocked HTTP.

**Architecture:** `lib/data/` holds API clients. Each client takes an injectable `http.Client` (defaulting to a real one) so tests inject `MockClient` from `package:http/testing.dart` (part of the `http` package, so no new dependency). Clients return pure-Dart domain models (`fromJson` factories) and throw a shared `ApiException` on non-200. Keys are read via `String.fromEnvironment` (compile-time, from `--dart-define-from-file=secrets.json`); tests pass keys directly so no env is needed.

**Tech Stack:** Flutter, `http` (+ `package:http/testing.dart`), Dart.

**Design SSOT:** [FreshLoop system design](../level-2-architecture/running-route-generator-2026-05-30.md). External services §5, architecture/data-flow §7, data models §8, error handling §11, secrets §13.7.

**Scope of M2.1:** config + ORS routing + Nominatim geocoding only. The enrichment clients (Open-Meteo air/elevation, OSM Overpass greenery) are **M2.2**; photo clients (Mapillary, Wikimedia) are **M2.3**; assembling everything into `RouteScoreInputs` for the M1 scorer is **M3**. Out of scope here.

**Notes for the implementer:**
- Flutter at `$HOME/flutter/bin/flutter` if not on PATH. Run tests with `flutter test`.
- Real keys live in gitignored `secrets.json` (already present locally). NEVER commit real keys; only the `secrets.example.json` template is committed.
- All commit messages and code comments in **English**, Conventional Commits, no AI/assistant/tooling attribution or co-author trailers. Small per-task commits.
- Do not touch `.cc-connect/`, `secrets.json`, or unrelated files.

---

## File Structure (created in M2.1)

```
secrets.example.json                       # committed template (real secrets.json is gitignored)
.gitignore                                 # allow secrets.example.json
lib/
  app/
    app_config.dart                        # AppConfig: reads ORS_API_KEY / nominatim UA via String.fromEnvironment
  data/
    api_exception.dart                     # ApiException (service, statusCode, body)
    routing/
      route_geometry.dart                  # RoutePoint, RouteGeometry (+ fromOrsGeoJson)
      ors_route_client.dart                # OrsRouteClient.roundTrip(...)
    geocoding/
      geo_place.dart                       # GeoPlace (+ fromNominatimJson)
      nominatim_client.dart                # NominatimClient.search(query)
test/
  data/
    routing/
      route_geometry_test.dart
      ors_route_client_test.dart
    geocoding/
      nominatim_client_test.dart
```

---

## Task 1: App config (API keys via dart-define) + committed template

**Files:**
- Create: `lib/app/app_config.dart`, `secrets.example.json`
- Modify: `.gitignore` (allow the example), `README.md` (config note)

- [ ] **Step 1: Create the committed template `secrets.example.json`**

```json
{
  "ORS_API_KEY": "your-openrouteservice-api-key",
  "MAPILLARY_TOKEN": "MLY|your-app-id|your-access-token"
}
```

- [ ] **Step 2: Allow the example in `.gitignore`**

The repo ignores `**/secrets.json`. Add an explicit allow for the template so it is tracked. Append to `.gitignore`:
```
# Allow the committed secrets template (real secrets.json stays ignored)
!secrets.example.json
```

- [ ] **Step 3: Create `lib/app/app_config.dart`**

```dart
/// Compile-time configuration. Values come from `--dart-define-from-file=secrets.json`
/// (gitignored). Empty strings mean the key was not provided — clients that need a
/// key should fail clearly rather than calling an API unauthenticated.
class AppConfig {
  const AppConfig._();

  /// OpenRouteService API key (sent as the `Authorization` header).
  static const String orsApiKey = String.fromEnvironment('ORS_API_KEY');

  /// Contact string used in the required Nominatim `User-Agent` header.
  /// See https://operations.osmfoundation.org/policies/nominatim/
  static const String nominatimUserAgent =
      String.fromEnvironment('NOMINATIM_USER_AGENT', defaultValue: 'FreshLoop/0.1 (course project)');
}
```

- [ ] **Step 4: Add a config note to `README.md`**

Under the existing "Secrets" section, append:
```markdown

To run against live APIs, copy the template and fill in your keys, then pass it at run/build time:

\`\`\`bash
cp secrets.example.json secrets.json   # secrets.json is gitignored
flutter run --dart-define-from-file=secrets.json
\`\`\`
```
(Use a real fenced block in the README; the `\`\`\`` above is escaped only for this plan.)

- [ ] **Step 5: Verify analysis is clean and commit**

Run: `flutter analyze`; expect "No issues found!".
```bash
git add lib/app/app_config.dart secrets.example.json .gitignore README.md
git commit -m "feat: add app config for API keys via dart-define

Read keys from --dart-define-from-file at compile time, commit a secrets
template, and document the run command. Real secrets.json stays gitignored."
```

---

## Task 2: Shared `ApiException`

**Files:**
- Create: `lib/data/api_exception.dart`
- Test: covered indirectly by client tests (Task 3/4); no dedicated test needed for a plain data-holding exception.

- [ ] **Step 1: Create `lib/data/api_exception.dart`**

```dart
/// Thrown when an external API returns a non-success response.
/// Carries enough context for callers to degrade gracefully (design doc §11).
class ApiException implements Exception {
  final String service;
  final int statusCode;
  final String body;

  ApiException(this.service, this.statusCode, this.body);

  @override
  String toString() => 'ApiException($service, status=$statusCode): $body';
}
```

- [ ] **Step 2: Analyze + commit**

Run: `flutter analyze`; expect it clean.
```bash
git add lib/data/api_exception.dart
git commit -m "feat: add ApiException for non-200 API responses"
```

---

## Task 3: OpenRouteService round-trip routing client

**Files:**
- Create: `lib/data/routing/route_geometry.dart`, `lib/data/routing/ors_route_client.dart`
- Test: `test/data/routing/route_geometry_test.dart`, `test/data/routing/ors_route_client_test.dart`

ORS round-trip request: `POST https://api.openrouteservice.org/v2/directions/foot-walking/geojson` with header `Authorization: <key>`, body `{"coordinates":[[lng,lat]],"elevation":true,"options":{"round_trip":{"length":<m>,"points":5,"seed":<n>}}}`. Response is GeoJSON: `features[0].geometry.coordinates` = `[[lng,lat,elev],...]`; `features[0].properties.summary.distance` (metres); `features[0].properties.ascent` (metres).

- [ ] **Step 1: Write the failing model test**

Create `test/data/routing/route_geometry_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/data/routing/route_geometry.dart';

void main() {
  group('RouteGeometry.fromOrsGeoJson', () {
    final json = {
      'features': [
        {
          'geometry': {
            'coordinates': [
              [8.681, 49.414, 110.0],
              [8.682, 49.415, 115.0],
              [8.681, 49.414, 110.0],
            ],
          },
          'properties': {
            'ascent': 42.0,
            'summary': {'distance': 5012.3, 'duration': 3600.0},
          },
        },
      ],
    };

    test('parses points (lng,lat,elev), distance and ascent', () {
      final g = RouteGeometry.fromOrsGeoJson(json);
      expect(g.points.length, 3);
      expect(g.points.first.lat, 49.414);
      expect(g.points.first.lng, 8.681);
      expect(g.points.first.elevation, 110.0);
      expect(g.distanceM, 5012.3);
      expect(g.ascentM, 42.0);
    });

    test('defaults ascent to 0 when absent', () {
      final j = {
        'features': [
          {
            'geometry': {'coordinates': [[8.0, 49.0]]},
            'properties': {'summary': {'distance': 100.0}},
          },
        ],
      };
      final g = RouteGeometry.fromOrsGeoJson(j);
      expect(g.ascentM, 0);
      expect(g.points.single.elevation, isNull);
    });

    test('throws FormatException when no features', () {
      expect(() => RouteGeometry.fromOrsGeoJson({'features': []}), throwsFormatException);
    });
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/data/routing/route_geometry_test.dart`
Expected: FAIL, because URI `route_geometry.dart` doesn't exist.

- [ ] **Step 3: Implement the models**

Create `lib/data/routing/route_geometry.dart`:
```dart
/// A single point on a route. Elevation is null when the source had no 3rd ordinate.
class RoutePoint {
  final double lat;
  final double lng;
  final double? elevation;

  const RoutePoint({required this.lat, required this.lng, this.elevation});
}

/// A route's geometry plus the summary metrics needed for scoring.
class RouteGeometry {
  final List<RoutePoint> points;
  final double distanceM;
  final double ascentM;

  const RouteGeometry({
    required this.points,
    required this.distanceM,
    required this.ascentM,
  });

  /// Parses an OpenRouteService GeoJSON directions response. Coordinates are
  /// `[lng, lat, elevation?]`. Throws [FormatException] if no feature is present.
  factory RouteGeometry.fromOrsGeoJson(Map<String, dynamic> json) {
    final features = (json['features'] as List?) ?? const [];
    if (features.isEmpty) {
      throw const FormatException('ORS response has no features');
    }
    final feature = features.first as Map<String, dynamic>;
    final coords = (feature['geometry'] as Map<String, dynamic>)['coordinates'] as List;
    final props = feature['properties'] as Map<String, dynamic>;
    final summary = (props['summary'] as Map<String, dynamic>?) ?? const {};

    final points = coords.map((c) {
      final list = c as List;
      return RoutePoint(
        lng: (list[0] as num).toDouble(),
        lat: (list[1] as num).toDouble(),
        elevation: list.length > 2 ? (list[2] as num).toDouble() : null,
      );
    }).toList();

    return RouteGeometry(
      points: points,
      distanceM: ((summary['distance'] as num?) ?? 0).toDouble(),
      ascentM: ((props['ascent'] as num?) ?? 0).toDouble(),
    );
  }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/data/routing/route_geometry_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Write the failing client test (mocked HTTP)**

Create `test/data/routing/ors_route_client_test.dart`:
```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:freshloop/data/api_exception.dart';
import 'package:freshloop/data/routing/ors_route_client.dart';

void main() {
  group('OrsRouteClient.roundTrip', () {
    test('posts a round-trip request and parses the geometry', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'features': [
              {
                'geometry': {
                  'coordinates': [
                    [8.681, 49.414, 110.0],
                    [8.682, 49.415, 120.0],
                  ],
                },
                'properties': {
                  'ascent': 30.0,
                  'summary': {'distance': 5000.0},
                },
              },
            ],
          }),
          200,
        );
      });
      final client = OrsRouteClient(apiKey: 'test-key', client: mock);

      final g = await client.roundTrip(lat: 49.414, lng: 8.681, lengthM: 5000, seed: 7);

      expect(g.distanceM, 5000.0);
      expect(g.ascentM, 30.0);
      expect(g.points.length, 2);
      // request shape
      expect(captured.method, 'POST');
      expect(captured.headers['Authorization'], 'test-key');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['coordinates'], [[8.681, 49.414]]);
      expect(body['options']['round_trip']['length'], 5000);
      expect(body['options']['round_trip']['seed'], 7);
    });

    test('throws ApiException on non-200', () async {
      final mock = MockClient((req) async => http.Response('quota exceeded', 403));
      final client = OrsRouteClient(apiKey: 'k', client: mock);
      expect(
        () => client.roundTrip(lat: 1, lng: 2, lengthM: 3000),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
```

- [ ] **Step 6: Run to verify failure**

Run: `flutter test test/data/routing/ors_route_client_test.dart`
Expected: FAIL, because URI `ors_route_client.dart` doesn't exist.

- [ ] **Step 7: Implement the client**

Create `lib/data/routing/ors_route_client.dart`:
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_exception.dart';
import 'route_geometry.dart';

/// Client for OpenRouteService round-trip foot routing (design doc §5).
/// Inject [client] in tests; defaults to a real [http.Client] in production.
class OrsRouteClient {
  final http.Client _client;
  final String apiKey;

  OrsRouteClient({required this.apiKey, http.Client? client})
      : _client = client ?? http.Client();

  static final Uri _endpoint =
      Uri.parse('https://api.openrouteservice.org/v2/directions/foot-walking/geojson');

  /// Generates a loop of roughly [lengthM] metres starting and ending at
  /// ([lat], [lng]). [seed] varies the generated shape so callers can request
  /// several distinct candidates. Throws [ApiException] on a non-200 response.
  Future<RouteGeometry> roundTrip({
    required double lat,
    required double lng,
    required double lengthM,
    int seed = 1,
  }) async {
    final resp = await _client.post(
      _endpoint,
      headers: {
        'Authorization': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'coordinates': [
          [lng, lat],
        ],
        'elevation': true,
        'options': {
          'round_trip': {'length': lengthM, 'points': 5, 'seed': seed},
        },
      }),
    );
    if (resp.statusCode != 200) {
      throw ApiException('OpenRouteService', resp.statusCode, resp.body);
    }
    return RouteGeometry.fromOrsGeoJson(
      jsonDecode(resp.body) as Map<String, dynamic>,
    );
  }
}
```

- [ ] **Step 8: Run to verify pass**

Run: `flutter test test/data/routing/ors_route_client_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 9: Analyze + commit**

Run: `flutter analyze`; expect it clean.
```bash
git add lib/data/routing/ test/data/routing/
git commit -m "feat: add OpenRouteService round-trip routing client

Parse ORS GeoJSON into a RouteGeometry (points + distance + ascent) and post a
round-trip request with an injectable http client; throw ApiException on non-200."
```

---

## Task 4: Nominatim geocoding client

**Files:**
- Create: `lib/data/geocoding/geo_place.dart`, `lib/data/geocoding/nominatim_client.dart`
- Test: `test/data/geocoding/nominatim_client_test.dart`

Nominatim request: `GET https://nominatim.openstreetmap.org/search?q=<query>&format=jsonv2&limit=1` with a required `User-Agent` header. Response is a JSON array of `{ "lat": "...", "lon": "...", "display_name": "..." }` (lat/lon are strings).

- [ ] **Step 1: Write the failing test (mocked HTTP)**

Create `test/data/geocoding/nominatim_client_test.dart`:
```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:freshloop/data/geocoding/geo_place.dart';
import 'package:freshloop/data/geocoding/nominatim_client.dart';

void main() {
  group('NominatimClient.search', () {
    test('parses the first result and sends required headers/params', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode([
            {'lat': '52.5170', 'lon': '13.3889', 'display_name': 'Berlin, Germany'},
          ]),
          200,
        );
      });
      final client = NominatimClient(userAgent: 'FreshLoop/0.1 test', client: mock);

      final place = await client.search('Berlin');

      expect(place, isA<GeoPlace>());
      expect(place!.lat, closeTo(52.5170, 1e-9));
      expect(place.lng, closeTo(13.3889, 1e-9));
      expect(place.label, 'Berlin, Germany');
      expect(captured.headers['User-Agent'], 'FreshLoop/0.1 test');
      expect(captured.url.queryParameters['q'], 'Berlin');
      expect(captured.url.queryParameters['format'], 'jsonv2');
    });

    test('returns null when there are no results', () async {
      final mock = MockClient((req) async => http.Response('[]', 200));
      final client = NominatimClient(userAgent: 'ua', client: mock);
      expect(await client.search('nowhere-xyz'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/data/geocoding/nominatim_client_test.dart`
Expected: FAIL, because the URIs don't exist.

- [ ] **Step 3: Implement the model**

Create `lib/data/geocoding/geo_place.dart`:
```dart
/// A geocoded place: coordinates plus a human-readable label.
class GeoPlace {
  final double lat;
  final double lng;
  final String label;

  const GeoPlace({required this.lat, required this.lng, required this.label});

  /// Parses one Nominatim `jsonv2` result. `lat`/`lon` arrive as strings.
  factory GeoPlace.fromNominatimJson(Map<String, dynamic> json) {
    return GeoPlace(
      lat: double.parse(json['lat'] as String),
      lng: double.parse(json['lon'] as String),
      label: (json['display_name'] as String?) ?? '',
    );
  }
}
```

- [ ] **Step 4: Implement the client**

Create `lib/data/geocoding/nominatim_client.dart`:
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_exception.dart';
import 'geo_place.dart';

/// Client for OSM Nominatim forward geocoding (design doc §5). Nominatim's usage
/// policy requires a descriptive User-Agent. Returns null when nothing matches.
class NominatimClient {
  final http.Client _client;
  final String userAgent;

  NominatimClient({required this.userAgent, http.Client? client})
      : _client = client ?? http.Client();

  Future<GeoPlace?> search(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'limit': '1',
    });
    final resp = await _client.get(uri, headers: {'User-Agent': userAgent});
    if (resp.statusCode != 200) {
      throw ApiException('Nominatim', resp.statusCode, resp.body);
    }
    final results = jsonDecode(resp.body) as List;
    if (results.isEmpty) return null;
    return GeoPlace.fromNominatimJson(results.first as Map<String, dynamic>);
  }
}
```

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/data/geocoding/nominatim_client_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Analyze + commit**

Run: `flutter analyze`; expect it clean.
```bash
git add lib/data/geocoding/ test/data/geocoding/
git commit -m "feat: add Nominatim geocoding client

Forward-geocode a place name to a GeoPlace with the required User-Agent header;
return null on no match and throw ApiException on non-200."
```

---

## Task 5: Final verification

**Files:** none

- [ ] **Step 1: Full suite.** Run `flutter test`; expect 25 (M1) + 7 new (route_geometry 3 + ors 2 + nominatim 2) = 32 tests, all passing.
- [ ] **Step 2: Analyze.** Run `flutter analyze`; expect "No issues found!".
- [ ] **Step 3: Secret + tree check.** `git status` clean; `git ls-files | grep secrets` shows ONLY `secrets.example.json` (never `secrets.json`); confirm no key strings in tracked files.

---

## Self-Review (completed by author)

**Spec coverage:** design §5 ORS routing → Task 3; Nominatim → Task 4; secrets §13.7 (gitignored keys + template + dart-define) → Task 1; §11 error handling (non-200 → ApiException, empty → null) → Tasks 2-4. Deferred by design: air/elevation/Overpass → M2.2; photos → M2.3; assembling `RouteScoreInputs` + UI → M3.

**Placeholder scan:** none. Every step has complete code, real mock JSON, and exact expected values.

**Type consistency:** `RoutePoint`/`RouteGeometry` (Task 3) match between model, client, and tests; `ApiException(service, statusCode, body)` signature (Task 2) used identically in Tasks 3-4; `GeoPlace.fromNominatimJson` (Task 4) matches its usage; `OrsRouteClient({apiKey, client})` and `NominatimClient({userAgent, client})` constructor shapes match their tests. `MockClient`/`http.Response` come from `package:http/testing.dart` + `package:http`, already available.

**Note on live APIs:** clients are verified against mocked responses only (no network in tests). The ORS key is live-validated; Mapillary deferred to M2.3/M3. Live end-to-end wiring is M3.
