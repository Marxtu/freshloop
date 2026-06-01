# Changelog & development log

FreshLoop was built incrementally and traceably by a single author (CHENWEI PAN). Every
milestone followed the same loop: a design doc (`docs/level-3-implementation/…`), then
test-driven implementation, then two independent reviews (specification and code quality),
then a reviewed pull request merged to `main`. The result is 15 PRs (#1–#15), 3 release tags,
and a real commit history, so the whole R&D journey is on GitHub rather than a single drop.

- **Pull requests:** https://github.com/Marxtu/freshloop/pulls?q=is%3Apr+is%3Amerged
- **Commit history:** https://github.com/Marxtu/freshloop/commits/main
- **Releases:** https://github.com/Marxtu/freshloop/releases
- Design docs by level: `docs/level-1-foundation/` (analysis), `docs/level-2-architecture/` (system design, UX & visual), `docs/level-3-implementation/` (per-milestone plans), `docs/audit/` (UI reviews), and `docs/project-report-2026-05-31.md`.

---

## [1.0.0] — 2026-05-31 (tag `v1.0.0`)

The complete app: the full M1–M6 roadmap, a visual overhaul, and a round of on-device polish.

### Post-release iteration (driven by real on-device testing)
- **Start a run anywhere.** A home address search with live type-ahead (Photon, an OSM-based geocoder built for autocomplete) plus a GPS "locate me" button set the start from the runner's real position instead of a fixed city centre. Suggestions are sorted nearest-first and each shows its straight-line distance from you.
- **Geocoder swap (Nominatim to Photon).** On-device testing showed Nominatim's `/search` is not a prefix matcher: typing "Carre" returned towns named "Carrè" worldwide, and `bounded`-restricting to the area just returned nothing and fell back to those. Photon prefix-matches as you type ("Carre" finds the nearby "Carrefour") and biases to your location.
- **Out-and-back routes.** Where the trail network is too sparse for a clean loop (an alpine valley returned tangled, self-crossing ~13 km loops for a 5 km request), the generator now also builds out-and-back candidates: route to a turnaround about half the distance away, then mirror the path home. These are clean (no self-crossings) and land much closer to the requested distance (~4.5 km vs 12.5 km at that start, verified against the live API). Each candidate is labelled Loop or Out & back.
- **Closest-to-target route lengths.** The generator over-generates a pool (loops and out-and-backs) and keeps the ones closest to the requested distance; when even the closest is well off (>50%), the candidate screen shows a clear note ("the trail network here is sparse, try a longer distance or a start nearer roads").
- **Google-Maps-style search feel.** Modelled on how Maps biases predictions to the visible map (location/viewport bias, where a smaller area surfaces establishments): search now follows the map centre (pan, then search re-biases there), predictions fire from the 2nd character with a tighter 250 ms debounce, the map supports long-press to start a run there (reverse-geocoded via Photon), and the search box gains a clear (×) button.
- **Collapsible map sheet.** "Design your run" drags down to a handle so the map goes near full-screen (and the start marker is visible), then snaps back up.
- **Sharper photos.** Mapillary 1024px thumbnails (they were upscaled and blurry), fetched in parallel; 360° panoramas kept as a badged fallback instead of an empty strip.
- **Tap-to-view photos.** Full-screen zoom and pan, and 360° panoramas open in a real spherical viewer (drag to rotate). The viewer lazy-loads a high-resolution image: panoramas pull the original full-resolution equirectangular image (2048px is still soft at ~5.7 px/° once wrapped on the sphere), behind a loading spinner with an automatic fall-back to a lighter image if the original fails; perspective shots use 2048px. The carousel keeps the light 1024px thumb.
- **Openable run history.** Each past run is tappable and opens a detail screen with its trail on a map, full stats (distance, time, pace), and the date it was run (run records now store a start timestamp; older records degrade gracefully).
- **Correct Android back navigation.** Drilling into a route now stacks screens (`push`, not `go`), so the system Back button (and the candidates app-bar arrow) returns to the previous screen instead of exiting the app to the launcher.
- **Robustness.** A clear *"API key missing, build with `--dart-define-from-file=secrets.json`"* error instead of a cryptic ORS 401; home sheet width-capped and centred on wide screens.

### Visual overhaul (#15)
A design-system pass: a hero score gauge (animated ring), iconographic axis stats, gradient sign-in, elevated rounded surfaces, and refined chips/inputs/buttons. Driven by the `frontend-design` skill and an iterative render-and-critique loop.

### M6 — multi-device, polish & end-to-end test (#14)
The `isWide` breakpoint: a candidates grid and route-detail side-by-side on tablet/landscape; accessibility (live-region errors, auth splash); and a hermetic home-to-generate-to-candidates flow test.

## M5 — accounts & cloud sync
- **M5.3** activate Firebase at runtime: auth gate + per-user cloud repos + local fallback (#13), live-verified end-to-end.
- **M5.2** email/password auth + Firestore repositories, mock-tested (#12).
- **M5.1** run history + favourite routes behind repository interfaces, on-device (#11).

## M4 — live run tracking
- **M4.2** tracking UI: live map-follow + post-run summary (#10).
- **M4.1** run-tracking engine: `RunTrackingCubit` + mockable `LocationSource` (#8).

## M3 — route generation, maps & detail
- **M3.3** route detail: elevation chart + scenery photos (#7).
- **M3.2** route-generation UI: theme, map, params, candidate cards (#6).
- **M3.1** route-generation engine: assembler + `RouteGenCubit` (#5).
- UI polish pass: verified visual-review tweaks (#9).

## M2 — external data layer (tag `v0.2.0-m2`)
- **M2.3** photo clients: Mapillary + Wikimedia (#4).
- **M2.2** enrichment clients: air quality (Open-Meteo) + greenery (Overpass) (#3).
- **M2.1** config, routing (OpenRouteService) + geocoding (Nominatim) (#2).

## M1 — foundation + scoring core (tag `v0.1.0-m1`)
- App shell + pure-Dart 3-axis scoring engine, behind injectable interfaces (#1).

## Design phase (before any code)
- **Level 1, Foundation:** course-materials analysis, leading to problem framing, rubric, and the framework decision (Flutter).
- **Level 2, Architecture:** system design (SSOT), the UX & rubric checklist, and the visual direction (Theme A, chosen from A/B/C).
- Provenance rules were set up front: single author, English throughout, real incremental git history.
