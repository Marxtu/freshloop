# FreshLoop M5.1 — History + Favorites (local persistence) · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development or superpowers:executing-plans. Checkbox (`- [ ]`) steps.

**Goal:** Let users save runs (history) and favorite routes, persisted on device via `shared_preferences`, behind repository interfaces so M5.2 can swap in Firebase without touching the UI.

**Architecture:** Pure-Dart `toJson`/`fromJson` on the stored models (domain stays Flutter-free). Abstract `RunHistoryRepository` + `FavoritesRepository` in `lib/services/`, with `SharedPrefs*` implementations (the only `shared_preferences`-touching code). A `FavoritesCubit` exposes the reactive favourite set; history is read on demand. Shared repo/cubit instances provided in `dependencies.dart`. Tests use `SharedPreferences.setMockInitialValues({})`, so they never touch real device storage.

**Tech Stack:** Flutter, flutter_bloc, `shared_preferences`, Dart.

**SSOT:** [system design](../level-2-architecture/running-route-generator-2026-05-30.md) §8 (`RunRecord`, persistence), [UX checklist](../level-2-architecture/ux-and-rubric-checklist-2026-05-31.md). Builds on M1 (`ScoreBreakdown`/`AxisScore`/`Tier`), M3.1 (`ScoredRoute`, `RouteGeometry`/`RoutePoint`), M4.1 (`RunRecord`), M4.2 (run summary "Save").

**Scope:** JSON for stored models + 2 repos (shared_preferences) + FavoritesCubit + History/Favorites screens + wiring (Save run, favourite toggle) + home nav. **Out:** Firebase auth + cloud sync = M5.2 (same interfaces, Firebase impls); profile/settings = later.

**Decisions:** favourite identity = a stable `routeKey` (seed + rounded distance + start lat/lng); history newest-first; storing full geometry/trail is acceptable at this scale.

**Notes:** Flutter at `$HOME/flutter/bin/flutter`. English, Conventional Commits, no AI/tooling attribution. **Run `flutter test` + `flutter analyze` green before each commit.** `lib/domain` stays Flutter-free (toJson/fromJson use only `Map`/`dart:core`). Tests must not touch real storage.

---

## File Structure (M5.1)

```
pubspec.yaml                                  # + shared_preferences
lib/domain/models/route_geometry_json.dart    # (NO) — add toJson/fromJson onto existing models instead
lib/data/routing/route_geometry.dart          # + toJson/fromJson (RoutePoint, RouteGeometry)
lib/domain/models/score_breakdown.dart         # + toJson/fromJson
lib/domain/models/scored_route.dart            # + toJson/fromJson + routeKey
lib/domain/models/run_record.dart              # + toJson/fromJson
lib/services/run_history_repository.dart        # abstract + SharedPrefsRunHistoryRepository
lib/services/favorites_repository.dart          # abstract + SharedPrefsFavoritesRepository
lib/state/favorites_cubit.dart                  # FavoritesCubit (reactive set)
lib/features/saved/history_screen.dart          # HistoryScreen
lib/features/saved/favorites_screen.dart        # FavoritesScreen
lib/app/dependencies.dart                       # + shared repo/cubit providers
lib/app/router.dart                             # + '/history', '/favorites'
lib/features/home/home_screen.dart              # app-bar actions -> history/favorites
lib/features/detail/route_detail_screen.dart    # favourite toggle
lib/features/tracking/run_summary_screen.dart   # enable Save -> history
test/...
```

---

## Task 1: JSON for the stored models

**Files:** modify `lib/data/routing/route_geometry.dart`, `lib/domain/models/score_breakdown.dart`, `lib/domain/models/scored_route.dart`, `lib/domain/models/run_record.dart`; create `test/domain/models/json_roundtrip_test.dart`

- [ ] **Step 1: Failing test** in `test/domain/models/json_roundtrip_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/domain/models/axis_score.dart';
import 'package:freshloop/domain/models/run_record.dart';
import 'package:freshloop/domain/models/score_breakdown.dart';
import 'package:freshloop/domain/models/scored_route.dart';

void main() {
  test('RouteGeometry JSON round-trips', () {
    const g = RouteGeometry(
      points: [RoutePoint(lat: 1, lng: 2, elevation: 3), RoutePoint(lat: 4, lng: 5)],
      distanceM: 100, ascentM: 10,
    );
    final r = RouteGeometry.fromJson(g.toJson());
    expect(r.points.length, 2);
    expect(r.points.first.elevation, 3);
    expect(r.points[1].elevation, isNull);
    expect(r.distanceM, 100);
    expect(r.ascentM, 10);
  });

  test('ScoredRoute JSON round-trips and keeps a stable routeKey', () {
    final route = ScoredRoute(
      seed: 2,
      geometry: const RouteGeometry(points: [RoutePoint(lat: 45.4, lng: 9.1)], distanceM: 5000, ascentM: 40),
      score: ScoreBreakdown(air: AxisScore(80), hills: AxisScore(60), scenery: AxisScore(40), total: 61.0, explanation: 'x'),
    );
    final r = ScoredRoute.fromJson(route.toJson());
    expect(r.seed, 2);
    expect(r.score.total, 61.0);
    expect(r.score.air.value, 80);
    expect(r.routeKey, route.routeKey);
  });

  test('RunRecord JSON round-trips', () {
    const rec = RunRecord(points: [RoutePoint(lat: 1, lng: 2)], distanceM: 2000, durationS: 600);
    final r = RunRecord.fromJson(rec.toJson());
    expect(r.distanceM, 2000);
    expect(r.durationS, 600);
    expect(r.points.length, 1);
  });
}
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement.** Add a `toJson`/`fromJson` on `RoutePoint` and `RouteGeometry` to `lib/data/routing/route_geometry.dart`:
```dart
// In RoutePoint:
  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, if (elevation != null) 'ele': elevation};
  factory RoutePoint.fromJson(Map<String, dynamic> j) => RoutePoint(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        elevation: j['ele'] == null ? null : (j['ele'] as num).toDouble(),
      );

// In RouteGeometry:
  Map<String, dynamic> toJson() => {
        'points': points.map((p) => p.toJson()).toList(),
        'distanceM': distanceM,
        'ascentM': ascentM,
      };
  factory RouteGeometry.fromJson(Map<String, dynamic> j) => RouteGeometry(
        points: (j['points'] as List).map((e) => RoutePoint.fromJson(e as Map<String, dynamic>)).toList(),
        distanceM: (j['distanceM'] as num).toDouble(),
        ascentM: (j['ascentM'] as num).toDouble(),
      );
```
Add to `lib/domain/models/score_breakdown.dart` (import `axis_score.dart` already present):
```dart
  Map<String, dynamic> toJson() => {
        'air': air.value, 'hills': hills.value, 'scenery': scenery.value,
        'total': total, 'explanation': explanation,
      };
  factory ScoreBreakdown.fromJson(Map<String, dynamic> j) => ScoreBreakdown(
        air: AxisScore((j['air'] as num).toDouble()),
        hills: AxisScore((j['hills'] as num).toDouble()),
        scenery: AxisScore((j['scenery'] as num).toDouble()),
        total: (j['total'] as num).toDouble(),
        explanation: j['explanation'] as String,
      );
```
Add to `lib/domain/models/scored_route.dart` (import `score_breakdown.dart` + `../../data/routing/route_geometry.dart` already present):
```dart
  /// Stable identity for favouriting (seed + rounded distance + start point).
  String get routeKey {
    final p = geometry.points.isEmpty ? '0,0' : '${geometry.points.first.lat},${geometry.points.first.lng}';
    return '$seed|${geometry.distanceM.round()}|$p';
  }

  Map<String, dynamic> toJson() => {
        'seed': seed,
        'geometry': geometry.toJson(),
        'score': score.toJson(),
      };
  factory ScoredRoute.fromJson(Map<String, dynamic> j) => ScoredRoute(
        seed: j['seed'] as int,
        geometry: RouteGeometry.fromJson(j['geometry'] as Map<String, dynamic>),
        score: ScoreBreakdown.fromJson(j['score'] as Map<String, dynamic>),
      );
```
Add to `lib/domain/models/run_record.dart` (import `../../data/routing/route_geometry.dart` already present):
```dart
  Map<String, dynamic> toJson() => {
        'points': points.map((p) => p.toJson()).toList(),
        'distanceM': distanceM,
        'durationS': durationS,
      };
  factory RunRecord.fromJson(Map<String, dynamic> j) => RunRecord(
        points: (j['points'] as List).map((e) => RoutePoint.fromJson(e as Map<String, dynamic>)).toList(),
        distanceM: (j['distanceM'] as num).toDouble(),
        durationS: j['durationS'] as int,
      );
```

- [ ] **Step 4: Run → PASS (3).** `flutter analyze`. Commit:
```bash
git add lib/data/routing/route_geometry.dart lib/domain/models/score_breakdown.dart lib/domain/models/scored_route.dart lib/domain/models/run_record.dart test/domain/models/json_roundtrip_test.dart
git commit -m "feat: add JSON serialization to route + run models (+ routeKey)"
```

---

## Task 2: `RunHistoryRepository` (shared_preferences)

**Files:** modify `pubspec.yaml`; create `lib/services/run_history_repository.dart`, `test/services/run_history_repository_test.dart`

- [ ] **Step 1: Add dep.** `flutter pub add shared_preferences`

- [ ] **Step 2: Failing test** in `test/services/run_history_repository_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/domain/models/run_record.dart';
import 'package:freshloop/services/run_history_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saves runs and lists them newest-first', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPrefsRunHistoryRepository(prefs);

    expect(await repo.all(), isEmpty);
    await repo.save(const RunRecord(points: [RoutePoint(lat: 1, lng: 2)], distanceM: 1000, durationS: 300));
    await repo.save(const RunRecord(points: [], distanceM: 2000, durationS: 600));

    final all = await repo.all();
    expect(all.length, 2);
    expect(all.first.distanceM, 2000); // newest first
  });
}
```

- [ ] **Step 3: Implement** `lib/services/run_history_repository.dart`:
```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models/run_record.dart';

/// Stores completed runs. M5.1 persists locally; M5.2 swaps in Firebase.
abstract class RunHistoryRepository {
  Future<void> save(RunRecord record);
  Future<List<RunRecord>> all(); // newest first
}

class SharedPrefsRunHistoryRepository implements RunHistoryRepository {
  static const _key = 'run_history_v1';
  final SharedPreferences _prefs;
  SharedPrefsRunHistoryRepository(this._prefs);

  @override
  Future<List<RunRecord>> all() async {
    final raw = _prefs.getStringList(_key) ?? const [];
    return raw
        .map((s) => RunRecord.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList()
        .reversed
        .toList();
  }

  @override
  Future<void> save(RunRecord record) async {
    final raw = _prefs.getStringList(_key) ?? <String>[];
    raw.add(jsonEncode(record.toJson()));
    await _prefs.setStringList(_key, raw);
  }
}
```

- [ ] **Step 4: Run → PASS (1).** `flutter analyze`. Commit:
```bash
git add pubspec.yaml lib/services/run_history_repository.dart test/services/run_history_repository_test.dart
git commit -m "feat: add RunHistoryRepository with shared_preferences impl"
```

---

## Task 3: `FavoritesRepository` + `FavoritesCubit`

**Files:** create `lib/services/favorites_repository.dart`, `lib/state/favorites_cubit.dart`, `test/services/favorites_repository_test.dart`, `test/state/favorites_cubit_test.dart`

- [ ] **Step 1: Failing repo test** in `test/services/favorites_repository_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/domain/models/axis_score.dart';
import 'package:freshloop/domain/models/score_breakdown.dart';
import 'package:freshloop/domain/models/scored_route.dart';
import 'package:freshloop/services/favorites_repository.dart';

ScoredRoute _route(int seed) => ScoredRoute(
      seed: seed,
      geometry: RouteGeometry(points: const [RoutePoint(lat: 45, lng: 9)], distanceM: 5000.0 + seed, ascentM: 40),
      score: ScoreBreakdown(air: AxisScore(80), hills: AxisScore(60), scenery: AxisScore(40), total: 60, explanation: 'x'),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('adds, lists, checks, and removes favourites', () async {
    final repo = SharedPrefsFavoritesRepository(await SharedPreferences.getInstance());
    final a = _route(1);
    await repo.add(a);
    expect((await repo.all()).length, 1);
    expect(await repo.isFavorite(a.routeKey), isTrue);
    await repo.remove(a.routeKey);
    expect(await repo.all(), isEmpty);
    expect(await repo.isFavorite(a.routeKey), isFalse);
  });
}
```

- [ ] **Step 2: Run → FAIL. Implement** `lib/services/favorites_repository.dart`:
```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models/scored_route.dart';

abstract class FavoritesRepository {
  Future<void> add(ScoredRoute route);
  Future<void> remove(String routeKey);
  Future<List<ScoredRoute>> all();
  Future<bool> isFavorite(String routeKey);
}

class SharedPrefsFavoritesRepository implements FavoritesRepository {
  static const _key = 'favorites_v1';
  final SharedPreferences _prefs;
  SharedPrefsFavoritesRepository(this._prefs);

  List<ScoredRoute> _load() => (_prefs.getStringList(_key) ?? const [])
      .map((s) => ScoredRoute.fromJson(jsonDecode(s) as Map<String, dynamic>))
      .toList();

  Future<void> _store(List<ScoredRoute> routes) =>
      _prefs.setStringList(_key, routes.map((r) => jsonEncode(r.toJson())).toList());

  @override
  Future<List<ScoredRoute>> all() async => _load();

  @override
  Future<bool> isFavorite(String routeKey) async =>
      _load().any((r) => r.routeKey == routeKey);

  @override
  Future<void> add(ScoredRoute route) async {
    final routes = _load();
    if (routes.any((r) => r.routeKey == route.routeKey)) return;
    routes.add(route);
    await _store(routes);
  }

  @override
  Future<void> remove(String routeKey) async {
    final routes = _load()..removeWhere((r) => r.routeKey == routeKey);
    await _store(routes);
  }
}
```
Run repo test → PASS (1). Commit:
```bash
git add lib/services/favorites_repository.dart test/services/favorites_repository_test.dart
git commit -m "feat: add FavoritesRepository with shared_preferences impl"
```

- [ ] **Step 3: Failing cubit test** in `test/state/favorites_cubit_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/domain/models/axis_score.dart';
import 'package:freshloop/domain/models/score_breakdown.dart';
import 'package:freshloop/domain/models/scored_route.dart';
import 'package:freshloop/services/favorites_repository.dart';
import 'package:freshloop/state/favorites_cubit.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('toggle adds then removes, exposing isFavorite', () async {
    final repo = SharedPrefsFavoritesRepository(await SharedPreferences.getInstance());
    final cubit = FavoritesCubit(repo);
    await cubit.load();
    final route = ScoredRoute(
      seed: 1,
      geometry: const RouteGeometry(points: [RoutePoint(lat: 45, lng: 9)], distanceM: 5000, ascentM: 40),
      score: ScoreBreakdown(air: AxisScore(80), hills: AxisScore(60), scenery: AxisScore(40), total: 60, explanation: 'x'),
    );

    await cubit.toggle(route);
    expect(cubit.isFavorite(route.routeKey), isTrue);
    expect(cubit.state.length, 1);

    await cubit.toggle(route);
    expect(cubit.isFavorite(route.routeKey), isFalse);
    expect(cubit.state, isEmpty);
    await cubit.close();
  });
}
```

- [ ] **Step 4: Implement** `lib/state/favorites_cubit.dart`:
```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/models/scored_route.dart';
import '../services/favorites_repository.dart';

/// Reactive favourites: state is the current list of favourite routes.
class FavoritesCubit extends Cubit<List<ScoredRoute>> {
  final FavoritesRepository repo;
  FavoritesCubit(this.repo) : super(const []);

  Future<void> load() async => emit(await repo.all());

  bool isFavorite(String routeKey) => state.any((r) => r.routeKey == routeKey);

  Future<void> toggle(ScoredRoute route) async {
    if (isFavorite(route.routeKey)) {
      await repo.remove(route.routeKey);
    } else {
      await repo.add(route);
    }
    emit(await repo.all());
  }
}
```
Run cubit test → PASS (1). Commit:
```bash
git add lib/state/favorites_cubit.dart test/state/favorites_cubit_test.dart
git commit -m "feat: add FavoritesCubit (reactive toggle over the repository)"
```

---

## Task 4: Screens + wiring + nav

**Files:** create `lib/features/saved/history_screen.dart`, `lib/features/saved/favorites_screen.dart`; modify `lib/app/dependencies.dart`, `lib/app/router.dart`, `lib/features/home/home_screen.dart`, `lib/features/detail/route_detail_screen.dart`, `lib/features/tracking/run_summary_screen.dart`; create `test/features/saved/history_screen_test.dart`

- [ ] **Step 1: dependencies.dart, shared instances.** Append:
```dart
import 'package:shared_preferences/shared_preferences.dart';
import '../services/run_history_repository.dart';
import '../services/favorites_repository.dart';

late final SharedPreferences appPrefs; // set in main() before runApp
RunHistoryRepository buildHistoryRepository() => SharedPrefsRunHistoryRepository(appPrefs);
FavoritesRepository buildFavoritesRepository() => SharedPrefsFavoritesRepository(appPrefs);
```
And in `lib/main.dart`, make `main` async and init prefs:
```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'app/dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  appPrefs = await SharedPreferences.getInstance();
  runApp(const FreshLoopApp());
}
```
Provide a `FavoritesCubit` app-wide in `lib/app/app.dart`. Add an optional injection param (mirroring the existing `generator`) and wrap `MaterialApp.router` in a `MultiBlocProvider`:
```dart
class FreshLoopApp extends StatelessWidget {
  final RouteGenerator? generator;
  final FavoritesRepository? favoritesRepository; // inject in tests
  const FreshLoopApp({super.key, this.generator, this.favoritesRepository});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => RouteGenCubit(generator ?? buildRouteGenerator())),
        BlocProvider(create: (_) => FavoritesCubit(favoritesRepository ?? buildFavoritesRepository())..load()),
      ],
      child: MaterialApp.router(/* title/theme/routerConfig unchanged */),
    );
  }
}
```
(import `flutter_bloc`'s `MultiBlocProvider`, `FavoritesCubit`, `FavoritesRepository`.)

**Smoke-test fix (verified):** `test/app/smoke_test.dart` pumps `const FreshLoopApp()`, which now builds `FavoritesCubit`, calls `buildFavoritesRepository()`, and reads the late `appPrefs`. Add a `setUp` so the default path works (imports: `shared_preferences`, `package:freshloop/app/dependencies.dart`):
```dart
setUp(() async {
  SharedPreferences.setMockInitialValues({});
  appPrefs = await SharedPreferences.getInstance();
});
```

- [ ] **Step 2: HistoryScreen** in `lib/features/saved/history_screen.dart`:
```dart
import 'package:flutter/material.dart';
import '../../domain/format.dart';
import '../../domain/models/run_record.dart';
import '../../services/run_history_repository.dart';

class HistoryScreen extends StatelessWidget {
  final RunHistoryRepository repo;
  const HistoryScreen({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Run history')),
      body: FutureBuilder<List<RunRecord>>(
        future: repo.all(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final runs = snap.data ?? const [];
          if (runs.isEmpty) {
            return const Center(child: Text('No runs yet — finish a run to see it here.'));
          }
          return ListView.separated(
            itemCount: runs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = runs[i];
              return ListTile(
                leading: const Icon(Icons.directions_run),
                title: Text('${(r.distanceM / 1000).toStringAsFixed(2)} km'),
                subtitle: Text('${formatDuration(r.durationS)} · ${formatPace(r.distanceM, r.durationS)} /km'),
              );
            },
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 3: FavoritesScreen** in `lib/features/saved/favorites_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/scored_route.dart';
import '../../state/favorites_cubit.dart';
import '../common/tier_badge.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final routes = context.watch<FavoritesCubit>().state;
    return Scaffold(
      appBar: AppBar(title: const Text('Favourite routes')),
      body: routes.isEmpty
          ? const Center(child: Text('No favourites yet — tap the heart on a route.'))
          : ListView.builder(
              itemCount: routes.length,
              itemBuilder: (context, i) {
                final ScoredRoute r = routes[i];
                return ListTile(
                  title: Text('${r.score.total.toStringAsFixed(0)} · ${(r.geometry.distanceM / 1000).toStringAsFixed(1)} km'),
                  subtitle: Text(r.score.explanation),
                  trailing: TierBadge(axis: 'Air', tier: r.score.air.tier),
                  onTap: () => context.push('/detail', extra: r),
                );
              },
            ),
    );
  }
}
```

- [ ] **Step 4: Routes.** In `lib/app/router.dart` add (import the screens + `buildHistoryRepository`):
```dart
GoRoute(path: '/history', builder: (c, s) => HistoryScreen(repo: buildHistoryRepository())),
GoRoute(path: '/favorites', builder: (c, s) => const FavoritesScreen()),
```

- [ ] **Step 5: Home nav.** `lib/features/home/home_screen.dart` is a bare `Stack` (map + bottom Card). Overlay two icon buttons top-right, above the map, for contrast use `IconButton.filledTonal`:
```dart
Positioned(
  top: 0, right: 0,
  child: SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Row(children: [
        IconButton.filledTonal(
          icon: const Icon(Icons.history),
          tooltip: 'Run history',
          onPressed: () => context.push('/history'),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          icon: const Icon(Icons.favorite),
          tooltip: 'Favourite routes',
          onPressed: () => context.push('/favorites'),
        ),
      ]),
    ),
  ),
),
```
Add this as a third child of the existing `Stack` (after the bottom `Align`). `context` already has go_router (`package:go_router/go_router.dart` is imported).

- [ ] **Step 6: Wire Save (summary) + favourite toggle (detail).**
  - `lib/features/tracking/run_summary_screen.dart`: convert to a `StatefulWidget` (keep the same constructor params + add an optional injectable repo) so Save can flip to "Saved". The existing test pumps `RunSummaryScreen(record: record)` in a bare `MaterialApp` and does not tap Save, so it stays green (the repo is only read on tap). Constructor:
```dart
class RunSummaryScreen extends StatefulWidget {
  final RunRecord record;
  final ScoredRoute? planned;
  final RunHistoryRepository? historyRepo; // inject in tests; defaults to the app repo
  const RunSummaryScreen({super.key, required this.record, this.planned, this.historyRepo});
  @override
  State<RunSummaryScreen> createState() => _RunSummaryScreenState();
}
```
In the state, `bool _saved = false;` and replace the Save `OutlinedButton.icon`:
```dart
OutlinedButton.icon(
  onPressed: _saved ? null : () async {
    await (widget.historyRepo ?? buildHistoryRepository()).save(widget.record);
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to history')));
  },
  icon: Icon(_saved ? Icons.bookmark_added : Icons.bookmark_border),
  label: Text(_saved ? 'Saved' : 'Save'),
),
```
(References to `record`/`planned` become `widget.record`/`widget.planned`. Imports: `../../app/dependencies.dart`, `../../services/run_history_repository.dart`.) `tracking_screen.dart:54` constructs it with `record`/`planned` only, so it is unchanged and defaults to the app repo.
  - `lib/features/detail/route_detail_screen.dart`: add a favourite toggle as a top-right action mirroring the existing `BackButton` (top-left). Add a third `Positioned` in the `Stack`:
```dart
Positioned(
  top: 0, right: 0,
  child: SafeArea(child: Builder(builder: (context) {
    final fav = context.watch<FavoritesCubit>();
    final isFav = fav.isFavorite(widget.route.routeKey);
    return IconButton.filledTonal(
      icon: Icon(isFav ? Icons.favorite : Icons.favorite_border),
      tooltip: isFav ? 'Remove favourite' : 'Save to favourites',
      onPressed: () => fav.toggle(widget.route),
    );
  })),
),
```
(Imports: `package:flutter_bloc/flutter_bloc.dart`, `../../state/favorites_cubit.dart`. The cubit is provided app-wide, so it's in scope under the router.)

- [ ] **Step 7: Widget test** in `test/features/saved/history_screen_test.dart` (in-memory fake repo):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/domain/models/run_record.dart';
import 'package:freshloop/features/saved/history_screen.dart';
import 'package:freshloop/services/run_history_repository.dart';

class _FakeRepo implements RunHistoryRepository {
  final List<RunRecord> _runs;
  _FakeRepo(this._runs);
  @override
  Future<List<RunRecord>> all() async => _runs;
  @override
  Future<void> save(RunRecord r) async => _runs.add(r);
}

void main() {
  testWidgets('lists saved runs', (tester) async {
    final repo = _FakeRepo([
      const RunRecord(points: [RoutePoint(lat: 1, lng: 2)], distanceM: 5000, durationS: 1500),
    ]);
    await tester.pumpWidget(MaterialApp(home: HistoryScreen(repo: repo)));
    await tester.pumpAndSettle();
    expect(find.textContaining('5.00 km'), findsOneWidget);
    expect(find.textContaining('25:00'), findsOneWidget);
  });

  testWidgets('shows empty state', (tester) async {
    await tester.pumpWidget(MaterialApp(home: HistoryScreen(repo: _FakeRepo([]))));
    await tester.pumpAndSettle();
    expect(find.textContaining('No runs yet'), findsOneWidget);
  });
}
```

- [ ] **Step 8:** `flutter test` (green) + `flutter analyze` (clean). Commit:
```bash
git add lib/features/saved/ lib/app/dependencies.dart lib/app/app.dart lib/main.dart lib/app/router.dart lib/features/home/home_screen.dart lib/features/detail/route_detail_screen.dart lib/features/tracking/run_summary_screen.dart test/features/saved/history_screen_test.dart
git commit -m "feat: add history + favorites screens, wiring, and home navigation"
```

---

## Task 5: Final verification

- [ ] **Step 1:** `flutter test` → expect 91 (after M4.2) + json 3 + history-repo 1 + fav-repo 1 + fav-cubit 1 + history-screen 2 = **99 tests**, all passing.
- [ ] **Step 2:** `flutter analyze` → clean.
- [ ] **Step 3:** `git status` clean; `lib/domain` Flutter-free (toJson/fromJson use only Map); no real secrets tracked.

---

## Self-Review (author)

**Spec coverage:** §8 persistence/history/favourites → repos (Tasks 2/3) + screens (Task 4); Save wiring (M4.2 placeholder) → Task 4 step 6; favourite toggle → Task 4 step 6. Deferred: Firebase auth + cloud sync (same interfaces) → M5.2; profile/settings → later.

**Placeholder scan:** none; complete code plus exact test expectations.

**Type consistency:** `toJson`/`fromJson` round-trip the existing models (RoutePoint/RouteGeometry/ScoreBreakdown/AxisScore/RunRecord/ScoredRoute); `routeKey` used by FavoritesRepository + Cubit; repos behind interfaces (`RunHistoryRepository`/`FavoritesRepository`) so M5.2 swaps Firebase impls; `FavoritesCubit` state is `List<ScoredRoute>`; screens consume `format` helpers (M4.2) + `TierBadge` (M3.2) + go_router `/detail` extra (M3.3). `appPrefs` initialised in `main` before `runApp`.

**Persistence note:** local (shared_preferences); tests use `setMockInitialValues({})`. Real cloud persistence + auth is M5.2 (Firebase); the repository interfaces are the seam.
