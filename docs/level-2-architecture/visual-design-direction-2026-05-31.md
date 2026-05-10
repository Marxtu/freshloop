# FreshLoop — Visual Design Direction (M3 UI)

> Level-2 architecture. The committed aesthetic point-of-view for the UI, set **before** building screens (per Anthropic's `frontend-design` method: choose a bold, intentional direction first). It is the visual companion to the [UX & grading checklist](ux-and-rubric-checklist-2026-05-31.md) — that file is the *rules* (professor's principles + Material 3 + accessibility); this file is the *taste*. Where they meet: **distinctive, but disciplined inside Material 3 and the professor's "keep it brief / pictures > words" bar.**
>
> Author: CHENWEI PAN · Date: 2026-05-31 · Applies from M3.2.

## 1. The direction (one sentence)

**"Fresh-air cartographic":** the map is the hero, crisp surfaces float over it, one vivid trail-green leads with a warm energetic accent reserved for the primary action and the top score — sporty and outdoors, never corporate-generic.

- **Tone:** energetic, outdoorsy, confident, clean. Photography-forward (scenery photos are visual anchors — directly serves the professor's "pictures are faster than words").
- **The one memorable thing:** opening a route *draws the loop onto the map* and the score badges settle in — the route feels designed *for you*, reinforcing "decide for me, but let me have the final say."

## 2. Typography (distinctive, not default — via `google_fonts`)

Material 3 does **not** require Roboto; we theme the `textTheme` with Google Fonts (the `google_fonts` package, added in M3.2). Avoids the generic Roboto/Inter/Arial look the `frontend-design` skill warns against, while staying fully legible (accessibility bar).

- **Display / headlines / big numbers:** **Sora** — geometric, modern, a little sporty; gives scores and screen titles energy.
- **Body / labels:** **DM Sans** — clean, legible, slightly characterful; comfortable at small sizes and large dynamic-type sizes.
- One display + one body, applied through `ThemeData.textTheme` so it's consistent everywhere. No third font.

## 3. Color (committed palette, dominant + sharp accent)

Built on Material 3 `ColorScheme.fromSeed` for tonal coherence + guaranteed contrast, but with **chosen** colors — not the default.

- **Primary (seed): vivid trail green** `#0E9F6E` (fresh, energetic — brighter than the muted forest green of the M1 placeholder; update the seed in `theme.dart`).
- **Accent (reserved): warm amber** `#F59E0B` — used *only* for the single primary CTA and the #1-ranked route's total, so the eye knows where to go (dominant green + sharp amber, not a timid even palette).
- **Tier colors** (paired ALWAYS with a label/icon — never color alone, per accessibility): good = green, partial = amber, poor = warm red `#EF4444`.
- **Surfaces:** near-white `#FCFDFB` with M3 surface tints + soft shadows for the floating cards over the map. No flat mid-gray cards. No purple gradients.

## 4. Motion (purposeful, high-impact moments — not scattered)

Echoes `frontend-design` ("one well-orchestrated reveal beats scattered micro-interactions") while respecting the professor's "no chart junk / keep it brief."

- **Candidate cards:** staggered entrance (short `animation-delay`-style cascade) when results arrive.
- **Route detail open:** the route **polyline draws on** the map; the camera eases to fit the loop; score badges fade/scale in.
- **Score/AQI:** brief count-up on the headline number.
- **Touch:** haptic tick on the primary CTA and on selecting a candidate.
- Keep it to these few moments; everything else is calm.

## 5. Composition (map-forward, the professor's own "good" shape)

The professor's exemplar screens are **map + panel master-detail** (Trenitalia). We adopt that:

- **Home / params:** full-bleed map with current location; inputs live in a **bottom sheet** (distance, 3 weight sliders, terrain chips, one amber "Generate" `FilledButton`) — never a form wall, never a grid of buttons.
- **Candidates:** 2–3 **map-preview cards** floating over the map (each: mini route preview + total + 3 tier badges + key stats), swipeable; tap to open.
- **Route detail:** full map with the drawn loop on top; a **draggable sheet** holds the elevation profile (one clean line), AQI/greenery badges + one-line explanation, the scenery **photo carousel**, and the primary actions (Start run / Save / Share).
- **Multi-device:** phone = map + bottom/draggable sheet; tablet/landscape = map + side panel (true master-detail). `LayoutBuilder`/`MediaQuery`.

## 6. Atmosphere & depth

- The **map tiles + scenery photos** ARE the texture — lean on them instead of decorative fills.
- Soft, directional shadows on floating cards (M3 elevation), rounded `28dp`-ish card corners for a friendly feel.
- Full-width scenery photos with subtle gradient scrim for caption legibility.

## 7. Hard "don'ts" (from `frontend-design` + the professor's anti-patterns)

- ❌ Roboto/Inter/Arial/system-default fonts · ❌ purple-on-white gradients · ❌ flat gray cookie-cutter cards · ❌ generic dashboard look.
- ❌ Oceans of buttons · ❌ idiot boxes · ❌ chart junk · ❌ metaphor mismatch (the professor's 4 anti-patterns — see the UX checklist §3).

## 8. Concrete deltas for M3.2 (first build)

1. Add `google_fonts`; set `textTheme` to Sora (display) + DM Sans (body) in `theme.dart`.
2. Update the seed to `#0E9F6E`; define the amber accent + tier colors as theme extensions/constants.
3. Add `flutter_map` + OSM tiles; map-forward home.
4. Params bottom sheet (sliders + chips + one amber CTA), candidate map-preview cards with staggered reveal.
5. Every screen reviewed against this direction **and** the UX checklist; then the Chrome screenshot walkthrough (phone + tablet) scores look-&-feel before merge.

> Note: `frontend-design` targets web (HTML/CSS); only its *design judgment* is applied here — the implementation is Flutter/Material 3. This direction is a starting commitment, refined as real screens are screenshot-reviewed.
