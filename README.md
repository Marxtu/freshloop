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
  <img src="docs/screenshots/m1-home.png" alt="FreshLoop home screen (M1 foundation)" width="260">
</p>
<p align="center"><em>M1 — home shell with the Material 3 theme. The route-generation flow, map, and tracking screens arrive in M3; more screenshots will be added as milestones ship.</em></p>

## Status

**M1 — Foundation + scoring core: complete.** App shell (Material 3 + `go_router`) and a
fully unit-tested, pure-Dart route-scoring engine. 25 tests passing, static analysis clean.

Latest build: **[v0.1.0-m1 release](https://github.com/Marxtu/freshloop/releases/tag/v0.1.0-m1)**
— `freshloop-0.1.0-m1-arm64.apk` (arm64, debug-signed test build).

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
- [ ] **M2** — External API layer (OpenRouteService, Open-Meteo air/elevation, OSM Overpass, Mapillary/Wikimedia photos)
- [ ] **M3** — Route-generation UI (params → candidates → route detail with map, elevation chart, photos)
- [ ] **M4** — Live GPS run tracking + post-run summary
- [ ] **M5** — Firebase auth/storage, history, favorites, profile
- [ ] **M6** — Multi-device adaptation, polish, and integration tests

## Tech stack

Flutter · flutter_bloc · http · geolocator · flutter_map (OSM) · go_router · Firebase · share_plus

## Getting started

```bash
flutter pub get
flutter test        # 25 unit/widget tests
flutter run         # on a device/emulator, or: flutter run -d chrome
```

## Documentation

- **Design (SSOT):** [`docs/level-2-architecture/running-route-generator-2026-05-30.md`](docs/level-2-architecture/running-route-generator-2026-05-30.md)
- **Foundation (course analysis):** [`docs/level-1-foundation/course-materials-analysis-2026-05-30.md`](docs/level-1-foundation/course-materials-analysis-2026-05-30.md)
- **M1 implementation plan:** [`docs/level-3-implementation/m1-foundation-and-scoring-2026-05-30.md`](docs/level-3-implementation/m1-foundation-and-scoring-2026-05-30.md)

## Secrets

API keys are never committed. Copy the `.example` templates to local config (gitignored).
See the design doc §13.7.
