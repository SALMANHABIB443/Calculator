# UI/UX Design System & Mockup Specification
## Calculator App

**Document Status:** Primary Visual Reference for Implementation (frozen, Phase 1)  
**Source of Truth:** Four provided mockups in `../Mockups/`  
**Theme:** Dark mode only (as shown)  
**Decisions:** See [DECISIONS.md](DECISIONS.md) — color values below are measured, not estimated

---

## 1. Design Philosophy and Visual Identity

The application follows a **modern, minimalist dark aesthetic** with high contrast, generous spacing, and clear visual hierarchy.

**Core Principles**
- Dark backgrounds reduce eye strain and match modern mobile OS preferences.
- Orange accent color used exclusively for primary actions (operators, `=`, toggles, Clear History, icons).
- Circular buttons create a soft, approachable feel.
- Clear typography hierarchy: large result number is the hero element.
- Cards and grouped sections provide structure without visual clutter.
- Consistent iconography and alignment across all screens.

**Overall Feel**  
Clean, confident, and focused on the calculation itself.

**Mockup reference** (D-13 — filenames encode generation time, not screen identity):

| Mockup File | Screen |
|-------------|--------|
| `ChatGPT Image Sep 28, 2026, 02_17_57 AM.png` | History |
| `ChatGPT Image Sep 28, 2026, 02_22_43 AM.png` | Main Calculator |
| `ChatGPT Image Sep 28, 2026, 02_25_36 AM.png` | Settings |
| `ChatGPT Image Sep 28, 2026, 02_30_45 AM.png` | About |

Mockups are 884x1779 px at 2x (logical 442x890), portrait.

---

## 2. Color Palette

All values below were **measured directly from the mockup pixels in Phase 1** (D-03)
and supersede the earlier visual estimates. The largest correction is the function
keys, which are a light mid-gray carrying near-black labels — not the medium gray
previously assumed.

| Role                    | Color      | Usage                                      |
|-------------------------|------------|--------------------------------------------|
| Background (App)        | `#000000`  | Full screen background                     |
| Surface / Card          | `#101011`  | History cards, Settings rows, About cards  |
| Primary Accent (Orange) | `#F89508`  | Operator buttons, `=`, toggles (ON), Clear History, icons |
| Secondary Button        | `#949494`  | AC, +/−, % buttons                         |
| Digit Button            | `#1E1E1E`  | Number buttons and the decimal point       |
| Primary Text            | `#FFFFFF`  | Main result, headings, active labels, keys on dark fills |
| Key Label (on `#949494`) | `#000000`  | Labels on the light function keys          |
| Secondary Text          | `#949AA4`  | Expression line, descriptions, subtitles   |
| Section Header Text     | `#949AA4`  | “APPEARANCE”, “PREFERENCES”, “Today”       |
| Divider / Separator     | Subtle dark line | Between Settings rows               |
| Icon Default            | `#FFFFFF` / `#F89508` | White by default; orange for active/feedback |

**Toggle Switch**
- Track (ON): `#F89508`
- Thumb: `#FFFFFF`
- Track (OFF): not present in any mockup — carried as residual unknown R-1 (see `DECISIONS.md` §4)

**Do not** hard-code these values at call sites. They are exposed as design tokens
(see §11) and consumed through a single palette class, so every screen reads the
same measured values.

---

## 3. Typography System

| Style                  | Approximate Size | Weight     | Color          | Usage                              |
|------------------------|------------------|------------|----------------|------------------------------------|
| Large Result           | 56–64 pt         | Bold / Semibold | White       | Primary calculator result          |
| Expression Line        | 18–22 pt         | Regular    | Secondary gray | Secondary expression above result  |
| Screen Title           | 28–34 pt         | Bold       | White          | “Settings”, “History”, “About”     |
| Subtitle               | 15–17 pt         | Regular    | Secondary gray | “Simple calculator, powerful features” |
| Section Header         | 13–14 pt         | Medium / Semibold | Secondary gray | “APPEARANCE”, “PREFERENCES”     |
| Row Title              | 17 pt            | Regular / Medium | White     | “Sound”, “Vibration”, etc.         |
| Row Subtitle           | 13–15 pt         | Regular    | Secondary gray | “Key press sound”, “2 decimal places” |
| History Expression     | 15–16 pt         | Regular    | Secondary gray | “125 × 8”                          |
| History Result         | 20–22 pt         | Semibold   | White          | “1,000”                            |
| Button Labels          | 22–28 pt         | Medium     | White / Black  | Calculator buttons                  |
| Bottom Action          | 16–17 pt         | Medium     | Orange         | “Clear History”                    |

**Font Family Recommendation**  
Use the system font (SF Pro on iOS, Roboto / system on Android) for native feel. Avoid custom fonts unless required.

---

## 4. Spacing, Layout & Alignment Rules

- **Screen margins**: 24 px horizontal padding (**measured in Phase 9**, §12.1;
  the original "~16–20 pt" estimate here was too narrow and is superseded).
- **Section spacing**: Generous vertical gaps between major sections (APPEARANCE → PREFERENCES → ABOUT).
- **Card internal padding**: ~16 pt.
- **Button grid**: Evenly spaced circular buttons with consistent gaps.
- **Row height**: Comfortable touch targets (~50–56 pt).
- **Bottom safe area**: Respect device home indicator / navigation bar.
- **Alignment**: Left-aligned text in lists; center-aligned calculator buttons and About hero.

---

## 5. Component Specifications

### 5.1 Calculator Buttons

| Type              | Shape     | Fill Color | Text/Icon Color | Size (logical) | Notes                          |
|-------------------|-----------|------------|-----------------|----------------|--------------------------------|
| Digit (0–9)       | Circle    | `#1E1E1E`  | `#FFFFFF`       | ~88 px (measured) | “0” is wide (spans 2 columns)  |
| Operator (÷×−+)   | Circle    | `#F89508`  | `#FFFFFF`       | ~88 px (measured) | Primary action; full right column |
| Function (AC ± %) | Circle    | `#949494`  | `#000000`       | ~88 px (measured) | **Dark label on light fill**   |
| Equals (=)        | Circle    | `#F89508`  | `#FFFFFF`       | ~88 px (measured) | Bottom-right, primary action   |
| Decimal (.)       | Circle    | `#1E1E1E`  | `#FFFFFF`       | ~88 px (measured) |                                |

Key diameter is **measured, not a range** as of Phase 9: the five key rows read
86.5–87.5 logical px, and the grid renders an 88 px cell from the measured 24 px
margin (D-60, §12.1). It is still derived rather than declared, because
`CalculatorButton` sizes from its container (D-27) and the grid is the only place
the geometry lives — see the note below.

**Resolved in Phase 3, tuned in Phase 9:** no diameter token exists —
`CalculatorButton` sizes from the box its parent gives it, so the keypad grid alone
determines the diameter (D-27). Phase 9 tuned that grid's only free input, the
screen margin, and the diameter followed to its measured value (D-60).

**The wide `0` key** is a **stadium**, not a circle. The table above calls every key
a circle and also says `0` spans 2 columns, which cannot both hold. A pill is the
only shape that is as tall as its neighbours, two columns wide, and round at both
ends (D-29).

**Pressed State**  
Slightly reduced opacity or a scale-down animation for tactile feedback. Not present
in the mockups; standard platform feedback is used.

### 5.2 Toggle Switches
- Standard iOS/Android style.
- ON state: `#F89508` track + `#FFFFFF` thumb.
- OFF state: no mockup shows it — residual unknown R-1 (§12).
- Positioned on the right side of the row.

### 5.3 List Rows / Cards
- Dark surface background (`#101011`) on the `#000000` page.
- Rounded corners (~12–16 px radius).
- Left icon + title + subtitle + right chevron or toggle.
- Subtle separators between rows inside a group.

### 5.4 Icons
- Line / outlined style.
- Consistent stroke weight.
- Color: `#FFFFFF` for most; `#F89508` for active feedback icons (Sound, etc.).
- Size: ~22–24 px in lists; larger in About hero.

### 5.5 App Icon (About Screen)
- Rounded square.
- Four circular operator buttons arranged in a 2×2 grid — two orange, two light gray:
  - Top-left: + (gray)
  - Top-right: − (orange)
  - Bottom-left: × (gray)
  - Bottom-right: = (orange)
- The two-orange / two-light split is confirmed by pixel measurement of mockup
  `02_30_45`; the glyph-to-quadrant assignment is carried from this spec.

---

## 6. Screen-by-Screen Layout Specifications

### 6.1 Main Calculator Screen

```
Screen
└── Safe Area Container (black background)
    ├── Top Bar
    │   ├── Left: Hamburger menu icon (white)
    │   └── Right: History (clock) icon (white)
    ├── Display Area (flex / top portion)
    │   ├── Expression Label (right-aligned, secondary color)
    │   └── Result Label (right-aligned, large white)
    └── Button Grid (bottom portion)
        ├── Row 1: AC | +/− | % | ÷
        ├── Row 2: 7 | 8 | 9 | ×
        ├── Row 3: 4 | 5 | 6 | −
        ├── Row 4: 1 | 2 | 3 | +
        └── Row 5: 0 (wide) | . | =
```

**Notes**
- Display area has large vertical space above the buttons.
- Result is the visual focus.
- No visible status bar content beyond time/battery (system).
- Verified against mockup `02_22_43`: the operator column (`÷ × − +`) and `=` are
  orange, the `0` key spans two columns, and there is **no backspace key**.

### 6.2 History Screen

```
Screen
└── Safe Area Container
    ├── Header
    │   ├── Left: Back arrow
    │   ├── Center: “History”
    │   └── Right: Trash icon
    ├── Scrollable Content
    │   ├── Section: “Today”
    │   │   └── History Cards (expression + result + chevron)
    │   └── Section: “Yesterday”
    │       └── History Cards
    └── Bottom Action (fixed or at end of scroll)
        └── “Clear History” (orange text + trash icon)
```

**Header** confirmed as back arrow + title + trash (D-10). Since **D-74** it is
`SecondaryPageHeader`: a bordered 48 px action box on each side of a centred
title, so one component still covers every secondary screen.

**Card Structure**
- Dark rounded rectangle, fill `#101011` on the `#000000` background.
- Top: expression (secondary color `#949AA4`).
- Bottom: result (`#FFFFFF`, larger).
- Right: chevron.

Verified against mockup `02_17_57`: two groups of cards separated by a dim section
header, with the orange Clear History action at the bottom center.

### 6.3 Settings Screen

```
Screen
└── Safe Area Container
    ├── Header
    │   ├── Left: Back arrow
    │   ├── Title: “Settings”  (no subtitle — see **D-71**)
    │   └── ~~Subtitle: “Customize your calculator experience”~~
    ├── Scrollable Content
    │   ├── Section Header: “APPEARANCE”
    │   │   └── Theme Row (sun icon + “Theme” / “Dark mode” + chevron)
    │   ├── Section Header: “PREFERENCES”
    │   │   ├── Sound Row (speaker + toggle ON)
    │   │   ├── Vibration Row (phone + toggle ON)
    │   │   ├── Decimal Places Row (123 icon + chevron)
    │   │   └── History Row (clock + toggle ON)
    │   └── Section Header: “ABOUT”
    │       ├── App Version Row
    │       ├── Privacy Policy Row
    │       └── Terms of Service Row
```

**Row Layout**
- Icon (left) → Title + Subtitle (middle) → Control (toggle or chevron, right).

**Header amendment (D-71).** The header renders the title alone. The subtitle
above was struck because it restated what every row on the screen already
says, and because it made this the app's only 88 px header — History and both
legal screens are 56 px. The title drops to 28 pt (the bottom of the §3 Screen
Title band) to suit a bar that is now a single line. About keeps its subtitle
and its 32 pt title; the two are no longer required to match.

**Header amendment (D-74).** The bar is no longer an `AppBar`. It is a plain
`Row` — `SecondaryPageHeader` — whose two sides are the same 48 px wide, so the
title's own middle is the screen's middle and the actions' *boxes* (not their
glyphs) ride the 24 px margin. The bar is `AppSizes.headerHeight` (56) as a
minimum: it grows for the second line an About-style subtitle needs and for
Dynamic Type, and each line is ellipsised rather than wrapped.

### 6.4 About Screen

```
Screen
└── Safe Area Container
    ├── Header
    │   ├── Left: Back arrow
    │   ├── Title: “About”
    │   └── Subtitle: “Simple calculator, powerful features”
    ├── Hero Section (centered)
    │   ├── App Icon
    │   ├── App Name “Calculator”
    │   ├── Version “1.0.0”
    │   └── Description paragraph
    ├── Section: “APP INFORMATION”
    │   ├── App Name Row
    │   ├── Version Row
    │   └── Developer Row (“Hasan Mahadi” — D-11)
    └── Section: “MORE”
        ├── Rate App Row
        ├── Share App Row
        └── Terms of Service Row
```

Verified against mockup `02_30_45`: the hero card holds a 2x2 app icon with two
orange circles and two light circles, followed by the app name, version, and a
description block, then two grouped sections of chevron rows.

---

## 7. Component Hierarchy Summary (Reusable)

- **AppIconButton** (the bordered 48 px header action)
- **AppPageHeader** (a destination's top bar: optional leading, title, actions)
- **SecondaryPageHeader** (back + centred title + optional trailing action)
- **SecondaryPageScaffold** (the black page, safe area, and header-above-body frame)
- **SectionHeader** (uppercase label)
- **SettingsRow** (icon + title + subtitle + trailing)
- **ToggleRow** (specialized SettingsRow with switch)
- **HistoryCard**
- **CalculatorButton** (variants: digit, operator, function)
- **PrimaryDisplay** / **SecondaryDisplay**
- **AppIcon** (brand mark)

---

## 8. Interactive States

| Element          | Default              | Pressed / Active          | Disabled (if applicable) |
|------------------|----------------------|---------------------------|--------------------------|
| Calculator Button| Fill per §5.1        | Reduced opacity / scaled  | Reduced opacity          |
| Toggle           | ON = `#F89508` track | Immediate visual change   | —                        |
| List Row         | `#101011` surface    | Subtle highlight          | —                        |
| Back / Icons     | `#FFFFFF`            | Reduced opacity           | —                        |
| Clear History    | `#F89508` text       | Reduced opacity           | —                        |

---

## 9. Empty & Error States

- **Empty History**: Centered illustration or icon + “No calculations yet” + short guidance.
- **Calculation Error**: Primary display shows “Error”. The secondary line retains the expression.
- No error dialogs are shown in the mockups; errors are displayed inline.
- **Clear History confirmation**: A confirmation dialog is **required** (D-05) even though
  it is not present in the mockup, because the action is destructive and irreversible.

---

## 10. Responsive Behavior

- **Portrait phone only** for v1.0, locked in code (D-09).
- The button grid scales proportionally to the available height and width while
  maintaining minimum touch targets; it must not clip on small or large phones.
- Large result text reduces size when the value becomes very long (auto-shrink).
- Landscape and tablet layouts are out of scope (D-09).

---

## 11. Design Tokens

Token values are resolved in §2 (colors) and §3 (typography) and are implemented as
a single tokens barrel plus a palette class, so the mockup-measured values have
exactly one definition site: `lib/core/design/app_colors.dart`,
`app_typography.dart`, and `app_spacing.dart`, exported through
`lib/core/design/app_tokens.dart`. Nothing below is typed by hand at a call site.

**Resolved in Phase 3.** Where §2 and §3 gave a range rather than a measured value,
the implementation takes the **midpoint**, so a later correction is a single number
to move rather than a re-measurement:

```
AppColors
  background           #000000      surface              #101011
  accent               #F89508      buttonDigit          #1E1E1E
  buttonFunction       #949494      textPrimary          #FFFFFF
  textOnFunction       #000000      textSecondary        #949AA4
  divider              #1A1A1B  (1)  toggleTrackOn       #F89508
  toggleTrackOff       #2A2A2A  (2)  toggleThumb         #FFFFFF
  pressedOpacity       0.85

AppTypography (size / weight)         AppSpacing / AppRadius
  resultLarge        60 / w600          screenHorizontal  20
  resultMedium       44 / w600          cardPadding       16
  expression         20 / w400          sectionGap        32
  screenTitle        32 / w700          AppRadius.card    14   (12–16)
  screenTitleCompact 28 / w700  (D-71)
  subtitle           16 / w400          AppRadius.tile    12
                                        AppRadius.iconButton 12  (D-74)
  sectionHeader      14 / w600          AppRadius.dialog  20
  rowTitle           17 / w500          AppSizes.header   56  (minimum, D-74)
  rowSubtitle        14 / w400          AppSizes.rowIcon  22
  historyExpression  16 / w400          AppSizes.brandIcon 88
  historyResult      21 / w600
  buttonLabel        25 / w500
  bottomAction       17 / w500
  body               15 / w400, 1.5 line height
  caption            12 / w400
```

`(1)` **Unmeasured** — §2 describes the divider only as a "subtle dark line". Chosen,
named as a token, and confirmed in Phase 9 (D-26).

`(2)` **Unmeasured** — residual unknown **R-1**; no mockup shows a toggle in the OFF
state. The platform default was rejected because Material 3 renders a light gray
track that breaks the palette. Resolved in one place by `AppTheme.switchTheme`, so
Phase 9 corrects it by editing one token (D-26).

**Key diameter** is deliberately *not* a token. Phase 1 measured a range of 85–95
logical px, and R-2 is unresolved, so `CalculatorButton` sizes from the box its
parent gives it and the keypad grid alone determines the diameter (D-27).

---

## 12. Notes and Residual Unknowns

Resolved in Phase 1 (see [DECISIONS.md](DECISIONS.md)):

- **Color values are measured, not estimated** (D-03). Superseded estimates are recorded
  there for reference.
- **Mockup-to-screen mapping** is corrected (D-13); the filenames encode generation time.
- **History header** is back arrow + title + trash (D-10).
- **Clear History confirmation** is required (D-05).
- **Dark mode only** confirmed for v1.0.
- **Portrait phones only** confirmed (D-09).

Resolved in Phase 9 (see [DECISIONS.md](DECISIONS.md)). Phase 9 decoded the four
mockup PNGs and measured them — the first phase able to; Phases 2–8 all closed by
recording that the images could not be read, so every geometric value until then came
from this document's prose:

| # | Unknown | Resolution |
|---|---------|-----------|
| R-1 | Toggle **OFF** track color — no mockup shows a toggle in the OFF state | **Closed as chosen, not measured** (D-61). All three mockup toggles are ON (track 44 × 25.5 px, `#F89508`), so no measurement is possible. `AppColors.toggleTrackOff` = `#2A2A2A`, resolved only by `AppTheme.switchTheme`. |
| R-2 | Exact calculator **key diameter** — pixel scans gave ~85–95 logical px | **Closed at 88 px** on the 442×890 canvas (D-60). The key rows measure 86.5–87.5 logical px; the excess came from the screen margin, not the keys. |

### 12.1 Measured geometry (Phase 9)

These supersede the prose ranges in §4 and §5.1, which were written from the images
by eye and, in the margin's case, simply wrong.

| Property | §4 / §5.1 said | Measured | Implemented |
|----------|---------------|----------|-------------|
| Screen margin | "~16–20 pt" | **24–25 px** (consistent across all three list screens) | `screenHorizontal = 24` |
| Calculator key diameter | "~85–95 px" | **86.5–87.5 px** (five key rows) | 88 px (derived) |
| Key gap, horizontal | "consistent gaps" | 13 px | `keyGap = 14` |
| Key gap, vertical | "consistent gaps" | 15 px | `keyGap = 14` |
| Toggle track | not stated | 44 × 25.5 px (ON only) | Material `Switch` |
| Palette | §2 | `#000000` `#1E1E1E` `#F89508` all confirmed | unchanged (D-03) |

The key diameter is **not an independent value**. Under D-27 the keypad derives its
cells from the width left over after the margins, so `(442 − 2·margin − 3·14) / 4`
gives 90.0 px at margin 20 and 88.0 px at margin 24. R-2 was a symptom of the margin
error, which is why measuring keys alone could only ever bracket a range.

D-69 keeps this arithmetic and its 88 px result but changes what is derived *from*
it: the grid now receives the box it lays out in and derives the cell itself, and
the `keyGap` reserved in that arithmetic is a real rendered child rather than a
number subtracted from a width. The table above therefore describes what renders,
which is the point of it — the earlier version of the grid reserved the same 14 px
and still drew touching keys.

Still notes, not blockers:

- Pressed / hover states are not shown in the mockups → standard platform feedback is used.
- No light theme mockup exists → Dark mode only.
- Settings and About surfaces read `#0D0F12`/`#0E0F11` against History's `#101011`.
  A 3-unit spread across AI-rendered images; treated as generation noise, not a real
  palette split, so the single `surface` token is retained.

---

**This document is the authoritative visual specification. Implementation must match the provided mockups as closely as possible.**

**End of Design Specification**