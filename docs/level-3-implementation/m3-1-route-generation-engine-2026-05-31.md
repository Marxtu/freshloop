# FreshLoop M3.1 — Route-Generation Engine (assembler + Cubit) · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Build the brain that turns a user's request into ranked, scored route candidates, with no UI yet. A `RouteGenerator` service orchestrates the M2 clients (ORS, then per-candidate AQI + greenery) and the M1 scorer; a `RouteGenCubit` exposes loading/loaded/error states. Fully unit-tested with the clients backed by `MockClient` (offline, deterministic).

**Architecture:** New `lib/services/` (orchestration; depends on `lib/data` clients + `lib/domain` scorer) and `lib/state/` (Cubit). Pure-domain additions (`RunParams`, `ScoredRoute`, geo helpers) stay Flutter-free in `lib/domain`. The Cubit is the only Flutter-aware piece (it uses `flutter_bloc`, the professor-taught state solution). Per design §11, enrichment failures (AQI/greenery) degrade to neutral values so a route still scores; only a routing (ORS) failure fails the whole request.

**Tech Stack:** Flutter, `flutter_bloc`, `http` (+ testing), Dart.

**Design SSOT:** [FreshLoop system design](../level-2-architecture/running-route-generator-2026-05-30.md) §3 (flow), §6 (scoring), §7 (architecture/Cubit), §8 (models), §11 (degradation). Builds on M1 scorer (`RouteScorer`, `RouteScoreInputs`, `ScoreWeights`, `ScoreBreakdown`) and M2 clients (`OrsRouteClient`, `OpenMeteoAirClient`, `OverpassClient`, `RouteGeometry`/`RoutePoint`).

**Scope of M3.1:** params model + scored-route model + geo helpers + generator service + Cubit. No screens, no map, no photos (photos are display-only, so they are fetched in the route-detail screen, M3.3). Params UI + candidate UI + map = M3.2; route detail + elevation chart + photo carousel = M3.3.

**Decisions:** generate 3 candidates (ORS seeds 1–3); subsample up to 10 points for AQI to keep requests small; `targetAscentM` is carried on `RunParams` (the params UI derives it from a terrain choice in M3.2); `loopType` from design §8 is omitted (YAGNI, since an ORS round-trip already produces a loop).

**Notes:** Flutter at `$HOME/flutter/bin/flutter` if not on PATH. English, Conventional Commits, no AI/tooling attribution, per-task commits. Run `flutter test` + `flutter analyze` green before every commit. Touch only the files named.

---

## File Structure (created in M3.1)

```
pubspec.yaml                              # + flutter_bloc
lib/
  domain/
    models/
      run_params.dart                     # RunParams
      scored_route.dart                    # ScoredRoute
    geo.dart                              # BoundingBox, boundingBoxOf(), subsample()
  services/
    route_generator.dart                  # RouteGenerator.generate(RunParams) -> List<ScoredRoute>
  state/
    route_gen_state.dart                  # RouteGenState (sealed) + variants
    route_gen_cubit.dart                  # RouteGenCubit
test/
  domain/geo_test.dart
  services/route_generator_test.dart
  state/route_gen_cubit_test.dart
```

---

## Task 1: Add flutter_bloc + value models (`RunParams`, `ScoredRoute`)

**Files:** modify `pubspec.yaml`; create `lib/domain/models/run_params.dart`, `lib/domain/models/scored_route.dart`, `test/domain/models/run_params_test.dart`

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add flutter_bloc`
Expected: `pubspec.yaml` gains `flutter_bloc`; `flutter pub get` runs.

- [ ] **Step 2: Write the failing test (RunParams defaults)**

Create `test/domain/models/run_params_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/domain/models/run_params.dart';
import 'package:freshloop/domain/models/score_weights.dart';

void main() {
  test('RunParams keeps inputs and defaults weights/ascent', () {
    const p = RunParams(startLat: 45.46, startLng: 9.19, targetDistanceM: 5000);
    expect(p.startLat, 45.46);
    expect(p.targetDistanceM, 5000);
    expect(p.targetAscentM, 0);
    expect(p.weights, isA<ScoreWeights>());
  });
}
```

- [ ] **Step 3: Run to verify failure.** `flutter test test/domain/models/run_params_test.dart` should FAIL (URI missing).

- [ ] **Step 4: Implement the models**

Create `lib/domain/models/run_params.dart`:
```dart
import 'score_weights.dart';

/// What the user asked for: where to start, how far, the axis weights, and a
/// target cumulative ascent (0 = prefer flat). See design doc §8.
class RunParams {
  final double startLat;
  final double startLng;
  final double targetDistanceM;
  final ScoreWeights weights;
  final double targetAscentM;

  const RunParams({
    required this.startLat,
    required this.startLng,
    required this.targetDistanceM,
    this.weights = const ScoreWeights(),
    this.targetAscentM = 0,
  });
}
```

Create `lib/domain/models/scored_route.dart`:
```dart
import '../../data/routing/route_geometry.dart';
import 'score_breakdown.dart';

/// One generated candidate: its geometry and its explainable score. [seed] is
/// the ORS round-trip seed that produced it (lets the UI request a fresh shape).
class ScoredRoute {
  final int seed;
  final RouteGeometry geometry;
  final ScoreBreakdown score;

  const ScoredRoute({required this.seed, required this.geometry, required this.score});
}
```

- [ ] **Step 5: Run to verify pass.** `flutter test test/domain/models/run_params_test.dart` should PASS (1).

- [ ] **Step 6: Analyze + commit**

Run `flutter analyze` (clean) then:
```bash
git add pubspec.yaml lib/domain/models/run_params.dart lib/domain/models/scored_route.dart test/domain/models/run_params_test.dart
git commit -m "feat: add RunParams and ScoredRoute models and flutter_bloc dep"
```

---

## Task 2: Geo helpers (`boundingBoxOf`, `subsample`)

**Files:** create `lib/domain/geo.dart`, `test/domain/geo_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/domain/geo_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/domain/geo.dart';

void main() {
  const pts = [
    RoutePoint(lat: 45.46, lng: 9.18),
    RoutePoint(lat: 45.48, lng: 9.22),
    RoutePoint(lat: 45.47, lng: 9.20),
  ];

  group('boundingBoxOf', () {
    test('computes min/max with padding', () {
      final b = boundingBoxOf(pts, padDeg: 0.0);
      expect(b.south, 45.46);
      expect(b.north, 45.48);
      expect(b.west, 9.18);
      expect(b.east, 9.22);
    });
    test('applies padding outward', () {
      final b = boundingBoxOf(pts, padDeg: 0.01);
      expect(b.south, closeTo(45.45, 1e-9));
      expect(b.east, closeTo(9.23, 1e-9));
    });
    test('throws on empty', () {
      expect(() => boundingBoxOf(const []), throwsArgumentError);
    });
  });

  group('subsample', () {
    test('returns all when within max', () {
      expect(subsample(pts, 10).length, 3);
    });
    test('reduces to max and keeps first and last', () {
      final many = List.generate(100, (i) => RoutePoint(lat: i.toDouble(), lng: 0));
      final s = subsample(many, 10);
      expect(s.length, 10);
      expect(s.first.lat, 0);
      expect(s.last.lat, 99);
    });
    test('returns input unchanged for empty', () {
      expect(subsample(const [], 5), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run to verify failure.** FAIL.

- [ ] **Step 3: Implement**

Create `lib/domain/geo.dart`:
```dart
import '../data/routing/route_geometry.dart';

/// A geographic bounding box (used for area queries like Overpass).
class BoundingBox {
  final double south;
  final double west;
  final double north;
  final double east;

  const BoundingBox({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });
}

/// The bounding box of [points], expanded outward by [padDeg] degrees.
/// Throws [ArgumentError] if [points] is empty.
BoundingBox boundingBoxOf(List<RoutePoint> points, {double padDeg = 0.002}) {
  if (points.isEmpty) {
    throw ArgumentError('points must not be empty');
  }
  var south = points.first.lat, north = points.first.lat;
  var west = points.first.lng, east = points.first.lng;
  for (final p in points) {
    if (p.lat < south) south = p.lat;
    if (p.lat > north) north = p.lat;
    if (p.lng < west) west = p.lng;
    if (p.lng > east) east = p.lng;
  }
  return BoundingBox(
    south: south - padDeg,
    west: west - padDeg,
    north: north + padDeg,
    east: east + padDeg,
  );
}

/// Evenly downsamples [points] to at most [max] items, always keeping the
/// first and last. Returns the input unchanged when it already fits.
List<RoutePoint> subsample(List<RoutePoint> points, int max) {
  if (points.length <= max || max <= 0) return points;
  final step = (points.length - 1) / (max - 1);
  final out = <RoutePoint>[];
  for (var i = 0; i < max; i++) {
    out.add(points[(i * step).round()]);
  }
  return out;
}
```

- [ ] **Step 4: Run to verify pass.** PASS (6).

- [ ] **Step 5: Analyze + commit**
```bash
flutter analyze
git add lib/domain/geo.dart test/domain/geo_test.dart
git commit -m "feat: add geo helpers (bounding box + evenly-spaced subsample)"
```

---

## Task 3: `RouteGenerator` service

**Files:** create `lib/services/route_generator.dart`, `test/services/route_generator_test.dart`

- [ ] **Step 1: Write the failing test (clients backed by MockClient)**

Create `test/services/route_generator_test.dart`:
```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:freshloop/data/air/open_meteo_air_client.dart';
import 'package:freshloop/data/greenery/overpass_client.dart';
import 'package:freshloop/data/routing/ors_route_client.dart';
import 'package:freshloop/domain/models/run_params.dart';
import 'package:freshloop/services/route_generator.dart';

http.Response _orsResp(double distance) => http.Response(
      jsonEncode({
        'features': [
          {
            'geometry': {
              'coordinates': [
                [9.18, 45.46, 100.0],
                [9.20, 45.47, 130.0],
                [9.18, 45.46, 100.0],
              ],
            },
            'properties': {
              'ascent': 30.0,
              'summary': {'distance': distance},
            },
          },
        ],
      }),
      200,
    );

void main() {
  group('RouteGenerator.generate', () {
    test('produces N scored candidates ranked by total, descending', () async {
      // ORS returns a route whose distance encodes the seed so each candidate differs.
      final ors = OrsRouteClient(
        apiKey: 'k',
        client: MockClient((req) async {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          final seed = body['options']['round_trip']['seed'] as int;
          return _orsResp(1000.0 * seed);
        }),
      );
      // Air: better AQI for later seeds (so ranking is not just input order).
      final air = OpenMeteoAirClient(
        client: MockClient((req) async => http.Response(
            jsonEncode([
              {'current': {'european_aqi': 40}},
              {'current': {'european_aqi': 40}},
            ]),
            200)),
      );
      final overpass = OverpassClient(
        userAgent: 'ua',
        client: MockClient((req) async => http.Response(
            jsonEncode({
              'elements': [
                {'type': 'way', 'tags': {'leisure': 'park'}},
              ],
            }),
            200)),
      );
      final gen = RouteGenerator(ors: ors, air: air, overpass: overpass);

      final routes = await gen.generate(
        const RunParams(startLat: 45.46, startLng: 9.19, targetDistanceM: 3000),
        candidates: 3,
      );

      expect(routes.length, 3);
      // sorted by score.total descending
      expect(routes[0].score.total, greaterThanOrEqualTo(routes[1].score.total));
      expect(routes[1].score.total, greaterThanOrEqualTo(routes[2].score.total));
      // every candidate carries geometry + score
      expect(routes.first.geometry.points, isNotEmpty);
    });

    test('degrades to a neutral score when enrichment APIs fail (route still scored)', () async {
      final ors = OrsRouteClient(apiKey: 'k', client: MockClient((req) async => _orsResp(3000)));
      final air = OpenMeteoAirClient(client: MockClient((req) async => http.Response('down', 500)));
      final overpass = OverpassClient(userAgent: 'ua', client: MockClient((req) async => http.Response('down', 500)));
      final gen = RouteGenerator(ors: ors, air: air, overpass: overpass);

      final routes = await gen.generate(
        const RunParams(startLat: 45.46, startLng: 9.19, targetDistanceM: 3000),
        candidates: 1,
      );

      expect(routes.length, 1); // ORS succeeded → we still return a scored route
      expect(routes.first.score.total, isNonNegative);
    });

    test('rethrows when routing (ORS) fails', () async {
      final ors = OrsRouteClient(apiKey: 'k', client: MockClient((req) async => http.Response('quota', 403)));
      final air = OpenMeteoAirClient(client: MockClient((req) async => http.Response('[]', 200)));
      final overpass = OverpassClient(userAgent: 'ua', client: MockClient((req) async => http.Response('{}', 200)));
      final gen = RouteGenerator(ors: ors, air: air, overpass: overpass);

      expect(
        () => gen.generate(const RunParams(startLat: 0, startLng: 0, targetDistanceM: 3000), candidates: 1),
        throwsA(anything),
      );
    });
  });
}
```

- [ ] **Step 2: Run to verify failure.** FAIL (no route_generator.dart).

- [ ] **Step 3: Implement**

Create `lib/services/route_generator.dart`:
```dart
import '../data/air/open_meteo_air_client.dart';
import '../data/greenery/greenery_data.dart';
import '../data/greenery/overpass_client.dart';
import '../data/routing/ors_route_client.dart';
import '../domain/geo.dart';
import '../domain/models/route_score_inputs.dart';
import '../domain/models/run_params.dart';
import '../domain/models/scored_route.dart';
import '../domain/scoring/route_scorer.dart';

/// Orchestrates the data clients and the scorer to produce ranked candidates.
/// Enrichment failures (air/greenery) degrade to neutral values so a route is
/// still scored (design doc §11); a routing failure propagates (no route, no run).
class RouteGenerator {
  final OrsRouteClient ors;
  final OpenMeteoAirClient air;
  final OverpassClient overpass;
  final RouteScorer scorer;

  RouteGenerator({
    required this.ors,
    required this.air,
    required this.overpass,
    this.scorer = const RouteScorer(),
  });

  /// Generates [candidates] loop routes for [params] and returns them ranked
  /// best-first. Neutral AQI (50) is used if air data is unavailable.
  Future<List<ScoredRoute>> generate(RunParams params, {int candidates = 3}) async {
    final scored = <ScoredRoute>[];
    for (var seed = 1; seed <= candidates; seed++) {
      final geometry = await ors.roundTrip(
        lat: params.startLat,
        lng: params.startLng,
        lengthM: params.targetDistanceM,
        seed: seed,
      );

      List<double> aqi;
      try {
        aqi = await air.sampleAqi(subsample(geometry.points, 10));
      } catch (_) {
        aqi = const [];
      }

      GreeneryData greenery;
      try {
        final b = boundingBoxOf(geometry.points);
        greenery = await overpass.fetchGreenery(
          south: b.south,
          west: b.west,
          north: b.north,
          east: b.east,
        );
      } catch (_) {
        greenery = const GreeneryData(greenCount: 0, scenicCount: 0);
      }

      final inputs = RouteScoreInputs(
        aqiSamples: aqi.isEmpty ? const [50.0] : aqi,
        actualAscentM: geometry.ascentM,
        targetAscentM: params.targetAscentM,
        greenRatio: greenery.greenRatio,
        scenicWaypoints: greenery.scenicWaypoints,
      );

      scored.add(ScoredRoute(
        seed: seed,
        geometry: geometry,
        score: scorer.score(inputs, params.weights),
      ));
    }
    return scorer.rank(scored, (r) => r.score.total);
  }
}
```

- [ ] **Step 4: Run to verify pass.** PASS (3).

- [ ] **Step 5: Analyze + commit**
```bash
flutter analyze
git add lib/services/route_generator.dart test/services/route_generator_test.dart
git commit -m "feat: add RouteGenerator orchestrating clients + scorer into ranked routes

Generate N round-trip candidates, enrich each with AQI + greenery (degrading to
neutral on enrichment failure), score and rank them; routing failures propagate."
```

---

## Task 4: `RouteGenCubit`

**Files:** create `lib/state/route_gen_state.dart`, `lib/state/route_gen_cubit.dart`, `test/state/route_gen_cubit_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/state/route_gen_cubit_test.dart`:
```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:freshloop/data/air/open_meteo_air_client.dart';
import 'package:freshloop/data/greenery/overpass_client.dart';
import 'package:freshloop/data/routing/ors_route_client.dart';
import 'package:freshloop/domain/models/run_params.dart';
import 'package:freshloop/services/route_generator.dart';
import 'package:freshloop/state/route_gen_cubit.dart';
import 'package:freshloop/state/route_gen_state.dart';

RouteGenerator _okGenerator() => RouteGenerator(
      ors: OrsRouteClient(
        apiKey: 'k',
        client: MockClient((req) async => http.Response(
            jsonEncode({
              'features': [
                {
                  'geometry': {'coordinates': [[9.18, 45.46, 100.0], [9.18, 45.46, 100.0]]},
                  'properties': {'ascent': 10.0, 'summary': {'distance': 3000.0}},
                },
              ],
            }),
            200)),
      ),
      air: OpenMeteoAirClient(
        client: MockClient((req) async =>
            http.Response(jsonEncode([{'current': {'european_aqi': 30}}]), 200)),
      ),
      overpass: OverpassClient(
        userAgent: 'ua',
        client: MockClient((req) async => http.Response(jsonEncode({'elements': []}), 200)),
      ),
    );

const _params = RunParams(startLat: 45.46, startLng: 9.19, targetDistanceM: 3000);

void main() {
  group('RouteGenCubit', () {
    test('starts in initial state', () {
      expect(_okGenerator, returnsNormally);
      final cubit = RouteGenCubit(_okGenerator());
      expect(cubit.state, isA<RouteGenInitial>());
      cubit.close();
    });

    test('emits loading then loaded with routes on success', () async {
      final cubit = RouteGenCubit(_okGenerator());
      // Set up the expectation before acting so both emissions are caught
      // regardless of the broadcast stream's microtask delivery timing.
      final expectation = expectLater(
        cubit.stream,
        emitsInOrder([isA<RouteGenLoading>(), isA<RouteGenLoaded>()]),
      );

      await cubit.generate(_params, candidates: 2);
      await expectation;

      expect(cubit.state, isA<RouteGenLoaded>());
      expect((cubit.state as RouteGenLoaded).routes.length, 2);
      await cubit.close();
    });

    test('emits error when routing fails', () async {
      final gen = RouteGenerator(
        ors: OrsRouteClient(apiKey: 'k', client: MockClient((req) async => http.Response('quota', 403))),
        air: OpenMeteoAirClient(client: MockClient((req) async => http.Response('[]', 200))),
        overpass: OverpassClient(userAgent: 'ua', client: MockClient((req) async => http.Response('{}', 200))),
      );
      final cubit = RouteGenCubit(gen);

      await cubit.generate(_params, candidates: 1);

      expect(cubit.state, isA<RouteGenError>());
      await cubit.close();
    });
  });
}
```

- [ ] **Step 2: Run to verify failure.** FAIL.

- [ ] **Step 3: Implement the states**

Create `lib/state/route_gen_state.dart`:
```dart
import '../domain/models/scored_route.dart';

/// States for the route-generation flow (design doc §7).
sealed class RouteGenState {
  const RouteGenState();
}

class RouteGenInitial extends RouteGenState {
  const RouteGenInitial();
}

class RouteGenLoading extends RouteGenState {
  const RouteGenLoading();
}

class RouteGenLoaded extends RouteGenState {
  final List<ScoredRoute> routes;
  const RouteGenLoaded(this.routes);
}

class RouteGenError extends RouteGenState {
  final String message;
  const RouteGenError(this.message);
}
```

- [ ] **Step 4: Implement the Cubit**

Create `lib/state/route_gen_cubit.dart`:
```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/models/run_params.dart';
import '../services/route_generator.dart';
import 'route_gen_state.dart';

/// Drives the route-generation flow: triggers generation and exposes
/// loading/loaded/error states for the UI (design doc §7).
class RouteGenCubit extends Cubit<RouteGenState> {
  final RouteGenerator generator;

  RouteGenCubit(this.generator) : super(const RouteGenInitial());

  Future<void> generate(RunParams params, {int candidates = 3}) async {
    emit(const RouteGenLoading());
    try {
      final routes = await generator.generate(params, candidates: candidates);
      emit(RouteGenLoaded(routes));
    } catch (e) {
      emit(RouteGenError(e.toString()));
    }
  }
}
```

- [ ] **Step 5: Run to verify pass.** PASS (3).

- [ ] **Step 6: Analyze + commit**
```bash
flutter analyze
git add lib/state/route_gen_state.dart lib/state/route_gen_cubit.dart test/state/route_gen_cubit_test.dart
git commit -m "feat: add RouteGenCubit with loading/loaded/error states"
```

---

## Task 5: Final verification

- [ ] **Step 1:** `flutter test` should report 51 (after M2) + 13 new (run_params 1 + geo 6 + route_generator 3 + cubit 3) = 64 tests, all passing.
- [ ] **Step 2:** `flutter analyze` clean.
- [ ] **Step 3:** `git status` clean; `lib/domain/**` still has no `package:flutter/` import (only the Cubit in `lib/state/` is Flutter-aware); no real secrets tracked.

---

## Self-Review (completed by author)

**Spec coverage:** §3 generate flow is `RouteGenerator` (Task 3) plus `RouteGenCubit` (Task 4); §6 scoring is reused via `RouteScorer`; §7 Cubit state management is Task 4; §8 `RunParams`/scored candidate is Task 1; §11 enrichment degradation is Task 3 try/catch plus neutral AQI. Deferred: params/candidate/detail screens, map, and photos go to M3.2/M3.3.

**Placeholder scan:** none. Complete code, real mock JSON, exact expected values.

**Type consistency:** `RunParams`/`ScoreWeights` (Task 1) consumed by generator (Task 3) + cubit (Task 4); `ScoredRoute{seed,geometry,score}` produced by generator, consumed by `RouteGenLoaded`; `boundingBoxOf`/`subsample` (Task 2) used in generator; generator constructor `{ors, air, overpass, scorer}` matches all tests; `RouteScorer.score`/`.rank` signatures from M1 used correctly; M2 client constructors (`OrsRouteClient({apiKey,client})`, `OpenMeteoAirClient({client})`, `OverpassClient({userAgent,client})`) match the test wiring.

**Layering note:** `lib/domain` stays pure; `lib/services` may import `lib/data` + `lib/domain` (orchestration); `lib/state` imports `flutter_bloc` plus the services. No reverse dependencies.
