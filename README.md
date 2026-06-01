# FreshLoop: a smart running-route generator

A Flutter app that *designs* running routes for you. Give it a start point and a target
distance and it generates loop routes, ranked by a quality score over air quality,
elevation, and scenery/greenery, with photos from along the way. You can then follow the
chosen route with live GPS tracking and export a report afterwards.

The point is that it designs a run rather than tracking one, which keeps it from being yet
another run-tracker clone.

Final project for *Design and Implementation of Mobile Applications* (Politecnico di
Milano, Prof. Luciano Baresi).

## Screenshots

<p align="center">
  <img src="docs/screenshots/home-v5.png" alt="Home — address search, GPS, collapsible 'design your run' sheet" width="232">
  &nbsp;
  <img src="docs/screenshots/candidates-v3.png" alt="Candidates — ranked route cards" width="232">
  &nbsp;
  <img src="docs/screenshots/detail-v3.png" alt="Route detail — map, elevation, photos" width="232">
</p>
<p align="center"><em>The route-generation flow (M3). The home screen is a map-forward "design your run" sheet; from there you reach the ranked candidate cards (route preview, score, per-axis badges), then a route's detail page with the loop on a map, an elevation profile, and along-the-way photos. Theme A uses Sora and DM Sans, trail-green with an amber accent.</em></p>

<p align="center">
  <img src="docs/screenshots/tracking-v2.png" alt="Live run tracking" width="232">
  &nbsp;
  <img src="docs/screenshots/summary-v2.png" alt="Post-run summary" width="232">
</p>
<p align="center"><em>The live run (M4). While tracking, the map follows you with live distance, time and pace plus a current-location dot; the post-run summary shows the trail, the stats, planned-vs-actual, and a share button.</em></p>

<p align="center">
  <img src="docs/screenshots/signin.png" alt="Branded sign-in / create account" width="232">
  &nbsp;
  <img src="docs/screenshots/history.png" alt="Run history" width="232">
  &nbsp;
  <img src="docs/screenshots/favourites.png" alt="Favourite routes" width="232">
</p>
<p align="center"><em>Accounts (M5): sign in or create an account, then browse run history and favourite routes. These sync to Firebase under <code>/users/&lt;uid&gt;</code> and are isolated per user by Firestore security rules, with an on-device fallback when you're offline or Firebase isn't configured.</em></p>

<p align="center">
  <img src="docs/screenshots/history-v2.png" alt="Run history — each past run shows its date and is tappable" width="232">
  &nbsp;
  <img src="docs/screenshots/run-detail-v1.png" alt="Run details — a past run's trail on a map with full stats" width="232">
</p>
<p align="center"><em>Openable run history. Each past run shows the date it was run and is tappable; opening one shows the trail on a map with full stats (distance, time, pace).</em></p>

### Multi-device (tablet / landscape)

<p align="center">
  <img src="docs/screenshots/tablet-detail.png" alt="Route detail on a tablet — map and detail panel side-by-side" width="760">
</p>
<p align="center"><em>The same screens adapt by width off a single <code>isWide</code> breakpoint (720dp). On a wide screen the route detail becomes a map and detail panel side-by-side (above) and the candidates become a multi-column grid; on phones they collapse to a draggable sheet over the map and a single-column list. This is genuine width-adaptive layout, which is the course's "multi-device" requirement.</em></p>

### Visual direction

The look-and-feel is grounded in the course's design principles. We sketched three directions and went with **A**:

<p align="center">
  <img src="docs/screenshots/theme-directions.png" alt="Three evaluated theme directions — A (chosen), B Ocean, C Forest editorial" width="760">
</p>

| | Direction | Palette / Typography | Why |
|---|---|---|---|
| **A** (chosen) | Fresh-air cartographic | trail-green `#0E9F6E` + amber accent, Sora / DM Sans | sporty and outdoors; clearest CTA, best legibility, closest to what the app is for |
| B | Ocean | teal + coral, Outfit / DM Sans | calm, wellness-y; the running energy comes through weaker |
| C | Forest editorial | deep green + clay, Fraunces / DM Sans | the most distinctive, but an editorial serif risks feeling wrong on a running tool |

Full rationale is in the [visual design direction](docs/level-2-architecture/visual-design-direction-2026-05-31.md) and the [UX & rubric checklist](docs/level-2-architecture/ux-and-rubric-checklist-2026-05-31.md).

## Status

Complete: all milestones M1–M6 are shipped. The full journey works end to end. You design a
run (start, distance, and air/hills/scenery weights), compare the ranked candidate routes,
inspect a route (map, elevation, along-the-way photos), run it live with map-follow and
distance/time/pace, review a post-run summary, and sign in to sync run history and favourite
routes to the cloud (Firebase Auth + Firestore, each user isolated by security rules, with an
on-device fallback). The UI adapts from phone-portrait to tablet/landscape. There are 128
tests passing, static analysis is clean, the work was built incrementally across reviewed PRs,
and it is released as v1.0.0 (Android APK).

### Recent updates (post-release, from on-device testing)

- **Start a run anywhere.** The home screen has an address search with live type-ahead (Photon, an OSM-based geocoder built for autocomplete: typing "Carre" surfaces nearby Carrefours, sorted nearest-first, each with its straight-line distance from you) plus a GPS "locate me" button, so the start point comes from your real location rather than a fixed city centre. This replaced Nominatim, whose `/search` isn't a prefix matcher, so "Carre" matched towns named "Carrè" worldwide instead of the shop near you.
- **Google-Maps-style search feel.** Modelled on how Maps biases predictions to the visible map: results now follow the map (pan to another area and the next search re-biases there, like "search this area"), predictions fire from the 2nd character (debounced), you can long-press the map to start a run anywhere (reverse-geocoded to a place name), and a clear (×) button resets the box.
- **Collapsible map.** The "Design your run" sheet drags down to a handle so the map goes near full-screen (and you can see the start marker), then snaps back up when you want to set params.
- **Sharper along-the-way photos.** We request Mapillary's 1024px thumbnails (they used to be upscaled and blurry) and fetch them in parallel; 360° panoramas are kept as a badged fallback instead of an empty strip.
- **Tap to view photos.** Full-screen zoom and pan, and 360° panoramas open in a real spherical viewer you can drag to look around. The viewer lazy-loads a high-resolution image: panoramas pull the original full-resolution image (2048px is still soft once wrapped on a 360° sphere), with a loading spinner and an automatic fall-back if it fails; perspective shots use 2048px. The carousel keeps the light 1024px thumbnail.
- **Openable run history.** Tap any past run to see its trail on a map, full stats (distance, time, pace), and the date it was run (runs now store a start timestamp).
- **Correct Android back.** Navigating into a route now stacks screens, so the system Back button returns to the previous screen instead of quitting the app.
- **Robustness.** A clear "API key missing, build with `--dart-define-from-file=secrets.json`" error instead of a cryptic ORS 401, and the home sheet is width-capped and centred on wide screens.

## How route generation works

<p align="center">
  <img src="docs/screenshots/route-gen-flow.png" alt="Route-generation data flow: generate candidates via OpenRouteService → enrich with Open-Meteo AQI and OSM Overpass greenery → score on three axes → rank best-first" width="720">
</p>

FreshLoop doesn't hand-roll pathfinding; the geometry is delegated to OpenRouteService. The
original part is the orchestration. It over-generates a pool of candidates, both round-trip
loops and out-and-back routes (route to a turnaround about half the distance away, then mirror
it home), and keeps the ones closest to the requested distance. Out-and-backs matter where the
trail network is too sparse for a clean loop: an alpine valley returns tangled ~13 km loops for
a 5 km request, but a ~4.5 km out-and-back works. It then enriches each kept candidate with live
data (Open-Meteo AQI, OSM Overpass greenery, and the route's own ascent), scores it on three
axes, and ranks them best-first for the comparison screen. Enrichment failures degrade to neutral
values so a route is still scored; only a routing failure stops generation. See
[`lib/services/route_generator.dart`](lib/services/route_generator.dart).

## How route scoring works

Each candidate loop is scored 0–100 on three axes, then combined with user-set weights:

- **Air.** The lower the AQI sampled along the route, the higher the score.
- **Elevation.** How close the actual ascent is to the runner's *target* (flat for
  beginners, hilly for training). It's a preference match, not "flatter is always better".
- **Scenery.** Greenery and water coverage in the route corridor, plus any scenic waypoints
  passed.

Each axis maps to a 3-tier badge (good / partial / poor) with a one-line explanation,
inspired by the WHO assessment rubric, so the score stays transparent rather than a black box.

## Roadmap

- [x] **M1.** Foundation: app shell + pure-Dart scoring engine
- [x] **M2.** External data layer: routing (OpenRouteService) + geocoding (Nominatim) + air quality (Open-Meteo) + greenery (OSM Overpass) + photos (Mapillary, Wikimedia), all behind injectable, fully mock-tested clients
- [x] **M3.1.** Route-generation engine: `RouteGenerator` (orchestrates clients + scorer into ranked candidates) + `RouteGenCubit`
- [x] **M3.2.** Route-generation UI: map-forward home, params sheet, candidate-comparison cards (Theme A)
- [x] **M3.3.** Route detail: map + elevation chart + AQI/greenery badges + scenery photo carousel
- [x] **M4.1.** Run-tracking engine: `RunTrackingCubit` + mockable `LocationSource` (geolocator) + distance math
- [x] **M4.2.** Tracking UI: live run screen (map-follow + distance/time/pace + stop) + post-run summary; current-location marker
- [x] **M5.1.** History & favourites behind repository interfaces (on-device persistence)
- [x] **M5.2.** Email/password auth + Firestore cloud sync (mock-tested), behind the same interfaces
- [x] **M5.3.** Firebase activated at runtime: auth gate + per-user cloud repos + local fallback (live-verified)
- [x] **M6.** Multi-device adaptation (grid + side-by-side), polish & accessibility, end-to-end flow test

## Tech stack

Flutter, flutter_bloc, http, geolocator, flutter_map (OSM), go_router, Firebase, share_plus.

## Getting started

```bash
flutter pub get
flutter test        # 127 unit/widget tests (no network/Firebase — fully mocked)

# Live APIs need keys. Copy the template, fill in your keys, and pass it at
# run/build time — WITHOUT this flag, route generation fails with a clear
# "API key missing" error (the keys are compile-time --dart-define values).
cp secrets.example.json secrets.json
flutter run -d chrome --dart-define-from-file=secrets.json
flutter build apk --release --target-platform android-arm64 --dart-define-from-file=secrets.json
```

## Development process and provenance

This was built incrementally and traceably by a single author, so the whole R&D journey is on
GitHub rather than a single drop. Every milestone followed the same loop: a design doc, then
test-driven implementation, then two independent reviews (specification and code quality), then
a reviewed pull request merged to `main`.

- **[`CHANGELOG.md`](CHANGELOG.md)** is the milestone-by-milestone development log (design phase, M1–M6, then the post-release on-device iteration), each entry with its PR.
- **[Pull requests (15)](https://github.com/Marxtu/freshloop/pulls?q=is%3Apr+is%3Amerged)**: one per milestone or step, design through implement, review, and merge.
- **[Commit history](https://github.com/Marxtu/freshloop/commits/main)**: real incremental commits.
- **[Releases](https://github.com/Marxtu/freshloop/releases)**: `v0.1.0-m1`, `v0.2.0-m2`, `v1.0.0` (Android APK).

### Documentation (layered)

- **Level 1, Foundation:** [course-materials analysis](docs/level-1-foundation/course-materials-analysis-2026-05-30.md), covering problem framing, rubric, and the framework decision.
- **Level 2, Architecture:** [system design (SSOT)](docs/level-2-architecture/running-route-generator-2026-05-30.md), the [UX & rubric checklist](docs/level-2-architecture/ux-and-rubric-checklist-2026-05-31.md), and the [visual direction](docs/level-2-architecture/visual-design-direction-2026-05-31.md).
- **Level 3, Implementation:** the per-milestone plans in [`docs/level-3-implementation/`](docs/level-3-implementation) (M1 through M6).
- **Reviews and report:** the [UI review](docs/audit/ui-review-2026-05-31.md) and the [project report](docs/project-report-2026-05-31.md).

## Secrets

API keys are never committed. Copy the `.example` templates to local config (gitignored).
See the design doc §13.7.

To run against live APIs, copy the template to a gitignored `secrets.json`, fill in your keys, and pass it at run/build time:

```bash
cp secrets.example.json secrets.json
flutter run --dart-define-from-file=secrets.json
```
