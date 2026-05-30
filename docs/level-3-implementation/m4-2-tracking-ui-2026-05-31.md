# FreshLoop M4.2 — Tracking UI (live run + post-run summary) · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development or superpowers:executing-plans. Checkbox (`- [ ]`) steps.

**Goal:** Make "Start run" real — a live tracking screen (map follows you, live distance/time/pace, Stop) and a post-run summary (trail, stats, planned-vs-actual), wired from the route detail. Also surfaces the current-location marker on maps (the deferred review items).

**Architecture:** UI in `lib/features/tracking/`. `TrackingScreen` owns a `RunTrackingCubit` (M4.1) built from an injectable `LocationSource` (default `GeolocatorLocationSource`); a 1 s ticker drives the elapsed-time display; the map shows the planned loop + the live trail + a current-position marker. On finish it pushes `RunSummaryScreen`. Pure `format` helpers handle time/pace. Widget tests use a fake `LocationSource` (no GPS); the geolocator path is analyze-only.

**Tech Stack:** Flutter, flutter_bloc, flutter_map, geolocator, `share_plus`.

**SSOT:** [system design](../level-2-architecture/running-route-generator-2026-05-30.md) §3/§4 (tracking + summary), §7 (GPS lifecycle), [UX checklist](../level-2-architecture/ux-and-rubric-checklist-2026-05-31.md) (§5 tracking/summary; "always know where I am" → current marker; no idiot boxes → confirm only discard). Builds on M4.1 (`RunTrackingCubit`, `RunRecord`, `LocationSource`), M3 (`RouteMap`, `ScoredRoute`).

**Scope:** format helpers + RouteMap current-marker + TrackingScreen + RunSummaryScreen + wiring + Android permission. **Out:** saving runs to history (Save is a disabled placeholder → M5).

**Notes:** Flutter at `$HOME/flutter/bin/flutter`. English, Conventional Commits, no AI/tooling attribution. **Run `flutter test` + `flutter analyze` green before each commit.** `lib/domain` stays Flutter-free. Widget tests must not hit GPS/network; cancel timers on dispose so no test has pending timers.

---

## File Structure (M4.2)

```
android/app/src/main/AndroidManifest.xml   # + ACCESS_FINE/COARSE_LOCATION
lib/domain/format.dart                      # formatDuration, formatPace
lib/features/common/route_map.dart          # + optional currentLocation marker
lib/features/tracking/tracking_screen.dart  # TrackingScreen
lib/features/tracking/run_summary_screen.dart # RunSummaryScreen
lib/app/router.dart                         # + '/tracking'
lib/features/detail/route_detail_screen.dart # enable "Start run" -> push '/tracking'
test/domain/format_test.dart
test/features/tracking/tracking_screen_test.dart
test/features/tracking/run_summary_screen_test.dart
```

---

## Task 1: Format helpers (pure)

**Files:** `lib/domain/format.dart`, `test/domain/format_test.dart`

- [ ] **Step 1: Failing test** — `test/domain/format_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/domain/format.dart';

void main() {
  group('formatDuration', () {
    test('mm:ss under an hour', () {
      expect(formatDuration(0), '00:00');
      expect(formatDuration(65), '01:05');
    });
    test('h:mm:ss at/over an hour', () {
      expect(formatDuration(3725), '1:02:05');
    });
  });
  group('formatPace', () {
    test("min'sec\" per km", () {
      expect(formatPace(1000, 300), "5'00\"");
      expect(formatPace(2000, 600), "5'00\"");
    });
    test('placeholder when distance is ~0', () {
      expect(formatPace(0, 120), "--'--\"");
    });
  });
}
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement** — `lib/domain/format.dart`:
```dart
/// "mm:ss" under an hour, "h:mm:ss" at/over an hour.
String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Pace as `m'ss"` per km; `--'--"` when no meaningful distance.
String formatPace(double distanceM, int seconds) {
  if (distanceM < 1) return "--'--\"";
  final secPerKm = seconds / (distanceM / 1000);
  final m = secPerKm ~/ 60;
  final s = (secPerKm % 60).round();
  return "$m'${s.toString().padLeft(2, '0')}\"";
}
```

- [ ] **Step 4: Run → PASS (4).** `flutter analyze`. Commit:
```bash
git add lib/domain/format.dart test/domain/format_test.dart
git commit -m "feat: add duration + pace formatting helpers"
```

---

## Task 2: `RouteMap` current-location marker

**Files:** modify `lib/features/common/route_map.dart`

- [ ] **Step 1: Add an optional current-location marker.** In `RouteMap`, add a `final RoutePoint? currentLocation;` field (constructor param, default null). When non-null, add a `MarkerLayer` with a distinct blue dot. Keep all existing layers. The marker:
```dart
if (currentLocation != null)
  MarkerLayer(markers: [
    Marker(
      point: LatLng(currentLocation!.lat, currentLocation!.lng),
      width: 22,
      height: 22,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
      ),
    ),
  ]),
```
Update the constructor to `const RouteMap({super.key, required this.points, this.interactive = true, this.currentLocation});`.

- [ ] **Step 2:** `flutter analyze` (clean) + `flutter test` (84 still pass — additive change). Commit:
```bash
git add lib/features/common/route_map.dart
git commit -m "feat: optional current-location marker on RouteMap"
```

---

## Task 3: `TrackingScreen`

**Files:** `lib/features/tracking/tracking_screen.dart`, `test/features/tracking/tracking_screen_test.dart`

- [ ] **Step 1: Failing widget test** — `test/features/tracking/tracking_screen_test.dart`:
```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/app/theme.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/services/location_source.dart';
import 'package:freshloop/features/tracking/tracking_screen.dart';

class _FakeSource implements LocationSource {
  _FakeSource(this.controller, {this.granted = true});
  final StreamController<RoutePoint> controller;
  final bool granted;
  @override
  Future<bool> ensurePermission() async => granted;
  @override
  Stream<RoutePoint> positions() => controller.stream;
}

void main() {
  testWidgets('shows live distance and a Stop control while tracking', (tester) async {
    final controller = StreamController<RoutePoint>.broadcast();
    await tester.pumpWidget(MaterialApp(
      theme: freshLoopTheme,
      home: TrackingScreen(locationSource: _FakeSource(controller)),
    ));
    await tester.pump(); // let start() resolve + first emit
    await tester.pump();

    controller.add(const RoutePoint(lat: 45.0, lng: 9.0));
    await tester.pump();
    controller.add(const RoutePoint(lat: 45.001, lng: 9.0)); // ~111 m
    await tester.pump();

    expect(find.textContaining('Stop'), findsOneWidget);
    expect(find.textContaining('0.11'), findsWidgets); // 0.11 km shown

    // dispose to cancel the ticker (no pending timers)
    await tester.pumpWidget(const SizedBox());
    await controller.close();
  });

  testWidgets('shows a permission message when location is denied', (tester) async {
    final controller = StreamController<RoutePoint>.broadcast();
    await tester.pumpWidget(MaterialApp(
      theme: freshLoopTheme,
      home: TrackingScreen(locationSource: _FakeSource(controller, granted: false)),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Location'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await controller.close();
  });
}
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement** — `lib/features/tracking/tracking_screen.dart`:
```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/format.dart';
import '../../domain/models/scored_route.dart';
import '../../services/location_source.dart';
import '../../state/run_tracking_cubit.dart';
import '../../state/run_tracking_state.dart';
import '../common/route_map.dart';
import 'run_summary_screen.dart';

/// Live run tracking: the map follows the user, live distance/time/pace, and a
/// Stop control. Owns a [RunTrackingCubit] built from [locationSource].
class TrackingScreen extends StatefulWidget {
  final LocationSource locationSource;
  final ScoredRoute? planned;
  const TrackingScreen({super.key, required this.locationSource, this.planned});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  late final RunTrackingCubit _cubit = RunTrackingCubit(widget.locationSource);
  final Stopwatch _watch = Stopwatch();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _watch.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _cubit.start();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _watch.stop();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return BlocConsumer<RunTrackingCubit, RunTrackingState>(
      bloc: _cubit,
      listener: (context, state) {
        if (state is RunFinished) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => RunSummaryScreen(record: state.record, planned: widget.planned),
          ));
        }
      },
      builder: (context, state) {
        if (state is RunPermissionDenied) {
          return Scaffold(
            appBar: AppBar(title: const Text('Run')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Location permission is needed to track your run.',
                    textAlign: TextAlign.center),
              ),
            ),
          );
        }
        final live = state is RunInProgress ? state : null;
        final distanceM = live?.distanceM ?? 0;
        final points = live?.points ?? const [];
        final elapsed = _watch.elapsed.inSeconds;
        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: RouteMap(
                  points: widget.planned?.geometry.points ?? points,
                  currentLocation: points.isNotEmpty ? points.last : null,
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _stat(t, (distanceM / 1000).toStringAsFixed(2), 'km'),
                            _stat(t, formatDuration(elapsed), 'time'),
                            _stat(t, formatPace(distanceM, elapsed), 'pace'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: t.colorScheme.error),
                            onPressed: _cubit.stop,
                            icon: const Icon(Icons.stop),
                            label: const Text('Stop run'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(ThemeData t, String value, String label) => Column(
        children: [
          Text(value, style: t.textTheme.headlineSmall),
          Text(label, style: t.textTheme.bodySmall),
        ],
      );
}
```

- [ ] **Step 4: Run → PASS (2).** `flutter analyze`. Commit:
```bash
git add lib/features/tracking/tracking_screen.dart test/features/tracking/tracking_screen_test.dart
git commit -m "feat: add live TrackingScreen (map follow + distance/time/pace + stop)"
```

---

## Task 4: `RunSummaryScreen`

**Files:** `lib/features/tracking/run_summary_screen.dart`, `test/features/tracking/run_summary_screen_test.dart`

- [ ] **Step 1: Failing widget test** — `test/features/tracking/run_summary_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/app/theme.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/domain/models/run_record.dart';
import 'package:freshloop/features/tracking/run_summary_screen.dart';

void main() {
  testWidgets('shows distance, time, pace for a finished run', (tester) async {
    const record = RunRecord(
      points: [RoutePoint(lat: 45.0, lng: 9.0), RoutePoint(lat: 45.001, lng: 9.0)],
      distanceM: 2000,
      durationS: 600,
    );
    await tester.pumpWidget(const MaterialApp(home: RunSummaryScreen(record: record)));
    await tester.pump();
    expect(find.textContaining('2.00'), findsWidgets);   // km
    expect(find.text('10:00'), findsOneWidget);          // duration
    expect(find.text("5'00\""), findsOneWidget);         // pace
    expect(find.textContaining('Done'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement** — `lib/features/tracking/run_summary_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/format.dart';
import '../../domain/models/run_record.dart';
import '../../domain/models/scored_route.dart';
import '../common/route_map.dart';

/// Post-run summary: the actual trail, headline stats, and (if the run followed
/// a planned route) planned-vs-actual distance. Save is a placeholder (M5).
class RunSummaryScreen extends StatelessWidget {
  final RunRecord record;
  final ScoredRoute? planned;
  const RunSummaryScreen({super.key, required this.record, this.planned});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final km = (record.distanceM / 1000).toStringAsFixed(2);
    return Scaffold(
      appBar: AppBar(title: const Text('Run summary')),
      body: ListView(
        children: [
          SizedBox(height: 220, child: RouteMap(points: record.points, interactive: false)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat(t, '$km', 'km'),
                    _stat(t, formatDuration(record.durationS), 'time'),
                    _stat(t, formatPace(record.distanceM, record.durationS), 'pace'),
                  ],
                ),
                if (planned != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Planned ${(planned!.geometry.distanceM / 1000).toStringAsFixed(1)} km · '
                    'ran $km km',
                    style: t.textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: null, // saving to history arrives in M5
                        icon: const Icon(Icons.bookmark_border),
                        label: const Text('Save (M5)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => SharePlus.instance.share(
                          ShareParams(text: 'I ran $km km in ${formatDuration(record.durationS)} with FreshLoop!'),
                        ),
                        icon: const Icon(Icons.share),
                        label: const Text('Share'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(ThemeData t, String value, String label) => Column(
        children: [
          Text(value, style: t.textTheme.headlineSmall),
          Text(label, style: t.textTheme.bodySmall),
        ],
      );
}
```
(If `SharePlus.instance.share(ShareParams(...))` does not match the installed share_plus API, use the correct current call and report it.)

- [ ] **Step 4: Run → PASS (1).** `flutter analyze`. Commit:
```bash
git add lib/features/tracking/run_summary_screen.dart test/features/tracking/run_summary_screen_test.dart
git commit -m "feat: add RunSummaryScreen (trail, stats, planned-vs-actual, share)"
```

---

## Task 5: Wire "Start run" + route + Android permission

**Files:** `lib/app/router.dart`, `lib/features/detail/route_detail_screen.dart`, `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Add the `/tracking` route** in `lib/app/router.dart` (import `TrackingScreen`, `GeolocatorLocationSource`, `ScoredRoute`):
```dart
GoRoute(
  path: '/tracking',
  builder: (context, state) => TrackingScreen(
    locationSource: const GeolocatorLocationSource(),
    planned: state.extra as ScoredRoute?,
  ),
),
```

- [ ] **Step 2: Enable "Start run"** in `lib/features/detail/route_detail_screen.dart` — replace the disabled button:
```dart
                  FilledButton.icon(
                    onPressed: null, // live tracking arrives in M4
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start run (M4)'),
                  ),
```
with (add `import 'package:go_router/go_router.dart';`):
```dart
                  FilledButton.icon(
                    onPressed: () => context.push('/tracking', extra: widget.route),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start run'),
                  ),
```

- [ ] **Step 3: Android location permission.** In `android/app/src/main/AndroidManifest.xml`, add inside `<manifest>` (above `<application>`):
```xml
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

- [ ] **Step 4:** `flutter analyze` (clean) + `flutter test` (green). Commit:
```bash
git add lib/app/router.dart lib/features/detail/route_detail_screen.dart android/app/src/main/AndroidManifest.xml
git commit -m "feat: wire Start run to tracking + add Android location permission"
```

---

## Task 6: Final verification

- [ ] **Step 1:** `flutter test` → expect 84 (after M4.1) + format 4 + tracking 2 + summary 1 = **91 tests**, all passing.
- [ ] **Step 2:** `flutter analyze` → clean.
- [ ] **Step 3:** `git status` clean; `lib/domain` Flutter-free; no real secrets tracked.

---

## Self-Review (author)

**Spec coverage:** §3/§4 tracking + summary → Tasks 3/4; §7 GPS lifecycle (cubit + ticker cancelled on dispose) → Task 3 `dispose`; current-location marker (review L1/M9) → Task 2 + tracking map; "Start run" wiring (review M8) → Task 5; "no idiot boxes" → Stop has no confirm dialog. Deferred: saving runs → M5 (Save disabled).

**Placeholder scan:** none — complete code + exact test expectations (distance/pace/duration values verified).

**Type consistency:** `RunTrackingCubit`/states/`RunRecord`/`LocationSource` (M4.1) used in TrackingScreen; `formatDuration`/`formatPace` (Task 1) used in both screens + tested; `RouteMap` gains `currentLocation` (Task 2) used by TrackingScreen; `ScoredRoute` (M3.1) passed via go_router extra; `GeolocatorLocationSource` (M4.1) in the route builder. share_plus API call flagged for version-check in Task 4.

**Test/GPS note:** TrackingScreen tested with a `_FakeSource` + StreamController (deterministic distance); the ticker is cancelled on dispose and tests dispose the widget (no pending timers). `GeolocatorLocationSource` + the manifest are verified by analyze/build, not unit tests.
