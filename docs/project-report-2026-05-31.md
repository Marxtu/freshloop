# FreshLoop — Project Report

*Design and Implementation of Mobile Applications — final project.*

## 1. What it is

**FreshLoop** is a smart **running-route generator**. The user sets a start point and a target
distance and says what matters to them — clean air, the right amount of hills, scenery — and the
app generates and ranks several loop routes that return to the start, each with an explainable
score, an elevation profile, and along-the-way photos. The runner picks one and can then track the
run live and review a post-run summary. Signed-in users get their run history and favourite routes
synced to the cloud.

**Positioning.** FreshLoop *designs* a run rather than merely *tracking* one. This is a deliberate
choice: route generation scored on environmental quality is the novel core, which keeps the project
clear of "re-implement an existing app" territory while still exercising the full mobile stack
(maps, location, external APIs, auth, cloud storage, responsive UI).

## 2. Architecture

A strict layered architecture with one-way dependencies, so each layer is testable in isolation:

| Layer | Responsibility | Key types |
|---|---|---|
| `lib/domain` | Pure Dart — models + scoring, **no Flutter imports** | `ScoredRoute`, `ScoreBreakdown`, `AxisScore`, `RunRecord`, scoring functions |
| `lib/data` | External API clients (injectable `http.Client`) | ORS routing, Open-Meteo air, OSM Overpass greenery, Mapillary/Wikimedia photos |
| `lib/services` | Orchestration + repository **interfaces** | `RouteGenerator`, `PhotoService`, `RunHistoryRepository`, `FavoritesRepository`, `AuthRepository` |
| `lib/state` | State management (flutter_bloc Cubits) | `RouteGenCubit`, `RunTrackingCubit`, `FavoritesCubit`, `AuthCubit` |
| `lib/features` | UI screens + widgets | home, candidates, detail, tracking, summary, auth, saved |

The seams that paid off most:
- **Repository interfaces** for storage/auth let the same UI run on local `shared_preferences` *or*
  Firebase — the backend was swapped in (M5.2/M5.3) by changing two factory functions, no screen
  edits. Tests use in-memory/mock implementations.
- **Injectable `http.Client`** in every data client means the whole external layer is tested with
  canned responses (`package:http/testing.dart` `MockClient`) — no network in CI.

## 3. How scoring works

Each candidate loop is scored 0–100 on three axes, combined with the user's weights:

- **Air** — lower sampled AQI along the route ⇒ higher score.
- **Elevation** — closeness of the route's actual ascent to the runner's *target* (flat for
  beginners, hilly for training): a preference match, not "flatter is better".
- **Scenery** — greenery/water coverage in the route corridor plus scenic waypoints passed.

Each axis maps to a 3-tier badge (good / partial / poor) with a one-line explanation, so the score
is transparent rather than a black box. Graceful degradation: if an enrichment source is
unavailable, that axis degrades instead of failing the whole generation.

## 4. Milestones

| Milestone | Delivered |
|---|---|
| **M1** | App shell + pure-Dart scoring engine |
| **M2** | External data layer: routing, geocoding, air, greenery, photos — all behind injectable, mock-tested clients |
| **M3** | Route-generation engine + map-forward home + candidate comparison + route detail (map, elevation, photos) |
| **M4** | Live run tracking (`RunTrackingCubit` + mockable `LocationSource`) + post-run summary |
| **M5** | History & favourites behind repository interfaces (M5.1 local) → email/password auth + Firestore cloud sync (M5.2) → activated at runtime with an auth gate, per-user cloud repos, and local fallback (M5.3, live-verified) |
| **M6** | Multi-device adaptation (candidate grid + side-by-side detail), polish & accessibility, end-to-end flow test |

## 5. Backend & security

Firebase Authentication (email/password) + Cloud Firestore. Data is namespaced per user at
`/users/{uid}/runs` and `/users/{uid}/favorites`, and Firestore security rules restrict every
document to its owning, authenticated user:

```
match /users/{userId}/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

This was verified end-to-end against the live project: sign-up → write a run → read it back
succeeded, and a cross-user read was denied (HTTP 403). When Firebase is not configured the app
falls back to on-device storage, so it always runs.

## 6. Multi-device

A single `isWide` breakpoint (720 dp) drives the adaptive layouts: the candidate list becomes a
multi-column grid, and the route-detail screen switches from a draggable sheet over the map to a
side-by-side map + detail panel. Forms are width-constrained on tablets.

## 7. Testing & quality

- **123 automated tests**, `flutter analyze` clean. Coverage spans pure-Dart scoring, every data
  client (mocked), the cubits, widgets, responsive layouts (both breakpoints, with an overflow
  regression guard), and a hermetic end-to-end generation flow (home → generate → candidates).
- **Mock-first**: the app uses real APIs; tests never touch the network or real Firebase
  (`MockClient`, `fake_cloud_firestore`, `firebase_auth_mocks`).
- **Process**: each milestone was a short design doc → test-driven implementation → two independent
  reviews (specification + code quality) → fixes → a reviewed pull request. 14 PRs total.

## 8. Tech stack & rationale

Flutter / Dart; **flutter_bloc** (Cubit) for state (the course's taught pattern); `flutter_map` +
`latlong2` over OpenStreetMap tiles; `go_router`; `geolocator`; `google_fonts` (Sora + DM Sans);
`shared_preferences`; `firebase_core` / `firebase_auth` / `cloud_firestore`. Material 3 with a
custom "fresh-air cartographic" theme (trail-green + an amber accent reserved for the primary action
and the top-ranked result). Flutter was chosen over React Native for a single codebase with strong
typed-Dart testability and first-class Material 3.

## 9. Documentation map

- `docs/level-1-foundation/` — problem framing & research
- `docs/level-2-architecture/` — system design, UX & rubric checklist, visual direction
- `docs/level-3-implementation/` — per-milestone implementation plans (M1–M6)
- `docs/audit/` — UI review records
- `firestore.rules` — the deployed security rules
