# FreshLoop — Smart Running Route Generator · System Design

> Level-2 architecture. This document is the design SSOT (single source of truth) for **FreshLoop**. All implementation should trace back here; the factual basis is in [Course Materials Analysis](../level-1-foundation/course-materials-analysis-2026-05-30.md).
>
> - Project: FreshLoop (product working name, changeable): an app that helps you **design** a run, not yet another run tracker
> - Course: PoliMi, *Design and Implementation of Mobile Applications* (Prof. Baresi), final project
> - Author: CHENWEI PAN (solo, wearing all three roles: routing / data / client)
> - Date: 2026-05-30
> - Status: Design aligned; pending Level-3 implementation plan

---

## 1. Context & Goals

**One-line definition**: Given a start point + target distance, the app generates 2–3 **loop running routes**, ranks them by a quality score over **air quality + elevation + scenery/greenery**, attaches along-route scenery photos; once chosen, the user can follow the route, record it via GPS, see a post-run summary, and export a report.

**Core thesis**: Not run tracking (Strava/Nike Run Club are everywhere, so that hits red line 2), but run *design*, which sits in the empty lane between sponsor cases where originality is clean.

**Mapping to the rubric** (basis in Level-1 §1.2):

| Rubric dimension | How FreshLoop hits it |
|---|---|
| # screens & functionality | ~11 screens + generation/scoring/tracking/history/report features |
| Used external services | **7+** real external APIs beyond Firebase (§5) |
| Look and feel | Material 3 centralized theme + map/photo/elevation visualizations |
| "Multi-device" support | Genuine phone + tablet/landscape adaptation (§9) |
| Test campaign | unit + widget + integration, three layers (§12) |
| Design/Test document | this document + test document + Level-1 foundation |
| Professional presentation | complete provenance, defensible decisions (§13, §14) |

---

## 2. Scope

**In (MVP, must-do)**
- Loop route generation (start + distance yields 2–3 candidates)
- Three-dimension quality scoring (air/elevation/scenery) + 3-tier badges + total + one-line explanation (borrow the WHO pattern)
- Along-route scenery photo carousel (key waypoints, not every meter)
- Elevation profile chart, route map rendering
- Tracking (live GPS recording) + post-run summary (planned vs actual)
- History, favorites, profile/settings
- Report export (share route / post-run summary)
- Phone + tablet adaptation

**Out (YAGNI / listed as stretch, scheduled by time, not all done)**
- Home-screen widget (today's AQI / suggested route)
- Wear OS / Apple Watch tracking companion
- Push notifications (air improved / route ready)
- Statistics & streak gamification

**Non-goals (red lines)**: social network, pure Firebase CRUD, already-published app, commercialization, for-profit partnerships.

---

## 3. Core User Flow

```
Launch → (first run) onboarding + permissions → Home map
  → [Generate route] → Params (distance + 3-axis weights + loop type)
  → Generating (progress feedback) → Candidate comparison (2–3, with quality badges + total)
  → Route detail (map + elevation profile + AQI + scenery photos + explanation)
      ├─ [Favorite]
      ├─ [Export / share report]
      └─ [Start run] → Tracking (follow route + live GPS stats)
          → Post-run summary (planned vs actual, splits) → Save to history
Home/drawer → History list → History detail
Home/drawer → Favorite routes
Home/drawer → Profile/settings (units, default preferences)
```

---

## 4. Screens (~11)

1. Onboarding + permission requests (location, notifications)
2. Home map (entry "Generate route" + current location)
3. Params (target distance, 3-axis preference weights, loop type)
4. Generating / candidate comparison (2–3 with scores)
5. Route detail (map + elevation profile + AQI overlay + photo carousel + score explanation)
6. Tracking (follow route + live GPS stats)
7. Post-run summary (planned vs actual, split paces)
8. History list
9. History detail
10. Favorite routes
11. Profile / settings

---

## 5. External Services (hard rubric point — 7+ beyond Firebase)

| Purpose | Service | Notes |
|---|---|---|
| Loop route generation | **OpenRouteService** | built-in round-trip foot routing; needs API key |
| Map tile rendering | **OSM tiles** (via `flutter_map`) | free, no key (mind polite usage / caching) |
| Place search | **Nominatim** | search start point by name (OSM geocoding) |
| Air-quality axis | **Open-Meteo Air Quality** | no key |
| Elevation axis | **Open-Meteo Elevation / Open-Elevation** | sample elevation, compute ascent |
| Scenery/greenery axis | **OSM Overpass** | fetch parks/water, compute greenery |
| Along-route photos | **Mapillary** (street-level) + **Wikimedia Commons** (landmarks) | coverage varies by city; needs graceful degradation |
| Run weather hint | **Open-Meteo Weather** | feels-like / rain hint |
| Account/storage (baseline, not a "highlight service") | **Firebase Auth + Firestore** | users, favorites, history |

> Secret management: see §13.7. The repo holds only `.example` templates; real keys live in gitignored config.

---

## 6. Route Quality Scoring (core algorithm, pure Dart, ideal unit target)

Borrows the WHO "3-tier scoring + report" pattern (Level-1 §2.1).

- **Input**: a candidate route's sampled point sequence.
- **Three sub-scores** (each normalized to 0–100):
  - **Air** = (weighted) mean of AQI samples along the route, where lower is better
  - **Elevation** = closeness of actual cumulative ascent to the user's target ascent (beginners want flat, training wants hills, so it's by preference, not "flatter is always better")
  - **Scenery** = greenery/water coverage ratio within the route buffer + number of scenic waypoints passed
- **Total** = the three sub-scores weighted by the user's **axis weights** (adjustable on the params screen).
- **3-tier badges**: each sub-score maps to Meets +++ / Partial ++ / Does not meet +, with a **one-line explanation** ("70% of this route runs through parks, air is excellent"), so it's explainable, not a black box.
- **Ranking**: sort the 2–3 candidates by total.

> Scoring logic is **decoupled** from external data fetching: scoring is a pure function (sampled data in, score out), easy to unit-test and mock.

---

## 7. Tech Stack & Architecture

**Tech stack (finalized)**: Flutter, `flutter_bloc`(Cubit), `http`, `geolocator`, `flutter_map`(+OSM tiles), `go_router`, Firebase(Auth/Firestore), `share_plus`. Rationale in Level-1 §3.

**Layered architecture (high cohesion / low coupling)**:

```
Presentation  Screens + reusable widgets (StatelessWidget/StatefulWidget)
                 │  setState for local; listens to Cubit
State (BLoC)  Cubit: RouteGenCubit / RunTrackingCubit / HistoryCubit ...
                 │  exposes state, calls domain/data
Domain        pure Dart: scoring / route models / unit conversion  ← no Flutter deps, easy to unit-test
                 │
Data          API clients (http + fromJson) + Firebase repositories + local cache
                 │
External      ORS / Open-Meteo / Overpass / Mapillary / Wikimedia / OSM / Firebase
```

**State-management strategy** (the way the professor taught, Level-1 §3.3)
- Per-screen ephemeral state (toggles, sliders, inputs) uses `setState`
- Sibling sharing uses state hoisting + `ValueChanged` callbacks
- Cross-screen app state (candidate routes, run session, history) uses `Cubit`/`flutter_bloc`
- **Do not introduce Riverpod/Provider** (not taught; importing it would read as "not course-produced")

**Data flow (generate route)**
```
Params screen → RouteGenCubit.generate(params)
  → Data layer: ORS round-trip → candidate geometry
  → fetch data in parallel: Open-Meteo Air / Elevation, Overpass greenery, Mapillary/Wikimedia photos
  → Domain: scoreRoute(candidate, data) → ScoreBreakdown
  → Cubit emit candidate list (sorted) → candidate comparison screen (FutureBuilder/BlocBuilder)
```

**Async & streams** (the way the professor taught)
- REST fetch: `http.get` + `Uri.parse` + `json.decode` + `Model.fromJson` + `FutureBuilder`
- Live GPS: `geolocator` position **stream** + `StreamBuilder`; cancel `StreamSubscription` in `dispose`

---

## 8. Data Models (core)

- `RoutePoint { lat, lng, elevation? }`
- `RouteCandidate { id, points[], distanceM, ascentM, score: ScoreBreakdown, photos: ScenePhoto[] }`
- `ScoreBreakdown { air: Tier+value, hills: Tier+value, scenery: Tier+value, total, explanation }` (Tier = good/partial/poor)
- `ScenePhoto { url, source(Mapillary/Wikimedia), lat, lng, caption? }`
- `RunRecord { id, plannedRouteId?, points[], startedAt, durationS, distanceM, splits[] }`
- `RunParams { startLat, startLng, targetDistanceM, weights{air,hills,scenery}, targetAscentM?, loopType }`
- `UserProfile { uid, units, defaultWeights }`

All API models implement a `fromJson` factory (the parsing pattern the professor taught).

---

## 9. Multi-Device Adaptation

- **Phone (compact, <600dp)**: single column, full-screen map + bottom sheet info card.
- **Tablet/landscape (≥600dp)**: map + right-side info panel side by side (candidate list / detail / elevation chart).
- Implementation: `LayoutBuilder` (`constraints.maxWidth>600` branch) + `MediaQuery.sizeOf/orientationOf`.
- **Build genuine width-adaptive layouts, not just scale up the phone layout** (course definition, Level-1 §3.5).
- Provide 2x/3x assets per pixel density.

---

## 10. UX / Design Principles (look & feel rubric point)

- **Material 3**: `ThemeData` + `ColorScheme.fromSeed` centralized theme (Color/Typography/Shape), `useMaterial3: true`.
- **Follow MAD principles** (professor's later slides):
  - Visibility of system status: progress + skeletons during generation/fetch; live feedback during tracking
  - Consistency, recognition over recall (remember default preferences), immediate feedback (SnackBar/animation), error prevention (param validation, undoable actions)
- **Accessibility**: sufficient contrast, dynamic type support, semantic labels (Semantics).
- **Restraint**: map-first, layered information, avoid the anti-patterns the professor named.

---

## 11. Error Handling & Degradation

| Scenario | Handling |
|---|---|
| Location permission denied | guide to settings; allow manual start point on map |
| ORS/data API failure or timeout | retry + friendly error; degrade scoring on available data when a sub-score is missing, and annotate |
| No Mapillary/Wikimedia photo for the area | graceful blank (no broken image), placeholder / map thumbnail |
| Offline / no network | offline notice; cached history and favorites remain readable |
| External API rate limits | local cache + request throttling; cache OSM tiles for polite usage |
| Cannot generate a loop route | prompt to adjust distance/start, explain why |

---

## 12. Test Campaign (three layers)

- **Unit (`test`)**: scoring algorithm (pure function, many scenarios), unit conversion, `fromJson` parsing for each API model, data repositories with a mocked `http` layer.
- **Widget (`flutter_test`/`WidgetTester`)**: params screen, candidate comparison, route detail, tracking-screen key interactions (`find` + `expect` + `pump`).
- **Integration (`integration_test`)**: the golden path, generate then detail then track (mocked location) then save.
- Maps onto the testing pyramid the course taught (Level-1 §3.5). Tests are added incrementally with features, forming a demonstrable test campaign.

---

## 13. Engineering Provenance

> Goal: a development trail that is **real, complete, and defensible**. This is required for grading (design/test doc + presentation) and is the strongest evidence that "I made this myself." **Bottom line: build a real, well-recorded trail; do not fabricate records** (no backdated timestamps, no fabricated collaborators, no work credited to people who did not do it). Commit messages describe the change, not the tooling; whether AI assistance must be disclosed is a course-policy question to confirm with the TA (§15). The defense will expose anyone who cannot explain their own code, so "truly understood + truly iterated" is the only stable path to a high score.

### 13.1 Identity
- Single author **CHENWEI PAN**, single git identity (honest; no fabricated non-existent collaborators).
- Course requires 3 people/group: if **real** teammates join later, each configures their own `user.name/user.email` and commits; no commits manufactured for people who did not write the code.
- Commit email must be linked to the GitHub account (**to be written into** `git config user.email` after the user confirms it; see §13.8 TODO).

### 13.2 What push preserves (fact)
- `git push` uploads **all commits** on the branch (messages, author, author date, every diff), not just the final state. So committing locally first and pushing once at the end still gives GitHub the full history, timeline, per-line blame, and contributor graph.

### 13.3 Branch strategy
- `main` is the integration branch; each feature on a `feature/<slug>` branch (even solo, branches narrate feature evolution).
- Merge via **merge commit or by preserving feature-branch history**; **no squash-merge** (it collapses a series of commits into one, losing granularity).

### 13.4 Commit conventions
- Conventional Commits (`feat:`/`fix:`/`docs:`/`test:`/`refactor:`…).
- **Human-voice** messages ("fix elevation API timeout"), small steps; **avoid** one giant `add whole app` initial commit or AI-sounding batch messages.
- **All commit messages and code comments in English** (course language; reads as self-made for an English course).

### 13.5 Timeline integrity (red line)
- Author dates are preserved and shown on GitHub. **Do not backdate/tamper timestamps to fake a "whole semester" timeline**; to lengthen the timeline, genuinely spread the work over time.
- Do not `rebase`/`amend`/force-push `main` after it is pushed (rewrites history, drops original commits).

### 13.6 The design process is part of the trail (user requirement)
- The **early design chain** (research, then brainstorming/selection, then tech decisions) is committed as **distinct design-phase commits**: the Level-1 course-materials analysis, this design document, and the §14 design-evolution log.
- Let the git history show the real order: "research first, then decide, then implement."

### 13.7 Secret safety (push = publish)
- API keys (ORS/Mapillary/Firebase config) **never enter the repo**; once in history, deleting the file does not remove it, and public repos get indexed/cached, so a leak must be revoked/rotated.
- Repo holds only `*.example` templates; real keys live in `.gitignore`d local config / environment variables; `.gitignore` covers `.env`, `secrets`, Firebase config files.

### 13.8 GitHub-side provenance signals (enable later)
- PR + code-review comments, issues, CI (GitHub Actions running `flutter test`), signed commits (Verified badge).
- **TODO (pending the user's GitHub account)**: (1) confirm and write the commit email; (2) create the remote repo and push; (3) configure Actions to run tests.

---

## 14. Design Evolution Log (decision log / early-design-process provenance)

> Records how this design was reached, step by step, for defense recall and traceability.

| # | Decision | Alternatives | Choice & rationale |
|---|---|---|---|
| D1 | Domain | many domains | chose **running/fitness** (user interest) |
| D2 | Angle | tracker / route generator / exploration game / home pose-recognition | chose **route generator**: avoids the "already-existing app" red line, API-dense, map visualization looks good |
| D3 | Smart axes | air / scenery / elevation / safety / surface | chose **air + elevation + scenery**, composed into a "multi-dimension route quality score" |
| D4 | Scope | plan-only / plan + track | chose **plan + lightweight tracking**: more screens, a sensor and testing story, but "generation" stays the hero |
| D5 | Visual enhancement | — | added **along-route scenery photos** (Mapillary+Wikimedia): lifts look&feel and adds one more external service |
| D6 | Framework | Flutter / RN / native | chose **Flutter**: RN/native decks teach no maps/location; Flutter deck maps 1:1 and the single engine suits maps+GPS (Level-1 §3.2) |
| D7 | Map plugin | google_maps_flutter / flutter_map | chose **flutter_map + OSM**: free, no key, avoids Google billing |
| D8 | State management | setState/Cubit / Riverpod / Provider | cross-screen via **Cubit/flutter_bloc** (professor-sanctioned); no untaught Riverpod/Provider |
| D9 | Score presentation | black-box score / 3-tier explainable | chose **3-tier badges + explanation + report** (borrow WHO pattern) |
| D10 | Team/identity | 3 people / solo | **solo CHENWEI PAN** wearing all three roles, single real git identity |

---

## 15. Risks

| Risk | Mitigation |
|---|---|
| Whether the professor accepts Flutter for the project | slides list Flutter as a *taught* technology (p5), but the project rules (p6–p9) are silent on framework choice, so it's strongly implied, not explicitly permitted (Level-1 §3.1). **Must get TA confirmation before kickoff.** |
| Solo vs the 3-person course requirement | user is aware; add real teammates' identities later if any; no fabrication |
| External API rate limits/coverage (Mapillary street-level varies by city) | cache + throttle + graceful degradation when no data (§11) |
| Maps/location not taught in the decks | pull "official pub.dev packages" legitimately (Level-1 §3.4) |
| Scope too large | stretch features strictly deferred; close the MVP loop first |

---

## Appendix A: Active Decisions

See §14 decision log. Append major changes here later, and record the timeline in `docs/CHANGELOG/`.
