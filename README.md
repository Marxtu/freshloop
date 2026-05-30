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
  <img src="docs/screenshots/m32-home.png" alt="FreshLoop home — map-forward with the route params sheet" width="260">
</p>
<p align="center"><em>The home screen (M3.2): a full-screen map with the "design your run" sheet — distance + air/hills/scenery weight sliders + a terrain choice + the amber Generate action. Theme A (Sora / DM Sans, trail-green + amber). Candidate cards, route detail, and tracking follow.</em></p>

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

**M3.2 — Route-generation UI: complete.** On top of M1 (scoring engine), M2 (the full
beyond-Firebase data stack: OpenRouteService, Nominatim, Open-Meteo, OSM Overpass,
Mapillary, Wikimedia), and M3.1 (the `RouteGenerator` + `RouteGenCubit` engine), the first
real screens are in: a map-forward home with the params sheet (distance + axis-weight
sliders + terrain + Generate) and the candidate-comparison cards. **70 tests passing**,
static analysis clean. Next: M3.3 route detail (elevation chart + photo carousel).

Latest release: **[v0.2.0-m2](https://github.com/Marxtu/freshloop/releases/tag/v0.2.0-m2)** (`freshloop-0.2.0-m2-arm64.apk`).

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
- [ ] **M3.3** — Route detail: map + elevation chart + AQI/greenery badges + scenery photo carousel
- [ ] **M4** — Live GPS run tracking + post-run summary
- [ ] **M5** — Firebase auth/storage, history, favorites, profile
- [ ] **M6** — Multi-device adaptation, polish, and integration tests

## Tech stack

Flutter · flutter_bloc · http · geolocator · flutter_map (OSM) · go_router · Firebase · share_plus

## Getting started

```bash
flutter pub get
flutter test        # 70 unit/widget tests
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
