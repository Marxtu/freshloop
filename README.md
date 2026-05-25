# FreshLoop — Smart Running Route Generator

A Flutter app that **designs** running routes for you: given a start point and a target
distance, it generates loop routes ranked by a quality score over **air quality**,
**elevation**, and **scenery/greenery**, with along-route photos — then lets you follow
the route with live GPS tracking and export a report.

It *designs* a run rather than tracking one — staying original instead of being another
run-tracker clone.

Final project for *Design and Implementation of Mobile Applications* (Politecnico di
Milano, Prof. Luciano Baresi).

## Screenshots

<p align="center">
  <img src="docs/screenshots/home-v3.png" alt="Home — map + params sheet" width="232">
  &nbsp;
  <img src="docs/screenshots/candidates-v3.png" alt="Candidates — ranked route cards" width="232">
  &nbsp;
  <img src="docs/screenshots/detail-v3.png" alt="Route detail — map, elevation, photos" width="232">
</p>
<p align="center"><em>The route-generation flow (M3) — <b>home</b> (map-forward "design your run" sheet) → <b>candidates</b> (ranked cards: route preview, score, per-axis badges) → <b>route detail</b> (map loop, elevation profile, along-the-way photos). Theme A: Sora / DM Sans, trail-green + amber.</em></p>

<p align="center">
  <img src="docs/screenshots/tracking-v2.png" alt="Live run tracking" width="232">
  &nbsp;
  <img src="docs/screenshots/summary-v2.png" alt="Post-run summary" width="232">
</p>
<p align="center"><em>Live run (M4) — <b>tracking</b> (the map follows you with live distance/time/pace + a current-location dot) → <b>post-run summary</b> (trail, stats, planned-vs-actual, share).</em></p>

<p align="center">
  <img src="docs/screenshots/signin.png" alt="Branded sign-in / create account" width="232">
  &nbsp;
  <img src="docs/screenshots/history.png" alt="Run history" width="232">
  &nbsp;
  <img src="docs/screenshots/favourites.png" alt="Favourite routes" width="232">
</p>
<p align="center"><em>Accounts (M5) — <b>sign in / create account</b> → <b>run history</b> and <b>favourite routes</b>, synced to Firebase under <code>/users/&lt;uid&gt;</code> and isolated per user by Firestore security rules (with on-device fallback when offline/unconfigured).</em></p>

### Visual direction

Look-&-feel is grounded in the course's design principles. We evaluated three directions and chose **A**:

<p align="center">
  <img src="docs/screenshots/theme-directions.png" alt="Three evaluated theme directions — A (chosen), B Ocean, C Forest editorial" width="760">
</p>

| | Direction | Palette · Typography | Why |
|---|---|---|---|
| **A** ✅ | Fresh-air cartographic | trail-green `#0E9F6E` + amber accent · Sora / DM Sans | sporty & outdoors; clearest CTA, best legibility — closest to the app's purpose |
| B | Ocean | teal + coral · Outfit / DM Sans | calm/wellness feel; running energy weaker |
| C | Forest editorial | deep green + clay · Fraunces / DM Sans | most distinctive, but an editorial serif risks mismatch with a running tool |

Full rationale: [visual design direction](docs/level-2-architecture/visual-design-direction-2026-05-31.md) · [UX & grading checklist](docs/level-2-architecture/ux-and-rubric-checklist-2026-05-31.md).

## Status

**Complete — all milestones M1–M6 shipped.** The full journey works end to end: **design** a run
(start + distance + air/hills/scenery weights) → **compare** ranked candidate routes → **inspect**
a route (map, elevation, along-the-way photos) → **run** it live (map-follow + distance/time/pace)
→ review a **post-run summary** → and **sign in** to sync **run history & favourite routes** to the
cloud (Firebase Auth + Firestore, each user isolated by security rules, with an on-device fallback).
The UI adapts from phone-portrait to tablet/landscape. **123 tests passing**, static analysis clean,
built incrementally across 14 reviewed PRs.

## How route scoring works

Each candidate loop is scored 0–100 on three axes, then combined with user-set weights:

- **Air** — the lower the AQI sampled along the route, the higher the score.
- **Elevation** — how close the actual ascent is to the runner's *target* (flat for
  beginners, hilly for training) — a preference match, not "flatter is always better".
- **Scenery** — greenery/water coverage in the route corridor plus scenic waypoints passed.

Each axis maps to a 3-tier badge (good / partial / poor) with a one-line explanation,
inspired by the WHO assessment rubric — so the score is transparent, not a black box.

## Roadmap

- [x] **M1** — Foundation: app shell + pure-Dart scoring engine
- [x] **M2** — External data layer: routing (OpenRouteService) + geocoding (Nominatim) + air quality (Open-Meteo) + greenery (OSM Overpass) + photos (Mapillary, Wikimedia), all behind injectable, fully mock-tested clients
- [x] **M3.1** — Route-generation engine: `RouteGenerator` (orchestrates clients + scorer into ranked candidates) + `RouteGenCubit`
- [x] **M3.2** — Route-generation UI: map-forward home, params sheet, candidate-comparison cards (Theme A)
- [x] **M3.3** — Route detail: map + elevation chart + AQI/greenery badges + scenery photo carousel
- [x] **M4.1** — Run-tracking engine: `RunTrackingCubit` + mockable `LocationSource` (geolocator) + distance math
- [x] **M4.2** — Tracking UI: live run screen (map-follow + distance/time/pace + stop) + post-run summary; current-location marker
- [x] **M5.1** — History & favourites behind repository interfaces (on-device persistence)
- [x] **M5.2** — Email/password auth + Firestore cloud sync (mock-tested), behind the same interfaces
- [x] **M5.3** — Firebase activated at runtime: auth gate + per-user cloud repos + local fallback (live-verified)
- [x] **M6** — Multi-device adaptation (grid + side-by-side), polish & accessibility, end-to-end flow test

## Tech stack

Flutter · flutter_bloc · http · geolocator · flutter_map (OSM) · go_router · Firebase · share_plus

## Getting started

```bash
flutter pub get
flutter test        # 91 unit/widget tests
flutter run         # on a device/emulator, or: flutter run -d chrome
```

## Documentation

- **Design (SSOT):** [`docs/level-2-architecture/running-route-generator-2026-05-30.md`](docs/level-2-architecture/running-route-generator-2026-05-30.md)
- **Foundation (course analysis):** [`docs/level-1-foundation/course-materials-analysis-2026-05-30.md`](docs/level-1-foundation/course-materials-analysis-2026-05-30.md)
- **M1 implementation plan:** [`docs/level-3-implementation/m1-foundation-and-scoring-2026-05-30.md`](docs/level-3-implementation/m1-foundation-and-scoring-2026-05-30.md)

## Secrets

API keys are never committed. Copy the `.example` templates to local config (gitignored).
See the design doc §13.7.

To run against live APIs, copy the template to a gitignored `secrets.json`, fill in your keys, and pass it at run/build time:

```bash
cp secrets.example.json secrets.json
flutter run --dart-define-from-file=secrets.json
```
