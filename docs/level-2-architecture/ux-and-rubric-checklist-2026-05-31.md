# FreshLoop — UX & Grading Checklist (enforced on every UI milestone)

> Level-2 architecture. The single, checkable standard that every screen (M3 onward) is **built against and reviewed against**. Grounded in the professor's own course material — not generic advice. Sources: opening slides `dima1.pdf` p6–9 (rubric) and p26–39 ("MAD: Mobile Application Design"); see [Course Materials Analysis](../level-1-foundation/course-materials-analysis-2026-05-30.md) and the design SSOT [FreshLoop system design](running-route-generator-2026-05-30.md) §10.
>
> - Author: CHENWEI PAN · Date: 2026-05-31
> - How to use: the M3+ implementer builds each screen to satisfy §2–§4; the reviewer audits each screen against this file; the Chrome screenshot walkthrough scores screens against §2–§5. A screen is "done" only when it passes §1 gates + has no §3 anti-pattern.

---

## 1. Grading gates (the 7 rubric dimensions — must all be served)

From `dima1.pdf` p7. Every UI milestone must keep these moving:

1. **# screens & functionality** — each screen earns its place with real function.
2. **Used external services** — surfaces beyond-Firebase data (routes, AQI, greenery, photos) visibly.
3. **Look and feel** — see §2–§4 below.
4. **"Multi-device" support** — genuine width-adaptive layout (phone + tablet/landscape), not a scaled-up phone screen.
5. **Test campaign** — widget tests for each screen's key states/interactions.
6. **Design/Test document** — this file + the design SSOT are part of it.
7. **Professional presentation** — polished, demoable, explainable.

**Hard no's (red lines, p6 + the two "dreams"):** no social network; not just Firebase CRUD (external APIs must be front-and-center); nothing that already exists on the market; nothing commercial.

---

## 2. The professor's 5 design principles (verbatim) → how FreshLoop applies each

Prof. Baresi, "A few design principles" (p35). These are the primary look-&-feel bar.

| Principle (his words) | How FreshLoop must honor it |
|---|---|
| **"Simply my life"** | The app does the hard part: enter start + distance and it designs the run. No manual route drawing, no jargon. Sensible defaults everywhere. |
| **"Keep it brief"** | Minimal input per screen. Params screen asks only what's needed (distance + 3 weight sliders + loop type). No walls of text; short labels. |
| **"Pictures are faster than words"** | Lead with the **map**, **scenery photos**, **elevation profile**, and **tier badges/color** — not paragraphs. Numbers get an icon + color, not a sentence. |
| **"Decide for me but let me have the final say"** | The app **generates & ranks** candidate routes (decides), but the user **chooses** among them and can adjust weights/distance and re-generate (final say). This is literally FreshLoop's core loop — make it obvious. |
| **"I should always know where I am"** | Every screen has a clear title; current GPS location always visible on maps; back/route is obvious; generation/tracking show explicit state ("Generating…", "2.1 km of 5 km"). Never a dead-end or ambiguous screen. |

Plus the ethos (p27, p29): **"Simple, cheap, addicting"** and **"Quality!!!!"** — favor a focused, delightful core loop over feature sprawl.

---

## 3. The professor's 4 anti-patterns — MUST NOT appear (auto-fail on review)

Prof. Baresi, "Anti-patterns" (p36, citing Theresa Neil's Mobile Design Pattern Gallery).

| Anti-pattern | What it means | FreshLoop rule |
|---|---|---|
| **Metaphor mismatch** | UI element doesn't match its real-world meaning | A map looks/behaves like a map; a slider means "more/less"; badges mean quality. No clever-but-confusing metaphors. |
| **Idiot boxes** | Pointless confirmation dialogs ("Are you sure?") | No gratuitous confirmations. Use undo (SnackBar) instead of "Are you sure?". Only confirm truly destructive, irreversible actions. |
| **Too many chart elements** | Cluttered, over-decorated charts | The elevation profile shows one clean line + minimal axes. AQI/score visuals stay simple. No chart junk. |
| **Oceans of buttons** | A grid/wall of buttons (the eBay example) | The params screen uses **sliders, chips, and a single primary CTA** — not a grid of buttons. One clear primary action per screen. |

---

## 4. Platform & accessibility standards (align with the above)

- **Material 3**: one centralized `ThemeData` (`ColorScheme.fromSeed`, `useMaterial3`); use M3 components (Cards for candidates, Chips for weights/badges, `NavigationBar`/`Drawer`, `FilledButton` for the primary CTA). Consistent spacing scale (8/16/24).
- **Touch targets** ≥ 48×48 dp (Fitts's law; thumb-friendly).
- **Contrast** ≥ WCAG AA (4.5:1 body text, 3:1 large text / icons) — verify badge and on-map text legibility.
- **Don't rely on color alone** — pair tier color with a label/icon (accessibility; also helps the AQI/score read).
- **Dynamic type** — layouts survive larger system font sizes (no clipping).
- **Semantics** — meaningful `Semantics`/labels on icon-only controls and images.
- **Feedback & status** (echoes "always know where I am"): progress indicators + skeletons during API calls; clear empty states ("No photos for this area"); friendly, actionable error states (design §11), never a raw exception.
- **Choice economy** (Hick's law / "keep it brief"): limit simultaneous choices; 2–3 route candidates, not ten.

---

## 5. Per-screen UX acceptance criteria (M3 targets)

Each M3 screen must satisfy its row before it's "done":

| Screen | Must show / do | Principle anchor |
|---|---|---|
| **Params** | distance input + 3 weight sliders (air/hills/scenery) + loop type; sensible defaults; one primary "Generate" CTA; no button grid | Keep it brief; Decide-for-me; no Oceans of buttons |
| **Generating** | explicit progress + what's happening; cancelable | I should always know where I am |
| **Candidate comparison** | 2–3 route **cards** with map preview + total score + 3 tier badges + key stats; tap to open | Pictures > words; Decide-for-me (let me pick) |
| **Route detail** | map with the loop drawn + current location; clean elevation profile; AQI/greenery badges with explanation; scenery photo carousel; primary actions (start run / save / share) | Pictures > words; no chart junk; let me have final say |
| **Tracking** | map follows position; live distance/time/pace; clear "running" state; stop without an idiot box (confirm only the discard) | Always know where I am; no idiot boxes |
| **Post-run summary** | planned vs actual, splits, one clear save/share | Keep it brief; pictures > words |
| **History / favorites / profile** | scannable lists (cards/tiles), empty states, minimal chrome | Simply my life; keep it brief |

**Multi-device:** phone = single column (map + bottom sheet); tablet/landscape = map + side panel (the professor's own "good" examples are this master-detail map+form split). Build with `LayoutBuilder`/`MediaQuery`, verified at both sizes in the screenshot walkthrough.

---

## 6. Enforcement loop

1. **Build** each screen to its §5 row + §2 principles, avoiding all §3 anti-patterns, meeting §4 standards.
2. **Review** (spec+quality subagent) audits the screen against §1–§4 and flags any anti-pattern as a must-fix.
3. **Visual walkthrough** (Chrome web build → headless screenshot, phone + tablet widths) scores each screen against §2–§5 with the screenshot-critique loop (frontend-design judgment + this checklist).
4. A screen ships only when gates pass and no anti-pattern remains.
