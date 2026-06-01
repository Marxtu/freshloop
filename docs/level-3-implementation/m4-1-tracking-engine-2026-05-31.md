# FreshLoop M4.1 — Run-Tracking Engine · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development or superpowers:executing-plans. Checkbox (`- [ ]`) steps.

**Goal:** The brain for live run tracking, no UI yet. A `LocationSource` abstraction over `geolocator` (so it's mockable), a haversine distance helper, a `RunRecord`, and a `RunTrackingCubit` that consumes a position stream, accumulates distance, and finishes with a record. Fully unit-tested with a fake location source (no GPS, no plugin in tests).

**Architecture:** `lib/services/location_source.dart` defines the interface + a `GeolocatorLocationSource` (the only geolocator-touching code; not unit-tested, verified by analyze). `lib/state/run_tracking_cubit.dart` holds the live state. Distance is computed in `lib/domain/geo.dart` (pure). The Cubit cancels its stream subscription in `close()` (the resource-lifecycle discipline the course stresses).

**Tech Stack:** Flutter, flutter_bloc, `geolocator`, Dart.

**SSOT:** [system design](../level-2-architecture/running-route-generator-2026-05-30.md) §3 (tracking flow), §7 (Cubit + GPS lifecycle), §8 (`RunRecord`). Builds on M3.1 (`RoutePoint`, geo helpers).

**Scope:** distance math + RunRecord + LocationSource + RunTrackingCubit. **Out:** tracking screen + post-run summary UI + Android location-permission manifest + wiring "Start run", all deferred to M4.2.

**Notes:** Flutter at `$HOME/flutter/bin/flutter`. English, Conventional Commits, no AI/tooling attribution. **Run `flutter test` + `flutter analyze` green before each commit.** `lib/domain` stays Flutter-free; `lib/state` may use flutter_bloc; only `location_source.dart` imports geolocator. Tests must not touch the plugin/GPS.

---

## File Structure (M4.1)

```
pubspec.yaml                              # + geolocator
lib/domain/geo.dart                       # + haversineMeters()
lib/domain/models/run_record.dart         # RunRecord
lib/services/location_source.dart         # LocationSource (abstract) + GeolocatorLocationSource
lib/state/run_tracking_state.dart         # RunTrackingState (sealed) + variants
lib/state/run_tracking_cubit.dart         # RunTrackingCubit
test/domain/geo_haversine_test.dart
test/domain/models/run_record_test.dart
test/state/run_tracking_cubit_test.dart
```

---

## Task 1: `haversineMeters` (pure)

**Files:** modify `lib/domain/geo.dart`; create `test/domain/geo_haversine_test.dart`

- [ ] **Step 1: Failing test** in `test/domain/geo_haversine_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/domain/geo.dart';

void main() {
  group('haversineMeters', () {
    test('zero for identical points', () {
      expect(haversineMeters(const RoutePoint(lat: 45.46, lng: 9.19),
          const RoutePoint(lat: 45.46, lng: 9.19)), 0);
    });
    test('~111 m for 0.001 degree of latitude', () {
      final d = haversineMeters(const RoutePoint(lat: 45.0, lng: 9.0),
          const RoutePoint(lat: 45.001, lng: 9.0));
      expect(d, closeTo(111.2, 1.0));
    });
    test('~111 km for 1 degree of longitude at the equator', () {
      final d = haversineMeters(const RoutePoint(lat: 0, lng: 0),
          const RoutePoint(lat: 0, lng: 1));
      expect(d, closeTo(111320, 200));
    });
  });
}
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement.** Add to `lib/domain/geo.dart` (add `import 'dart:math' as math;` at top):
```dart
/// Great-circle distance between two points, in metres (Haversine).
double haversineMeters(RoutePoint a, RoutePoint b) {
  const earthRadiusM = 6371000.0;
  double rad(double deg) => deg * math.pi / 180.0;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final lat1 = rad(a.lat);
  final lat2 = rad(b.lat);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return earthRadiusM * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}
```

- [ ] **Step 4: Run → PASS (3).** `flutter analyze`. Commit:
```bash
git add lib/domain/geo.dart test/domain/geo_haversine_test.dart
git commit -m "feat: add haversineMeters distance helper"
```

---

## Task 2: `RunRecord`

**Files:** `lib/domain/models/run_record.dart`, `test/domain/models/run_record_test.dart`

- [ ] **Step 1: Failing test** in `test/domain/models/run_record_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/domain/models/run_record.dart';

void main() {
  group('RunRecord.paceSecPerKm', () {
    test('300 s over 1 km is 300 s/km', () {
      const r = RunRecord(points: [], distanceM: 1000, durationS: 300);
      expect(r.paceSecPerKm, 300);
    });
    test('zero distance yields zero pace (no divide-by-zero)', () {
      const r = RunRecord(points: [], distanceM: 0, durationS: 120);
      expect(r.paceSecPerKm, 0);
    });
  });
}
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement** in `lib/domain/models/run_record.dart`:
```dart
import '../../data/routing/route_geometry.dart';

/// A completed (or in-progress snapshot of a) run: the GPS trail, total
/// distance, and elapsed time. See design doc §8.
class RunRecord {
  final List<RoutePoint> points;
  final double distanceM;
  final int durationS;

  const RunRecord({required this.points, required this.distanceM, required this.durationS});

  /// Average pace in seconds per kilometre (0 when no distance was covered).
  double get paceSecPerKm => distanceM <= 0 ? 0 : durationS / (distanceM / 1000);
}
```

- [ ] **Step 4: Run → PASS (2).** `flutter analyze`. Commit:
```bash
git add lib/domain/models/run_record.dart test/domain/models/run_record_test.dart
git commit -m "feat: add RunRecord with average-pace helper"
```

---

## Task 3: `LocationSource` (+ geolocator)

**Files:** modify `pubspec.yaml`; create `lib/services/location_source.dart`

- [ ] **Step 1: Add geolocator.** `flutter pub add geolocator`

- [ ] **Step 2: Implement** in `lib/services/location_source.dart`:
```dart
import 'package:geolocator/geolocator.dart';
import '../data/routing/route_geometry.dart';

/// Source of live position updates. Abstracted so the tracking Cubit can be
/// unit-tested with a fake stream (no GPS, no plugin) — see design doc §7.
abstract class LocationSource {
  /// Ensures location permission is granted; returns true if usable.
  Future<bool> ensurePermission();

  /// A stream of the user's position as [RoutePoint]s.
  Stream<RoutePoint> positions();
}

/// Production implementation backed by the `geolocator` plugin.
class GeolocatorLocationSource implements LocationSource {
  const GeolocatorLocationSource();

  @override
  Future<bool> ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  @override
  Stream<RoutePoint> positions() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
        ),
      ).map((p) => RoutePoint(lat: p.latitude, lng: p.longitude, elevation: p.altitude));
}
```

- [ ] **Step 3:** `flutter analyze` (clean) + `flutter test` (still green; no new test, since the geolocator wrapper is verified by analyze and exercised via the Cubit's fake source in Task 4). Commit:
```bash
git add pubspec.yaml lib/services/location_source.dart
git commit -m "feat: add LocationSource abstraction over geolocator"
```

---

## Task 4: `RunTrackingCubit`

**Files:** `lib/state/run_tracking_state.dart`, `lib/state/run_tracking_cubit.dart`, `test/state/run_tracking_cubit_test.dart`

- [ ] **Step 1: Failing test** in `test/state/run_tracking_cubit_test.dart`:
```dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/services/location_source.dart';
import 'package:freshloop/state/run_tracking_cubit.dart';
import 'package:freshloop/state/run_tracking_state.dart';

class _FakeSource implements LocationSource {
  _FakeSource(this._controller, {this.granted = true});
  final StreamController<RoutePoint> _controller;
  final bool granted;
  @override
  Future<bool> ensurePermission() async => granted;
  @override
  Stream<RoutePoint> positions() => _controller.stream;
}

void main() {
  group('RunTrackingCubit', () {
    test('starts idle', () {
      final cubit = RunTrackingCubit(_FakeSource(StreamController<RoutePoint>()));
      expect(cubit.state, isA<RunIdle>());
      cubit.close();
    });

    test('emits permission-denied when permission is refused', () async {
      final cubit = RunTrackingCubit(_FakeSource(StreamController<RoutePoint>(), granted: false));
      await cubit.start();
      expect(cubit.state, isA<RunPermissionDenied>());
      await cubit.close();
    });

    test('accumulates distance from the position stream, then finishes', () async {
      final controller = StreamController<RoutePoint>();
      final cubit = RunTrackingCubit(_FakeSource(controller));
      await cubit.start();
      expect(cubit.state, isA<RunInProgress>());

      controller.add(const RoutePoint(lat: 45.0, lng: 9.0));
      await Future<void>.delayed(Duration.zero);
      controller.add(const RoutePoint(lat: 45.001, lng: 9.0)); // ~111 m further
      await Future<void>.delayed(Duration.zero);

      final progress = cubit.state as RunInProgress;
      expect(progress.distanceM, closeTo(111.2, 1.0));
      expect(progress.points.length, 2);

      cubit.stop();
      final finished = cubit.state as RunFinished;
      expect(finished.record.distanceM, closeTo(111.2, 1.0));
      expect(finished.record.points.length, 2);
      await cubit.close();
      await controller.close();
    });
  });
}
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement the states** in `lib/state/run_tracking_state.dart`:
```dart
import '../domain/models/run_record.dart';
import '../data/routing/route_geometry.dart';

/// States for live run tracking (design doc §7).
sealed class RunTrackingState {
  const RunTrackingState();
}

class RunIdle extends RunTrackingState {
  const RunIdle();
}

class RunPermissionDenied extends RunTrackingState {
  const RunPermissionDenied();
}

class RunInProgress extends RunTrackingState {
  final double distanceM;
  final List<RoutePoint> points;
  const RunInProgress({required this.distanceM, required this.points});
}

class RunFinished extends RunTrackingState {
  final RunRecord record;
  const RunFinished(this.record);
}
```

- [ ] **Step 4: Implement the Cubit** in `lib/state/run_tracking_cubit.dart`:
```dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/routing/route_geometry.dart';
import '../domain/geo.dart';
import '../domain/models/run_record.dart';
import '../services/location_source.dart';
import 'run_tracking_state.dart';

/// Drives a live run: subscribes to the [LocationSource], accumulates distance
/// via haversine, and finishes with a [RunRecord]. Cancels its subscription in
/// [close] (GPS lifecycle discipline, design doc §7).
class RunTrackingCubit extends Cubit<RunTrackingState> {
  final LocationSource source;
  StreamSubscription<RoutePoint>? _sub;
  final List<RoutePoint> _points = [];
  final Stopwatch _watch = Stopwatch();
  double _distanceM = 0;

  RunTrackingCubit(this.source) : super(const RunIdle());

  Future<void> start() async {
    if (!await source.ensurePermission()) {
      emit(const RunPermissionDenied());
      return;
    }
    _points.clear();
    _distanceM = 0;
    _watch
      ..reset()
      ..start();
    emit(const RunInProgress(distanceM: 0, points: []));
    _sub = source.positions().listen((p) {
      if (_points.isNotEmpty) {
        _distanceM += haversineMeters(_points.last, p);
      }
      _points.add(p);
      emit(RunInProgress(distanceM: _distanceM, points: List.unmodifiable(_points)));
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _watch.stop();
    emit(RunFinished(RunRecord(
      points: List.of(_points),
      distanceM: _distanceM,
      durationS: _watch.elapsed.inSeconds,
    )));
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
```

- [ ] **Step 5: Run → PASS (3).** `flutter analyze`. Commit:
```bash
git add lib/state/run_tracking_state.dart lib/state/run_tracking_cubit.dart test/state/run_tracking_cubit_test.dart
git commit -m "feat: add RunTrackingCubit (distance accumulation + lifecycle)"
```

---

## Task 5: Final verification

- [ ] **Step 1:** `flutter test` → expect 76 (after M3) + haversine 3 + run_record 2 + cubit 3 = **84 tests**, all passing.
- [ ] **Step 2:** `flutter analyze` → clean.
- [ ] **Step 3:** `git status` clean; `lib/domain` Flutter-free; only `location_source.dart` imports geolocator; no real secrets tracked.

---

## Self-Review (author)

**Spec coverage:** §3 tracking (accumulate distance from GPS) → Cubit (Task 4); §7 GPS lifecycle (cancel subscription on close) → Task 4 `close()`; §8 `RunRecord` → Task 2; distance math → Task 1. Deferred: tracking screen + post-run summary + Android permission manifest + "Start run" wiring → M4.2.

**Placeholder scan:** none. Complete code plus exact test expectations (haversine numbers verified by formula).

**Type consistency:** `RoutePoint` (M3.1) used across haversine/LocationSource/Cubit; `haversineMeters` (Task 1) used by the Cubit (Task 4); `RunRecord` (Task 2) produced by the Cubit; `LocationSource` interface (Task 3) implemented by `GeolocatorLocationSource` and the test's `_FakeSource`; states (`RunIdle`/`RunPermissionDenied`/`RunInProgress`/`RunFinished`) match the Cubit + tests.

**Test/GPS note:** the Cubit is tested with a `_FakeSource` + a `StreamController` (deterministic distance, no plugin). `durationS` (real `Stopwatch`) is not asserted; tests assert distance + point count + state transitions. `GeolocatorLocationSource` is verified by `flutter analyze` only; real-device permission wiring lands in M4.2.
