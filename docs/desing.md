# UI/UX Design System & Mockup Specification
## Calculator App

**Document Status:** Current — regenerated from `lib/` on 2026-10-13  
**Source of Truth:** The four mockups in `../Mockups/` **and** the shipped code. Where the
two disagree, §12 lists the departure and the code wins. The **white theme** has no mockup:
its palette is the sibling Ethar app's (D-90, §2.4).  
**Theme:** Two themes — **Dark** (the mockups) and **White** (D-90). Dark is the default and
the stored preference (`AppSettings.defaults.theme` = `'dark'`).  
**Decisions:** See [DECISIONS.md](DECISIONS.md) — cited here as `D-xx`, never restated  
**Tokens:** `lib/core/design/app_tokens.dart` — see §11 for the full reference

> **How to read this document.** §2–§5 and §11 are *generated* from the token files and
> the component library, so a value here is always a value in the code. §6–§10 describe
> what the screens actually do. Every value carries a **provenance**:
>
> | Mark | Meaning |
> |------|---------|
> | **M** | Measured from mockup pixels (Phase 1 and Phase 9) |
> | **C** | Chosen — a judgement call, defensible but not measured |
> | **D** | Derived — computed from another token by code, not stored |
>
> A token marked **C** is the honest kind of value in a design system: a decision with a
> reason, not a guess. Changing it is a one-line edit in one file.

---

## 1. Design Philosophy and Visual Identity

A **modern, minimalist aesthetic** with high contrast, generous spacing, and a clear
visual hierarchy, shipped in **two themes** (D-90): a **dark** theme measured from the
mockup pixels, and a **white** theme taken from the sibling **Ethar** app so the two
apps read as one family.

**Core Principles**

- **One palette per theme.** Every colour is read through `AppPalette` (D-90), never from a
  frozen `static const`, so the two themes differ only in the instance they install. The dark
  page is `#000000`; the white page is `#FEFEFE`. Both are chosen for contrast against the ink
  they carry, so a value that only works on one background is half a token.
- **Orange accent, primary actions only** — operators, `=`, toggles when ON, Clear History,
  active icons. Never selection, never decoration. Each theme states its own orange: `#F89508`
  (the calculator mockup's) on dark, `#FE651B` (Ethar's brand) on white. Neither accent had to
  be re-measured to give the other up.
- **Rounded-square keys** create a soft, approachable feel (D-114, reversing the circles of D-29).
- **The result is the hero.** Nothing on the calculator competes with the number.
- **Cards and grouped sections** give structure without clutter.
- **One optical margin.** Every card edge, section label, row, and header action box sits on
  the same 24 px line (§4). This is the strongest consistency rule in the app and the one
  most easily broken by a framework default (D-70).
- **One header shape.** Every screen's top bar is a `Row` bounded by 48 px bordered boxes,
  so titles centre by geometry rather than by a flag (D-74).
- **One node per interactive row.** A row announces as one thing, not four (D-59, §10.2).

**Overall Feel**
Clean, confident, and focused on the calculation itself.

**Mockup reference** (D-13 — filenames encode generation time, not screen identity):

| Mockup File | Screen |
|-------------|--------|
| `ChatGPT Image Sep 28, 2026, 02_17_57 AM.png` | History |
| `ChatGPT Image Sep 28, 2026, 02_22_43 AM.png` | Main Calculator |
| `ChatGPT Image Sep 28, 2026, 02_25_36 AM.png` | Settings |
| `ChatGPT Image Sep 28, 2026, 02_30_45 AM.png` | About |

Mockups are 884 × 1779 px at 2× (logical 442 × 890), portrait.

---

## 2. Color Palette

The single definition site is `AppPalette` (`lib/core/design/app_palette.dart`), a
`ThemeExtension` carrying **one value per theme**. `AppPalette.dark` is the token set
`AppColors` (`lib/core/design/app_colors.dart`) already holds — the dark theme is unchanged —
and `AppPalette.light` is the white theme (§2.4). Nothing outside these may hard-code a hex
value: screens and components read `context.appColors.<token>`, so a token change propagates
in one edit **and follows the active theme** (D-90).

`AppTheme` (`app_theme.dart`) builds the two `ThemeData`s from the two palettes, and
`AppType` resolves the §3 ramp's colours per palette, so a difference between the two themes
cannot appear on one side only.

### 2.1 Core palette — the dark theme (`AppPalette.dark` / `AppColors`)

| Token | Value | Role | Prov. |
|-------|-------|------|-------|
| `background` | `#000000` | Full screen background; the page behind every card | M |
| `surface` | `#101011` | Shared card & row surface: Settings groups, **History cards**, About hero card, confirmation dialog, decimal-places sheet, header action boxes | M |
| `surfaceRaised` | `#151517` | A surface one step above `surface` that is **not** a card (D-91). The History card used to read this; it now reads `surface` like every other card | C (D-72) |
| `surfaceSoft` | `#20232A` | Soft fill behind a row's 44 px leading icon tile (D-91) — Ethar's `_SettingsIconTile` fill | C (D-91) |
| `cardBorder` | `#292D35` | The 1 px outline around a grouped card (D-91) | C (D-91) |
| `ruleOnPage` | `#45454A` | 1 px rule across the calculator's display-to-keypad boundary — a different object from `divider` | C |
| `accent` | `#F89508` | Primary action: operator keys, `=`, toggles ON, Clear History, active icons | M |
| `danger` | `#FF5A5F` | Wrong-PIN feedback — the dots and the "Wrong PIN" line (D-88) | C |
| `buttonDigit` | `#242428` | Digit keys and the decimal point | M |
| `buttonFunction` | `#A2A2A8` | `AC`, `+/−`, `%` | M |
| `textPrimary` | `#FFFFFF` | Main result, headings, active labels, keys on dark fills | M |
| `textOnFunction` | `#000000` | Labels on the light function keys | M |
| `textOnAccent` | `#FFFFFF` | Labels on anything filled with `accent`. Named as its own token so the **light** theme can print ink on a light accent instead (D-90) | D |
| `textSecondary` | `#949AA4` | Expression line, subtitles, captions, section headers, chevrons | M |
| `divider` | `#292D35` | Hairline between rows inside a grouped card (retuned in D-91) | C |
| `toggleTrackOn` | `#F89508` | Toggle track, ON | M |
| `toggleTrackOff` | `#2A2A2A` | Toggle track, OFF | C — **R-1**, D-61 |
| `toggleThumb` | `#FFFFFF` | Toggle thumb, ON and OFF alike | M |
| `pressedOpacity` | `0.85` | Opacity of a pressed key or button | C |

The three selection tokens live in §2.2; the keypad's fill, halo, and gradient tokens in §5.1.

**The function keys are the palette's trap.** They are a *light* mid-gray carrying
*near-black* labels — not a medium gray with white labels. This was the largest single
correction in the Phase 1 measurement, and `CalculatorButtonVariant` owns the pair so no
call site can mismatch a fill with its foreground.

**R-1, resolved.** Phase 9 read the mockup pixels for the first time and confirmed what
Phase 1 suspected: all three Settings toggles in the mockup are **ON** (track 44 × 25.5 px,
`#F89508`). No mockup contains the OFF state, so no value for it can be measured. The
platform default was rejected — it renders a light gray track that breaks the black/gray
palette. `#2A2A2A` is a dark gray from the same family as `buttonDigit`, so it sits *in* the
palette rather than on top of it. Accepted as final for v1.0 (D-61); a designer hand-off
would supersede it, and that is the single edit needed when one arrives.

### 2.2 Selection palette (History multi-select, D-76)

Three tokens, because the three roles are genuinely different — collapsing them is exactly
what makes a selected card unreadable.

| Token | Value | Role | Why |
|-------|-------|------|-----|
| `selectionAccent` | `#FFFFFF` | Checkbox fill, selected card's border, the "N selected" count | White, **not** `accent`. Orange is the app's *primary action* colour; selection is a mode, not an action. Painting three rows orange would claim three button presses. |
| `surfaceSelected` | `#2E2E31` | Fill of a selected card | **Not** `selectionAccent`. A pure-white card carrying this app's white result text would be unreadable, and inverting the type to fix it would turn a list of selected rows into slabs that outshout the numbers. This is white at low opacity over the black page — the same relationship `surfaceRaised` has to `background`, one step further along — so the card reads as *lifted* and the accent on top stays the brightest thing in the row. |
| `selectionCheck` | `#000000` | Tick inside the selected circle | Black on white. `textPrimary` is the obvious reach and is what the sibling app uses on its orange fill, but there the fill is a mid-tone; on a *white* circle a white tick is invisible. This is the same black the app already prints on light fills. |

### 2.3 Notes on the palette

- **Surface spread is generation noise.** Settings and About surfaces read `#0D0F12` /
  `#0E0F11` against History's `#101011` in the mockups. A 3-unit spread across AI-rendered
  images; treated as noise, not a real palette split — which is why the History redesign
  introduced `surfaceRaised` rather than moving `surface` and restyling three other screens.
  The History card itself has since returned to `surface` (D-91) like every other card.
- **Icons** are `#FFFFFF` by default and `#F89508` for active/feedback glyphs, passed
  explicitly per call site (§5.4).

### 2.4 The white theme (`AppPalette.light`, D-90)

The second theme is **not** a re-measure of anything: it is the sibling **Ethar** app's white
palette, so the two apps read as one family. Every value below is Ethar's own token except
the keypad fills, which Ethar has no equivalent of and which follow the *same relationship the
dark theme uses* — digits a step below the card, function keys a step further still.

| Token | Dark | White |
|-------|------|-------|
| `background` | `#000000` | `#FEFEFE` |
| `surface` | `#101011` | `#FFFFFF` |
| `surfaceRaised` | `#151517` | `#FAFAFB` |
| `surfaceSelected` | `#2E2E31` | `#F0F1F3` |
| `surfaceSoft` | `#20232A` | `#FAFAFB` |
| `cardBorder` | `#292D35` | `#ECEDEF` |
| `cardShadow` | `null` (none) | `0x0D0F172A`, blur 24, offset (0, 8) |
| `accent` | `#F89508` | `#FE651B` |
| `danger` | `#FF5A5F` | `#D92D20` |
| `buttonDigit` | `#242428` | `#F4F5F7` |
| `buttonFunction` | `#A2A2A8` | `#D9DADD` |
| `textPrimary` | `#FFFFFF` | `#0C0F16` |
| `textOnFunction` | `#000000` | `#0C0F16` |
| `textOnAccent` | `#FFFFFF` | `#FFFFFF` |
| `textSecondary` | `#949AA4` | `#656A78` |
| `divider` | `#292D35` | `#ECEDEF` |
| `ruleOnPage` | `#45454A` | `#DCDEE2` |
| `toggleTrackOn` | `#F89508` | `#FE651B` |
| `toggleTrackOff` | `#2A2A2A` | `#DFE1E5` |
| `toggleThumb` | `#FFFFFF` | `#FFFFFF` |
| `selectionAccent` | `#FFFFFF` | `#0C0F16` |
| `selectionCheck` | `#000000` | `#FFFFFF` |
| `keyShadow` | `#1AFFFFFF` halo, blur 10, offset (0, 2) | `#1F0F172A` dark shadow |
| `keyBorder` | `#33333A` | `#E4E6EA` |

**Card edges swap jobs between themes.** The dark theme separates a card from the page with a
1 px `cardBorder` and **no** shadow (a black shadow on a black page is invisible at every
elevation); the white theme keeps Ethar's border *and* adds `cardShadow`. Ethar drops the
shadow in dark for the same reason, so the two themes differ because the page differs, not
for variety.

**Two pairings invert on purpose.** `selectionAccent`/`selectionCheck` are white-fill +
black-tick on dark and ink-fill + white-tick on white (a white disc on a white card is
invisible). `textOnAccent` stays white in both because both accents are oranges that want a
white label — but it is a **named token** so the light theme is free to disagree without
restyling the dark one.

---

## 3. Typography

The single definition site is `AppTypography` (`lib/core/design/app_typography.dart`). The
system font is used throughout (SF Pro on iOS, Roboto on Android) so no custom asset ships;
only weight, size, and spacing are specified. **One ramp serves both themes**: the `Colour`
column below names the palette token each style reads, and `AppType` (`app_type.dart`)
re-colours `AppTypography`'s tokens per `AppPalette`, so the same size lands as white on dark
and ink on white (D-90) with no second scale.

### 3.1 The scale

Every token below is the value in the code — there is no range any more. Where this
document once gave a range, the implementation took the **midpoint**, which left a single
number to move when Phase 9 measured the mockups.

| Token | Size | Weight | Line height | Colour | Usage |
|-------|------|--------|-------------|--------|-------|
| `resultLarge` | 60 | w600 | 1.1 | `textPrimary` | Hero result on the calculator display |
| `resultMedium` | 44 | w600 | 1.1 | `textPrimary` | Result once it exceeds 10 characters |
| `expression` | 20 | w400 | — | `textSecondary` | Expression line above the result |
| `screenTitle` | 32 | w700 | — | `textPrimary` | Header title — "History", "About", both legal screens |
| `screenTitleCompact` | 28 | w700 | — | `textPrimary` | Compact header title (Settings); the About hero card's app name |
| `subtitle` | 16 | w400 | — | `textSecondary` | Supporting line under a title |
| `sectionHeader` | 14 | w600 | — (ls 1.1) | `textSecondary` | Uppercase group label — "APPEARANCE", "PREFERENCES" |
| `rowTitle` | 17 | w500 | — | `textPrimary` | Primary label in a row — "Sound" |
| `rowSubtitle` | 14 | w400 | — | `textSecondary` | Supporting label in a row — "Key press sound" |
| `rowValue` | 16 | w400 | — | `textSecondary` | Trailing value on a row — "2", "On", "1.0.0" |
| `historyExpression` | 16 | w500 | 1.3 | `textSecondary` | "125 × 8" at the top of a History card |
| `historyResult` | 22 | w600 | 1.1 | `textPrimary` | "1,000" at the bottom of a History card |
| `historyDayLabel` | 17 | w600 | 1.2 | `textSecondary` | "Today", "Yesterday" above a group |
| `buttonLabel` | 25 | w500 | — | per variant | Label on a calculator key |
| `bottomAction` | 17 | w500 | — | `accent` | "Clear History" at the foot of the list |
| `caption` | 12 | w400 | — | `textSecondary` | Version footer, legal metadata |
| `body` | 15 | w400 | 1.5 | `textSecondary` | Body copy on the legal screens, dialog messages |
| `legalHeading` | 18 | w600 | — | `textPrimary` | Section heading on the legal screens and the sheet title |
| `selectionCount` | 20 | w700 | — | `selectionAccent` | "3 selected" in the History header (D-76) |

### 3.2 Rules the scale encodes

- **The result steps down before it shrinks.** Past 10 characters the display drops from
  `resultLarge` to `resultMedium`; beyond that a `FittedBox` scales the line rather than
  clipping or ellipsizing a number the user is trying to read. Auto-shrink, in that order.
- **History speaks in sentence case at reading size.** `historyDayLabel` (17) is not a
  `sectionHeader` (14 uppercase) because the two screens want different voices: Settings and
  About shout their group labels, History introduces a day. Reusing one style for both would
  have restyled three screens to serve one. `historyDayLabel` is `rowTitle`'s size, so a day
  heading and a row label are the same kind of thing at the same rank.
- **The History card's type was corrected twice.** D-72 pushed the expression to 28 and the
  result to 44; D-73 returned both to this document's bands (16 and 22). At 28 the
  expression competed with the result it introduces, and at 44 the result outranked even the
  page title (32). At 22 the result is still the largest thing on the card.
- **`historyResult` uses tabular figures.** Fixed-width digits mean a column of results
  aligns digit-for-digit instead of shifting as the numbers change. It is the only token
  with a `FontFeature`.
- **The result on a History card must never be truncated.** A half-shown number is worse
  than a smaller one, so it is wrapped in `FittedBox(fit: scaleDown)` and scales to fit.
- **`screenTitleCompact` exists as a token, not a `copyWith`.** The About hero card prints
  the app's name through the same default as a screen title; an in-place size edit to shrink
  the Settings header would have demoted the app's own name along with it (D-71, D-75).

---

## 4. Spacing, Radii, and Fixed Sizes

The single definition site is `AppSpacing`, `AppRadius`, and `AppSizes`
(`lib/core/design/app_spacing.dart`). These are exact values, not ranges — Phase 9 measured
them (§12.1).

### 4.1 Spacing

| Token | Value | Use |
|-------|-------|-----|
| `screenHorizontal` | **24** | The screen margin. The most important number in the app (§4.3). |
| `calculatorSideMargin` | 16 | The calculator's own side margin (D-110) — every other screen is still 24 |
| `cardPadding` | 16 | Inner padding of a card or list row |
| `dividerIndent` | 72 | Start of a row divider, so the hairline begins where the titles do (D-91) |
| `dividerEndIndent` | 16 | End of a row divider |
| `sectionGap` | 32 | Vertical gap between major page sections |
| `xl` | 24 | Large step — also the margin and the header gap |
| `lg` | 16 | Medium step — card padding is `lg` horizontally inside rows |
| `md` | 12 | Gap between stacked elements in one section; icon-to-text gap in a row |
| `sm` | 8 | Tight gap — between a day label and its cards, and other one-step insets |
| `headerTopGap` | 24 | Between the top safe area and the page header |
| `bottomSafe` | 24 | Below the last element, clearing the gesture bar |
| `calculatorDisplayGap` | 24 | Between the display block and the top key row |
| `historyCardGap` | 8 | Between two History cards (applied half above / half below each) |
| `historyCardHorizontal` | 18 | Horizontal padding inside a History card (D-93) |
| `historyCardVertical` | 17 | Vertical padding inside a History card (D-93) |
| `historyGroupGap` | 24 | Above a day label — the gap that separates two groups |

### 4.2 Radii

| Token | Value | Use |
|-------|-------|-----|
| `card` | 14 | Settings groups, About hero card, dialog, bottom sheet, the Vault's Categories card |
| `historyCard` | 12 | History cards (**D-93**, corrected from 14) |
| `tile` | 12 | A row inside a grouped card |
| `iconButton` | 12 | The header action's bordered square |
| `dialog` | 20 | The About hero card and the confirmation dialog |
| `calculatorKey` | 26 | Rounded-square calculator keys (**D-114**) |

**A radius names an object, not a number.** `tile` and `iconButton` are both 12 without being
duplicates — a row inside a grouped card and the header action's square are different objects
that must not be allowed to drift — and one shared value standing for both is precisely the
drift a token file exists to prevent. `historyCard` and `card` once held the same number for
the same reason; **D-93 split them** (12 and 14) when it corrected which Ethar card a History
entry actually tracks. A test asserts the pairs in both directions, so an edit that moves one
and not the other fails, and an edit that moves both is deliberate.

### 4.3 The 24 px screen margin

`screenHorizontal = 24` is the app's single horizontal rhythm, and it was **corrected from
20** in Phase 9 (D-60). The card edges in the History, Settings, and About mockups all sit
at logical x ≈ 24, consistently across three independently rendered images.

This one token also **fixed the calculator key size** (D-60), because the keypad derives its
cells from the width left over after the margins. At the 442 × 890 mockup canvas:

```
margin 20 -> cell (442 - 40 - 3*14) / 4 = 90.0   too large
margin 24 -> cell (442 - 48 - 3*14) / 4 = 88.0   matched the pixels
```

88 px is inside the 86.5–87.5 px the key rows actually measure, which is how correcting the
margin closed **R-2**. The key diameter was never an independent value; measuring keys
alone could only ever bracket a range.

**The calculator left this margin in D-110.** The arithmetic above is a *cost*, and the
calculator is the one screen that has no cards to align with — it is a 4-column grid whose
cell is whatever width it is handed minus the margins. The spacious redesign therefore gave
the calculator column `calculatorSideMargin = 16` and widened `keyGap` 14 → 16 together:

```
margin 16, gap 14 -> (442 - 32 - 42) / 4 = 89.5
margin 16, gap 16 -> (442 - 32 - 48) / 4 = 90.5   the D-110 geometry
```

Widening the gap *alone* would have shrunk the keys, and tightening the margin alone would
have left them touching; only the pair buys a bigger key **and** more air around it. Every
card edge in every other screen is still at 24 — `screenHorizontal` did not move, and
`calculatorSideMargin` is a second token precisely so it could not.

### 4.4 Fixed sizes

| Token | Value | Min or fixed | Use |
|-------|-------|--------------|-----|
| `headerHeight` | 56 | **min** | Every top bar. A minimum because the bar grows for Dynamic Type, and every screen's top spacing is measured from it. |
| `rowMinHeight` | **64** | **min** | A tappable settings row — raised from 56 in **D-91** because the row now holds a 44 px icon tile; the whole row is the target, so the switch is operable from anywhere across it |
| `rowIcon` | 22 | fixed | The icon inside a list row |
| `iconTouchTarget` | 48 | fixed | Side of an icon-only action, and the header action's box |
| `historyMetaGlyph` | 17 | fixed | The glyph leading a History card's meta row (D-93) |
| `historyMetaGap` | 5 | fixed | Gap between that glyph and its text (D-93) |
| `brandIcon` | 88 | fixed | The About hero brand mark |
| `historyCardMinHeight` | 88 | **min** | A History card — see below |
| `calculatorPanelMaxWidth` | 480 | fixed | The calculator's header + display + keypad column |
| `calculatorHeaderAction` | 56 | fixed | The calculator's Settings and History buttons — its own scale, since a 48 px box above a 90 px key reads as a header for a smaller app (D-110) |
| `calculatorBackspaceRow` | 48 | fixed | The calculator's backspace row, one header box tall; reserved before the keypad is sized (D-81) |
| `secretHomeButton` | 56 | fixed | The floating home button on the Secret Mode screens; a Material small-FAB silhouette (D-86) |

`AppSecretSpacing.homeButtonInset` (24) is the inset the floating home button keeps from the
right and bottom edges, under the `SafeArea` — named so its clearance is one fact rather than
a number retyped at each of the two screens it appears on.

**Why the minimums are minimums.** A hard `SizedBox(height: 88)` on a History card would be
the one value that is wrong on every screen except a 1× one. At 1× its content settles at
88; at the 1.3× text-scale ceiling the same content grows past that, and the card must grow
with it rather than clipping its own result or throwing a render overflow.

**The 480 cap is the whole "resizable window" story.** The calculator's header, display, and
keypad share one column so their edges line up (D-69). Without a cap the grid derives its
cell from whatever width it is given, so a 1280 px window would render 268 px keys. 480 is
slightly wider than the 442-wide reference canvas, so a large phone is never letterboxed and
the measured 88 px cell is untouched.

---

## 5. Components

### 5.1 Calculator Keys and Keypad

**Layout** — 4 columns × 5 rows, from the mockup:

```
AC      +/−     %       ÷
7       8       9       ×
4       5       6       −
1       2       3       +
0 (2 columns)     .       =
```

Verified against mockup `02_22_43`: the operator column (`÷ × − +`) and `=` are orange, the
`0` key spans two columns, and the **grid** has no backspace key (D-19). **D-81** added a
backspace control — this app's own painted `AppBackspaceIcon`, not Material's
`backspace_outlined` — in a row of its own *between the display and the rule*, one
`iconTouchTarget` (48) tall, on the left of the same column the keys use. So the grid is
still 4 × 5; the backspace is not one of its cells.

**Variants.** Each owns its own fill and label colour **and its own label size**,
so a screen can never pair a fill with the wrong foreground, or paint the orange
column at the digit size (D-111):

| Variant | Keys | Fill | Label | Label size |
|---------|------|------|-------|------------|
| `digit` | `0`–`9`, `.` | `#242428` | `#FFFFFF` | 25 / w500 |
| `operator` | `+ − × ÷` and `=` | `#F89508` | `#FFFFFF` | **32 / w600** |
| `function` | `AC`, `+/−`, `%` | `#A2A2A8` | `#000000` | **24 / w600** |

Each variant also carries a **tactile surface** (D-114): a subtle vertical gradient
(`keyDigitTop`/`Bottom`, `keyFunctionTop`/`Bottom`, `keyOperatorTop`/`Bottom`), an inner
top-edge highlight (`keyDigitHighlight`, `keyFunctionHighlight`, `keyOperatorHighlight`), and
— for the operator column only — an accent-tinted `keyOperatorShadow` (blur 14, offset (0, 3))
behind a `keyOperatorBorder`. The white theme states the same recipe in light values (§2.4) so
the keys keep their depth on a white page.

**The keys are painted, not elevated (D-111).** A `Material` casts its elevation
shadow in a colour the framework chooses — black in the dark theme — and the page
is `#000000`, so a black shadow on a black page is invisible at *every* elevation
value. `keyElevation` is therefore gone: the dark theme draws a faint **white
halo** (`#1AFFFFFF`, blur 10, offset (0,2)) and the white theme an ordinary dark
shadow (`#1F0F172A`), both from a `ShapeDecoration` outside the `Material`, plus
a 1 px `keyBorder` (`#33333A` / `#E4E6EA`) — the outline is the only one of the
three that says where a key *ends*.

**Geometry is derived, never stored.**

| Token | Value | Meaning |
|-------|-------|---------|
| `keyGap` | **16** | Widened from 14 with the calculator margin in **D-110** |
| `minTouchTarget` | 44 | Accessibility floor for the cell |
| `maxCellSize` | **160** | Ceiling, so a tall phone stops growing the keys |
| `columnCount` / `rowCount` | 4 / 5 | From the mockup |

```
cellSize = min( (width  - 3*16) / 4 ,  (height - 4*16) / 5 )   clamped to [0, 160]
```

Whichever axis is tighter decides the size, so the grid shrinks on a small phone instead of
overflowing and stops growing on a tall one. There is deliberately **no matching floor**:
`minTouchTarget` sizes the *space the screen reserves* for the grid, not the cell inside it,
because on a very short screen the display's number outranks the key size. `CalculatorButton`
then takes the smaller of its own box's two axes and keeps its shape at any phone size.

**The gap is a real child.** `keyGap` is rendered as actual `SizedBox` widgets between keys
rather than subtracted from a width (D-69). An earlier version reserved the same gap and
still drew touching keys — the reservation and the rendering were two different numbers that
agreed by coincidence.

**The keys are rounded squares, not circles** (D-114, reversing D-29). Each is an
`AppRadius.calculatorKey` (26) corner on the ~90 px cell — moderate corners that read compact
and refined. **The wide `0` key reuses the same radius** while spanning two columns, so it is
a wide rounded rectangle rather than a pill; a circle and a two-column span cannot both hold,
and the rounded rectangle is the shape that keeps every key's corners identical.

**Pressed state.** `AnimatedOpacity` to `pressedOpacity` (0.85) over 100 ms. Not present in
the mockups; standard platform feedback is used.

### 5.2 Toggle Switches

- Standard Material `Switch`, kept at its standard 52 × 32 box rather than drifting with
  whatever theme is applied.
- **ON**: track `#F89508` (`toggleTrackOn`), thumb `#FFFFFF`.
- **OFF**: track `#2A2A2A` (`toggleTrackOff`, R-1 / D-61), same thumb.
- **The Material 3 track outline is cleared.** The mockups show no outline around the track,
  and the default would draw one.
- Positioned on the right of the row, and the **whole row is the tap target**, so the switch
  can be operated from anywhere across the row's 56 pt height rather than only on the
  52 × 32 control.
- The switch keeps its **own semantics node and its on/off state** rather than merging into
  the row — a screen reader reaching it announces "Sound" *and* the position, instead of
  attaching the position to a node named after the whole row (D-59).

### 5.3 List Rows and Cards

- **Rows** are transparent on their own and take their fill from `SettingsGroup`, so a stack
  of rows reads as **one card with hairlines** between them rather than as separate floating
  tiles. Minimum height **64** (`rowMinHeight`, raised from 56 in **D-91** because the row now
  holds a 44 px icon tile), padding `cardPadding` horizontally and `md` vertically.
- **Layout**: icon tile (44) → 16 gap → title + optional subtitle → control. A tappable row with
  no explicit trailing control draws a chevron, which is what every navigational row in the
  mockups shows. **Every trailing control — chevron, switch, or value — is flush against the
  row's right `cardPadding`** (**D-92**), and the trailing slot is a plain
  `ConstrainedBox(maxWidth: 105)` rather than a flex child, so the title's `Expanded` takes all
  the width the control does not need. Ethar bounds its value at the same 105.
- Separators between rows use `divider` `#292D35` (retuned in **D-91**), indent **72** so the
  hairline starts where the titles do and never runs under the icon tile, end-indent 16.
- **Cards** are `surface` (`#101011` dark, `#FFFFFF` light) with a 14 px corner — a History card's
  corner is `historyCard` (**12**, D-93) — and **a 1 px
  `cardBorder` outline** (`#292D35` dark, `#ECEDEF` light). The white theme additionally lifts
  the card with `cardShadow` `0x0D0F172A`, blur 24, offset (0, 8); **dark casts none**, matching
  Ethar. **D-91 reverses the earlier "no border, no elevation" rule:** on a black page the fill
  is the only thing separating a card from the background, and one step of luminance is a
  difference a user can see but cannot point at. The outline is that point.

### 5.4 Icons

- Material's **outlined** set throughout, so stroke weight is consistent by construction.
- Colour: `#FFFFFF` by default; `#F89508` passed explicitly for active/feedback glyphs
  (Sound, Vibration, Clear History).
- Sizes are **named buckets**, never raw numbers at a call site:

| Bucket | Value | Use |
|--------|-------|-----|
| `AppIconSize.small` | 18 | Dense content such as a row's chevron |
| `AppIconSize.row` | 22 | The default — rows, and every header glyph |
| `AppIconSize.tile` (D-91) | 21 | The glyph inside a row's 44 px `AppIconTile`. One below `row` because Ethar's tile holds a 21 px glyph, and one pixel is the difference between a glyph that fills its tile and one that looks large inside it |
| `AppIconSize.large` | 28 | Retained as a step, though D-74 moved header glyphs to `row` |
| `AppIconSize.illustration` | 40 | The History empty state's illustration |
| `AppIconSize.hero` | 44 | The About brand mark |

`illustration` and `hero` are separate buckets on purpose. History asks for 40 and the brand
mark is 44; reusing one bucket would make a placeholder glyph as large as the app's own logo,
which reads as a missing asset rather than as "nothing here yet".

- **`AppTrashIcon`** is a `CustomPainter` rather than an icon font, because the design calls
  for a specific glyph Material's set does not contain (D-73). The alternatives were both
  worse: `flutter_svg` would add a runtime dependency and an asset pipeline for one icon,
  against a project that deliberately takes its audio, haptics, and navigation from the SDK
  and the plugins it actually needs; flattening the path into IconFont codepoints makes the
  drawing unreadable once generated. It mirrors `AppIcon`'s API exactly — same defaults, same
  `semanticLabel` escape hatch — so swapping one for the other changes only the widget name.
- **`AppTrashIcon` is the app's only delete glyph** (D-119). Every place the app can delete
  from — the History header and bottom action, the selection bars, the image viewer, the
  Vault's Recycle bin row and its empty page, the gallery's Trash tab, its empty illustration,
  and the delete action inside the Trash — paints this widget. Material's `delete_outline` and
  `delete_forever` are **not** used anywhere, so no two screens can show two different trashes.
- **`AppBackspaceIcon`** is the app's own `⌫` glyph, a `CustomPainter` like `AppTrashIcon`
  rather than Material's `backspace_outlined` (D-81). It is painted in two places — the
  calculator's backspace row and the Secret Mode PIN keypad's bottom-right key — so the two
  `⌫`s are the same shape. `AppIconTile` (D-91) is the app's 44 px icon container: the leading
  tile on every settings row and on each Vault category cell, so those read as one object.
- Icons sitting beside a text label are **decorative** and carry no semantic label, so a
  screen reader does not announce the row twice.

### 5.5 Brand Mark (About hero)

A rounded square holding four circular operator keys in a 2 × 2 grid:

```
  + (light)   − (orange)
  × (light)   = (orange)
```

The left column is the light function-key gray and the right column the orange accent, so the
mark reuses the same two tokens as the keypad — the icon is a miniature of the thing it
names. The two-orange / two-light split was confirmed by measuring the pixels of mockup
`02_30_45`; the glyph-to-quadrant assignment is carried from this specification. Drawn from
tokens at `AppSizes.brandIcon` (88) rather than shipped as an asset, so it stays sharp at any
size and follows a palette change.

### 5.6 Headers

Every screen's top bar is one of three components. All three sit on `headerTopGap` (24)
above the safe area, apply `screenHorizontal` at their sides, and bound their row by
`headerHeight` (56) as a **minimum** so Dynamic Type grows the bar rather than clipping it.

**`AppPageHeader`** — a screen that is a *destination*: the calculator's own bar, and the
debug catalogue. A plain `Row`, not an `AppBar`. `AppBar` reserves a 56 px leading slot, adds
an 8 px action inset, and centres its leading glyph *inside* the slot — so a stock header
paints its 22 px glyph at x ≈ 21, three pixels inside the line every card in the app is built
on (D-70). A `Row` has no slot to fight. Title optional; the calculator passes none, because
§6.1 puts the display where a title would go.

**`SecondaryPageHeader`** — every pushed screen: History, Settings, About, both legal
documents. A bordered back box on the left, a centred title, an optional trailing action. The
title is centred **by geometry**: both sides of the row are 48 px wide (a real action on one
side, an equal-width blank on the other), so the middle the title is laid out in is symmetric
about the screen and the word lands in the optical centre at any title length. Without the
blank, a lone back arrow would shift its own title 60 px right.

**`AppSelectionHeader`** — the History screen's selection mode (D-76). Swapped in place of
`SecondaryPageHeader`, never stacked with it: a screen showing both "History" and "3 selected"
would give two answers to what mode the user is in, and the delete action would have nowhere
to sit. Carries the count (`selectionCount`), a select-all / deselect-all toggle, delete, and
cancel.

**`AppIconButton`** — the bordered square every header action wears (D-74). A `surface` fill,
a 1 px `divider` border, and a 12 px corner. Drawing the box is the point: a bare glyph three
pixels off the line every card is built on reads as a squashed layout, while a box whose
*edge* rides the margin reads as a deliberate object. The box is exactly 48 px square so the
header can centre a title between two of them, and the glyph size is owned by the component
rather than the call site, so no screen can ship a 28 px arrow beside a 22 px one. It stays a
real `IconButton` so `find.byType`, tooltips, and the accessibility layer all work for free.

**No header carries a subtitle.** The parameter was removed rather than left unused (D-75), so
no screen can reintroduce the two-line banner by accident.

---

## 6. Screen Specifications

Twelve routes exist (`app_router.dart`); eleven ship, and `/catalog` is debug-only (D-20).
The Vault screens (§6.8–§6.10, §6.11) are ordinary registered routes because the
five-second hold has to push one, and pushing needs a registered path.

| Route | Screen | Header |
|-------|--------|--------|
| `/` | Calculator | `AppPageHeader` (actions only, no title) |
| `/history` | History | `SecondaryPageHeader`, swapping to `AppSelectionHeader` |
| `/settings` | Settings | `SecondaryPageHeader` |
| `/about` | About | `SecondaryPageHeader` |
| `/privacy` | Privacy Policy | `SecondaryPageHeader` |
| `/terms` | Terms of Service | `SecondaryPageHeader` |
| `/secret/unlock` | PIN prompt (D-82) | none — a bare `Scaffold` with a top-left back arrow (D-87) |
| `/secret` | **Vault** (D-84, FEAT-SEC-003) | `AppPageHeader` titled "Vault", actions = Search + Menu |
| `/secret/settings` | Vault settings (FEAT-SEC-004) | `SecondaryPageHeader` |
| `/secret/change-pin` | Change PIN flow | `SecretPinField` steps (D-113) |
| `/secret/browse/:place` | One Vault place (FEAT-SEC-007, D-114) | `SecondaryPageHeader` |
| `/catalog` | Component Catalog | `AppPageHeader` — **debug only**, behind `kDebugMode` |

### 6.1 Calculator

```
SafeArea (black)
└── Column, capped at 480 and centred          (D-69)
    ├── AppPageHeader
    │   ├── Left:  bordered box — gear (settings) → Settings
    │   └── Right: bordered box — history clock → History
    ├── Expanded: CalculatorDisplay                       (D-78)
    │   ├── upper half: expression  20 w400 secondary, right-aligned, ellipsised
    │   │              — the calculation as keyed, in-progress operand included (D-79)
    │   ├── lower half: result      60 w600 primary, right-aligned, scaleDown
    │   │              — the live preview of what `=` would give (D-79)
    │   └── the two halves are equal; each line centres in its own
    ├── 24 px ruled gap: 1 px rule, inset 24 px from each edge
    └── CalculatorKeypad (5 × 4, derived cell)
```

**One capped column.** The header, the display, and the keypad share it so their left and
right edges line up: the number sits flush with the `=` column instead of drifting away from
it as the window widens. The keypad has **no horizontal padding of its own** — `gridWidth` is
already the column inside the screen margin, and filling that column is what puts the result
flush with the operator column.

**The display is two screens, split down the middle** (D-78). The space it is given is
divided into two equal halves: the **calculation** — the expression being built, `9 + 9` —
centres in the upper half, and the **output** — the result, `18` — in the lower one. So the
result sits clear of the keys rather than against them, and its height is *reserved before*
the keypad is sized: `minimumHeight(scaler)` returns two result line boxes, one per half (D-54).

**The output line is a live preview** (D-79). The lower half shows what `=` *would* produce,
updated on every keystroke, so `9 + 9` already reads `18` while the second `9` is still being
keyed and pressing `=` does not move the number. The preview is derived from the display
state, so the engine still folds nothing until `=` or the next operator commits it, and
changing `decimalPlaces` re-renders the preview without touching the calculation. Two
consequences shape what each line carries: the **calculation** line includes the operand being
typed (`9 + 9`, not `9 +`), since the output line is no longer showing it; and an **operator
with no number in front of it is ignored** (D-80), so a lone `+` is never printed and a number
never appears behind one. A calculation that cannot be completed yet — `5 ÷ 0` — keeps showing
the running total rather than flashing `Error`; `Error` is `=`'s answer.

**Tall screens give the surplus to the display, not the keys.** The keypad's height follows
from the column's *width*, so on a tall phone the extra space lands in the display's two halves.

**No title in the header.** The display occupies the position a title would take.

**Verified against mockup `02_22_43`**: the operator column and `=` are orange, `0` spans two
columns, and there is no backspace key.

### 6.2 History

The History screen was **rebuilt** in D-72 and rescaled in D-73; it no longer matches mockup
`02_17_57` (see §12.2).

```
SecondaryPageScaffold
├── SecondaryPageHeader — bordered back box | "History" | bordered trash box
└── CustomScrollView
    ├── 16 px lead-in
    ├── HistoryDayLabel "Today"          17 w600 secondary, sentence case
    ├── HistoryCard × n
    ├── HistoryDayLabel "Yesterday"      + 24 px group gap above
    ├── HistoryCard × n
    └── 24 px bottom safe
└── "Clear History" (accent, bottom action)
```

**A History card:**

- Fill `surface` (`#101011`) with a 1 px `cardBorder` outline, radius `historyCard` (12,
  D-93), **minimum** height 88, padding 18 horizontal / 17 vertical (D-93). The card no longer
  reads `surfaceRaised`; it is the same object as every other card (D-91).
- Expression (16 w500 secondary, ellipsised) above an 8 px gap and the result (22 w600
  primary, tabular figures, `scaleDown` and never truncated).
- Trailing chevron at `AppIconSize.row` (22) in `textSecondary`. A row-sized chevron, not a
  header-sized one — at 28 px it was a third of the card's height, and the affordance is not
  the content.
- **Cards sit on the app's own 24 px margin**, not an inset one (D-73). D-72's dedicated
  inset pulled the cards inboard of both the screen margin *and* the header's back arrow,
  which read as a mistake rather than as a distinction — the header's arrow sits on the same
  line everything else does.
- Card-to-card gap is 8, applied half above and half below each card so the value the design
  states is the distance a user actually sees between two edges.
- Day boundary is a change of subject, so `historyGroupGap` (24) is deliberately larger than
  the 8 px between cards.
- The scroll view starts 16 px below the header rather than flush under it, because the first
  day label carries its own group gap for the days that follow it — a gap that applied only
  from the second group onwards would put the newest day hard against the title.

**Tapping a card** loads that result back into the calculator.

**The trash stays visible even with nothing to delete** (D-10) but returns early rather than
opening a confirmation for an empty list, and paints `textSecondary` rather than white: a
white icon that does nothing reads as a working button that is merely not responding, which
is worse than either an enabled button or a visibly inert one (D-38).

**"Clear History"** is hidden when there is nothing to clear (D-38), though the header trash
keeps the action reachable either way.

#### 6.2.1 Multi-select (D-76)

| Interaction | Behaviour |
|-------------|-----------|
| **Enter** | **Long-press** a card. Not double-tap, and not a persistent checkbox column: on a list of up to 200 rows an always-on affordance costs a row's worth of height, and the trailing slot already changes shape in selection mode. |
| **Toggle** | Tap a card to add or remove it. In selection mode the row is a *choice*, not a load action. |
| **Paint** | Keep the finger down and **drag** after the long-press: every row the finger crosses is set — not toggled — and the press's own row decides the direction, so starting on an unselected row adds and starting on a chosen one removes. Dragging back over a row already touched does nothing. Shared with the gallery, the documents list, and its recycle bin (`DragSelectRegion`, D-120); the region auto-scrolls near an edge so a row off-screen can be reached without lifting. |
| **Header** | Swapped for `AppSelectionHeader`: "N selected", select-all / deselect-all, delete, cancel. |
| **Back gesture** | **Cancels the selection** rather than leaving the screen. A mode that swallowed the back button would make History unreachable by the gesture every other pushed screen answers to, and losing a selection is a far smaller loss than losing the page. |
| **Bottom action** | Hidden while selecting. |
| **After delete** | The selection set is cleared, so the header cannot keep claiming rows that no longer exist and a second tap cannot come back with an empty delete. |

**Selected card** — a 2 px `selectionAccent` outline drawn *inward* by a `Container` wrapping
the `Material`, plus a `surfaceSelected` fill. The inward border means the card's measured
width does not change, so the geometry contract holds in selection mode exactly as it does at
rest. The border lives on the wrapper rather than the `Material`'s own `shape` because
`Material` asserts that `shape` and `borderRadius` are never both given, and `borderRadius`
is what the resting card's geometry test asserts on.

At rest the card already carries the 1 px `cardBorder` outline every card now shares (D-91),
so selection does not invent a border — it **recolours and thickens it** to 2 px
`selectionAccent`. That is what makes a selection of twenty rows scannable at a glance, with no
change in width.

**The checkbox** is a 28 px circle (`selectionCircle`, §11). Unchecked it keeps a visible
ring, so an unselected row in selection mode still reads as *offering a choice* rather than as
a row that has lost its affordance.

### 6.3 Settings

```
SecondaryPageScaffold
├── SecondaryPageHeader — bordered back box | "Settings"
└── ListView
    ├── SectionHeader "APPEARANCE"
    │   └── Theme        sun + "Theme" / "Dark" or "White"   → Theme sheet (D-90)
    ├── SectionHeader "PREFERENCES"
    │   ├── Sound        speaker + "Key press sound"        toggle
    │   ├── Vibration    phone   + "Vibrate on key press"   toggle
    │   ├── Decimal Places  "123" + "2 decimal places"     → bottom sheet
    │   └── History      clock  + "Keep calculation history" toggle
    ├── SectionHeader "ABOUT"
    │   ├── App Version        → "1.0.0"
    │   ├── Privacy Policy     → route
    │   └── Terms of Service   → route
    └── Footer caption: "Calculator 1.0.0"
```

**The Theme row is a picker.** It shows the current theme's human name — "Dark" or "White",
resolved through `AppThemeName.from(stored)`, never by comparing the raw string — and opens a
modal bottom sheet (`ThemeSheet`) with one row per theme (D-90). Each row previews **three
chips of that theme's real palette**, so the user recognises a theme by what it looks like
rather than by its name, and the sheet opens with the current choice check-marked. Choosing
persists the name and the whole app repaints; dismissing without choosing leaves the theme
alone. This **supersedes D-45's display-only row**, which held only while one theme existed.

**The header is the title alone** (D-71, D-75). The mockup's subtitle
("Customize your calculator experience") was struck because it restated what every row on the
screen already says and made Settings the app's only 88 px header while History and the legal
screens were 56 px.

Verified against mockup `02_25_36`: three grouped sections of icon + title + subtitle +
chevron-or-toggle rows.

### 6.4 About

```
SecondaryPageScaffold
├── SecondaryPageHeader — bordered back box | "About"
└── ListView
    ├── Hero card  (radius 20, surface)
    │   ├── AppBrandIcon 88
    │   ├── "Calculator"        screenTitleCompact
    │   ├── "Version 1.0.0"    caption
    │   └── description paragraph   body
    ├── SectionHeader "APP INFORMATION"
    │   ├── App Name    label_outline   → "Calculator"
    │   ├── Version     info_outline    → "1.0.0"
    │   └── Developer   person_outline  → "Hasan Mahadi"  (D-11)
    └── SectionHeader "MORE"
        ├── Rate App    star_outline   + subtitle
        ├── Share App   share_outlined + subtitle
        └── Terms of Service  description_outlined + subtitle
```

There is **no Privacy row on About** (D-52): it lives in Settings, and one row per screen is
enough.

**App Information rows carry trailing values** in `rowValue` rather than chevrons, because
they state a fact instead of navigating. "Hasan Mahadi" is shown verbatim (D-11).

Verified against mockup `02_30_45`: the hero card holds the 2 × 2 brand mark with two orange
and two light circles, followed by name, version, and description, then two grouped sections
of chevron rows.

**Share App** opens the system share sheet (D-53); **Rate App** raises the native in-app
review prompt, falling back to the store listing. Both sit behind service seams and **fail
softly** — an unavailable action shows a SnackBar reading "This action is unavailable right
now" rather than throwing.

---

### 6.5 Legal Documents

Two in-app screens, `/privacy` and `/terms` (D-07). No external URLs, no web view, no new
dependency: **the copy lives in a data file** (`legal_content.dart`) rather than in the widget
tree, so a developer can replace the placeholder text before release without touching
rendering code, and the claims it makes are test-gated (D-68).

```
SecondaryPageScaffold
├── SecondaryPageHeader — bordered back box | "Privacy Policy" / "Terms of Service"
└── ListView
    ├── legalHeading  18 w600 primary
    ├── body          15 w400 secondary, height 1.5
    ├── legalHeading
    └── body …
```

Rendered as ordered `(heading, body)` pairs down the page, with no card treatment — legal copy
is reading material, not a list of options, and wrapping it in surfaces would give it a
structure it does not have. The copy's own claim about stored data is rendered as a bulleted
list rather than a `Text` block, so the paragraphs above and below it read as prose.

If the copy is empty the screen falls back to an `EmptyState` rather than rendering a blank
page.

### 6.6 Decimal Places Sheet

A **modal bottom sheet**, not a pushed route.

```
showModalBottomSheet
├── top corners rounded to AppRadius.dialog (20)
├── "Decimal Places"                 legalHeading 18
├── explanatory line                 rowSubtitle 14
└── 7 options, one radio group
    ├── "No decimal places"
    ├── "1 decimal place"
    ├── "2 decimal places"          ← current selection
    ├── "3 decimal places"
    └── … up to 6
```

- **Why a sheet and not a route.** A route would also buy a back arrow and a screen title,
  which this option list does not need — and the sheet's dismissal *is* the cancel.
- Material's default sheet shape is overridden with the app's own radius; shapes come from
  `AppRadius`, not from the platform.
- The selected option is marked with a **`Icons.check`, not a radio dot**, in `accent`. The
  accent is reserved for primary actions, and the check reads unambiguously at a glance.
- The seven options are **one radio group** semantically, so a screen reader announces the
  current choice and the set together rather than as seven unrelated rows (D-59).
- Each option's label is also the Settings row's own subtitle, so the row reads "2 decimal
  places" and the sheet's matching option reads the same.

### 6.7 Component Catalog (debug only)

`/catalog`, registered behind `kDebugMode` and unreachable from the shipped navigation graph
(D-20), so **no release build contains it**. There is deliberately no button anywhere in the
app that opens it; navigate to the route by hand, or temporarily invert the router's
`initialLocation`.

Sections: colours as swatches, the type scale with samples, calculator keys in all three
variants, and rows and cards — including a live `SettingsGroup` and `ToggleRow`.

This is the place to eyeball any future change to the palette or the type scale. It is also
where two long-standing residual unknowns were resolved: the toggle OFF track (R-1, closed in
D-61) and the calculator key diameter (R-2, closed by measurement in D-60).

---

### 6.8 Secret PIN Entry Screen

**Not in any mockup.** D-13 maps all four mockups to real screens and this is not one of them, so
nothing below is a pixel match — it is assembled from the tokens §2–§4 already define.

**Purpose.** The one screen the five-second hold (D-82) opens. It asks for the four-digit code and
nothing else: **no title, no heading, no logo, and nothing that names the feature or the code.** A screen
that names itself is a screen a screenshot spoils, and a hint naming `0000` would remove the only thing this
feature is for. **Revised by D-86**, which added the prompt line and the recovery link below while keeping
both of those rules intact.

**Layout.**

- Full-page `AppColors.background`. A plain `Scaffold`, **not** `SecondaryPageScaffold` — there is
  no header here, because a header is where a title would live.
- **A prompt line**, "Enter your PIN", in `textSecondary` above the dots (**D-86**). It says what is
  wanted and nothing about what the answer is; a user who reached this screen with no idea what the dots
  are for gets nothing from the privacy alone.
- **Four dots**, centred in the upper half, on a single row with an even gap. Each is a small
  circle: `textSecondary` when empty, `textPrimary` when filled. They are **not** characters and
  **not** asterisks — the code is never rendered as text at any point (D-83).
- **No "Forgot PIN?" link.** D-86 added one below the dots; **D-88 removed it**, because with the
  30-second lockout in place it was an unlimited bypass of the lockout. Recovery is the reset in
  the Vault's own Settings page (§6.10), which can only be reached after unlocking.
- **A top-left back arrow**, the shared `AppIconButton` on the app's 24 px margin, tooltip "Back to
  calculator", going to the calculator with `go` (**D-87**). It is the only exit, and deliberately
  **not** the bottom-right FAB D-86 put here — on a screen whose one task is typing four digits, a
  FAB reads as a competing primary action. D-87 amended D-84's "no back arrow" clause for this screen
  only; the content rules (no title, no logo, no copy) still hold.
- **A keypad** below the dots, styled on §5.1's keys: `0`–`9` plus a backspace glyph in the
  bottom-right position, digit keys on `buttonDigit` and the backspace on the same fill. It is
  **not** the calculator's `CalculatorKeypad` — no operators, no `=`, no `AC`, no `.` — because a
  full arithmetic pad on this screen would suggest the screen computes something. It reuses the same
  tokens and the same `CalculatorButton` component, sized smaller (its cell is capped at the
  calculator's own measured 88 px key).

**Wrong-code feedback.** The dots clear and the indicator **shakes** once, horizontally, and a line under the
dots reads **"Wrong PIN"** in `AppColors.danger`, with the dots themselves outlined in the same colour
(**D-88**). The entry is cleared and the next attempt is accepted at once — **except** on the third wrong
code in a row, which locks the pad for **30 seconds** and replaces the line with a countdown,
"Too many attempts. Try again in 30s" (**D-88**, reversing D-85's "no lockout"). The message is there because
a pad that has stopped accepting input without saying why is indistinguishable from a broken one; the
lockout is there because 10⁴ codes are otherwise free in under a minute. Neither string ever names the code.

**Accessibility.** The dots carry a `Semantics` label reporting how many digits have been entered,
never their values; each key carries its digit as a label; the shake is `ExcludeSemantics`-free so
the shake itself announces nothing. Touch targets stay at the §4.4 floor.

---

### 6.9 Vault (the unlocked secret screen)

**Purpose.** What the correct code reveals: the hidden area's own file manager
(`SecretScreen`, **FEAT-SEC-003**). **D-84 said this page would stay blank** — one control and
nothing else, so a screenshot would give nothing away. **It has been reversed on the record:**
a file manager that lists nothing, opens nothing, and stores nothing is not a private area, it
is a wall, and a user who has already proved they know the PIN is exactly the user least served
by one. What the reversal costs is stated rather than hidden: the title "Vault" **names the
area** a screenshot could read, which withdraws §6.8's naming rule *for this screen only*. The
rule that still holds is the one about the code: `0000`, "PIN", "default", and "Secret" appear
nowhere, so a screenshot of this page hands over the *name* of a private storage area and never
the four digits that open it.

**Layout.**

```
Scaffold (background) → SafeArea → Stack
├── Column
│   ├── AppPageHeader   title "Vault"   actions: Search · Menu
│   │     (Search on → VaultSearchHeader replaces the header in place)
│   └── Expanded: ListView (secret-home-list)
│       ├── 16 px lead-in
│       ├── SettingsGroup — "Recent files"          (history glyph)
│       ├── SectionHeader "Categories"
│       │   └── _SecretCategoryCard                 (3 × 2 grid, the card recipe)
│       ├── SectionHeader "Storage"
│       │   └── SettingsGroup — "Internal storage" · "SD card"
│       ├── 24 px gap
│       └── SettingsGroup — "Recycle bin" · "Analyse storage"
└── SecretHomeButton (floating, bottom-right, 56 px)   [hidden while searching]
```

- Full-page `background`. A plain `Scaffold`, **not** `SecondaryPageScaffold` — this screen has
  no argument with the app's chrome, but it also has no ordinary secondary-page title; it carries
  the app's destination header instead.
- **The header is `AppPageHeader` titled "Vault"** (`screenTitle`), with **two** actions on the
  right: a Search button (`Icons.search`, tooltip "Search") and an overflow button
  (`Icons.more_vert`, tooltip "Menu"), both the shared bordered `AppIconButton` on the app's
  24 px margin. `AppPageHeader.title` takes the slack, so the two boxes still land on the right
  margin by construction — the same header shape every other destination uses.
- **The floating home button** (**D-86**) stays, bottom-right, 56 px (`secretHomeButton`),
  `textPrimary` behind `textOnFunction`, going to the calculator with `go`. It is a sibling of
  the scrolling column rather than of a one-button `Stack`, so the list's last card must pad
  clear of it — `secretHomeButton + homeButtonInset + md`, written from the same two tokens that
  size it.
- **Search is inline.** Tapping Search replaces `AppPageHeader` with the shared `VaultSearchHeader`
  and the body with live results: a `Photos (N)` group and a `Documents (N)` group of `SettingsRow`s,
  filtered on name, date, or (for photos) album. An empty query shows "Search your vault"; nothing
  matching shows "No results found". Closing restores the header and the home list, and the floating
  home button is hidden while the field is open.

**The Categories grid.** A card using the same recipe as `SettingsGroup` (fill, `cardBorder`,
radius `card`, `cardPadding`), holding six cells in **3 columns × 2 rows** — a
`_SecretCategoryTile` per cell: an `AppIconTile` (44) above its label (`rowSubtitle`, centred,
two lines). The six come from `vaultCategoryIds` — **Images, Videos, Audio files, Documents,
Downloads, Installation files** — each resolved to its `VaultPlace` so the tile and the page it
opens cannot disagree about the title or the glyph. Tapping a cell pushes `/secret/browse/:id`.

**The two Storage rows carry real figures.** "Internal storage" (smartphone glyph) and "SD card"
(`sd_card` glyph) read their subtitles from `vaultStorageProvider`, which asks the platform:
`'…'` while the channel answers, `'Unavailable'` if it never does, and for the SD row
`'Not inserted'` when no card is present. A figure on this screen is therefore a fact about the
phone, not a constant — and its `/secret/browse/:place` page stays a list waiting for files.

**The two bottom rows are actions, not a group** — "Recycle bin" (which wears the painted
`AppTrashIcon`, D-119) and "Analyse storage" — so they get a plain 24 px gap rather than a
`SectionHeader`.

**Every row leads somewhere.** All eleven `VaultPlace`s open a page (FEAT-SEC-007, §6.11); the
pages for *Images*, *Documents*, and *Recycle bin* are the live features of §6.12–§6.14, and the
rest honestly say they are empty.

**Tap targets.** Search toggles inline search; Menu opens `SecretMenu` (§6.10); every row pushes
`/secret/browse/:id`; the home button returns to the calculator.

---

### 6.10 Vault Settings & Change PIN

**Secret Settings.** An ordinary pushed page — `SecondaryPageScaffold` with a `SecondaryPageHeader`
carrying a back box and the title "Settings" — holding **exactly one** `SettingsGroup` with **two**
`SettingsRow`s (**D-86** added the second): a lock glyph titled "Change PIN" with a trailing chevron,
then a restart glyph titled "Reset PIN" in `accent`, also with a chevron. The main Settings screen's four
preferences are **not** duplicated here; this page exists only to change the PIN (D-84). The header is
identical to every other Settings bar in the app, which is the point: a different-looking page would
announce itself. **D-115** made it reachable through the Vault's overflow menu rather than directly:
that button now opens `SecretMenu` — the shared `MenuSlider`, sliding in from the left with a lock
avatar, the title "Vault", and one row, "Settings" — which pushes this page. Nothing about the page
changed; it gained a hop, and back from here returns to the Vault rather than to an open panel.

**Reset PIN** (**D-86**, revised by **D-88**). Opens `AppConfirmationDialog` reading "Reset PIN?" / "Your PIN will return to the
default, 0000. You will need 0000 to get back in." Confirmed, the stored code is **erased** — a `remove`,
not a write of `0000` — and the user lands on the Vault screen rather than being left on this page, whose
other row needs the PIN they have just forgotten. **D-88 removed the "Forgot PIN?" link the PIN screen
used to carry**, because with the 30-second lockout in place it was an unlimited bypass; this row is
therefore the *only* recovery, and it is reached only after unlocking. **The security cost
is on the record in D-86: anyone who reaches this page can wipe the PIN in one tap.** The row is placed
last because it is destructive and because the user browsing for "Change PIN" should not meet it first.

**Change PIN flow** (**D-85**, revised by **D-113**). Three consecutive screens in one route, each the
§6.8 entry screen with no keypad differences:

1. **Verify** — the current code, under the prompt "Enter current PIN". An incorrect code does not advance
   (D-85); it clears the entry and says **"Incorrect PIN"**.
2. **Enter** — the new four-digit code, under "Enter new PIN". This step **cannot be wrong**: any four
   digits is a legal new PIN, including the current one, so it advances on every entry and shows no error.
3. **Confirm** — the code again, under "Confirm new PIN". A mismatch clears **only this screen**, says
   **"PINs do not match"**, and re-asks step 3 with the candidate kept, so the user types their own code a
   second time rather than choosing a third (**D-113**, replacing "a mismatch returns to step 2 with the
   dots cleared").

A match persists the code at once, shows **"PIN changed successfully"** in `textSecondary` in the same
reserved status line, and returns to the Vault settings page after **1200 ms**. The pause is deliberate:
AC-021 persists the code *before* the flow ends so an interruption cannot lose it, which leaves the user
owed an answer. The pad and the back arrow are inert while the line is up, and no `Snackbar` is
introduced — the app has none, and this is the one screen that must not gain ink (D-84).

Steps 2 and 3 exist as separate screens because a mistyped new PIN that is saved immediately locks
the user out of the only page that can change it again (D-85). No step carries explanatory copy; the
three are told apart by the **prompt line** alone.

**The header control is a back arrow**, tooltip "Back", replacing `Icons.close`/"Cancel" (**D-113**), and it
steps backwards instead of abandoning the flow: step 3 returns to step 2 with the candidate kept, step 2
returns to step 1 with it discarded, step 1 leaves the flow. The system back gesture still pops the route
from any step (D-56), which is safe because **nothing unconfirmed is ever written**: until the match, the
candidate exists only in the screen's own memory.

---

### 6.11 Vault place pages (FEAT-SEC-007, D-114)

`VaultPlaceScreen` is the destination behind `/secret/browse/:place` and the one screen for all eleven
rows of §6.9. `vaultPlaces` is the **single description of every place** — `id`, `title`, glyph, and
`emptyTitle` — so the row that opens a page and the page it opens cannot disagree about either.

Three ids hand off to a live feature; every other id renders an empty page:

- `images` → the gallery (§6.12)
- `documents` → the document vault (§6.13)
- `recycle-bin` → the document recycle bin (§6.14)

Everything else is a plain `SecondaryPageScaffold` (back box + the place's title) whose body is a single
`EmptyState`: the place's own glyph at the **illustration size** (`AppIconSize.illustration`), in
`textSecondary`, above the place's own `emptyTitle` ("No images yet", "No videos yet", …). The glyph *is*
the content on these pages rather than a decoration beside some, so it is drawn at the illustration size
and `EmptyState` is told so explicitly.

**An unknown segment is not an error.** The route matches any segment, so a hand-typed or stale
`/secret/browse/anything` finds no place and falls back to the generic page — title **"Files"**, which
names no category — rather than throwing. On Android a thrown `Widget` error inside the vault is a crash
the user sees, not an error state, so the fallback is the whole point (D-114). The literal segment
`:place` itself takes the same path, which is what keeps `navigation_graph_test`'s "every registered path
resolves to a screen" honest.

### 6.12 Images gallery (FEAT-SEC-008, D-116)

`VaultImagesScreen` is **two modes in one widget**:

- **Landing** (no `albumId`) — the tabbed gallery.
- **Album details** (`albumId` set, with `albumTitle`) — a page scoped to one album; the tab strip and
  bottom bar are hidden and the header carries the album's title. The virtual ids `all`, `favorites`, and
  `recent` are accepted the same way, so the Quick Access rows open a page too.

**Tabs** are `_VaultTab` — **Pictures / Albums / Favorites / Trash** — shown as a four-way strip under
the header *and* as the bottom tab bar (`vault-bottom-tabs`, icon + label), both bound to the same
`_tab`. Both are hidden in selection, album-detail, and search modes, so each of those modes carries its
own gap under the header instead of inheriting the strip's.

- **Pictures** — the 3-column grid (`vault-images-grid`) of every visible image.
- **Albums** — the album list, led by the virtual **Quick Access** rows (All · Favorites · Recent) then
  the concrete albums.
- **Favorites** — the grid filtered to favourited images; empty state "No favorites yet".
- **Trash** — soft-deleted images, restored or deleted permanently from here.

**Grid cells** (`VaultGridTile`) carry a **circular selection check** and, when favourited, a heart badge.
Selection is a `Set<String>` of image ids and `_selecting` is derived from it being non-empty, so a screen
with nothing selected has no selection state to reset.

**The header** is `VaultGalleryHeader`. Not selecting, it is a compact row — back box, title, search, and
an overflow; selecting, it becomes a close box, a centred `"N selected"` line, and an **All / None** text
button. Tapping Search swaps the header for the shared `VaultSearchHeader` (§7) filtering on name, album,
or date.

**The bottom bar** appears in selection mode only (`_selectionBar`):

- on **Trash**: **Restore · Share · Delete** (Delete opens the permanent-delete confirmation),
- elsewhere: **Create · Share · Delete** (Create opens the add-to-album sheet; Delete moves to the
  recycle bin),
- always: **More**, which opens the overflow sheet.

**Import** runs `image_picker.pickMultiImage()` and copies the picked files into the vault, showing an
import banner while it works. The target album is the **concrete** album currently open (only when the
Albums tab holds a real id); otherwise — and always for the virtual `all`/`favorites`/`recent` rows, which
must never become a picture's `albumIds` entry — it imports into **Pictures**.

**Opening an album pushes a route.** `_openAlbum` pushes a fresh `VaultImagesScreen(albumId:, albumTitle:)`
on its own `MaterialPageRoute` rather than flipping `_albumId` in place. The inline swap left Back
pointing at the whole Gallery, so returning from an album left the vault; pushing also keeps the gallery —
its selected tab and scroll position — mounted underneath, so Back lands exactly where the album was
opened from.

### 6.13 Document vault (FEAT-SEC-009)

`VaultDocumentsScreen` mirrors the gallery's shape — **two modes in one screen**:

- **Landing** (no `initialFilter`) — a **Browse by type** card, the **All documents** collection row, and
  the **five most recent** documents, above the floating Home button.
- **Collection** (`initialFilter` set) — the same rows scoped to one family (or all), pushed from a Browse
  row or the collection row so Back returns to whatever opened it. The title is "All documents" for
  `all`, otherwise the type's label. **Only the All-documents page carries the type filter chips**; a
  single-family page does not, since every row there already belongs to its family.

The search text and the chip filter are **local to the screen**, not in a provider: they are transient,
and a data mutation must not also clear what the user typed.

Filters are `VaultDocumentFilter` — **All · PDF · Word · Text · Other** (`all` carries no type; the others
map onto `VaultDocumentType`). Each row is a document row led by its type glyph and type accent (the
PDF/Word/Text accents; `textSecondary` for Other), with an overflow offering **Open · Rename · Share ·
File info · Delete**. Delete confirms first ("Move document to recycle bin?" / "Delete N documents?").

**Import** uses `file_picker`, encrypts the file into the vault (AES-256-GCM, the key held in
`flutter_secure_storage`), and never leaves plaintext anywhere the user or another app could browse to.

### 6.14 Recycle bins and viewers

**Two recycle bins, one per medium.** Images have the **Trash** tab of §6.12; documents have
`VaultDocumentsTrashScreen`, which is where the `recycle-bin` place lands (§6.11). Both restore an entry
or delete it permanently, and both exist because deletion in a vault is **soft**: a trashed entry is
hidden from its live list and permanently removed after a **30-day** retention window.

**Two viewers, one per medium.**

- **`VaultImageViewer`** — a full-screen pager over the list it was opened from: swipe between images,
  pinch and double-tap to zoom (one `TransformationController` per page, so zoom on one image does not
  follow the user to the next), tap to hide or show the chrome, and a favourite toggle plus Share and
  Delete in the chrome.
- **`VaultDocumentViewerScreen`** — a header viewer whose body depends on the type: a PDF renders through
  `pdfx` (`VaultPdfPreview`, with a `vaultPdfViewerBuilderProvider` seam so widget tests can substitute a
  fake), plain text renders as selectable text, and Word/Other fall through to an "open in another app"
  view rather than pretending to render a format the app cannot.

---

## 7. Component Catalogue

Every shared component, exported from `lib/core/widgets/core_widgets.dart`. Screens import
that one file rather than each widget directly, so the set is discoverable from a single
place and a rename moves one import instead of six.

| Component | File | Use it for |
|-----------|------|-----------|
| `AppPageHeader` | `app_page_header.dart` | A screen that is a destination — the calculator's bar |
| `SecondaryPageHeader` | `secondary_page_header.dart` | Any pushed screen: back box, centred title, optional trailing action |
| `AppSelectionHeader` | `selection_header.dart` | The History selection bar: count, select-all, delete, cancel |
| `DragSelectRegion` / `DragSelectItem` | `drag_select.dart` | The hold-and-drag multi-select gesture and its per-item marker (D-120) — wraps any list where a selection is painted across items |
| `SecondaryPageScaffold` | `secondary_page_scaffold.dart` | The black page + safe area + header-above-body frame every pushed screen uses |
| `AppIconButton` | `app_icon_button.dart` | A header action: the bordered 48 px square |
| `AppIcon` | `app_icon.dart` | Any Material glyph, sized from a named bucket |
| `AppTrashIcon` | `app_trash_icon.dart` | The painted delete glyph — **every** delete affordance in the app (D-73, D-119) |
| `AppBackspaceIcon` | `app_backspace_icon.dart` | The painted `⌫` glyph — the calculator's backspace and the Secret keypad's (D-81) |
| `AppIconTile` | `app_icon_tile.dart` | The 44 px icon container: a settings row's leading tile and each Vault category cell (D-91) |
| `MenuSlider` | `menu_slider.dart` | The slide-in panel behind an overflow button — header, rows, footer (D-115); `MenuSliderTile` / `MenuSliderIconTile` / `MenuSliderHeader` / `MenuSliderFooter` are its parts |
| `AppBrandIcon` | `app_brand_icon.dart` | The About hero brand mark, drawn from tokens |
| `AppToggle` | `app_toggle.dart` | The switch; owns the theme's track colours |
| `ToggleRow` | `toggle_row.dart` | A `SettingsRow` whose control is a toggle — the whole row is the target |
| `SettingsRow` | `settings_row.dart` | Icon + title + subtitle + trailing control; chevron when tappable |
| `SettingsGroup` | `settings_row.dart` | The card that owns a stack of rows and their hairlines |
| `SectionHeader` | `section_header.dart` | Uppercase group label — "APPEARANCE", "PREFERENCES" |
| `HistoryDayLabel` | `history_day_label.dart` | Sentence-case day heading — "Today", "Yesterday" |
| `HistoryCard` | `history_card.dart` | One History entry; also owns `HistorySelectionCircle` |
| `EmptyState` | `empty_state.dart` | Icon + title + message (+ optional action), centred in its viewport |
| `AppDialog` | `app_dialog.dart` | `AppConfirmationDialog` — title, message, cancel / confirm |
| `CalculatorButton` | `calculator_button.dart` | One key; sizes itself from the box its parent gives it |

**Feature-local** (not in the shared library): `CalculatorKeypad`, `CalculatorDisplay`,
`ComponentCatalogScreen`; the Vault's `VaultSearchHeader`, `SecretMenu` (a configured `MenuSlider`), and
the media widgets `VaultGalleryHeader`, `VaultGridTile`, and `VaultDocumentRow`.

**`VaultSearchHeader` is one widget for four screens** (D-114) — the Vault home's inline search and the
gallery, documents, and recycle-bin searches all render this one bar rather than each drawing its own
field, so a search looks the same wherever the user is. It takes the field's `Key`, its controller, and
its hint text; the caller keeps its own query state.

**Naming note.** The old document listed `PrimaryDisplay` / `SecondaryDisplay` and called the
brand mark `AppIcon`. Both were wrong: the display widget is `CalculatorDisplay`, and `AppIcon`
is the generic glyph wrapper while the brand mark is `AppBrandIcon`.

---

## 8. Interactive States

| Element | Default | Pressed / active | Disabled |
|---------|---------|------------------|----------|
| Calculator key | Fill per §5.1 | Opacity → 0.85 over 100 ms | Opacity → 0.85, inert |
| Toggle | Track per §5.2 | Immediate position change | — |
| Settings row | `surface` via its group | Material ripple across the whole row | `onTap: null` → no ripple, no chevron |
| History card | `surface` + 1 px `cardBorder` | Ink ripple | — |
| History card, selected | `surfaceSelected` + 2 px outline | Ink ripple | — |
| Header action box | `surface` fill, 1 px `divider` border | IconButton's own feedback | `textSecondary` glyph, `onPressed: null` |
| Back / chevron | `#FFFFFF` / `textSecondary` | IconButton feedback | — |
| "Clear History" | `accent` text | Opacity | Hidden when there is nothing to clear |
| "Clear History", **held** | **Identical to Default** | **Identical to Default** | — |
| Secret dot (filled) | `textPrimary` circle | — | — |
| Secret dot (empty) | `textSecondary` circle | — | — |
| Secret key | `buttonDigit` fill, `textPrimary` label | Opacity → 0.85 over 100 ms | — |

**Two rules the disabled states follow.**

1. **A control that does nothing must not look enabled.** The History header trash paints
   `textSecondary` when there is nothing to delete. A white icon that does nothing reads as a
   working button that is merely not responding, which is worse than either an enabled button
   or a visibly inert one. The button's *behaviour* and its *paint* are stated once, in the
   screen, so they cannot disagree.
2. **A row that is not navigable must not draw a chevron.** `SettingsRow` draws one only when it
   has an `onTap`; an affordance that leads nowhere is worse than no affordance. (The Theme row
   now leads to a sheet, so it draws one — D-90.)

---

## 9. Empty, Error, and Confirmation States

### 9.1 The three History bodies

Loading, failed, and empty are **three separate branches**, not one "nothing here" case.
Collapsing them would show "No calculations yet" for a storage failure, which is a lie.

| State | Shown |
|-------|-------|
| **Loading** | Centred `CircularProgressIndicator` in `accent` |
| **Failed** | `EmptyState` — "Could not load history" + a fixed sentence + a **"Try again"** button |
| **Empty** | `EmptyState` — "No calculations yet" + "Results you calculate will appear here." |

**The error message is a fixed sentence, never the exception itself** (D-58). The presentation
layer must map errors to user-visible messages, and interpolating `'$error'` put
`Exception: ...` and platform detail in front of the user for a fully offline app whose only
useful statement is that it could not read its own storage. The retry is real rather than
decorative: the repository falls back to memory when `shared_preferences` is unavailable
(D-44), so a second attempt can genuinely succeed.

**The empty state centres in its scroll view** (D-70). A `Center` inside a vertical
`SingleChildScrollView` is handed an *unbounded* main axis, so it collapses to its child's
height and the block sticks to the top of the page. The scroll view states the viewport as a
**minimum** height for the `Center` to centre within, while content taller than the viewport
(at a large Dynamic Type factor) still overflows and scrolls.

**The History empty state's icon is 40 px, not the 44 px `hero` bucket** — that bucket is
sized for the About brand mark, and a placeholder glyph as large as the app's own logo reads
as a missing asset rather than as "nothing here yet".

### 9.2 Other states

- **Calculation error**: the display's result line shows "Error"; the expression line retains
  what was typed. No dialog — errors are inline.
- **Legal copy missing**: `EmptyState` rather than a blank page.
- **Vault states**: each Vault place draws its own `EmptyState` ("No images yet", "No videos yet", …);
  the Vault's inline search shows "Search your vault" for an empty query and "No results found"
  when nothing matches; the gallery's Favorites tab shows "No favorites yet"; and the documents
  list shows "Could not open the documents" with a real **Try again** on error, or "No documents
  found" when there are none.

### 9.3 Confirmations

Destructive actions are never immediate (D-05). The History copy sets:

| Action | Title | Message | Confirm |
|--------|-------|---------|---------|
| Clear all | "Clear history?" | "This will permanently delete all your saved calculations." | "Clear" |
| Delete N | "Delete this item?" (1) / "Delete these N items?" (N) | "This will permanently delete the selected calculation." / "…N saved calculations." | "Delete" |

**The count is worded, not just numbered.** "Delete 1 item?" reads as a miscount, and the
dialog that states *how many* is about to be deleted is the last place to get that wrong. The
singular and plural are separate strings rather than a pluralisation helper, because the
message differs in structure too, not only in number.

**The Vault adds three more destructive confirmations**, each its own copy rather than a shared
"Are you sure?": the **reset PIN** dialog of §6.10, the document vault's
**move-to-recycle-bin** dialog ("Move document to recycle bin?" for one, "Delete N documents?"
for several, §6.13), and the **permanent delete** offered from either recycle bin (§6.14). The
same rules hold throughout — the count is worded, the confirm label names the action, and
nothing destructive is immediate (D-05).

Dialog styling: `AppRadius.dialog` (20), `surface` fill, title in `rowTitle`, message in
`body`, and the confirm label in **`accent`** — the one destructive action on the page.

---

## 10. Responsive Behaviour and Accessibility

### 10.1 Layout and text scaling

- **Portrait phones only** for v1.0, locked in code (D-09).
- The keypad's cell is **derived** from the box it is given (§5.1), so it never clips on a
  small phone and never grows without limit on a large one.
- The calculator's column is **capped at 480** and centred (§4.4).
- **Dynamic Type is clamped to 1.0×–1.3× app-wide** (D-54), installed once at
  `MaterialApp.router` so one insertion reaches every screen. The floor of 1.0 keeps the
  system from ever *shrinking* the mockup-matched type scale; the ceiling keeps a fixed-format
  layout — a derived key grid, a measured margin — from being destroyed by a 2× setting.
- Everything that must not clip at the ceiling is a **minimum**, not a fixed height: the
  header bar, the settings row, the History card, the display's reserved line box.
- Titles are `maxLines: 1` and ellipsised, so a long word cannot make a header two lines tall
  and shift every screen's top spacing.
- Landscape and tablet layouts are out of scope (D-09).

### 10.2 Accessibility

The app's accessibility pass (D-59) established one rule: **an interactive row is one node,
not four.** Left alone, TalkBack walked a settings row as the icon, then the title, then the
subtitle, then the chevron — announcing decoration followed by loose text, with nothing tying
them together or saying what activating one would do.

| Rule | Implementation |
|------|----------------|
| **One node per row** | `SettingsRow` wraps its label column in `Semantics(container: true)` and excludes the visual children. The `trailing` slot stays in the tree. |
| **The switch keeps its own state** | `AppToggle` labels the `Switch` with the row title but leaves the switch's own semantics intact. Merging into the row would have left the on/off state attached to a node named after the whole row, so reaching the switch announced "Sound, Key press sound" with nothing saying which position it was in. |
| **Groups are headings** | `SectionHeader` and `HistoryDayLabel` are marked `header: true`. Uppercase styling and a 17 px grey sentence are *visual* devices — TalkBack does not infer a heading from either — so without the flag "PREFERENCES" and "Today" are announced exactly like the body text beneath them. |
| **Selection is announced** | `HistoryCard` sets `selected:` and swaps its label to "… , selected" / "… , not selected". In selection mode the row is a *choice*, and the resting label ("load this result") would describe the wrong action. |
| **Cards are buttons** | The card is one button node, because it is one action. |
| **Decorative icons are silent** | An icon beside a text label carries no `semanticLabel`; `AppIcon` wraps it in `ExcludeSemantics` when a label *is* given, so the row is not announced twice. |
| **Actions are named** | Every header action's `tooltip` is its accessible name: "Back", "Clear History", "Cancel selection", "Select all" / "Deselect all", "Delete selected". |
| **Keys are named** | `CalculatorButton` announces as a button with an explicit label, because the visible glyph is wrong for `AC`. |
| **The sheet is one group** | The seven decimal-place options are a single radio group, announced with the current choice. |
| **The PIN is never spoken** | The four dots report *how many* digits are entered and never their values, so a screen reader cannot read the code back to anyone. Each key announces its own digit as a button, and the wrong-code shake is announced as nothing at all — a spoken "incorrect" would confirm the screen is real (D-84, D-85). |
| **The Vault names each header action** | The Vault home's two header actions are named by their tooltips, "Search" and "Menu" (D-115); every row and category cell is named by its visible label. |

**Contrast.** Every text/background pair in §2 clears WCAG AA at its size: white on black,
`#949AA4` on `#101011` (~7.4:1), black on `#A2A2A8` (~7.4:1), white on `#F89508` (~2.6:1 —
used only for large/bold glyphs and for the `=` key label, where AA's large-text threshold
applies). The white theme's pairs are checked the same way against `#FEFEFE` and `#FFFFFF`.

**Touch targets.** Every tappable row is ≥ 64 px tall (D-91), every icon-only action is a 48 px box,
and every calculator cell is ≥ 44 px (§5.1).

---

## 11. Design Tokens

Single-definition-site and exported through `lib/core/design/app_tokens.dart`. **Nothing below
is typed by hand at a call site.** Full rationale for each value is in §2–§5; this section is
the reference.

```
AppColors — the dark theme's tokens, §2 (installed as `AppPalette.dark`)
  background #000000  surface #101011  surfaceRaised #151517  surfaceSoft #20232A
  cardBorder #292D35  accent #F89508  danger #FF5A5F  ruleOnPage #45454A
  buttonDigit #242428  buttonFunction #A2A2A8
  textPrimary #FFFFFF  textOnFunction #000000  textSecondary #949AA4
  divider #292D35  toggleTrackOn #F89508  toggleTrackOff #2A2A2A  toggleThumb #FFFFFF
  selectionAccent #FFFFFF  surfaceSelected #2E2E31  selectionCheck #000000
  keys: keyBorder #33333A  keyDigitTop #2B2B30  keyDigitBottom #1D1D21
        keyFunctionTop #B4B4BA  keyFunctionBottom #97979E  keyFunctionBorder #8E8E95
        keyOperatorTop #FFA62B  keyOperatorBottom #E07F00  keyOperatorBorder #D97A04
        keyShadow #1AFFFFFF (blur 10, offsetY 2), operator shadow #4DF89508 (blur 14, offsetY 3)
        highlights: digit #14FFFFFF · function #33FFFFFF · operator #40FFFFFF
  pressedOpacity 0.85

AppPalette — one value per theme, §2.4 (dark = `AppColors`; light = the white theme)
  cardShadow: none (dark) / #0D0F172A (white)     textOnAccent: #FFFFFF / #FFFFFF
  background: #000000 / #FEFEFE   surface: #101011 / #FFFFFF   accent: #F89508 / #FE651B
  textPrimary: #FFFFFF / #0C0F16  selectionAccent: #FFFFFF / #0C0F16  (full table in §2.4)

AppTypography — 19 tokens, size / weight, §3
  resultLarge 60/w600   resultMedium 44/w600   expression 20/w400
  screenTitle 32/w700  screenTitleCompact 28/w700  subtitle 16/w400
  sectionHeader 14/w600 rowTitle 17/w500  rowSubtitle 14/w400  rowValue 16/w400
  historyExpression 16/w500  historyResult 22/w600 (tabular)  historyDayLabel 17/w600
  buttonLabel 25/w500  bottomAction 17/w500  caption 12/w400  body 15/w400
  legalHeading 18/w600  selectionCount 20/w700

AppSpacing — 17, §4.1
  screenHorizontal 24  calculatorSideMargin 16  cardPadding 16  sectionGap 32
  headerTopGap 24  bottomSafe 24  calculatorDisplayGap 24
  xl 24  lg 16  md 12  sm 8
  dividerIndent 72  dividerEndIndent 16
  historyCardGap 8  historyCardHorizontal 18  historyCardVertical 17  historyGroupGap 24

AppRadius — 6, §4.2
  card 14  historyCard 12  tile 12  iconButton 12  dialog 20  calculatorKey 26

AppSizes — 13, §4.4
  headerHeight 56 (min)  rowMinHeight 64 (min)  rowIcon 22  iconTouchTarget 48
  brandIcon 88  historyCardMinHeight 88 (min)  historyMetaGlyph 17  historyMetaGap 5
  calculatorPanelMaxWidth 480  calculatorHeaderAction 56  calculatorHeaderGlyphRatio 26/56
  calculatorBackspaceRow 48  secretHomeButton 56

Feature-local — calculator_keypad.dart
  keyGap 16  minTouchTarget 44  maxCellSize 160  columnCount 4  rowCount 5
  fallback cell 88 (CalculatorButton, unbounded boxes only)
  selectionCircle 28  selectionBorderWidth 2  (HistoryCard, §6.2.1)
  compactResultLength 10  (CalculatorDisplay, §3.2)
```

---

## 12. Mockup Deltas and Residual Unknowns

### 12.1 Measured geometry (Phase 9)

These supersede the prose ranges this document used to carry, which were written from the
images by eye and, in the margin's case, simply wrong.

| Property | Old value | Measured | Implemented |
|----------|-----------|----------|-------------|
| Screen margin | "~16–20 pt" | **24–25 px** (consistent across all three list screens) | `screenHorizontal = 24` |
| Calculator key diameter | "~85–95 px" | **86.5–87.5 px** (five key rows) | 88 px, derived |
| Key gap, horizontal | "consistent gaps" | 13 px | `keyGap = 16` (D-110) |
| Key gap, vertical | "consistent gaps" | 15 px | `keyGap = 16` (D-110) |
| Toggle track | not stated | 44 × 25.5 px (ON only) | Material `Switch` |
| Palette | §2 | `#000000`, `#242428`, `#F89508` all confirmed | unchanged as the dark theme (D-03) |

**R-2 was a symptom of the margin error.** Under D-27 the keypad derives its cells from the
width left after the margins, so `(442 − 2·margin − 3·14) / 4` gives 90.0 px at margin 20 and
88.0 px at margin 24. Measuring the keys alone could only ever bracket a range.

### 12.2 Where the shipped app deliberately departs from the mockups

The mockups are the source of the *visual language*; they are not a pixel-level contract. The
following departures are intentional and were each recorded as a decision.

| # | Departure | Why | Ref |
|---|-----------|-----|-----|
| 1 | **History was rebuilt** — larger cards, day labels, 8 px gaps, 88 px cards | The mockup's History had cards too small to read as items you act on. D-72 gave it its own visual identity; D-73 pulled it back to the app's 24 px margin and its documented type bands, which is what leaves room for seven entries on a 360 dp phone instead of three. | D-72, D-73, D-77 |
| 2 | **Headers are bordered boxes, not bare glyphs** | A bare glyph three pixels off the line every card is built on reads as a squashed layout; a box whose *edge* rides the margin reads as a deliberate object. | D-74 |
| 3 | **No header subtitle anywhere** | Settings' subtitle restated what every row already says. The parameter was removed so no screen can reintroduce a two-line banner. | D-71, D-75 |
| 4 | **Selection is white, not orange** | Orange is the app's primary-*action* colour. Selection is a mode; painting three rows orange would claim three button presses. | D-76 |
| 5 | **Decimal Places is a bottom sheet, not a route** | A route would also buy a back arrow and a title this option list does not need. | — |
| 6 | **History cards are 12 px, one step tighter than grouped cards** | D-77 first made them equal (14) to a Settings group; D-93 corrected *which* Ethar card a History entry tracks — the task card (`radius: 12`), not the editor option row — so it now differs from `card` (14) on purpose. | D-77, D-93 |
| 7 | **The Theme row is a picker, not a label** | D-45's display-only row held only while one theme existed. With a second theme (D-90) the row opens a sheet of live palette swatches; a row that looks navigable and does nothing is the failure mode §8 forbids, and it is now the *wrong* row for that failure. | D-45 (superseded), D-90 |
| 8 | **Calculator column is capped at 480 px** | Without it a resizable window would render 268 px keys. | D-69 |
| 9 | **The whole Secret Mode area has no mockup at all** | Not a departure from a mockup so much as an absence of one: D-13 maps all four mockups to real screens and none of them shows a PIN screen, a Vault, or a settings page. §6.8–§6.14 are therefore specified from the app's own tokens and components, not from pixels. | D-82, D-83 |
| 10 | **The Vault is a live file manager, not a blank screen** | D-84 said the unlocked page would stay blank — the safest possible screenshot. It is reversed on the record: a vault that lists nothing is a wall, and the user who proved they know the PIN is the one it least serves. The title "Vault" now names the area; the PIN's four digits, "PIN", "default", and "Secret" still appear nowhere. | D-84 (reversed) |
| 11 | **A second, white theme exists** | There is no white mockup. The theme is the sibling Ethar app's palette (D-90), so the two apps read as one family, and every colour is read through `AppPalette` so the two never drift onto one side only. | D-90 |
| 12 | **Calculator keys are rounded squares, not circles** | D-29 drew every key as a circle; D-114 replaced the circles with an `AppRadius.calculatorKey` (26) rounded square, and the wide `0` reuses that radius as a rounded rectangle rather than a stadium. | D-29 (reversed), D-114 |

### 12.3 Residual unknowns

| # | Unknown | Status |
|---|---------|--------|
| R-1 | Toggle **OFF** track colour — no mockup shows a toggle in the OFF state | **Closed as chosen, not measured** (D-61). All three mockup toggles are ON (44 × 25.5 px, `#F89508`), so no measurement is possible. `toggleTrackOff` = `#2A2A2A`. This is the single edit needed if a designer hand-off arrives. |
| R-2 | Exact calculator **key diameter** — pixel scans gave ~85–95 logical px | **Closed at 88 px** on the 442 × 890 canvas (D-60). The key rows measure 86.5–87.5 logical px; the excess came from the screen margin, not the keys. |

### 12.4 Standing notes, not blockers

- **Pressed / hover states** are not shown in the mockups → standard platform feedback.
- **No light theme mockup exists** → the white theme comes from the sibling Ethar app's palette, not from a measurement (D-90).
- **Surface spread** of 3 units across the mockups → generation noise, not a palette split.
- **Legal copy is placeholder text** a developer must replace before release (D-07), and its
  claims are test-gated (D-68).
- **The Play Store URL's domain is a placeholder** until the listing is confirmed.

---

**This document is the authoritative visual specification, and it is generated from the code.**
If a value here disagrees with `lib/`, the code is right and this document is stale — fix it
here in the same change. A design system that drifts from its implementation is worse than one
that admits it is a description of what was built.

**End of Design Specification**
