# Course Materials Analysis (Assignment / Rubric / Sponsor Cases / Framework Lectures)

> Level-1 foundation. This document is the factual basis for every design decision in **FreshLoop**. It distills the professor's published materials (`dima1.pdf` opening slides plus the 8 PDFs in `2026-05.zip`) into binding conclusions about *what to build*, *how*, and *to what bar*. Every choice in the Level-2 design and Level-3 plan should trace back to a line here.
>
> - Course: Politecnico di Milano, *Design and Implementation of Mobile Applications* (Prof. Luciano Baresi)
> - Author: CHENWEI PAN
> - Date: 2026-05-30
> - Status: Baseline (foundation reference; append dated blocks if the professor releases new materials)

---

## 1. Assignment & Rubric (`dima1.pdf` opening slides, 39 pp)

### 1.1 Project rules (red lines)

| Dimension | Requirement |
|---|---|
| Topic source | Student self-proposal (needs professor approval), or sponsor projects (Bending Spoons / WHO / TreNord / TIM) |
| Red line 1 | No business-related / commercializable apps |
| Red line 2 | No apps that already exist (already published) on the market |
| Red line 3 | No projects under agreement with for-profit entities |
| Team | 3 people per group |
| Timing | Topic negotiation only after mid-November |
| Copyright | Belongs to the students |
| Tech stack | **Cross-platform (Flutter + React Native) + native Android + iOS**, listed on slide p5 "Key ingredients" as *taught course technologies*. Note: the project rules (p6–p9) are **silent** on which framework the project itself may use; Flutter is strongly implied but not explicitly permitted (see §3.1). |

### 1.2 Seven grading dimensions (slide p7, the most important)

1. **# screens and functionality**: number of screens and richness of features
2. **Used external services**: MUST use external services **beyond** Firebase auth/storage (hard penalty point)
3. **Look and feel**: visual and interaction quality
4. **"Multi-device" support**: multi-device adaptation (the quotes signal "decent adaptive layout suffices")
5. **Test campaign**: a systematic testing approach
6. **Design/Test document**: design document + test document
7. **Professional presentation**: quality of the defense

### 1.3 The professor's two preferences (strong signals)

- Do not build a social network
- Do not just do Firebase CRUD (must integrate real external APIs)

---

## 2. Sponsor Case Analysis (4 briefs in `2026-05.zip`)

> Purpose: (a) calibrate the shape and complexity bar of a "good project" in the professor's eyes; (b) confirm our self-chosen topic does not collide with the sponsor cases; (c) absorb reusable patterns.

### 2.1 WHO (who.pdf, 12 pp)

- Domain: outbreak response / health-facility engineering (humanitarian).
- Two app ideas: an IDTM tent-installation field guide (with **visual recognition** of items and installation mistakes); a health-facility assessment tool that takes you from picking a disease, through a structured survey, to a **3-tier scoring (Meets +++ / Partial ++ / Does not meet +)**, ending in a **downloadable report** with suggested improvements.
- Expectation signal: serious offline-capable field tooling, computer vision, structured domain data, a scoring engine, report generation. This is the most technically demanding of the four cases.
- **Reusable**: WHO's "3-tier scoring + downloadable report" pattern maps directly onto FreshLoop's route-quality scoring (turn the score from a black box into structured, explainable badges plus a report export).

### 2.2 TreNord (treNord.pdf, 8 pp)

- Domain: Lombardy regional railway (Milano-Cortina 2026 Olympics regional transport sponsor). Scale: ~800k travelers/day, >2,000 trains/day, >450 stations.
- Ask: an **onboard infotainment platform**, content only available during the journey; **beacon/NFC proximity** check-in to unlock exclusive content; personalization by **time slot + traveler profile**; a detailed 2025 demographic dataset to drive content design.
- **Reusable**: time-slot personalization; weather / interactive maps / local events; the "start from a station" hook.

### 2.3 TIM (tim.pdf, 3 pp)

- Domain: telco enterprise innovation (5G/cloud/edge). Two ideas: DJI drone control (DJI Mobile SDK 5, Android only, real hardware needed); **MoveAble** road-safety for vulnerable users (virtual OBU, **MQTT/AMQP pub/sub** to TIM Smart Roads platform, **ETSI C-ITS** messages, periodic GPS publishing, "implement at least one case").
- Expectation signal: real protocol/SDK integration against an industrial platform; "at least one case" sets a clear minimum scope bar.
- **Only GPS/maps adjacency to our project**: MoveAble proves that "live GPS + map UI + periodic position publishing" is an accepted, expected pattern (but in a completely different domain, so no collision).

### 2.4 Bending Spoons (bendingSpoons.pdf, 20 pp) — closest template to a self-chosen project

- 5 self-contained consumer-app ideas (Tic-Tac-Toe / language learning Multilingo / expense splitting MoneySplit / TV tracker SeriesTime) + rules.
- Explicitly allows: "choose our idea, a variation, **or a completely different idea**; language (Swift/Kotlin) cannot change once chosen". So **a self-chosen topic like FreshLoop is allowed**.
- **Key: every idea card has the same shape** = "one clear core flow + one named real external API (WordsAPI/Wordnik+DeepL, TV Shows API…) + a list of stretch features", **and every card ends with 'home widget + Apple Watch/Wear'**.
- **This is the grading template**: a focused core flow, a real external API, and platform-extension polish (widget, wearable, haptics, animations, notifications, personalization, statistics). FreshLoop's complexity should match or slightly exceed these cards.

### 2.5 Collision & originality conclusion

- **No sponsor case collides with running/route/fitness**, so we're safe against red line 2 (already-existing app) relative to these cases.
- The self-chosen FreshLoop sits in the empty lane between the cases. Originality is clean, and Bending Spoons explicitly permits "a completely different idea."

---

## 3. Framework Lecture Evaluation (4 decks in `2026-05.zip`) → Decision: Flutter

> 4 decks: `3-flutter.pdf` (157 pp), `4-reactNative.pdf` (106 pp), `5-android.pdf` (109 pp), `6-ios.pdf` (46 pp).

### 3.1 Is cross-platform allowed?

- The native decks (Compose/SwiftUI) **never mention** cross-platform. Slide p5 "Key ingredients" lists Flutter + RN, but **as course technologies that will be taught**, not as a rule about the project. The project rules on p6–p9 say nothing about which framework the project may use.
- So Flutter is **strongly implied but not explicitly permitted** for the project. Status: **needs TA confirmation**, and not to be treated as a settled allowance.
- Residual risk: ask the TA/professor "is Flutter OK for the project?" before formal kickoff (see Risks in the design doc). (Note: Bending Spoons' "Swift/Kotlin only" is a sponsor-specific mentor rule, not a general project constraint, so it neither permits nor forbids Flutter for a self-proposed topic.)

### 3.2 Why Flutter (not RN / native)

- The RN deck **teaches no maps/geolocation at all** (no react-native-maps, no expo-location), so there's no head start for a map+GPS-heavy app.
- The native decks **also teach no GPS/maps APIs** (CoreLocation/MapKit appear only as boxes in architecture diagrams; Android only mentions `LocationManager` once, for lifecycle), which makes maps/location "self-taught" territory for any stack.
- Flutter's single rendering engine (Skia) is less fiddly for live map rendering, continuous geolocation, and smooth animation, and the Flutter deck maps almost 1:1 onto this project's features.

### 3.3 "Write it the way the professor taught" mapping (Flutter deck → FreshLoop)

| FreshLoop feature | Taught pattern to follow (to read as "self-made") |
|---|---|
| Call air/elevation/photo APIs | `http` + `dart:convert` + `fromJson` + **`FutureBuilder`** (taught verbatim; **not dio**) |
| Live GPS tracking | `geolocator` position stream + **`StreamBuilder`** (StreamBuilder taught via WebSocket; geolocator is in his shown Flutter Favorites) |
| Cross-screen shared state (routes↔map↔tracking) | **`Cubit`/`flutter_bloc`** (his sanctioned app-state solution; **not Riverpod/Provider, which aren't taught**) |
| Per-screen local state | `setState` + state hoisting + `ValueChanged` callbacks |
| Navigation | `Navigator` named routes (+ `go_router` for deep links; both taught) |
| Multi-device | **`LayoutBuilder` + `MediaQuery`** ("Adaptive design" section; `maxWidth>600` branch) |
| Look & feel | `ThemeData` + `ColorScheme.fromSeed` + Material 3 (matches his emphasized Color/Typography/Shape) |
| GPS lifecycle | Subscribe on screen enter, cancel `StreamSubscription` in `dispose` (resource-lifecycle discipline stressed in native decks) |
| Test campaign | `test` (scoring algo is pure Dart, an ideal unit target) + `flutter_test`/`WidgetTester` (widget tests); `integration_test` as a value-add |

### 3.4 Not covered by the decks — pull as "external package/service" (which is itself a grading plus)

- **Map rendering**: not taught, so pull from pub.dev (the professor's framing is "use only official/pub.dev packages, add via `flutter pub add`", which legitimizes it). Choose **`flutter_map` + OSM tiles** (free, no key; avoids google_maps_flutter's billing-enabled Google key).
- **Geolocation**: `geolocator` (shown in his Flutter Favorites shelf).
- **Testing**: `integration_test` and http mocking not taught, but a reasonable and defensible extension (the native Android deck taught a full testing pyramid as precedent).

### 3.5 Course definitions of multi-device / look&feel / testing (from native decks, for rubric alignment)

- **Multi-device** = width/size-class-driven adaptive layouts + phone↔tablet (Android `BoxWithConstraints`, iOS size classes); the Flutter equivalent is `LayoutBuilder`/`MediaQuery`. **Must build genuine width-adaptive layouts, not just scale up the phone layout**.
- **Look & feel** = Material 3 Color/Typography/Shape centralized theme, which Flutter `ThemeData` maps directly onto.
- **Test campaign** = the Android testing pyramid (unit + instrumented/Compose UI tests, Finders/Assertions/Actions); Flutter `flutter_test` (unit/widget) + `integration_test` map almost 1:1, so plan all three layers.

---

## 4. Hard constraints summary (for Level-2 traceability)

1. Must have a prominent, real external-API stack beyond Firebase (hard rubric point + professor preference).
2. Shape = one focused core flow + a real external API + a stretch feature list (Bending Spoons template).
3. Multi-device = genuine width-adaptive layout (phone+tablet to start; widget/watch as stretch).
4. Look & feel = Material 3 centralized theme + follow MAD design principles, avoid anti-patterns.
5. Test campaign = unit + widget + integration (three layers).
6. Explainable scoring + report export (borrow the WHO pattern).
7. Prefer "write it the way the professor taught" (§3.3); for untaught parts, pull "official pub.dev packages".
8. Do not cross the three red lines; no social network; no pure CRUD.

---

## Appendix: source files

- `.cc-connect/attachments/dima1 (1).pdf`: opening slides (requirements + rubric)
- `.cc-connect/attachments/extracted/{who,treNord,tim,bendingSpoons}.pdf`: the 4 sponsor cases
- `.cc-connect/attachments/extracted/{3-flutter,4-reactNative,5-android,6-ios}.pdf`: the 4 framework decks

(`.cc-connect/` is the attachment drop directory, excluded via `.gitignore`, not committed.)
