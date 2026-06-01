# FreshLoop M6 — Multi-device adaptation, polish & integration tests · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development or superpowers:executing-plans. Checkbox steps.

**Goal:** The final milestone. Make the UI adapt to **tablet/large/landscape** screens (not just phone-portrait), add a few polish and accessibility touches, and add end-to-end flow tests that tie the milestones together. The app today is phone-portrait-first; M6 makes it look deliberate on a wide screen and proves the core journeys with hermetic widget-level integration tests.

**Constraints reminder:** no emulator in this environment (no KVM), so "integration tests" = **full-app widget tests** under `flutter test` (drive the real widget tree with injected fakes); these run headless in CI. Do NOT add device-only `integration_test` harnesses that can't run here.

**SSOT:** [system design](../level-2-architecture/running-route-generator-2026-05-30.md), [UX & rubric checklist](../level-2-architecture/ux-and-rubric-checklist-2026-05-31.md). Builds on M1–M5 (all merged). Reuses Theme A.

**Notes:** Flutter at `$HOME/flutter/bin/flutter`. English; Conventional Commits; no AI/tooling attribution. **`flutter test` + `flutter analyze` green before every commit.** Keep the `firebaseReady=false` local-mode invariant from M5.3 intact (tests must not touch Firebase). Current suite: **114 tests**.

## Design: one breakpoint helper, applied consistently
Create `lib/app/responsive.dart`:
```dart
import 'package:flutter/widgets.dart';

/// Layout breakpoint: at/above this logical width we use the "wide" (tablet/
/// desktop/landscape) layout instead of the phone-portrait one.
const double kWideBreakpoint = 720;

bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideBreakpoint;
```
Apply it in three places (candidates grid, detail side-by-side, centred forms). Use `MediaQuery.sizeOf` (not `.of`) to avoid unnecessary rebuilds.

---

## Task 1: Candidates — grid on wide screens

**Files:** create `lib/app/responsive.dart`; modify `lib/features/candidates/candidates_screen.dart`; create `test/features/candidates/candidates_responsive_test.dart`

- [ ] Add `responsive.dart` (above).
- [ ] In `CandidatesScreen`, replace the single `ListView.builder` with a width-aware body: when `isWide(context)`, render a `GridView` (`SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 480, mainAxisExtent: <card height>)`; pick an extent that fits `CandidateCard` without overflow, and verify by running) so the ranked cards flow into 2+ columns; otherwise keep the `ListView.builder`. Keep the empty state. Keep `onTap → context.push('/detail', extra: route)` and the rank = index+1.
- [ ] **Widget test:** pump `CandidatesScreen` inside a `BlocProvider<RouteGenCubit>` seeded with a `RouteGenLoaded` of 3 routes (reuse the route-building helper from the existing candidates/cubit tests). Use `tester.view.physicalSize`/`devicePixelRatio` (or a `MediaQuery` wrapper with a large `Size`) to render at **1000×800**, then assert a `GridView` is present and all 3 `CandidateCard`s render; render at **400×800** and assert a `ListView` is present. Reset the test view in `tearDown`.
- [ ] `flutter analyze` + `flutter test`. Commit: `git commit -m "feat: lay out route candidates in a grid on wide screens"`

---

## Task 2: Route detail — side-by-side on wide screens

**Files:** modify `lib/features/detail/route_detail_screen.dart`; create `lib/features/detail/route_detail_content.dart`; create `test/features/detail/route_detail_responsive_test.dart`

- [ ] **Extract** the sheet's inner content (the handle is sheet-only; the score row + tier badges + explanation + elevation + "Along the way" photos + "Start run" button) into a reusable `RouteDetailContent` widget taking the `ScoredRoute` + the cached `Future<List<ScenePhoto>>` + a `ScrollController?`. Both layouts use it (keeps a single source of truth; avoids the photo-future-rebuild bug, so keep the future created once in the State, as today).
- [ ] In `RouteDetailScreen.build`: when `isWide(context)`, render a `Row`: `Expanded(flex: 3, child: RouteMap(points: ...))` + a `SizedBox(width: 420)` (or `Expanded(flex: 2)`) holding a `Material`/`Card` with `RouteDetailContent` in a `ListView` (its own controller); keep the `BackButton` + the favourite toggle (M5) reachable in both layouts. When narrow, keep today's `Stack` + `DraggableScrollableSheet` calling `RouteDetailContent`.
- [ ] **Widget test:** pump `RouteDetailScreen(route: sample, photoService: <fake returning []>)` (reuse the fake PhotoService pattern from the existing detail test) at **1100×800**, then assert the map and the detail content are both visible simultaneously (e.g., `find.text('Start run')` + `find.byType(RouteMap)` with no `DraggableScrollableSheet`); at **400×800**, assert the `DraggableScrollableSheet` is used. Reset view in `tearDown`.
- [ ] `flutter analyze` + `flutter test`. Commit: `git commit -m "feat: show route detail side-by-side with the map on wide screens"`

---

## Task 3: Polish + accessibility

**Files:** modify `lib/features/auth/sign_in_screen.dart`, `lib/app/app.dart` (or the auth gate), maybe `lib/features/params/params_sheet.dart`

- [ ] **Sign-in on large screens:** wrap the form column in a `ConstrainedBox(maxWidth: 420)` so it doesn't stretch edge-to-edge on tablets (it's already `Center`ed). 
- [ ] **Accessibility:** wrap the sign-in error `Text` in `Semantics(liveRegion: true, child: ...)` so screen readers announce auth errors when they appear (flagged in the M5.2 review).
- [ ] **Loading splash for `AuthStatus.unknown`:** in Firebase mode, while the first auth event is resolving, show a centered branded splash (logo/title + `CircularProgressIndicator`) instead of momentarily flashing a screen. Implement as a small `SplashScreen` shown by the auth gate when `status == unknown` (or a `/loading` route the redirect targets on `unknown`). Must NOT affect local mode (no AuthCubit there) and must keep the smoke test green.
- [ ] **Widget test (a11y/splash):** a focused test that the sign-in error is wrapped in a `liveRegion` Semantics when an error is present; and (if feasible) that the gate shows the splash on `unknown`. Keep it small.
- [ ] `flutter analyze` + `flutter test`. Commit: `git commit -m "feat: polish — centred sign-in, live-region errors, auth splash"`

---

## Task 4: End-to-end flow tests (hermetic, headless)

**Files:** create `test/integration/generate_flow_test.dart`; (optional) `test/integration/wide_layout_test.dart`

- [ ] **Generation flow:** pump `FreshLoopApp(generator: <fake>)` where the fake is a `RouteGenerator` built with `MockClient`s returning canned ORS/air/greenery responses; **reuse `_okGenerator()` from `test/state/route_gen_cubit_test.dart`** (copy/adapt it). On the home screen: tap **Generate** (the `ParamsSheet` button), `pumpAndSettle`, and assert the app navigated to the candidates screen and shows the ranked cards ("Choose your route" + ≥1 `CandidateCard`). This exercises home → `RouteGenCubit` → router redirect/navigation → candidates end-to-end in the real widget tree.
  - Note: stop at candidates, because navigating into `/detail` would construct the real `buildPhotoService()` (network). Detail is covered by its own widget tests with an injected fake PhotoService. If you want a card-to-detail assertion, assert the tap triggers navigation intent without awaiting photos, or skip it. Don't introduce real network into the test.
  - Keep `firebaseReady=false` so the app is in local mode (no auth gate) for this flow. Set it defensively in `setUp` like the smoke test.
- [ ] **(Optional) Wide-layout smoke:** pump `FreshLoopApp(generator: <fake>)` at 1100×800, run the same flow, assert the candidates grid renders. Only if it doesn't duplicate Task 1's coverage meaningfully.
- [ ] `flutter analyze` + `flutter test`. Commit: `git commit -m "test: add end-to-end generation flow test"`

---

## Task 5: Final verification

- [ ] `flutter test` → all green (114 + Task1 ~2 + Task2 ~2 + Task3 ~1–2 + Task4 ~1 ≈ **120+**).
- [ ] `flutter analyze` → clean.
- [ ] Manually reason about / confirm no overflow at the wide and narrow sizes for candidates + detail (RenderFlex overflow throws in tests, so a clean test run is good evidence).
- [ ] Local-mode invariant intact (smoke + flow tests don't touch Firebase). `git status` clean.

---

## Self-Review (author)

**Spec coverage:** multi-device = candidates grid (Task 1) + detail side-by-side (Task 2) + centred forms (Task 3), all via one `isWide` helper; polish/a11y = Task 3; integration/e2e = Task 4 (hermetic widget-level, since no emulator). 

**Risk register:** (1) Grid/Row overflow at boundary sizes → choose conservative extents and let the test (which throws on overflow) catch it. (2) Extracting `RouteDetailContent` must preserve the cached photo future (no per-frame refetch, the M5.1/M3.3 bug) → future stays in the State, passed in. (3) Flow test must stay hermetic → fake generator via MockClient, stop before the photo-fetching detail route, `firebaseReady=false`. (4) Splash must not break local mode / smoke test → gated to Firebase mode + `unknown` only. (5) `tester.view` size overrides must be reset in `tearDown` to avoid cross-test bleed.

**Type consistency:** `isWide(BuildContext)` shared; `RouteDetailContent` consumes the same `ScoredRoute` + `Future<List<ScenePhoto>>`; candidates still push `/detail` with the route extra; flow test reuses the cubit test's `RouteGenerator`/`MockClient` helper and `FreshLoopApp(generator:)` injection. No domain/scoring changes.
