# FreshLoop M3.3 — Route Detail (elevation chart + photos) · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development or superpowers:executing-plans. Checkbox (`- [ ]`) steps.

**Goal:** The route-detail screen behind a candidate tap: the loop on a map, a clean elevation profile, the per-axis badges + explanation, and a scenery photo carousel, all wired from the candidate cards.

**Architecture:** A dep-free `ElevationChart` (CustomPainter, one clean line, no chart junk per the UX checklist). A `PhotoService` (orchestrates the M2.3 Mapillary + Wikimedia clients over a few route waypoints, dedups, degrades gracefully). A `PhotoCarousel` widget. `RouteDetailScreen` composes them, takes a `ScoredRoute`, and fetches photos via `FutureBuilder`. Candidate cards navigate to it with go_router `extra`.

**Tech Stack:** Flutter, flutter_map, flutter_bloc, http, `share_plus` (share action). No charting dependency; elevation is hand-painted.

**SSOT:** [visual direction](../level-2-architecture/visual-design-direction-2026-05-31.md) (route detail row), [UX checklist](../level-2-architecture/ux-and-rubric-checklist-2026-05-31.md) (§5 route detail; no chart junk; pictures > words), [system design](../level-2-architecture/running-route-generator-2026-05-30.md) §4. Builds on M2.3 (`MapillaryPhotoClient`, `WikimediaPhotoClient`, `ScenePhoto`), M3.1 (`ScoredRoute`, geo `subsample`), M3.2 (`RouteMap`, `TierBadge`, candidates screen, `dependencies.dart`).

**Scope:** elevation chart + photo service + carousel + detail screen + nav wiring. **Out:** live run tracking ("Start run" is a disabled/placeholder action, deferred to M4); export/share may be a simple share_plus text.

**Notes:** Flutter at `$HOME/flutter/bin/flutter`. English, Conventional Commits, no AI/tooling attribution. Run `flutter test` + `flutter analyze` green before each commit. Widget tests must not hit the network (inject fakes or canned data).

---

## File Structure (M3.3)

```
pubspec.yaml                                       # + share_plus
lib/features/detail/
  elevation_chart.dart                             # ElevationChart (CustomPainter)
  photo_carousel.dart                              # PhotoCarousel (PageView of ScenePhoto)
  route_detail_screen.dart                         # RouteDetailScreen(route, photoService)
lib/services/photo_service.dart                    # PhotoService.photosForRoute(geometry)
lib/app/dependencies.dart                          # + buildPhotoService()
lib/app/router.dart                                # + '/detail' (reads ScoredRoute from extra)
lib/features/candidates/candidates_screen.dart     # candidate onTap -> push '/detail'
test/services/photo_service_test.dart
test/features/detail/elevation_chart_test.dart
test/features/detail/photo_carousel_test.dart
```

---

## Task 1: `PhotoService`

**Files:** `lib/services/photo_service.dart`, `test/services/photo_service_test.dart`

- [ ] **Step 1: Failing test.** `test/services/photo_service_test.dart`:
```dart
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
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement.** `lib/services/photo_service.dart`:
```dart
import '../data/photos/mapillary_client.dart';
import '../data/photos/scene_photo.dart';
import '../data/photos/wikimedia_client.dart';
import '../data/routing/route_geometry.dart';
import '../domain/geo.dart';

/// Collects along-route scenery photos from Mapillary + Wikimedia over a few
/// sampled waypoints. Each source/waypoint failure is swallowed (photos are
/// decorative — design §11), and results are de-duplicated by url.
class PhotoService {
  final MapillaryPhotoClient mapillary;
  final WikimediaPhotoClient wikimedia;

  PhotoService({required this.mapillary, required this.wikimedia});

  Future<List<ScenePhoto>> photosForRoute(
    RouteGeometry geometry, {
    int maxWaypoints = 3,
    int perSource = 2,
  }) async {
    const d = 0.0015; // ~150 m bbox half-size for Mapillary (small = avoids 500s)
    final waypoints = subsample(geometry.points, maxWaypoints);
    final photos = <ScenePhoto>[];
    for (final wp in waypoints) {
      try {
        photos.addAll(await mapillary.photosInBbox(
          south: wp.lat - d, west: wp.lng - d, north: wp.lat + d, east: wp.lng + d,
          limit: perSource,
        ));
      } catch (_) {/* skip this waypoint's street imagery */}
      try {
        photos.addAll(await wikimedia.photosNear(
          lat: wp.lat, lng: wp.lng, radiusM: 250, limit: perSource,
        ));
      } catch (_) {/* skip this waypoint's landmarks */}
    }
    final seen = <String>{};
    return photos.where((p) => seen.add(p.url)).toList();
  }
}
```

- [ ] **Step 4: Run, expect PASS (2).** `flutter analyze`. Commit:
```bash
git add lib/services/photo_service.dart test/services/photo_service_test.dart
git commit -m "feat: add PhotoService merging Mapillary + Wikimedia along a route"
```

---

## Task 2: `ElevationChart` (dep-free CustomPainter)

**Files:** `lib/features/detail/elevation_chart.dart`, `test/features/detail/elevation_chart_test.dart`

- [ ] **Step 1: Failing test.** `test/features/detail/elevation_chart_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/features/detail/elevation_chart.dart';

void main() {
  testWidgets('renders a CustomPaint for a route with elevations', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ElevationChart(points: [
          RoutePoint(lat: 0, lng: 0, elevation: 100),
          RoutePoint(lat: 0, lng: 0, elevation: 130),
          RoutePoint(lat: 0, lng: 0, elevation: 110),
        ]),
      ),
    ));
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('shows a no-data hint when elevations are missing', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ElevationChart(points: [RoutePoint(lat: 0, lng: 0)])),
    ));
    expect(find.text('No elevation data'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement.** `lib/features/detail/elevation_chart.dart`:
```dart
import 'package:flutter/material.dart';
import '../../data/routing/route_geometry.dart';

/// A minimal elevation profile: one filled line, no axes clutter (the course's
/// "too many chart elements" anti-pattern). Heights normalize to the route's
/// own min/max. Shows a hint when no elevation data is available.
class ElevationChart extends StatelessWidget {
  final List<RoutePoint> points;
  final double height;
  const ElevationChart({super.key, required this.points, this.height = 96});

  @override
  Widget build(BuildContext context) {
    final elevations = [
      for (final p in points)
        if (p.elevation != null) p.elevation!,
    ];
    if (elevations.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No elevation data', style: Theme.of(context).textTheme.bodySmall),
        ),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _ElevationPainter(elevations, Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _ElevationPainter extends CustomPainter {
  final List<double> elevations;
  final Color color;
  _ElevationPainter(this.elevations, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final lo = elevations.reduce((a, b) => a < b ? a : b);
    final hi = elevations.reduce((a, b) => a > b ? a : b);
    final span = (hi - lo).abs() < 1 ? 1.0 : hi - lo;
    final dx = size.width / (elevations.length - 1);
    Offset at(int i) => Offset(
          dx * i,
          size.height - ((elevations[i] - lo) / span) * (size.height - 8) - 4,
        );

    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < elevations.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.12));
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ElevationPainter old) =>
      old.elevations != elevations || old.color != color;
}
```

- [ ] **Step 4: Run, expect PASS (2).** `flutter analyze`. Commit:
```bash
git add lib/features/detail/elevation_chart.dart test/features/detail/elevation_chart_test.dart
git commit -m "feat: add dep-free ElevationChart (single clean profile line)"
```

---

## Task 3: `PhotoCarousel`

**Files:** `lib/features/detail/photo_carousel.dart`, `test/features/detail/photo_carousel_test.dart`

- [ ] **Step 1: Failing test.** `test/features/detail/photo_carousel_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/data/photos/scene_photo.dart';
import 'package:freshloop/features/detail/photo_carousel.dart';

void main() {
  testWidgets('shows a hint when there are no photos', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PhotoCarousel(photos: [])),
    ));
    expect(find.text('No photos for this area'), findsOneWidget);
  });

  testWidgets('builds a page per photo', (tester) async {
    const photos = [
      ScenePhoto(url: 'https://img/1.jpg', source: PhotoSource.mapillary, lat: 0, lng: 0),
      ScenePhoto(url: 'https://img/2.jpg', source: PhotoSource.wikimedia, lat: 0, lng: 0, caption: 'Park'),
    ];
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PhotoCarousel(photos: photos)),
    ));
    expect(find.byType(PageView), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement.** `lib/features/detail/photo_carousel.dart`:
```dart
import 'package:flutter/material.dart';
import '../../data/photos/scene_photo.dart';

/// A swipeable strip of along-route scenery photos with a caption scrim.
/// Network image failures fall back to a neutral placeholder (graceful — §11).
class PhotoCarousel extends StatelessWidget {
  final List<ScenePhoto> photos;
  final double height;
  const PhotoCarousel({super.key, required this.photos, this.height = 180});

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No photos for this area', style: Theme.of(context).textTheme.bodySmall),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: PageView.builder(
        itemCount: photos.length,
        controller: PageController(viewportFraction: 0.9),
        itemBuilder: (context, i) {
          final p = photos[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    p.url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                  ),
                  if (p.caption != null)
                    Positioned(
                      left: 0, right: 0, bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter, end: Alignment.topCenter,
                            colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                          ),
                        ),
                        child: Text(p.caption!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Run, expect PASS (2).** `flutter analyze`. Commit:
```bash
git add lib/features/detail/photo_carousel.dart test/features/detail/photo_carousel_test.dart
git commit -m "feat: add PhotoCarousel for along-route scenery photos"
```

---

## Task 4: `RouteDetailScreen` + navigation wiring

**Files:** `lib/features/detail/route_detail_screen.dart`, `lib/app/dependencies.dart` (+ buildPhotoService), `lib/app/router.dart` (+ '/detail'), `lib/features/candidates/candidates_screen.dart` (onTap pushes the route)

- [ ] **Step 1: Implement `buildPhotoService()`.** Append to `lib/app/dependencies.dart`:
```dart
import '../data/photos/mapillary_client.dart';
import '../data/photos/wikimedia_client.dart';
import '../services/photo_service.dart';

PhotoService buildPhotoService() => PhotoService(
      mapillary: MapillaryPhotoClient(accessToken: AppConfig.mapillaryToken),
      wikimedia: WikimediaPhotoClient(userAgent: _userAgent),
    );
```
(Add `static const String mapillaryToken = String.fromEnvironment('MAPILLARY_TOKEN');` to `AppConfig` in `lib/app/app_config.dart` if not present.)

- [ ] **Step 2: Implement `RouteDetailScreen`.** `lib/features/detail/route_detail_screen.dart`:
```dart
import 'package:flutter/material.dart';
import '../../data/photos/scene_photo.dart';
import '../../domain/models/scored_route.dart';
import '../../services/photo_service.dart';
import '../common/route_map.dart';
import '../common/tier_badge.dart';
import 'elevation_chart.dart';
import 'photo_carousel.dart';

/// The chosen route in full: the loop on a map, with a draggable sheet holding
/// the score breakdown, elevation profile, scenery photos, and actions.
class RouteDetailScreen extends StatelessWidget {
  final ScoredRoute route;
  final PhotoService photoService;
  const RouteDetailScreen({super.key, required this.route, required this.photoService});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = route.score;
    final km = (route.geometry.distanceM / 1000).toStringAsFixed(1);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: RouteMap(points: route.geometry.points)),
          Positioned(
            top: 0, left: 0,
            child: SafeArea(child: BackButton(onPressed: () => Navigator.of(context).maybePop())),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.42,
            minChildSize: 0.2,
            maxChildSize: 0.9,
            builder: (context, controller) => Container(
              decoration: BoxDecoration(
                color: t.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Center(child: Container(width: 40, height: 4, color: t.colorScheme.outlineVariant)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(s.total.toStringAsFixed(0), style: t.textTheme.headlineLarge),
                      const SizedBox(width: 6),
                      Text('score', style: t.textTheme.bodySmall),
                      const Spacer(),
                      Text('$km km · ${route.geometry.ascentM.toStringAsFixed(0)} m up',
                          style: t.textTheme.bodyMedium),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, children: [
                    TierBadge(axis: 'Air', tier: s.air.tier),
                    TierBadge(axis: 'Hills', tier: s.hills.tier),
                    TierBadge(axis: 'Scenery', tier: s.scenery.tier),
                  ]),
                  const SizedBox(height: 8),
                  Text(s.explanation, style: t.textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  Text('Elevation', style: t.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  ElevationChart(points: route.geometry.points),
                  const SizedBox(height: 16),
                  Text('Along the way', style: t.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  FutureBuilder<List<ScenePhoto>>(
                    future: photoService.photosForRoute(route.geometry),
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
                      }
                      return PhotoCarousel(photos: snap.data ?? const []);
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: null, // live tracking arrives in M4
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start run (M4)'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Wire navigation.** In `lib/app/router.dart` add a route that reads the `ScoredRoute` from `state.extra` and builds the detail with `buildPhotoService()`:
```dart
GoRoute(
  path: '/detail',
  builder: (context, state) => RouteDetailScreen(
    route: state.extra! as ScoredRoute,
    photoService: buildPhotoService(),
  ),
),
```
(Add imports for `RouteDetailScreen`, `ScoredRoute`, and `dependencies.dart` in router.dart.)

In `lib/features/candidates/candidates_screen.dart`, change the card's `onTap: () {}` to:
```dart
onTap: () => context.push('/detail', extra: routes[i]),
```
(import `package:go_router/go_router.dart`.)

- [ ] **Step 4:** `flutter test` (existing suite still green, since no test mounts the live `/detail` route) + `flutter analyze` (clean). Commit:
```bash
git add lib/features/detail/route_detail_screen.dart lib/app/dependencies.dart lib/app/app_config.dart lib/app/router.dart lib/features/candidates/candidates_screen.dart
git commit -m "feat: add RouteDetailScreen and wire candidate tap to it"
```

---

## Task 5: Final verification

- [ ] **Step 1:** `flutter test` should report 70 (after M3.2) + photo_service 2 + elevation_chart 2 + photo_carousel 2 = 76 tests, all passing.
- [ ] **Step 2:** `flutter analyze` clean.
- [ ] **Step 3:** `git status` clean; `lib/domain` still Flutter-free; no real secrets tracked.

---

## Self-Review (author)

**Spec coverage:** UX checklist §5 route detail (map + clean elevation + badges + explanation + photo carousel + action) is Task 4; "no chart junk" is the dep-free single-line ElevationChart (Task 2); "pictures > words" is the photo carousel (Tasks 1/3); graceful degradation §11 is PhotoService try/catch plus carousel empty/error states. Deferred: "Start run" live tracking goes to M4 (disabled button).

**Placeholder scan:** none. Complete widget code plus exact test expectations.

**Type consistency:** `ScoredRoute`/`ScoreBreakdown`/`Tier` (M1/M3.1) used in detail + badges; `RouteGeometry`/`RoutePoint` in chart + map + PhotoService; `subsample` (M3.1 geo) in PhotoService; `MapillaryPhotoClient`/`WikimediaPhotoClient`/`ScenePhoto` (M2.3) in PhotoService/carousel; `RouteMap`/`TierBadge` (M3.2) reused; go_router `extra` passes `ScoredRoute`; `AppConfig.mapillaryToken` added. `withValues(alpha:)` is the current (non-deprecated) Color API.

**Live-API note:** the detail screen fetches photos at runtime (needs `--dart-define-from-file=secrets.json` for the Mapillary token; Wikimedia is keyless). Widget tests never mount the live `/detail` route; the photo widgets are tested with canned data and PhotoService with MockClient.
