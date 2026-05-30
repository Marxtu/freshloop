# Changelog & development log

FreshLoop was built **incrementally and traceably** by a single author (CHENWEI PAN). Every
milestone followed the same loop: a **design doc** (`docs/level-3-implementation/…`) → **test-driven
implementation** → **two independent reviews** (specification + code quality) → a **reviewed pull
request** merged to `main`. The result is **15 PRs (#1–#15)**, **3 release tags**, and a real commit
history — the whole R&D journey is on GitHub, not a single drop.

- **Pull requests:** https://github.com/Marxtu/freshloop/pulls?q=is%3Apr+is%3Amerged
- **Commit history:** https://github.com/Marxtu/freshloop/commits/main
- **Releases:** https://github.com/Marxtu/freshloop/releases
- Design docs by level: `docs/level-1-foundation/` (analysis) · `docs/level-2-architecture/` (system design, UX & visual) · `docs/level-3-implementation/` (per-milestone plans) · `docs/audit/` (UI reviews) · `docs/project-report-2026-05-31.md`.

---

## [1.0.0] — 2026-05-31 · tag `v1.0.0`

The complete app: full M1–M6 roadmap, a visual overhaul, and a round of on-device polish.

### Post-release iteration (driven by real on-device testing)
- **Start a run anywhere** — home **address search with live autocomplete** (OSM Nominatim, **nearby-first** with a global fallback, debounced) + a **GPS "locate me"** button set the start from the runner's real position instead of a fixed city centre.
- **Collapsible map sheet** — "Design your run" drags down to a handle so the map goes near full-screen (and the start marker is visible), then snaps back up.
- **Sharper photos** — Mapillary **1024px** thumbnails (were upscaled/blurry), fetched in parallel; 360° panoramas kept as a **badged fallback** instead of an empty strip.
- **Tap-to-view photos** — full-screen zoom/pan; **360° panoramas open in a real spherical viewer** (drag to rotate). The viewer **lazy-loads a high-resolution image**: panoramas pull the **original full-resolution** equirectangular image (2048px is still soft at ~5.7 px/° once wrapped on the sphere), behind a loading spinner with automatic fall-back to a lighter image if the original fails; perspective shots use 2048px. The carousel keeps the light 1024px thumb.
- **Openable run history** — each past run is **tappable** and opens a detail screen with its **trail on a map**, full stats (distance/time/pace), and **the date it was run** (run records now store a start timestamp; older records degrade gracefully).
- **Correct Android back navigation** — drilling into a route now **stacks** screens (`push`, not `go`), so the system Back button (and the candidates app-bar arrow) returns to the previous screen instead of exiting the app to the launcher.
- **Robustness** — clear *"API key missing — build with `--dart-define-from-file=secrets.json`"* error instead of a cryptic ORS 401; home sheet width-capped/centred on wide screens.

### Visual overhaul — `#15`
Design-system pass: hero **score gauge** (animated ring), iconographic **axis stats**, gradient sign-in, elevated rounded surfaces, refined chips/inputs/buttons. Driven by the `frontend-design` skill + an iterative render-and-critique loop.

### M6 — multi-device, polish & end-to-end test — `#14`
`isWide` breakpoint: candidates **grid** + route-detail **side-by-side** on tablet/landscape; accessibility (live-region errors, auth splash); a hermetic home→generate→candidates flow test.

## M5 — accounts & cloud sync
- **M5.3** activate Firebase at runtime: auth gate + per-user cloud repos + local fallback — `#13` *(live-verified end-to-end)*
- **M5.2** email/password auth + Firestore repositories, mock-tested — `#12`
- **M5.1** run history + favourite routes behind repository interfaces (on-device) — `#11`

## M4 — live run tracking
- **M4.2** tracking UI (live map-follow + post-run summary) — `#10`
- **M4.1** run-tracking engine (`RunTrackingCubit` + mockable `LocationSource`) — `#8`

## M3 — route generation, maps & detail
- **M3.3** route detail (elevation chart + scenery photos) — `#7`
- **M3.2** route-generation UI (theme, map, params, candidate cards) — `#6`
- **M3.1** route-generation engine (assembler + `RouteGenCubit`) — `#5`
- UI polish pass (verified visual-review tweaks) — `#9`

## M2 — external data layer · tag `v0.2.0-m2`
- **M2.3** photo clients — Mapillary + Wikimedia — `#4`
- **M2.2** enrichment clients — air quality (Open-Meteo) + greenery (Overpass) — `#3`
- **M2.1** config, routing (OpenRouteService) + geocoding (Nominatim) — `#2`

## M1 — foundation + scoring core · tag `v0.1.0-m1`
- App shell + pure-Dart 3-axis scoring engine, behind injectable interfaces — `#1`

## Design phase (before any code)
- **Level 1 — Foundation:** course-materials analysis → problem framing, rubric, framework decision (Flutter).
- **Level 2 — Architecture:** system design (SSOT), UX & rubric checklist, visual direction (Theme A, evaluated A/B/C).
- Provenance rules set up front: single author, English throughout, real incremental git history.
