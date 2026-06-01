# FreshLoop M3.2 — Route-Generation UI (theme, map, params, candidates) · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development or superpowers:executing-plans. Checkbox (`- [ ]`) steps.

**Goal:** The first real screens. Apply the locked visual direction (Theme A), render a map (`flutter_map`), let the user set params in a bottom sheet, trigger the M3.1 `RouteGenCubit`, and show ranked candidate cards. Built to the UX checklist + visual direction; verified by widget tests and a Chrome screenshot walkthrough.

**Architecture:** UI in `lib/features/`; theme upgraded in `lib/app/theme.dart`; a reusable `RouteMap` widget wraps `flutter_map`. The home wires `RouteGenCubit` (M3.1) via `BlocProvider`; screens render from its states. Real generation needs runtime keys (`--dart-define-from-file=secrets.json`); widget tests inject canned Cubit states or a fake generator, with no network in tests.

**Tech Stack:** Flutter, `flutter_bloc`, `flutter_map` + `latlong2`, `google_fonts`, `go_router`.

**SSOT:** [Visual design direction](../level-2-architecture/visual-design-direction-2026-05-31.md) (Theme A), [UX & grading checklist](../level-2-architecture/ux-and-rubric-checklist-2026-05-31.md), [system design](../level-2-architecture/running-route-generator-2026-05-30.md). Builds on M3.1 (`RouteGenCubit`, `RouteGenerator`, `ScoredRoute`, `RunParams`, `RouteGeometry`/`RoutePoint`).

**Scope of M3.2:** theme + deps, `RouteMap` widget, params bottom sheet, home + generate wiring, candidate comparison cards, routing. **Out:** route detail (elevation chart + photo carousel) = M3.3; live run tracking = M4.

**Decisions (per UX checklist + visual direction):** map-forward; params via bottom sheet (sliders + chips + one amber `FilledButton`, no button grid); terrain chips (Flat/Rolling/Hilly) map to `targetAscentM = {flat:0, rolling: 12*km, hilly: 30*km}`; 3 candidates; tier color always paired with a label.

**Notes:** Flutter at `$HOME/flutter/bin/flutter`. English, Conventional Commits, no AI/tooling attribution. Run `flutter test` + `flutter analyze` green before each commit. Touch only files named. Widget tests must not hit the network.

---

## File Structure (M3.2)

```
pubspec.yaml                                  # + flutter_map, latlong2, google_fonts
lib/app/theme.dart                            # Theme A: google_fonts textTheme, seed #0E9F6E, accent/tier colors
lib/app/router.dart                           # routes: '/', '/candidates'
lib/features/
  common/route_map.dart                       # RouteMap (flutter_map wrapper: tiles + polyline + markers)
  common/tier_badge.dart                       # TierBadge (color + label, never color-only)
  params/terrain.dart                          # Terrain enum + targetAscentFor()
  params/params_sheet.dart                     # ParamsSheet (distance + 3 weight sliders + terrain chips + Generate CTA)
  home/home_screen.dart                        # map-forward home hosting ParamsSheet, listens to RouteGenCubit
  candidates/candidate_card.dart               # CandidateCard (mini map preview + total + badges + stats)
  candidates/candidates_screen.dart            # list of CandidateCards (staggered)
test/features/
  params/terrain_test.dart
  params/params_sheet_test.dart
  candidates/candidate_card_test.dart
  app/smoke_test.dart                          # updated (theme + home render)
```

---

## Task 1: Dependencies + Theme A

**Files:** `pubspec.yaml`; `lib/app/theme.dart`; update `test/app/smoke_test.dart`

- [ ] **Step 1: Add deps.** `flutter pub add flutter_map latlong2 google_fonts`

- [ ] **Step 2: Implement Theme A.** Replace `lib/app/theme.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// FreshLoop palette (visual direction "Theme A").
class AppColors {
  AppColors._();
  static const seed = Color(0xFF0E9F6E); // vivid trail green (primary)
  static const accent = Color(0xFFF59E0B); // amber — reserved for the primary CTA + top score
  static const tierGood = Color(0xFF0E9F6E);
  static const tierPartial = Color(0xFFF59E0B);
  static const tierPoor = Color(0xFFEF4444);
}

/// Material 3 theme with the distinctive Sora (display) + DM Sans (body) pairing.
final ThemeData freshLoopTheme = () {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.seed);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.sora(textStyle: base.textTheme.displayLarge, fontWeight: FontWeight.w700),
      displayMedium: GoogleFonts.sora(textStyle: base.textTheme.displayMedium, fontWeight: FontWeight.w700),
      headlineLarge: GoogleFonts.sora(textStyle: base.textTheme.headlineLarge, fontWeight: FontWeight.w600),
      headlineMedium: GoogleFonts.sora(textStyle: base.textTheme.headlineMedium, fontWeight: FontWeight.w600),
      titleLarge: GoogleFonts.sora(textStyle: base.textTheme.titleLarge, fontWeight: FontWeight.w600),
    ),
  );
}();
```

- [ ] **Step 3: Update the smoke test** so it still passes with the new theme. Replace `test/app/smoke_test.dart` body to pump `FreshLoopApp` and assert the home tagline renders (keep it minimal; home content changes in Task 4, so for now assert the app builds without throwing):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/app/app.dart';

void main() {
  testWidgets('app boots with the FreshLoop theme', (tester) async {
    await tester.pumpWidget(const FreshLoopApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
```

- [ ] **Step 4:** `flutter test` (green) + `flutter analyze` (clean), then commit:
```bash
git add pubspec.yaml lib/app/theme.dart test/app/smoke_test.dart
git commit -m "feat: apply Theme A (Sora/DM Sans, trail-green + amber) and add map deps"
```

---

## Task 2: `Terrain` → target ascent (pure)

**Files:** `lib/features/params/terrain.dart`, `test/features/params/terrain_test.dart`

- [ ] **Step 1: Failing test.** `test/features/params/terrain_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/features/params/terrain.dart';

void main() {
  group('targetAscentFor', () {
    test('flat is 0 regardless of distance', () {
      expect(targetAscentFor(Terrain.flat, 5000), 0);
    });
    test('rolling is ~12 m per km', () {
      expect(targetAscentFor(Terrain.rolling, 5000), 60); // 12 * 5km
    });
    test('hilly is ~30 m per km', () {
      expect(targetAscentFor(Terrain.hilly, 5000), 150); // 30 * 5km
    });
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement.** `lib/features/params/terrain.dart`:
```dart
/// How hilly the runner wants the route. Maps to a target cumulative ascent.
enum Terrain { flat, rolling, hilly }

/// Target ascent (metres) for [terrain] over [distanceM]: flat=0, rolling≈12 m/km,
/// hilly≈30 m/km. Feeds RunParams.targetAscentM (scored against actual ascent).
double targetAscentFor(Terrain terrain, double distanceM) {
  final km = distanceM / 1000;
  switch (terrain) {
    case Terrain.flat:
      return 0;
    case Terrain.rolling:
      return 12 * km;
    case Terrain.hilly:
      return 30 * km;
  }
}
```

- [ ] **Step 4: Run, expect PASS (3).** `flutter analyze`. Commit:
```bash
git add lib/features/params/terrain.dart test/features/params/terrain_test.dart
git commit -m "feat: add Terrain preference mapping to target ascent"
```

---

## Task 3: `RouteMap` widget + `TierBadge`

**Files:** `lib/features/common/route_map.dart`, `lib/features/common/tier_badge.dart`, `test/features/candidates/candidate_card_test.dart` will use them (test added in Task 5). Add a light render test for RouteMap here.

- [ ] **Step 1: Implement `TierBadge`** (color always paired with a label, for accessibility). `lib/features/common/tier_badge.dart`:
```dart
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../domain/models/tier.dart';

/// A small chip showing an axis result: a coloured dot + a text label
/// (never colour alone). [axis] is e.g. "Air", "Hills", "Scenery".
class TierBadge extends StatelessWidget {
  final String axis;
  final Tier tier;
  const TierBadge({super.key, required this.axis, required this.tier});

  Color get _color => switch (tier) {
        Tier.good => AppColors.tierGood,
        Tier.partial => AppColors.tierPartial,
        Tier.poor => AppColors.tierPoor,
      };

  String get _label => switch (tier) {
        Tier.good => 'good',
        Tier.partial => 'ok',
        Tier.poor => 'poor',
      };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$axis $_label',
      child: Chip(
        avatar: CircleAvatar(backgroundColor: _color, radius: 6),
        label: Text('$axis · $_label'),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
```

- [ ] **Step 2: Implement `RouteMap`.** `lib/features/common/route_map.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../data/routing/route_geometry.dart';

/// A map showing a route polyline (and optionally a start marker) over OSM
/// tiles. [interactive] is false for small card previews.
class RouteMap extends StatelessWidget {
  final List<RoutePoint> points;
  final bool interactive;
  const RouteMap({super.key, required this.points, this.interactive = true});

  @override
  Widget build(BuildContext context) {
    final latLngs = points.map((p) => LatLng(p.lat, p.lng)).toList();
    final center = latLngs.isEmpty ? const LatLng(45.4642, 9.19) : latLngs.first;
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 14,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'it.polimi.freshloop',
        ),
        if (latLngs.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(points: latLngs, strokeWidth: 5, color: Theme.of(context).colorScheme.primary),
            ],
          ),
        if (latLngs.isNotEmpty)
          MarkerLayer(
            markers: [
              Marker(
                point: latLngs.first,
                child: Icon(Icons.place, color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
      ],
    );
  }
}
```

- [ ] **Step 3:** `flutter analyze` (clean, since these compile against flutter_map). Commit:
```bash
git add lib/features/common/route_map.dart lib/features/common/tier_badge.dart
git commit -m "feat: add RouteMap (flutter_map polyline) and TierBadge widgets"
```
(Widget render tests for these come with the screens in Tasks 4-5, where they're mounted in a pumpable context.)

---

## Task 4: Params bottom sheet + home wiring

**Files:** `lib/features/params/params_sheet.dart`, `lib/features/home/home_screen.dart`, `lib/app/router.dart`, `test/features/params/params_sheet_test.dart`

- [ ] **Step 1: Failing widget test.** `test/features/params/params_sheet_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/app/theme.dart';
import 'package:freshloop/domain/models/run_params.dart';
import 'package:freshloop/features/params/params_sheet.dart';

void main() {
  testWidgets('shows controls and emits RunParams on Generate', (tester) async {
    RunParams? captured;
    await tester.pumpWidget(MaterialApp(
      theme: freshLoopTheme,
      home: Scaffold(
        body: ParamsSheet(
          startLat: 45.46,
          startLng: 9.19,
          onGenerate: (p) => captured = p,
        ),
      ),
    ));

    expect(find.text('Generate'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(4)); // distance + 3 weights

    await tester.tap(find.text('Generate'));
    await tester.pump();

    expect(captured, isNotNull);
    expect(captured!.startLat, 45.46);
    expect(captured!.targetDistanceM, greaterThan(0));
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement `ParamsSheet`.** `lib/features/params/params_sheet.dart`:
```dart
import 'package:flutter/material.dart';
import '../../domain/models/run_params.dart';
import '../../domain/models/score_weights.dart';
import 'terrain.dart';

/// Bottom-sheet form: target distance, three axis-weight sliders, a terrain
/// choice, and one primary "Generate" action. Keep-it-brief; no button grid.
class ParamsSheet extends StatefulWidget {
  final double startLat;
  final double startLng;
  final ValueChanged<RunParams> onGenerate;
  const ParamsSheet({
    super.key,
    required this.startLat,
    required this.startLng,
    required this.onGenerate,
  });

  @override
  State<ParamsSheet> createState() => _ParamsSheetState();
}

class _ParamsSheetState extends State<ParamsSheet> {
  double _distanceKm = 5;
  double _air = 1, _hills = 1, _scenery = 1;
  Terrain _terrain = Terrain.rolling;

  void _generate() {
    final distanceM = _distanceKm * 1000;
    widget.onGenerate(RunParams(
      startLat: widget.startLat,
      startLng: widget.startLng,
      targetDistanceM: distanceM,
      weights: ScoreWeights(air: _air, hills: _hills, scenery: _scenery),
      targetAscentM: targetAscentFor(_terrain, distanceM),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Design your run', style: t.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Distance: ${_distanceKm.toStringAsFixed(1)} km'),
          Slider(
            value: _distanceKm,
            min: 1,
            max: 21,
            divisions: 40,
            label: '${_distanceKm.toStringAsFixed(1)} km',
            onChanged: (v) => setState(() => _distanceKm = v),
          ),
          _weight('Clean air', _air, (v) => setState(() => _air = v)),
          _weight('Right hills', _hills, (v) => setState(() => _hills = v)),
          _weight('Scenery', _scenery, (v) => setState(() => _scenery = v)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final terrain in Terrain.values)
                ChoiceChip(
                  label: Text(terrain.name),
                  selected: _terrain == terrain,
                  onSelected: (_) => setState(() => _terrain = terrain),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
              onPressed: _generate,
              icon: const Icon(Icons.route),
              label: const Text('Generate'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weight(String label, double value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 96, child: Text(label)),
        Expanded(
          child: Slider(value: value, max: 3, divisions: 3, onChanged: onChanged),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run, expect PASS (1).**

- [ ] **Step 5: Implement the home screen** (map-forward; params in a sheet; listens to the Cubit; navigates to candidates on loaded). `lib/features/home/home_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../state/route_gen_cubit.dart';
import '../../state/route_gen_state.dart';
import '../common/route_map.dart';
import '../params/params_sheet.dart';

/// Map-forward home: the map fills the screen; a bottom sheet holds the params.
/// On a successful generation it navigates to the candidates screen.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Milan Duomo as a sensible default start until live location is wired (M4).
  static const _startLat = 45.4642;
  static const _startLng = 9.19;

  @override
  Widget build(BuildContext context) {
    return BlocListener<RouteGenCubit, RouteGenState>(
      listener: (context, state) {
        if (state is RouteGenLoaded) {
          context.go('/candidates');
        } else if (state is RouteGenError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not generate a route: ${state.message}')),
          );
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: RouteMap(points: [])),
            Align(
              alignment: Alignment.bottomCenter,
              child: BlocBuilder<RouteGenCubit, RouteGenState>(
                builder: (context, state) {
                  final loading = state is RouteGenLoading;
                  return Card(
                    margin: const EdgeInsets.all(12),
                    child: loading
                        ? const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : ParamsSheet(
                            startLat: _startLat,
                            startLng: _startLng,
                            onGenerate: (p) => context.read<RouteGenCubit>().generate(p),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6:** Update `flutter analyze`. Router + Cubit provider wiring lands in Task 6 (where `/candidates` exists), so the home compiles now but navigation is exercised in Task 6. Commit:
```bash
git add lib/features/params/params_sheet.dart lib/features/home/home_screen.dart test/features/params/params_sheet_test.dart
git commit -m "feat: add params bottom sheet and map-forward home wired to RouteGenCubit"
```

---

## Task 5: Candidate cards + candidates screen

**Files:** `lib/features/candidates/candidate_card.dart`, `lib/features/candidates/candidates_screen.dart`, `test/features/candidates/candidate_card_test.dart`

- [ ] **Step 1: Failing widget test.** `test/features/candidates/candidate_card_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/app/theme.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/domain/models/axis_score.dart';
import 'package:freshloop/domain/models/score_breakdown.dart';
import 'package:freshloop/domain/models/scored_route.dart';
import 'package:freshloop/features/candidates/candidate_card.dart';

ScoredRoute _route() => ScoredRoute(
      seed: 1,
      geometry: const RouteGeometry(
        points: [RoutePoint(lat: 45.46, lng: 9.19), RoutePoint(lat: 45.47, lng: 9.20)],
        distanceM: 5000,
        ascentM: 40,
      ),
      score: ScoreBreakdown(
        air: AxisScore(80),
        hills: AxisScore(90),
        scenery: AxisScore(40),
        total: 72.3,
        explanation: 'Strong on air, hills; weak on scenery.',
      ),
    );

void main() {
  testWidgets('shows total, distance and the explanation', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: freshLoopTheme,
      home: Scaffold(body: CandidateCard(route: _route(), rank: 1, onTap: () {})),
    ));
    await tester.pump();
    expect(find.textContaining('72'), findsWidgets); // total score shown
    expect(find.textContaining('5.0 km'), findsOneWidget); // distance
    expect(find.textContaining('weak on scenery'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement `CandidateCard`.** `lib/features/candidates/candidate_card.dart`:
```dart
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../domain/models/scored_route.dart';
import '../common/route_map.dart';
import '../common/tier_badge.dart';

/// A tappable candidate: a small non-interactive map preview, the total score
/// (amber for the #1 rank), the per-axis badges, and the one-line explanation.
class CandidateCard extends StatelessWidget {
  final ScoredRoute route;
  final int rank; // 1 = best
  final VoidCallback onTap;
  const CandidateCard({super.key, required this.route, required this.rank, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = route.score;
    final km = (route.geometry.distanceM / 1000).toStringAsFixed(1);
    final totalColor = rank == 1 ? AppColors.accent : t.colorScheme.onSurface;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 120,
              child: RouteMap(points: route.geometry.points, interactive: false),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('${s.total.toStringAsFixed(0)}',
                          style: t.textTheme.headlineMedium?.copyWith(color: totalColor)),
                      const SizedBox(width: 6),
                      Text('score', style: t.textTheme.bodySmall),
                      const Spacer(),
                      Text('$km km · ${route.geometry.ascentM.toStringAsFixed(0)} m up',
                          style: t.textTheme.bodyMedium),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      TierBadge(axis: 'Air', tier: s.air.tier),
                      TierBadge(axis: 'Hills', tier: s.hills.tier),
                      TierBadge(axis: 'Scenery', tier: s.scenery.tier),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(s.explanation, style: t.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run, expect PASS (1).**

- [ ] **Step 5: Implement `CandidatesScreen`** (reads `RouteGenLoaded`; staggered list). `lib/features/candidates/candidates_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../state/route_gen_cubit.dart';
import '../../state/route_gen_state.dart';
import 'candidate_card.dart';

/// Shows the ranked candidates from the Cubit's loaded state.
class CandidatesScreen extends StatelessWidget {
  const CandidatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RouteGenCubit>().state;
    final routes = state is RouteGenLoaded ? state.routes : const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your route')),
      body: routes.isEmpty
          ? const Center(child: Text('No routes — try generating again.'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: routes.length,
              itemBuilder: (context, i) => CandidateCard(
                route: routes[i],
                rank: i + 1,
                onTap: () {}, // route detail = M3.3
              ),
            ),
    );
  }
}
```

- [ ] **Step 6:** `flutter analyze` (clean). Commit:
```bash
git add lib/features/candidates/ test/features/candidates/candidate_card_test.dart
git commit -m "feat: add candidate cards and the candidate comparison screen"
```

---

## Task 6: Wire routing + Cubit provider + final verification

**Files:** `lib/app/router.dart`, `lib/app/app.dart`, `lib/main.dart`

- [ ] **Step 1: Router.** `lib/app/router.dart`:
```dart
import 'package:go_router/go_router.dart';
import '../features/home/home_screen.dart';
import '../features/candidates/candidates_screen.dart';

final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/candidates', builder: (context, state) => const CandidatesScreen()),
  ],
);
```

- [ ] **Step 2: Provide the Cubit app-wide.** In `lib/app/app.dart`, wrap `MaterialApp.router` with `BlocProvider<RouteGenCubit>`. The `RouteGenerator` is built from the data clients using `AppConfig` keys (real APIs at runtime; widget tests build their own provider). Add a factory `buildRouteGenerator()`:

Create `lib/app/dependencies.dart`:
```dart
import '../app/app_config.dart';
import '../data/air/open_meteo_air_client.dart';
import '../data/greenery/overpass_client.dart';
import '../data/routing/ors_route_client.dart';
import '../services/route_generator.dart';

const _userAgent = 'FreshLoop/0.1 (course project)';

/// Builds the production RouteGenerator from real clients + configured keys.
RouteGenerator buildRouteGenerator() => RouteGenerator(
      ors: OrsRouteClient(apiKey: AppConfig.orsApiKey),
      air: OpenMeteoAirClient(),
      overpass: OverpassClient(userAgent: _userAgent),
    );
```

Replace `lib/app/app.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/route_generator.dart';
import '../state/route_gen_cubit.dart';
import 'dependencies.dart';
import 'router.dart';
import 'theme.dart';

class FreshLoopApp extends StatelessWidget {
  /// Inject a generator in tests; production builds one from real clients/keys.
  final RouteGenerator? generator;
  const FreshLoopApp({super.key, this.generator});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RouteGenCubit(generator ?? buildRouteGenerator()),
      child: MaterialApp.router(
        title: 'FreshLoop',
        theme: freshLoopTheme,
        routerConfig: appRouter,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
```
(`lib/main.dart` stays `runApp(const FreshLoopApp())`.)

- [ ] **Step 3: Final verification.** `flutter test` should all pass (expect 65 prior + terrain 3 + params 1 + candidate 1 = 70, minus/plus any smoke-test delta; confirm the actual number is green). `flutter analyze` clean. Commit:
```bash
git add lib/app/router.dart lib/app/app.dart lib/app/dependencies.dart
git commit -m "feat: wire RouteGenCubit provider and the candidates route"
```

---

## Self-Review (author)

**Spec coverage:** visual direction Theme A lands in Task 1 (theme), Task 3 (RouteMap/TierBadge), and Task 5 (cards). For the UX checklist: bottom sheet + sliders + chips + single amber CTA (no button grid) is Task 4; tier color+label (no color-only) is TierBadge; map-forward master-detail is home + candidates; the map itself is "pictures > words". Engine wiring is Tasks 4/6. Deferred: route detail, elevation chart, and photo carousel go to M3.3; live location and tracking go to M4.

**Placeholder scan:** none. Complete widget code, exact test expectations.

**Type consistency:** `RouteGenCubit`/states from M3.1 used in home/candidates; `ScoredRoute`/`ScoreBreakdown`/`Tier` from M1/M3.1 in cards/badges; `RunParams`/`ScoreWeights` in params; `RouteGeometry`/`RoutePoint` in RouteMap; `targetAscentFor` (Task 2) used by ParamsSheet; flutter_map `MapOptions(initialCenter,initialZoom,interactionOptions)` is the v6+ API; `AppConfig.orsApiKey` from M2.1.

**Live-API note:** real generation runs with `flutter run --dart-define-from-file=secrets.json`; widget tests inject states or a fake generator and never hit the network. After Task 6, run the Chrome screenshot walkthrough (phone + tablet) and score against the visual direction + UX checklist before the PR.
