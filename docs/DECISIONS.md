# Decision Record
## Calculator App — Phase 1 Requirements & Design Finalization

**Document Status:** Frozen for v1.0 implementation; extended during Phases 2–7  
**Phase:** 1 (Requirements & Design Finalization) — decisions D-19 … D-23 added in Phase 2, D-24 … D-29 in Phase 3, D-30 … D-34 in Phase 4, D-35 … D-40 in Phase 5, D-41 … D-48 in Phase 6, D-49 … D-53 in Phase 7, D-62 … D-68 in Phase 10, D-69 in the calculator layout pass, D-71 in the settings header pass, D-74 in the header port  
**Last Updated:** 2026-10-01  
**Purpose:** Single authoritative source for every question Phase 1 closed. All other
documents cite these `D-xx` IDs instead of restating decisions. Later phases append
new decisions here rather than editing the originals.

---

## 1. How Mockups Were Measured

The four mockup PNGs in `Mockups/` are the primary source of truth. Because the
original text estimates were approximate, Phase 1 extracted the real values
programmatically by sampling pixels (histograms, region probes, and edge scans on
the 2x images). Findings that changed the specification:

- **Mockup-to-screen mapping was wrong in every document.** The files are named by
  generation timestamp, not by screen. See [D-13](#d-13-mockup-to-screen-mapping).
- **The accent palette is correct but the surface colors were not.** Function keys
  in particular are far lighter than estimated. See [D-03](#d-03-palette-source-of-truth).
- Mockups are **884x1779 px at 2x** (logical 442x890), portrait.

Two values could not be recovered from the mockups and remain open for Phase 9
visual comparison. They are listed in [Section 4](#4-residual-unknowns).

---

## 2. Technology Decisions

### D-01 — Target Platform and Stack
**Decision:** Flutter 3.47.2 (stable) / Dart 3.13.2, with Riverpod 2.6.1 for
state, go_router ^14.8.1 for navigation, and shared_preferences ^2.5.3 for
persistence. Additionally add `in_app_review` and `share_plus` (new
dependencies, both required by About actions — see [D-08](#d-08-rate-app-behavior)).

**Rationale:** These four packages are the standard Flutter stack for a small
offline app: Riverpod for state, `go_router` for a flat six-route graph, and
`shared_preferences` for key-value persistence. Pinning exact versions (rather
than carets) keeps builds reproducible; `in_app_review` and `share_plus` are
added only because the About actions require them (D-08). No heavier package is
warranted at this feature count, so the dependency list stays minimal.

**Closes:** `struction.md` §15 items 1–4.

### D-02 — History Persistence
**Decision:** Store history in `shared_preferences` as a single key holding a
JSON-encoded list, capped at 200 entries (oldest evicted first).

**Rationale:** History is a small, flat, append-only list. A relational database
adds a dependency and native setup for no benefit at this volume. The controller
follows a load-on-start / write-on-change pattern, including graceful degradation
to in-memory defaults when the platform channel is unavailable (so unit tests
pass without mocking).

**Closes:** `struction.md` §15 item 3.

### D-03 — Palette Source of Truth
**Decision:** Colors measured from the mockup pixels are authoritative. The
approximate values previously in `desing.md` §2 are superseded.

**Rationale:** The original estimates were explicitly flagged as visual guesses
(`desing.md:29`, `desing.md:293`). Measuring removes the guesswork and lets Phase 9
do a meaningful pixel diff instead of reconciling two sources of truth.

**Corrected values:**

| Role                       | Superseded | **Authoritative** |
|----------------------------|------------|-------------------|
| Background (App)           | `#000000`  | `#000000`         |
| Surface / History card     | `#1C1C1E`  | `#101011`         |
| Primary Accent (Orange)    | `#FF9F0A`  | `#F89508`         |
| Digit / decimal key        | `#2C2C2E`  | `#1E1E1E`         |
| Function key (AC +/- %)    | `#3A3A3C`  | `#949494`         |
| Primary Text               | `#FFFFFF`  | `#FFFFFF`         |
| Secondary Text             | `#8E8E93`  | `#949AA4`         |
| Toggle track (ON)          | `#FF9F0A`  | `#F89508`         |
| Toggle thumb               | `#FFFFFF`  | `#FFFFFF`         |

The largest correction is the function keys: they are a **light mid-gray with
near-black labels**, not a medium gray. This inverts the contrast relationship a
reader would assume from the old estimates (light function keys on near-black
digits, rather than subtly lighter medium-gray keys).

**Closes:** `desing.md` §12.

---

## 3. Product and Scope Decisions

### D-04 — Project Root and Documentation Layout
**Decision:** `Apps/Calculator` is the Flutter project root. The five Markdown
documents live in `Apps/Calculator/docs/`. The `Mockups/` directory stays at the
project root.

**Rationale:** `struction.md` §14 already specified `docs/` as the home for this
package. Keeping the spec inside the repo it governs prevents the two drifting
apart. Mockups remain at the root because they are design *source assets*, not
documentation prose.

**Closes:** `struction.md` §14.

### D-05 — Confirm Before Clearing History
**Decision:** Tapping the trash icon or "Clear History" shows a confirmation
dialog. The action does not proceed until confirmed.

**Rationale:** Clearing history is destructive and irreversible with no undo.
`phases.md:39` and `feature.md:232` both identified this as needing a decision
and recommended the guard. Confirmed.

**Effect:** Promoted from Should Have to **Must Have**.

**Closes:** `prd.md` §14 item 5.

### D-06 — Percent Semantics
**Decision:** `%` divides the current value by 100 (`50 %` -> `0.5`).

**Rationale:** Simple and predictable. `%` divides the current value by 100 and
never reinterprets it against the accumulator, which matches the iOS, Android,
and Windows calculators and avoids platform-dependent contextual variants (e.g.
iOS treating a trailing `%` as a share of the accumulator). The engine's
`_percent` handler implements exactly this, per
[D-17](#d-17-operator-precedence--evaluation-model).

**Closes:** `prd.md` §14 item 1 (partial), `feature.md` FEAT-CALC-005 note,
`prd.md:152` uncertainty.

### D-07 — Privacy Policy and Terms of Service
**Decision:** Both are **in-app text screens** rendering placeholder legal copy
that the developer replaces with final text before release. No external URLs, no
web view, no new dependency.

**Rationale:** `prd.md:249` left the destination open and `prd.md:242` noted the
content was never provided. An in-app page ships something functional in v1.0
without inventing URLs that do not exist yet, and avoids a dependency.

**Effect:** New feature **FEAT-LEGAL-001** added to `feature.md`.

**Superseded in part by D-68 (Phase 10).** The destination decision stands and is
unchanged: in-app text screens, no external URL, no web view, no new dependency.
The "placeholder copy" premise does not. The text is now final and lives in
`lib/features/legal/data/legal_content.dart` as structured data with its
platform claims test-gated. The single remaining item is the contact email,
which is a tracked placeholder Play will not accept; see `store/README.md`.

**Closes:** `prd.md` §14 item 3, `prd.md` §14 item 2 (destination part).

### D-08 — Rate App Behavior
**Decision:** Use the `in_app_review` plugin to raise the native in-app review
prompt, falling back to opening the platform store listing when the prompt is
unavailable (the standard, store-policy-compliant approach).

**Rationale:** The native review prompt is the expected and compliant path on both
Play Store and the App Store. `prd.md:250` left this open.

**Closes:** `prd.md` §14 item 4.

### D-09 — Orientation and Form-Factor Scope
**Decision:** v1.0 targets **portrait phones only**. The orientation is locked in
code. The button grid scales proportionally so smaller and larger phones both keep
adequate touch targets, and the result text auto-shrinks on very long values.

**Rationale:** All four mockups are portrait phone captures. Supporting landscape
or tablet without design references expands the Phase 9 comparison surface for no
stated benefit. `desing.md:265` flagged landscape as "not required unless
confirmed" — now confirmed as out of scope.

**Closes:** `desing.md` §10, `struction.md` §15 item 5, `prd.md` NFR-007.

### D-10 — History Screen Header
**Decision:** History uses a back arrow (left), the title "History", and a trash
icon (right).

**Rationale:** Matches `desing.md` §6.2 and keeps one shared `AppHeader` component
across all three secondary screens rather than adding a compact variant.

**Closes:** `desing.md` §6.2, `prd.md` §10.

### D-11 — Developer Name
**Decision:** The About screen shows **"Hasan Mahadi"**.

**Rationale:** The About screen is a long-lived, public-facing string, so the
full name is used rather than the "Mahadi" abbreviation at `prd.md:243`. The
value is centralized in `AppInfo.developer` so a future rebranding changes one
line.

**Closes:** `prd.md` §14 assumption 5, `feature.md` FEAT-ABOUT-002.

### D-12 — Application Identity
**Decision:** pubspec package name `calculator`; Android application ID and iOS
bundle ID `com.hasanmahadi.calculator`; version `1.0.0+1`.

**Rationale:** Version matches `prd.md:134` (About must display `1.0.0`) and the
identifier is derived from the developer name chosen in D-11, keeping the About
screen and the store listing in agreement.

**Closes:** `struction.md` §15 item 1.

### D-13 — Mockup-to-Screen Mapping
**Decision:** Correct the mapping used throughout the documentation. The mockup
filenames encode generation time, not screen identity.

| File                              | Screen               |
|-----------------------------------|----------------------|
| `ChatGPT Image Sep 28, 2026, 02_17_57 AM.png` | **History**    |
| `ChatGPT Image Sep 28, 2026, 02_22_43 AM.png` | **Main Calculator** |
| `ChatGPT Image Sep 28, 2026, 02_25_36 AM.png` | **Settings**   |
| `ChatGPT Image Sep 28, 2026, 02_30_45 AM.png` | **About**       |

**Rationale:** Established by rendering each mockup's luminance structure. The
`02_22_43` capture is unambiguously the calculator (5x4 grid of circular keys with
an orange operator column and a wide `0`). The `02_17_57` capture is a grouped list
of cards with an orange bottom action ("Clear History"). `02_25_36` shows settings
rows with orange toggles. `02_30_45` shows an About hero card containing a 2x2
app icon.

This also confirms the **keypad layout** in `desing.md` §6.1 is accurate as
written, including the wide `0` key and the orange `÷ × − + =` column.

**Closes:** `prd.md` §1, `desing.md` §6.

### D-14 — Changing Decimal Places Mid-Calculation
**Decision:** The decimal-places setting affects **result formatting only**. Changing
it re-renders the current result with the new precision, and does not rewrite or
invalidate an expression the user is still typing. The next evaluated result uses
the new precision.

**Rationale:** The in-flight expression is held as a string of entered tokens, not
as a formatted number, so a formatting change cannot corrupt it. This keeps the
setting orthogonal to calculator state and makes the behavior obvious to the user.

**Closes:** `prd.md` §14 item 1 (behavior part). The unspecified half — whether
trailing zeros are padded — is closed separately by
[D-21](#d-21--decimal-places-controls-rounding-not-padding).

### D-15 — Individual History Item Deletion
**Decision:** **Deferred past v1.0.** v1.0 supports bulk clear only.

**Rationale:** `prd.md:248` asked whether items can be deleted individually; only
bulk clear appears in the mockup. `feature.md:481` already classified individual
deletion as Could Have. Keeping it out of v1.0 avoids inventing an interaction the
design does not specify.

**Closes:** `prd.md` §14 item 2.

### D-16 — Key-Press Feedback Dependencies
**Decision:** Sound and vibration use only Flutter's built-in `services` APIs —
`HapticFeedback.selectionClick()` and `SystemSound.play(SystemSoundType.click)`.
**No new packages.**

**Rationale:** Both are part of Flutter's `services` library and require no
package, so the behavior is available with zero dependency cost. Sound is a
system click rather than a bundled asset, which is all the mockups imply, and
vibration uses the platform's selection-click tick.

**Closes:** `feature.md` FEAT-FEEDBACK-001 dependency question.

### D-17 — Operator Precedence and Evaluation Model
**Decision:** Expressions evaluate **strictly left-to-right, evaluating each
operator as it is pressed**, with no `×÷` precedence over `+−`. So `2 + 3 × 4`
evaluates to `20`, not `14`.

**Rationale:** This is the behavior of the iOS, Android, and Windows calculators —
what users of a phone calculator expect. It also removes the need for a parser:
each operator is applied to the running accumulator as it is pressed, so the
shunting-yard / recursive-descent machinery in `struction.md` §6 never has to be
built or tested. The engine (`lib/features/calculator/domain/calculator_engine.dart`)
implements the key enum, `CalculatorState` shape, error handling, and the
`formatNumber` helper against this model.

This **supersedes** the precedence requirement previously stated at
`feature.md:81` and `struction.md:99`; those sections are corrected to match.

**Closes:** The precedence conflict between `feature.md` §FEAT-CALC-002 and
`struction.md` §5–§6.

### D-18 — Thousands Separators
**Decision:** Results and history results are rendered with **thousands separators
by default** (`1,000`; `1,234,567.89`), with no user setting to disable it in v1.0.
Implemented by composing the engine's `formatNumber` with a `groupThousands` helper.

**Rationale:** The specification calls for separators in two places
(`feature.md` FEAT-CALC-001 and `desing.md` §3), but the engine's `formatNumber`
trims trailing zeros and does **not** insert separators. Without this decision the
result rendering would silently drop a specified behavior. The Settings screen
has no row for this, so it is fixed behavior rather than a preference.

It therefore requires a `groupThousands` helper alongside the engine formatter
in `lib/core/utils/format.dart` (D-18), plus a unit test locking in its behavior.

**Closes:** Discrepancy between `feature.md` FEAT-CALC-001 / `desing.md` §3 and the
engine's `formatNumber`.

### D-19 — No Backspace Key in the Engine
**Decision:** The `backspace` key is **not part of** `CalculatorKey`, and the
engine exposes no `_backspace()` handler. v1.0 supports AC only, exactly as the
specification requires.

**Rationale:** `desing.md:181` and `prd.md:297` both state explicitly that the
keypad has **no backspace key** and that only AC is shown, and D-13 confirmed the
keypad layout in `desing.md` §6.1 is accurate as written. `feature.md` lists no
such interaction either.

Including an unreachable enum value would leave a key in the domain model that
no screen can produce, inviting a future developer to wire up an interaction the
design explicitly rejects. The engine is therefore built without it from the
start.

**Closes:** Conflict between the keypad specification at `desing.md:181` /
`prd.md:297` and any engine surface for a backspace key.

### D-20 — Screen Entry Points and Navigation Graph
**Decision:** The Calculator's top bar carries exactly two entry points: a **hamburger
on the left that opens Settings**, and a **history clock on the right that opens
History**. About, Privacy Policy, and Terms of Service are reached **only from the
Settings screen**. There is no drawer and no bottom sheet.

**Rationale:** `prd.md:174` and `prd.md:236` describe the hamburger as a direct link
to Settings, and `feature.md:504` likewise records "Calculator → Settings (hamburger
menu — inferred)". `struction.md` §7's navigation map agrees, placing About, Privacy,
and Terms beneath Settings rather than beneath the root. A drawer or sheet would
invent an interaction no mockup specifies and would make the Phase 9 pixel comparison
impossible for that element.

**Closes:** Ambiguity between `prd.md:174` / `feature.md:504` (hamburger → Settings)
and a reading of `struction.md` §7 in which About hangs off the root route.

**Amended by D-117:** the Settings entry point's glyph is now the gear button, not
the hamburger; the direct-push behaviour, the tooltip, and this decision's
About / Privacy / Terms single-path rule are unchanged.

### D-21 — Decimal Places Controls Rounding, Not Padding
**Decision:** The `decimalPlaces` setting sets the **rounding precision** of a computed
result and never pads the output. `2 + 2` displays `4`, not `4.00`; `1 ÷ 3` with the
default of 2 displays `0.33`.

**Rationale:** Padding would contradict the engine's `formatNumber`, which trims
trailing zeros, and would not match the iOS, Android, or Windows calculators. It
would also make `1.50` and `1.5` look like different results to the user.
Rounding-only keeps the engine's behaviour intact and makes the setting read as
"how precise is the answer".

**Closes:** Unspecified interaction between D-14 (`decimalPlaces`) and the
trailing-zero trimming in the engine's `formatNumber`.

### D-22 — Android-Only Target for v1.0
**Decision:** Only the `android/` platform folder is generated and maintained for
v1.0. iOS may be added in Phase 10 if a second store release is wanted.

**Rationale:** Keeps the release plan (D-08 Play Store fallback) single-platform and
the build surface small for v1.0. `in_app_review` implements only Android and iOS,
so supporting more platforms would require guarding the Rate App call anyway.

**Closes:** Nothing outstanding; records the platform scope implied by D-01 and D-08.

### D-23 — `url_launcher` Present as a Transitive Dependency
**Decision:** `url_launcher` appears in the resolved dependency graph purely as a
transitive dependency of `share_plus` (and of `in_app_review`'s store fallback). It is
**not** a direct dependency and is never imported by application code.

**Rationale:** `struction.md` §15 lists "no URL launcher (D-07)" among the
deliberately-absent packages, which remains true of the app's own code. The legal
pages are still local text with no web view, so D-07 is unaffected. This entry exists
so a future reviewer reading `pubspec.lock` does not mistake the transitive package
for a specification violation.

**Closes:** Apparent contradiction between `struction.md` §15 and `pubspec.lock`.

---

## 3b. Design System Decisions (Phase 3)

### D-24 — Number Formatter Lives in `core`, Not the Calculator Feature
**Decision:** `formatResult` is defined in `lib/core/utils/format.dart` and
imports the engine's `formatNumber` from
`lib/features/calculator/domain/calculator_engine.dart`. This is the **only**
`core → features` import in the tree, and it is deliberate.

**Rationale:** `struction.md` §11 places the number formatter in
`core/utils/format.dart` and requires it to compose `groupThousands` with
`formatNumber` (D-18). Two consumers need it — the calculator display and, from
Phase 5, the history cards — and neither owns the other. Keeping it in
`core/utils` is therefore the only placement that does not force one feature to
export a formatter to the other.

The alternative was moving `formatNumber` itself down into `core/utils`, which
would have kept the dependency graph strictly layered at the cost of moving code
Phase 2 had already shipped and tested, and of relocating a function
`phases.md` §Phase 4 cites by name as part of the engine. Not worth it for one
import, which is why this is recorded as a known exception rather than silently
absorbed. The engine itself remains free of Flutter and of `core`.

**Closes:** The layering tension between `struction.md` §11 and §14.

### D-25 — The Component Catalog Is a Debug-Only Route
**Decision:** The design-system catalog is a screen at `/catalog`, registered in
`app_router.dart` **only under `kDebugMode`**. No link to it exists anywhere in
the UI.

**Rationale:** `phases.md` §Phase 3 calls a catalog "optional but recommended",
and the acceptance criterion is that components match the mockups. That has to be
eyeballed, so a browsable screen is the honest way to do it. Guarding it with
`kDebugMode` and adding no entry point means a release build contains neither the
route nor the screen, and the shipped navigation graph stays exactly as D-20
defines it — no invented drawer, sheet, or hidden route for Phase 9 to account
for during the pixel comparison.

**Closes:** The "optional but recommended" catalog deliverable in `phases.md`
§Phase 3.

### D-26 — Unmeasured Colour Tokens Are Chosen, Not Guessed Silently
**Decision:** Two colours the mockups do not resolve now have explicit,
individually named token values: `AppColors.divider` (`#1A1A1B`) and
`AppColors.toggleTrackOff` (`#2A2A2A`).

**Rationale:** `desing.md` §2 describes the divider as a "subtle dark line" with
no value, and R-1 has no mockup evidence at all. Both still have to render
*something* in Phase 3. Naming them as tokens rather than inlining hexes at call
sites means the choice is visible, documented, and correctable in one edit, and
`design_system_test.dart` can assert the relationships that must hold (the OFF
track must read as "off", not as the accent) even though the exact value is
provisional.

The platform default was rejected for the OFF track specifically: Material 3
renders a light gray track that would break the black-and-gray palette the
mockups establish.

**Closes:** Part of R-1. Phase 9 still confirms both values visually.

### D-27 — Calculator Keys Are Sized by Their Container, Not by a Token
**Decision:** `CalculatorButton` takes its size from the box its parent gives it
(the smaller of available width and height) and exposes no diameter token. A
midpoint fallback of 88px exists solely for an unbounded box.

**Rationale:** Phase 1 could only measure a *range* of 85–95 logical px (R-2), so
any fixed value committed now would be a guess dressed as a decision, and it
would break the "must not clip on small or large phones" requirement of D-09.
Sizing from constraints makes the grid the single place that determines key
diameter, which is exactly what Phase 9 needs to measure. It also makes the
component reusable outside the calculator without inheriting a magic number.

**Closes:** R-2 gains a sizing model; the value itself remains a Phase 9 item.

### D-28 — `CalculatorButton` Takes a Variant, Not a `CalculatorKey`
**Decision:** `CalculatorButton` accepts a `CalculatorButtonVariant`
(`digit` / `operator` / `function`), never a `CalculatorKey`. The mapping from
key to variant lives in the calculator feature's keypad grid in Phase 4.

**Rationale:** A colour pair belongs to the design system, so the design system
should not need to know the feature's domain enum. Wiring `CalculatorKey` into
`core/widgets` would create a second `core → features` import on top of D-24 and
would make a purely visual component untestable without the engine. The keypad
owns the layout, so it is the natural owner of the key→variant mapping too.

**Closes:** Keeps D-24 as the only `core → features` import in the tree.

### D-29 — The Wide `0` Key Is a Stadium
**Decision:** The `0` key spans two grid columns with fully rounded ends
(a stadium), not a circle and not a plain rectangle.

**Rationale:** `desing.md` §5.1 specifies the keys as circles *and* specifies
that `0` "spans 2 columns", which cannot both hold — a circle cannot be twice as
wide as it is tall. Every platform calculator resolves the conflict the same way,
with a pill. A stadium satisfies both requirements at once: it is as tall as its
neighbours and round at both ends.

**Closes:** The internal contradiction in `desing.md` §5.1. Phase 9 confirms the
rendering against mockup `02_22_43`.

### D-30 — The Engine Owns Numbers, the Display Owns Formatting
**Decision:** `CalculatorState` stores numbers and the entry string only. The
thousands separator (D-18), rounding to `decimalPlaces` (D-14/D-21), and the
primary line's text styling are applied in the presentation layer, by
`resolveDisplay`. `CalculatorDisplay` reads `decimalPlaces` from the settings
provider itself rather than receiving it through the controller.

**Rationale:** D-14 requires that changing `decimalPlaces` mid-calculation changes
what is *shown* without changing what is *stored*. A single `CopyWith` on an
immutable state would otherwise have to be reasoned about for every setting.
Keeping formatting at the edge makes the engine trivially testable with plain
numbers, and it means the engine needs no `TextStyle`, no `intl`, and no settings
dependency. It also settles a boundary question the phase plan left open: the
controller translates keys, the display translates state into pixels.

**Closes:** "Wire the display through the thousands-separator formatter" in
`phases.md` §Phase 4. A consequence recorded here: a *typed* entry is grouped but
never rounded, because rounding digits the user just pressed would rewrite their
input. Only computed results round.

### D-31 — `2 + =` Repeats the Pending Operator
**Decision:** With `2 +` on screen, pressing `=` resolves `2 + 2 = 4`, and pressing
`=` again folds the accumulator with the remembered operator. The alternative
(entering a `2 + 0` and waiting for an operand) was rejected.

**Rationale:** The first option leaves the `=` key looking dead, which is the
specific complaint the spec raised about iOS-style immediate execution. The second
matches the Android calculator users are comparing this app against. It is also
the smallest state: the operator is already stored for the next operand, so
repeating it needs no new field and no new mode.

**Closes:** FEAT-CALC-002 / D-17's unanswered edge case, where the operator key
immediately before `=` was unspecified.

### D-32 — Auto-Shrink Thresholds for the Primary Line
**Decision:** The result line uses `resultLarge` (60 pt) until the rendered string
exceeds 10 characters, drops to `resultMedium` (44 pt) above that, and is wrapped
in a `FittedBox(fit: scaleDown)` so anything longer still shrinks to fit the width
rather than clipping. `desing.md` §10 required the behaviour but not the numbers;
10 was chosen as roughly the widest 60 pt string that fits the 402 px content width
after grouping.

**Rationale:** A result the user cannot read is a functional failure, not a visual
one, so ellipsis was rejected — truncating a number misreports it. The display's
reserved height assumes the *large* size, so the smaller step and the fitted box
both only ever reduce the line's height or width.

### D-33 — Entry Limits Live in the Engine
**Decision:** The 15-digit entry cap, leading-zero replacement ("`0` then `5` gives
`5`"), and one-decimal-point-per-number are implemented in the engine as
`maxEntryDigits` plus the digit and dot handlers.

**Rationale:** These constrain what the user can *enter*, not how it looks, so they
are input validation rather than presentation. Keeping them in the engine means the
UI cannot bypass them by constructing a state directly, and they are covered by unit
tests rather than only by widget tests.

### D-34 — `FeedbackService` Takes Flags, Not the Provider
**Decision:** `FeedbackService` exposes `play(sound: bool, haptics: bool)` and has
no Riverpod dependency. The calculator controller reads the two settings and passes
them in. Phase 4's `settingsProvider` returns the documented defaults
synchronously; Phase 6 replaces it with the real repository behind the same
interface, so no controller or display code changes.

**Rationale:** D-16 fixes the implementation to `HapticFeedback` / `SystemSound`
with no new package, and D-02 puts persistence in Phase 6. A service that read the
provider itself would have hard-wired the settings model into a `core` class and
made the feedback path untestable without a provider override. Keeping the provider
in `lib/features/settings/data/` also avoids a second `core → features` import,
preserving D-24 as the only one.

**Closes:** "Add key-press sound and haptics" in `phases.md` §Phase 4, and the
sequencing question of whether the calculator would wait on settings persistence.

---

> **Note on D-35 … D-40.** The six sections below were reconstructed in Phase 10.
> The decision index and source comments have cited D-35 through D-40 since Phase 5,
> but their write-ups were missing from this file's body — the text jumped straight
> from D-34 to D-41. Each entry below was rebuilt by reading the code it governs, so
> the *decisions* and their *consequences* are verified against the implementation;
> the wording is Phase 10's, not the original author's. Treat them as accurate
> records of what the code does, not as a verbatim record of what was said at the time.

### D-35 — `CalculatorState` Exposes `justEvaluated`
**Decision:** The engine's immutable snapshot carries a `justEvaluated` boolean, promoted from the engine's private `_justEvaluated` field, and reset by every key press except `=`.

**Rationale:** History needs to know that a press actually *produced a result*, not merely that a key was hit. Without a signal on the snapshot, the controller would have to diff the display before and after every press — reconstructing a fact the engine already knows exactly, and getting it wrong for the cases where the two differ: a `=` with nothing to compute, and an operator press that collapses the display to `<value> +` without evaluating.

Putting it on the state rather than in the engine's return type keeps the engine's public surface a single immutable value, which is what D-35's siblings rely on: the controller reads one object per press and the notifier's `==` (used for rebuild suppression) accounts for the flag, so a press that evaluates produces a genuinely different state and rebuilds, while a press that does not is correctly seen as a no-op.

The flag is set in exactly one place, in `_equals()`, and that single write site is what makes D-36's follow-on rule expressible: `=` is the only press that records.

### D-36 — `2 + =` Is Recorded as a Completed Calculation
**Decision:** Pressing `2`, `+`, `=` evaluates to `4` and records a history entry, because D-31 makes a trailing operator repeat the running value — which is a real evaluation, not a malformed expression.

**Rationale:** `feature.md` said a malformed expression should show `Error`, and the intuitive reading of `2 + =` is that it is malformed. It is not: D-31 decided to follow the platform convention (iOS, Android, and Windows calculators all treat a trailing operator as "repeat the running value") precisely because users expect it, so `2 + =` reaches a value the same way any other calculation does.

That has a consequence worth stating explicitly, because it is the kind of thing that gets "fixed" later by someone who reads only `feature.md`: if history recorded only expressions with two operands, this one would vanish from the list while still having computed, and a user who typed it would see the number appear and then find no trace of it. The expression line is also left as the user typed it, so the entry reads `2 +` → `4`, which is honest about what was pressed.

**Closes:** the `feature.md` "malformed expression → Error" rule for this case, superseded by D-31.

### D-37 — Loading a History Result Produces a Fresh, Usable Value
**Decision:** Tapping a history entry calls `CalculatorController.loadResult(resultValue)`, which sets the value with no pending operator and no in-flight expression, then `pop`s back to the Calculator.

**Rationale:** The result must arrive as *input*, not as a finished display. If loading carried the old pending operator along, typing a digit afterwards would compute against whatever the user had been doing before they left, which is never what tapping a history entry means. A loaded value is also immediately editable: the user should be able to press `+` and keep going, or clear it and start over, with no special case in either.

`pop` rather than `go` is deliberate and is the navigation half of the same decision: the Calculator pushed the History route, so popping returns the user to the screen and state they left instead of rebuilding the stack around it.

### D-38 — The Header Trash Always Renders; The In-List Clear Action Hides When Empty
**Decision:** `desing.md` §6.2 specifies a fixed header with a trash icon plus a separate clear action inside the list. Both exist. The header trash renders unconditionally, and the bottom `_ClearHistoryAction` is omitted when there is nothing to clear.

**Rationale:** The header is fixed chrome — D-10 keeps it stable across states so the screen does not reflow when the list empties — so removing the trash from it would make the header change shape. Instead the button stays put and is disabled: `onPressed` is `null` when history is absent or empty, which greys it out and, importantly, returns early rather than opening a confirmation dialog for an empty list. A dialog asking "Clear history?" when there is no history is a small correctness bug that reads as a broken app.

The bottom action is the opposite case and hides entirely when empty, because an in-list action is content, not chrome — there is nothing for it to act on, and a lone "Clear History" under an empty-state message is visual noise competing with the message.

**Closes:** `desing.md` §6.2's fixed header, and the question of whether the in-list action is always present.

### D-39 — Calculator Depends on History; History Does Not Depend on Calculator
**Decision:** `CalculatorController` calls `HistoryNotifier.record`. `history_controller.dart` imports nothing from the calculator feature, and the repository interface takes already-formatted strings rather than a `CalculatorState`. The one exception is `history_screen.dart`, which imports `calculator/presentation/calculator_controller.dart` to implement D-37's tap-to-load.

**Rationale:** `struction.md` §9 requires features to stay independent, and a two-way import between two features is a cycle that `flutter analyze` will not flag but that makes both untestable in isolation. The direction that works is the one where the *active* screen drives the *storage*: pressing a key is something the calculator does, and recording it is a consequence the calculator knows about.

Pushing strings across the boundary rather than a `CalculatorState` is what makes the rule hold rather than merely appear to. The identifier and the timestamp belong to the storage layer, and the formatting — grouping separators, decimal places — belongs to the calculator under D-18 and D-21. History receives finished text and owns nothing about how numbers render.

The screen-level exception is worth naming rather than hiding, because "history does not import calculator" is false as a blanket statement. `history_screen.dart` does import the calculator controller, and it has to: loading a result is a navigation action, and the screen is where navigation lives. The invariant that actually matters is that the *data and controller layers* stay ignorant, which is what makes the repository substitutable in tests. A rule stated at the layer boundary survives contact with a real screen; a rule stated at the directory boundary does not.

### D-40 — History Enablement Is a Repository Concern, Injected as a Callback
**Decision:** `HistoryRepository` exposes `isEnabled()`, and the `shared_preferences` implementation takes an optional `Future<bool> Function()` at construction, defaulting to always-enabled. The `record` path returns early when it is disabled.

**Rationale:** AC-005 requires history to stop recording the moment the setting is off, but Phase 5 landed before settings persistence existed — D-02 defers that to Phase 6, and a direct dependency on the settings store would have meant building Phase 6's work inside Phase 5.

A callback threaded through the constructor resolves the sequencing without the coupling: the repository asks "should I record?" and does not know or care what answers. Phase 5 passes the default, so history is always on; Phase 6 injects a closure reading `AppSettings.historyEnabled`. The alternative — the calculator checking the setting before calling `record` — would put the policy in the caller, which means every future caller has to remember it, and the repository would happily record into a disabled history if one did not.

The default exists so the fallback and fake repositories need no ceremony, and so the many unit tests that exercise recording do not each have to construct a settings double.

---

### D-41 — Settings Are a Synchronous View Over an Async Notifier
**Decision:** Two providers. `settingsControllerProvider` is an
`AsyncNotifierProvider<AppSettings, AppSettings>` that owns the load and the
writes. `settingsProvider` stays a plain synchronous
`Provider<AppSettings>`, defined as
`ref.watch(settingsControllerProvider).valueOrNull ?? AppSettings.defaults`.
**Phase 4's doc comment proposed replacing `settingsProvider` with an
`AsyncNotifierProvider` outright; that was declined.** The four existing call
sites and two test overrides are unchanged.

**Rationale:** the rest of the app cannot consume the async form.
`CalculatorController` must read the two feedback flags *synchronously on every
key press* to pass them into a call it never awaits (**D-34**), and making it
`watch` would rebuild `CalculatorState` and discard the engine's internal
bookkeeping. The display needs a precision to round with on the same frame.
Layering the sync view over the async holder satisfies both without touching
either. Reading during the initial load yields the defaults and a pending future
schedules no frames, so nothing spins while it waits — and because the
calculator holds no persisted result, there is nothing on screen to briefly
render at the wrong precision.

**Consequence:** the four `lib/` read sites and the two
`settingsProvider.overrideWithValue` call sites in `test/` are byte-for-byte
unchanged, which is what the 250 pre-existing tests passing documents.
`data/settings_provider.dart` survives as a re-export shim so those paths keep
resolving; Phase 8 can collapse it when cross-feature imports are tidied.

**Closes:** the "replace the provider's type" note in `settings_provider.dart`
from Phase 4.

---

### D-42 — Settings Are Five Primitive Keys, Not One JSON Blob
**Decision:** `SharedPreferencesSettingsRepository` writes one native-typed key
per preference — `soundEnabled`, `vibrationEnabled`, `decimalPlaces`,
`historyEnabled`, `theme` — named exactly as `struction.md` §10 lists them.

**Rationale:** the platform store already understands booleans, integers, and
strings, so a JSON blob would add an encode and a decode step to save a handful
of bytes. The per-key form also fails better: one corrupt value costs the user
one default rather than every preference at once.

**Bug found while implementing this.** `SharedPreferences`' typed getters are
*casts*, not coercions — `getInt` is `_preferenceCache[key] as int?`
(`shared_preferences_legacy.dart:122`) and **throws a `TypeError`** on a
mismatch. The first draft of `load()` assumed the getters returned `null`, which
would have made a single corrupt key take down the entire load and pin the app to
defaults permanently. `_readOrNull` now wraps each read, honouring the "never
throws" contract the `SettingsRepository` interface already documented. A unit
test asserts one bad key degrades a single field while the rest survive.

---

### D-43 — A Write Made During the Initial Load Wins
**Decision:** `SettingsNotifier` records the last value written while `build()` is
still awaiting, and returns *that* in preference to the loaded value.

**Rationale:** `apply` publishes optimistically so a toggle moves on the frame
it is touched (**AC-004**). On a cold start a user can reach Settings and flip a
switch before `shared_preferences` has answered; the load then resolves with a
value read from disk *before* the toggle and would snap the switch back. The
write is both later and what the user did, so it wins. Clearing the field at the
top of `build()` keeps a later rebuild (after a write has already been
persisted) reading from storage normally.

---

### D-44 — `preferencesProvider` Moved to `core/storage/`
**Decision:** the app's single `SharedPreferences` acquisition point moved from
`features/history/presentation/history_controller.dart` to
`lib/core/storage/preferences_provider.dart`. Both persisted features read
through it.

**Rationale:** the settings feature needed a store, and the only seam was
defined inside the history feature. Importing it would have created
`settings → history` — inverting the one-way dependency **D-39** established
(the calculator calls into history; history knows nothing of the calculator).
`core` is the right owner because it imports a *plugin*, not a feature, so this
creates no `core → features` edge and **D-24**'s single such import stays
single. It also completes the promise in the original file's comment that the app
should have exactly one place that touches the plugin.

**Consequence:** three test files import `preferencesProvider` from its new home
and override it unchanged; no assertion changed.

---

### D-45 — The Theme Row Is Display-Only and the Core Theme Provider Is Not Rewired
**Decision:** the Theme row renders a chevron but is **not** a tap target
(`SettingsRow` only draws its own chevron when `onTap != null`, so the chevron is
passed as an explicit `trailing`). `appThemeProvider` and
`appThemeModeProvider` stay hard-coded dark, and the screen reads the stored
`theme` only to label the row. **Phase 3 left a comment saying Phase 6 would wire
this up; Phase 6 declined and replaced the comment with the reason.**

**Rationale:** dark is the only theme in v1.0, so the stored value is always
`dark` and consulting it could only ever produce the same `ThemeData` that
`appTheme.dark` already is. Wiring it would add the second `core → features`
import that **D-24** and **D-28** hold down to one, in exchange for a branch with
a single arm. The chevron is kept because the mockup shows one and the row is
supposed to read as navigation; the control is knowingly inert and says so.
`AppSettings._themeLabel` maps the stored name to a display string rather than
hard-coding "Dark mode", so the row tells the truth if a light theme lands.

**Closes:** the "Phase 6 makes it read `AppSettings.theme`" note in
`app_theme_provider.dart` and in `app.dart`.

---

### D-46 — Decimal Places Is a Modal Sheet, Offering 0 to 6
**Decision:** the precision picker is a modal bottom sheet with a checked row per
option, **not** the "sub-screen" a route would be, and it offers `0` through `6`.
`prd.md`'s navigation map calls it a sub-screen; **no mockup of one exists**.

**Rationale:** the sheet matches the affordance the row actually shows — a
chevron promising something *below*. A route would buy a back arrow and a screen
title that have no counterpart in any mockup, for a setting that is a single
choice rather than a place to get lost in. The range is a **chosen** bound, not a
measured one, since no document states it: seven options is the most that fits
without scrolling on the narrowest supported phone (desing.md §9, ~442dp logical
width) and comfortably covers the money and general-science cases. Zero is
included because whole-number arithmetic is a legitimate setting, not a
degenerate one. `AppSettings.clampDecimalPlaces` is applied on both read and
write, so a hand-edited store or a future wider range cannot leave the formatter
holding a precision the picker cannot show or undo. The sheet is scroll-controlled
and scrollable so a short viewport or enlarged Dynamic Type scrolls rather than
clipping.

---

### D-47 — `AppSettings` Gains Value Equality
**Decision:** `AppSettings` overrides `==`, `hashCode`, and `toString`.

**Rationale:** the calculator display watches it through
`settingsProvider.select((s) => s.decimalPlaces)`, and `select` compares with
`==`. Without value equality, two field-by-field identical instances compare
unequal, so flipping *Sound* would look to the display like a precision change
and rebuild the result line for nothing. With it, the rebuild happens exactly
when `decimalPlaces` moves — which is the whole of **D-14**. The same override
also lets `SettingsNotifier.apply` drop a no-op write before it reaches disk.

---

### D-48 — The Settings Screen Copy Was Brought Into Conformance With the Design Docs
**Decision:** the screen's labels now match `desing.md` §6.3 and `feature.md` §C
rather than the Phase 3 placeholders.

| Phase 3 | Now |
|---|---|
| header with no subtitle | + "Customize your calculator experience" |
| section "General" | "PREFERENCES" |
| "Dark mode" / "The only theme in v1.0" | "Theme" / "Dark mode", sun icon (**D-45**) |
| "Sound" + static `On` | `ToggleRow` + "Key press sound" |
| "Vibration" + static `On" | `ToggleRow` + "Vibrate on key press" |
| "Decimal Places" + static `2` | row + "2 decimal places" + chevron → picker |
| "Save History" + static `On` | "History" / "Keep calculation history", clock icon |
| "About" row | "App Version" row, still pushes the About screen |

**Rationale:** Phase 3 deliberately left content alone for Phases 5–7 to own, and
the placeholders it shipped contradicted the design docs it was built from.
`feature.md` FEAT-SET-006 names the row "App Version" and says tapping it opens
the About screen, which is what the mockup's ABOUT section shows.

**Consequence:** `navigation_test.dart` is the only pre-existing test that
changed, in two lines, because it navigated by the old row title. The other 248
pass untouched.

---

### D-49 — The Store Listing Is a URL Built From the Package Name
**Decision:** `AppInfo.playStoreListingId` (a dead query string `?id=com.hasanmahadi.calculator&hl=en`) is replaced with `AppInfo.playStoreUrl`, a full URL composed from `androidPackageName`.

**Rationale:** `in_app_review`'s Android `openStoreListing()` derives the URL from `context.packageName` and ignores any Dart-side argument (`InAppReviewPlugin.kt:135`), so the old field fed nothing. An explicit URL is visible in one place, doubles as the string `share_plus` needs, and keeps D-12's identifier as the single source.

**Closes:** The unused `playStoreListingId` field.

### D-50 — The About Screen Uses the Documented Copy, Not New Prose
**Decision:** About renders the header subtitle "Simple calculator, powerful features" (`desing.md` §6.4) and the hero description "A simple, fast and reliable calculator for your everyday needs." — the exact sentence from `feature.md` FEAT-ABOUT-001. The description now ships as `AppInfo.description`; the share message is composed from it (`"Calculator — <description> <playStoreUrl>"`).

**Rationale:** The design docs already specify this copy verbatim, so inventing fresh text would create a second source of truth for strings the store listing will also need in Phase 9.

**Closes:** The placeholder description inherited from Phase 3.

### D-51 — Rate App Implements D-08 Literally
**Decision:** `ReviewService.rateApp()` follows D-08 exactly: when the platform's `isAvailable()` answers true it raises the in-app review prompt; otherwise it opens the store listing. Any platform error resolves to an `unavailable` outcome — never a thrown exception.

**Rationale:** D-08 is the decision, and this service is the first place it can be realized verbatim. `in_app_review`'s README warns that a button-triggered `requestReview()` can still silently no-op when the Play review quota rate-limits the prompt; that is a store-side limitation this implementation cannot and should not paper over, matching `prd.md` AC-012 as written (Non-standing).

Quotas notwithstanding, "unavailable → open the store" still gives the user *some* store-compliant path on quota days.

**Closes:** `prd.md` AC-012's fallback sub-behavior.

### D-52 — About Carries a Terms Row but No Privacy Row
**Decision:** The MORE section lists Rate App, Share App, and Terms of Service — exactly three rows, matching `desing.md` §6.4. There is **no** Privacy Policy row on About; Privacy remains reachable only from Settings.

**Rationale:** The About mockup (`02_30_45`) visually confirmed via `desing.md` §6.4 shows those three interactions and no fourth. `prd.md` FEAT-LEGAL-001 says "from Settings or About" and is read loosely — About carries Terms (which the mockup shows), while Privacy stays under Settings, so every legal screen is reachable from exactly one documented place and the design is not re-invented.

**Closes:** The residue of D-07's destination ambiguity for the About entry point.

### D-53 — Plugin Calls Run Behind Service Seams and Fail Softly
**Decision:** `in_app_review` and `share_plus` are never imported by widgets. Each is wrapped in `lib/core/services/` as a `ReviewService` / `ShareService` over an interface (`ReviewApi`, `ShareApi`) and exposed as a Riverpod provider, following **D-34**'s `FeedbackService` pattern. Each action returns an outcome enum (`screenShown` / `storeOpened` / `unavailable`); on failure the About screen shows a SnackBar ("This action is unavailable right now") instead of letting an exception surface.

**Rationale:** Testing plugin calls requires faking the plugin both in `pubspec`-expressible unit tests and on a headless device (D-22), and the seams keep widget tests self-contained with a recording fake (**D-34**'s render-object-free approach). A platform failure must be presented as a transient condition, per `struction.md` §12 (no raw errors). This also keeps `core → features` at exactly the one D-24 exception.

**Closes:** `feature.md` FEAT-ABOUT-003's platform interaction, and the D-08/D-16 "no plugin in the tree beyond these" boundary.

### D-54 — Text Scaling Is Clamped to 1.0×–1.3× App-Wide
**Decision:** `MaterialApp.router` installs a `builder` that wraps the child in `MediaQuery.withClampedTextScaling(minScaleFactor: 1.0, maxScaleFactor: 1.3)`. The clamp is a single app-wide constant, `CalculatorApp.maxTextScaleFactor`. Below 1.0 is left to the platform because Android's accessibility range starts there and shrinking text is not an accessibility need. Where a widget reserves vertical space for a glyph — `CalculatorDisplay`'s result line, `AppHeader`'s title — the reservation multiplies by the ambient scale, because `Text` scales its own glyphs through the ambient `MediaQuery` while a `SizedBox` does not scale itself.

**Rationale:** `prd.md` AC-007 asks for Dynamic Type support without stating a range. Unclamped, the 2× Android maximum overflowed the keypad grid, because the keys are laid out from fixed spacing tokens (D-27 sizes the keys, but the *gaps* are tokens) — a short screen ran out of room for the display before the user had read anything. 1.3× is the largest factor at which every screen still lays out at the documented 320×568 minimum, and it is the factor at which the header, display, and empty states were verified to have room for their grown text. `EmptyState` additionally became scrollable, because an empty state is the one place a screen is guaranteed to have nothing else to scroll. Clamping rather than reflowing the whole grid keeps a fixed-token design system (which every screen is built from) working at large text, and the two places that clip are handled at the source rather than by shrinking the font.

**Consequence:** The app deliberately does not honour 1.5× or 2×. If the designer later supplies a layout that does, the clamp in `lib/app.dart` is the only thing to remove, and the scale-aware reservations become no-ops.

**Closes:** `prd.md` AC-007's unstated range, and Phase 8's Dynamic Type task.

### D-55 — Cold Start Is Proven by Restarting the Scope; No Lifecycle Observer
**Decision:** No `AppLifecycleListener`, no `WidgetsBindingObserver`, and no state is written to restore. Every persisted read is a provider's `build()`, so a cold start *is* the first `build()` in a new `ProviderScope`. `test/widget/cold_start_test.dart` proves this rather than assuming it: it unmounts the app (`pumpWidget(SizedBox.shrink())`), re-seeds the store from a snapshot taken with `snapshotStore()`, and pumps a **new** `ProviderScope`. It asserts that settings and history survive, that a half-typed expression does not, and that the app opens on the root route rather than where it was left.

**Rationale:** Phase 8's task list called for "app lifecycle (restore state on cold start)", which invites an observer. An observer would have nothing to do: `shared_preferences` has no OS lifecycle callback to hook, and a `ProviderScope` is destroyed on process death, so state restored *into* a fresh scope is the only kind that can exist. Adding a listener would have meant either persisting in-flight calculator state — which `prd.md` §11 explicitly does not want — or writing a lifecycle hook whose sole behaviour was to read providers, which is what the providers already do. The test's re-seeding step matters for the same reason: `SharedPreferences.setMockInitialValues` nulls the plugin's cached completer, so a second container without it would share one in-memory instance with the first and the "restart" would prove nothing.

**Closes:** The lifecycle-listener half of Phase 8's app-lifecycle task.

### D-56 — Transitions Are go_router's Default, and No Route Customises Them
**Decision:** No `GoRoute` in `lib/routing/app_router.dart` sets a `pageBuilder` or a `CustomTransitionPage`. Pushing a screen therefore produces the platform's standard push, and the system back gesture pops it. `test/widget/navigation_graph_test.dart` asserts the *absence* of a custom transition on every route, so a later polish pass cannot add one without the decision being revisited.

**Rationale:** No mockup shows motion — the source material is static screens — so any custom animation would be invented rather than designed, and it would be invented twice (Android push and Android predictive-back) and diverge from the platform's own back behaviour. `test/widget/navigation_graph_test.dart` locks the graph as a whole: exactly seven registered paths (D-20's six plus the debug-only catalog, D-25), every path resolving to a screen, and the negative half of D-20 — no About, Privacy, or Terms control reachable from the Calculator, and exactly two navigable icon buttons on the root route.

**Closes:** Phase 8's "transitions and navigation polish" task.

### D-57 — The `settings_provider.dart` Re-Export Shim Is Collapsed
**Decision:** `lib/features/settings/data/settings_provider.dart` — a file that existed only to `export` two symbols from `features/settings/presentation/` — is deleted. The three importing production files now import `../../settings/settings.dart` (the feature barrel) directly, and the two importing tests now import `package:calculator/features/settings/presentation/settings_controller.dart` directly.

**Rationale:** The shim was added in Phase 6 so that Phase 4's calculator could read settings before the settings feature existed. Once Phase 6 landed, the shim was a second name for the same two symbols, and it pointed a reader at `data/` for a definition that lives in `presentation/`. A file whose path implies a layer that is not its own is worse than no file: it invites an import that keeps the wrong dependency direction alive. Imports were repointed at the barrel in production because that is the feature's public surface, and at the concrete file in tests because a test should name the thing it is faking.

**Closes:** The D-41 shim note, and Phase 8's import-hygiene task.

### D-58 — A Failed History Read Shows a Fixed Sentence and a Retry
**Decision:** The History screen's `AsyncError` branch renders `EmptyState` with the title `Could not load history`, a **fixed** message — "Your saved calculations could not be read. Try again, or restart the app." — and a `Try again` button keyed `history-retry` that calls `ref.invalidate(historyControllerProvider)`. The exception is never interpolated into the UI; it stays in the `AsyncValue` for the log. The empty-history branch supplies **no** action, because there is nothing to retry.

**Rationale:** `struction.md` §12 requires the presentation layer to map errors to user-visible messages. The branch interpolated `'$error'`, which put `Exception: ...` and platform detail in front of a user of a fully offline app that has no log to read and no action to take beyond retrying. The retry is real rather than decorative: the repository falls back to memory when `shared_preferences` is unavailable (D-44), and invalidating the provider re-runs `build()`, which re-reads storage. A retry that fails again returns to the same error state rather than falling through to "No calculations yet" — which would be a lie, since a failed read is not an empty history. `EmptyState` gained an optional `action` slot so the same component serves "nothing yet" and "something went wrong" without the History screen bolting a column onto it.

**Closes:** `struction.md` §12's error-copy rule for the History screen, and the Phase 8 error-state task.

### D-59 — Interactive Rows Announce as One Node, and Switches Keep Their Own State
**Decision:** `SettingsRow` wraps its contents in a `Semantics` node labelled `"<title>, <subtitle>"`, marked `button: true` only when it has an `onTap`, with the icon, the visible title and subtitle, and the trailing chevron inside an `ExcludeSemantics`. `HistoryCard` does the same, labelled `"<expression>, <result>"`. `SectionHeader` is marked `header: true`. The decimal-places options are marked `selected` and `inMutuallyExclusiveGroup`, with a checkmark glyph excluded. `ToggleRow` passes `semanticsLabel: title` to `AppToggle`, and `AppToggle` wraps its `Switch` in `Semantics(container: true, label: ...)` rather than excluding it.

**Rationale:** Before this, a settings row announced as up to four separate stops — icon, title, subtitle, chevron — so a screen-reader user had to swipe four times and reassemble what reads as one line. Merging the decorative fragments into a single node is the difference between one stop and four. Two things are deliberately **not** merged: a tappable row is still marked as a button, so the platform announces that a tap does something; and the Switch stays its own node, because excluding or merging it would lose the on/off state — a row announcing "Sound, Key press sound" and nothing about whether sound is on is a control whose state the user cannot discover. D-45's Theme row is the case that proves the rule is a real distinction and not a blanket: it shows a chevron but is knowingly inert, so it is marked `button: false` and announcing it as a button would promise a tap that does nothing. Touch targets are unchanged — they were already at or above 44pt (D-27), and Phase 8 asserts that rather than adjusting it.

**Closes:** The `prd.md` AC-007 accessibility half, and Phase 8's accessibility task.

---

### D-60 — The Screen Margin Is 24 px, Which Also Fixes the Key Diameter
**Decision:** `AppSpacing.screenHorizontal` moves from 20 to 24. `CalculatorKeypad.keyGap` stays 14. The rendered key diameter on the 442×890 mockup canvas is therefore 88 px, and the two residual unknowns' measured follow-ups (screen margin, key gap) are recorded as 24 px and 13/15 px respectively.

**Rationale:** Phase 9 was the first phase able to open the mockups — Phases 2 through 8 each closed with the note that the images could not be read, so every geometric value up to this point came from `desing.md`'s *prose* rather than from pixels. Decoding the four PNGs and scanning them inverted two things at once.

First, the margin. The card edges in the History, Settings, and About mockups all sit at logical x≈24 (48–50 px at 2x), consistently across three independently rendered images. `desing.md` §4 gives a prose range of "~16–20 pt", and Phase 3 duly took 20 from the top of it. The prose was simply wrong about the source, and the measured value sits outside the range it allowed — the case D-03 was written for, applied to spacing rather than colour.

Second, and more usefully, the margin *is* the key diameter. Under D-27 the keypad sizes its cells from the width left over after the margins, so the two numbers were never independent: at margin 20 the grid yields `(442 − 40 − 3·14) / 4 = 90.0` px keys, and at margin 24 it yields `(442 − 48 − 3·14) / 4 = 88.0`. The mockup's five key rows measure 174–178 px at 2x, i.e. 86.5–87.5 logical. So the key was 2–3 px too large for a reason that had nothing to do with keys, and correcting the margin corrected the key. R-2 was a *symptom* of a margin error, which is why Phase 1 could only ever report a 85–95 range: it was measuring a consequence and had no way to reach the cause.

The gap was measured at 13 px horizontally and 15 px vertically. A single 14 px value is within 1 px of both, which is below the threshold at which a per-axis token earns its keep, so `keyGap` stays as one constant. Verified empirically rather than assumed: the rendered cell is 88.0 px on the mockup canvas, inside the measured band.

**Closes:** R-2, and the margin half of the §4 screen-spacing prose.

### D-61 — R-1 Is Closed as Chosen, Not Measured
**Decision:** `AppColors.toggleTrackOff` stays `#2A2A2A` and R-1 is closed. The value is accepted as a design decision; it is not, and cannot be, derived from the mockups.

**Rationale:** Phase 9's pixel read settles the question Phase 1 could only record. All three toggles in the Settings mockup are ON: the tracks measure 44 × 25.5 px and are orange `#F89508`, and no OFF state occurs in any of the four images. This is now a *positive* finding rather than an absence of one — the source material was searched and does not contain the state — so no future re-measurement can resolve it, and carrying it as open would misrepresent a closed question as a pending measurement.

The value itself is unchanged from D-26's provisional pick, and the reasoning is unchanged: the platform default renders a light gray track that breaks the black/gray palette, while `#2A2A2A` sits in the same family as the `#1E1E1E` digit keys. What changed is its status, from *provisional pending measurement* to *chosen, with the measurement proven impossible*. That is a weaker guarantee than a measured value and stronger than an unexamined default, and the test now says so: it asserts the literal and the property that makes it look right (visibly darker than the ON track), not a claim of measurement.

The correction path is unchanged and remains one edit — a designer hand-off would supersede this in `AppColors.toggleTrackOff` alone, since D-53 keeps the theme resolving it in one place.

**Closes:** R-1.

### D-62 — Release Signing Reads a Git-Ignored `key.properties` and Fails Loudly Without One
**Decision:** `android/app/build.gradle.kts` reads `android/key.properties` for `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`. If a release build is requested and `storeFile` is absent, the build stops with a `GradleException` printing the file's four keys, a `keytool` command to generate a keystore, and a pointer to the debug variant. The Flutter template's fallback — signing `release` with the debug key — is removed.

**Rationale:** The template's default is the worst of both outcomes. A debug-signed release builds cleanly, installs everywhere, and is accepted by no store, so the mistake is discovered at upload time, by Play, rather than at build time by the developer. Failing at configuration is worth a little friction: the message is the documentation, and it names the missing file and the fix.

The check runs before `android { }` deliberately. The natural place to detect a missing keystore is where `signingConfig` is assigned, but assigning a `signingConfig` by a name that was never created fails first with Gradle's own `SigningConfig with name 'release' not found`, which names neither the missing file nor the remedy. That was observed, not anticipated.

That same error has a second, less obvious consequence, which this project hit and fixed: the `buildTypes { release { signingConfig = ... } }` block is evaluated at *configuration* time for every variant, not just when release is being built. Using `getByName("release")` therefore made `flutter build apk --debug` and `flutter run` fail on any machine without an upload key — the signing requirement leaking into local development. The assignment uses `findByName("release")` instead, which yields `null` when the config does not exist. Reaching that null branch is impossible for a real release build, because the check above throws first; it only keeps the debug path working on a fresh clone. Worth stating because the first fix for "release builds should fail loudly" plausibly *causes* "debug builds stopped working", and only building both variants finds it.

Reading the file rather than taking `-P` flags is a security choice, not a stylistic one: a keystore password on a Gradle command line is visible in process listings and in CI logs. The UTF-8 BOM strip is a smaller version of the same class of problem — `Properties.load` reads ISO-8859-1 and folds a BOM into the first key's name, so a `key.properties` written by Notepad or by PowerShell's `Set-Content -Encoding UTF8` would silently lose `storeFile` and produce exactly the confusing "no release signing key" error on a file that is sitting right there. On a file a developer hand-writes and never expects to be encoding-sensitive, that is worth absorbing.

The file is git-ignored along with `*.jks` and `*.keystore`. Losing the keystore means never being able to update the published app, which the error message says explicitly, because that is the failure with no recovery path.

**Verified:** the hard failure fires with the message above; with a throwaway `CN=Throwaway` key present, the release APK, AAB, and split APKs all build and `apksigner`/`jarsigner` both accept them. The throwaway key and its `key.properties` were deleted afterwards and are not in this repository.

### D-63 — The Size Lever Is ABI Delivery, Not Obfuscation
**Decision:** R8's effect on total artifact size is documented as negligible and not treated as a release goal. Size is addressed by shipping an App Bundle, or `--split-per-abi` for sideloading, and the numbers measured in Phase 10 are recorded in `phases.md` rather than a target being chased.

**Rationale:** Measured on the fat release APK: 48.4 MB total, of which 47.3 MB is native code — `libflutter.so` and `libapp.so` for three ABIs — and 0.95 MB is `classes.dex`. R8 shrinks the dex, so even eliminating it entirely would move the total by about 2%. The per-ABI split APKs are 14.7 MB (armeabi-v7a), 17.2 MB (arm64-v8a), and 18.7 MB (x86_64), which is where the real reduction lives: Play serves one ABI per device.

This is recorded because the intuitive plan for a large Flutter APK — turn on minification — is the one that does not work here, and a reader who assumed otherwise would either chase the wrong lever or conclude the 48.4 MB figure is a defect. It is not: it is three architectures of the Dart engine in one file, and the distribution format is what addresses it.

**Closes:** the implicit assumption that a large release APK indicates a shrinking problem.

### D-64 — R8 and Resource Shrinking Are On for Release, with Near-Empty Keep Rules
**Decision:** `isMinifyEnabled` and `isShrinkResources` are both `true` on the `release` build type, with `proguard-android-optimize.txt` plus a deliberately near-empty `android/app/proguard-rules.pro` containing only `-keepattributes SourceFile,LineNumberTable` and `-renamesourcefileattribute SourceFile`.

**Rationale:** On the evidence of D-63 this is not a size play — it is the correct release posture, and it costs nothing. It strips the unused Java/Kotlin surface from the AndroidX and Material libraries the app pulls in transitively, and it removes unreferenced resources.

`proguard-rules.pro` is short because there is nothing to put in it, not because keeping rules were overlooked. The Flutter Gradle plugin contributes the engine's own rules, and both plugins in use (`in_app_review`, `share_plus`) are reached over platform channels rather than reflection, so neither is at risk. Keeping line numbers while hiding the source file name is deliberate: Play Console crash reports stay readable without publishing the source layout.

The honest caveat, and the reason the file is a short list rather than a growing one: a missing keep rule produces a crash at runtime that no build-time check can catch. Adding one would require a device to verify, and no device is available (`store/README.md`'s checklist keeps that step explicit rather than pretending the build proves it).

### D-65 — Cloud Backup and Device Transfer Are Both Switched Off
**Decision:** `android:allowBackup="false"`, `android:fullBackupContent="false"`, and `android:dataExtractionRules="@xml/data_extraction_rules"`, where the rules file excludes `root`, `database`, `sharedpref`, and `external` from **both** `cloud-backup` and `device-transfer`.

**Rationale:** The app's central privacy claim is that calculation history never leaves the device, and Android's default would break it invisibly. With `allowBackup="true"`, the system uploads the app's `shared_preferences` — the 200-entry history and the five settings keys — to the user's Google account and restores it onto a new device, with no in-app indication and no setting to stop it. The claim in the policy text would have been false at the platform level while reading true in the app.

Both channels are excluded deliberately. Device-to-device transfer is a separate path from Google-account backup and is opted out of separately; declaring only the first would have left a route out of the app that the policy does not mention. The rules file is required from API 31 onward to be explicit at all, which is why it exists even though `allowBackup="false"` already covers the older behaviour.

This is a real product cost, not a free win, and it is why it is a decision rather than a default: history does not follow a user to a new phone, and re-entering it is their job. The app already trades that way everywhere else — everything is local, and deleting the app deletes the data — so this makes the platform behaviour match the product's existing posture instead of contradicting it.

**Verified:** the compiled manifest carries all three attributes, and the Data Safety "no data collected" answer in `store/listing.md` rests on the absence of `INTERNET` plus this exclusion, not on a promise.

### D-66 — The Launcher Icon Is a Two-Layer Adaptive Icon With No Monochrome Layer
**Decision:** The launcher icon is generated: a flat `ic_launcher_background` colour fill plus an `ic_launcher_foreground` bitmap, wired through `mipmap-anydpi-v26/ic_launcher.xml` and `ic_launcher_round.xml`, with legacy and round PNGs at five densities for pre-API-26. The adaptive background colour is `#1E1E1E`, the same value as `AppColors.buttonDigit` and the same colour `tool/generate_assets.ps1` draws for the store icon. There is deliberately **no** `<monochrome>` layer.

**Rationale:** An adaptive icon's mask is drawn by the launcher and varies by OEM and by the user's chosen shape, so neither layer carries a rounded corner or a shadow — that is the launcher's job, and baking one in produces a double-rounded icon. A flat background fill is what lets the mask cut any shape into the artwork without inheriting a geometry the app chose. The foreground's grid is inset further than the legacy icon's because the launcher may crop the outer 18 dp of the 108 dp canvas and this layer has no background to bleed into the cropped ring.

The missing monochrome layer is the one part that looks like an omission and is not. Themed icons want a single-colour silhouette; this artwork is a four-colour grid whose meaning comes from the gray/orange split, so pointing `<monochrome>` at the colour foreground would have the system tint the whole bitmap one colour and produce four indistinct blobs — an icon that looks broken on exactly the surfaces the layer exists for. Omitting it means Android falls back to the colour adaptive icon, which is correct. A monochrome silhouette would need its own drawn asset.

Sharing `#1E1E1E` across the adaptive background, the keypad's digit keys, and the store icon is what keeps the three from drifting apart; the colour lives in one resource and one script, and changing it in only one of them would make the launcher icon and the store icon visibly disagree.

### D-67 — Store Artwork and Screenshots Are Generated, Not Committed by Hand
**Decision:** `tool/generate_assets.ps1` generates the launcher icons, the 512×512 store icon, the 1024×500 feature graphic, and the alpha-flattening pass over the screenshots. The four screenshots are rendered from the real app by `test/store/store_screenshots_test.dart` at 1080×1920. That test is skipped unless `GENERATE_STORE_ASSETS` is defined, so an ordinary `flutter test` run never compares the PNGs.

**Rationale:** Store graphics are the easiest thing in a release to get quietly wrong, because nothing fails when they are wrong — Play accepts a 24-bit screenshot with an alpha channel, or a feature graphic at the wrong size, and the listing just looks slightly off. Generating them from the same values the app renders makes the two impossible to desynchronise: the screenshots contain the real theme, the real copy, and the real widgets, so a colour-token change shows up in the next regeneration instead of in a Play review.

Skipping the screenshot test by default is a deliberate trade. Asserting golden PNGs across machines would fail on font-rasteriser differences rather than on real regressions, and these files are a listing artifact rather than a regression suite. They are regenerated on demand, not watched in CI.

The flattening pass exists because Flutter's golden writer emits an alpha channel and Play rejects screenshots that carry transparency. The matte is sampled from each screenshot's own background rather than hard-coded, so a theme change cannot leave a mismatched border around the artwork.

The script targets Windows PowerShell 5.1, which ships with Windows. It does not require PowerShell 7, and its icon and feature-graphic steps additionally need `System.Drawing`, so those steps are Windows-specific as written.

### D-68 — Legal Copy Lives in a Data File and Its Claims Are Test-Gated
**Decision:** The Privacy Policy and Terms of Service text moves to `lib/features/legal/data/legal_content.dart` as structured section data, with `legal_screens.dart` reduced to presentation. `test/unit/legal_content_test.dart` asserts the copy's structure, its cross-references, and its platform claims — including that the app declares no `INTERNET` permission — so a claim that stops being true fails a test rather than shipping.

**Rationale:** D-07 chose in-app text screens with copy "the developer replaces before release", and left the text itself unspecified. Once the text is real it is a load-bearing artifact rather than filler: it is the only place the app's privacy promises are stated, and the store listing's Data Safety answers and marketing copy both rest on it. Keeping it in a plain data file, separate from the widget that renders it, means the text can be reviewed, diffed, and asserted without rendering a screen.

The tests are the part worth defending. A privacy policy is prose, and prose does not fail a build when it becomes untrue — so the claims that can be checked against the platform are checked: the no-`INTERNET` claim against the merged manifest, the backup claim against `AndroidManifest.xml`, and the section structure against the headings the app's own navigation test already asserts. What remains unverifiable — that the copy is legally adequate, and that it matches reality on a real device — is stated rather than asserted.

One gate is deliberately left failing on purpose. `legalContactEmail` is `TODO-replace-with-your-address@example.com` because `example.com` is IANA-reserved and cannot receive mail. It is safe to commit and must not be published; the test asserts the placeholder is present, so supplying a real address fails that assertion and forces the author to deal with it in the same change. This supersedes D-07's "placeholder copy" premise for v1.0 — the copy is final except for that one address, and the only remaining release gates are external.

**Closes:** D-07's open question about the content of the legal text.

---

### D-69 — The Keypad Renders the Gaps It Declares, and the Screen Is One Capped Column
**Decision:** `CalculatorKeypad` lays its gaps out as real children instead of reserving them in arithmetic, and takes the box it lays out in (`availableWidth` / `availableHeight`) rather than a pre-solved `cellSize`, deriving the cell itself within `[maxCellSize]`. `keyGap` stays a constant of 14. `CalculatorScreen` becomes a single flex column in one `Center` + `ConstrainedBox(maxWidth: 480)` panel holding header, display, and keypad; the top bar is inset by `AppSizes.headerIconInset` so its 22 px glyphs land on the measured 24 px margin; and the display's reserved height yields to `CalculatorKeypad.minGridHeight` when a window is too short for both. The keys are 88 px on the 442×890 reference canvas, unchanged.

**Rationale:** The grid's bug was not a wrong number but a number that was never used. `gridWidth`/`gridHeight` reserved `keyGap` between cells, and the rows were then built from bare `SizedBox` cells with no separator — so every key was laid out *touching* its neighbour, each row came up 42 px short of the box the grid declared, and the 5-row column came up 56 px short at the bottom. The surplus was absorbed by whatever alignment happened to be in force: `Column`'s default `crossAxisAlignment: center` re-centred each row independently, and because the last row is one gap wider (`0` absorbs the gap it straddles) it landed 7 px out of line with the four above it, putting `=` off the operator column and `0` off the digit column. The display was sized against the full content width while the keypad was `Center`ed at its natural size, so the result's right edge never met the `=` column — a divergence that grew with the window. Nothing here is visible in a single test that asserted only cell sizes, which is why the geometry now has assertions of its own.

The gap was made a child rather than left in the arithmetic because a reserved gap and a rendered gap are different things, and only the second is a gap. `CrossAxisAlignment.stretch` states the rows fill the declared width instead of relying on each one happening to be the same width.

The header inset is `(screenHorizontal - (iconTouchTarget - rowIcon) / 2)`, derived rather than written as 11, because the margin is optical: `IconButton` centres a 22 px glyph in a 48 pt target, so it is the glyph, not the button box, that has to sit on the 24 px margin. The padding is pinned to zero so the arithmetic in the token is the whole story rather than a property of the theme's default inset.

The display carries **no horizontal padding of its own**, which is the non-obvious half of "one column". `gridWidth` is already the column inside the screen margin — the outer keys sit on it — so padding the display by another 24 px would leave the result one margin to the left of the `=` column it is meant to line up with. The display's lines are right-aligned, so filling the column is exactly what puts the number flush with the operator column; the margin is applied once, by the column, rather than twice.

**Why the gap cannot grow, which is the non-obvious part.** While the grid is width-bound its height is `1.25 × panelWidth + keyGap/4` — raising the gap from 14 to 21 buys 1.75 px of height and costs 5.25 px of key diameter, taking the reference keys from 88 px to 82.75 and breaking the measured 86.5–87.5 px band (D-60, R-2). When the height is the binding axis the grid already fills it exactly and a wider gap only shrinks keys. So no gap is useful on either axis, `keyGap` stays the measured 14, and the space above the display is what it is: on a phone the keypad's height is fixed by the panel's width, and roughly 190 px of top space is inherent to this design — as `desing.md` §6.1 intends ("large vertical space above the buttons"), not a defect to be tuned away. What *was* a defect is the keypad floating 80 px off the floor and the number sitting 16 px from one key row and 72 px from another.

**Why the min/max pair is not symmetric.** `maxCellSize` is a genuine bound: it only ever reduces the cell, so it can never overflow the box, and without it a 1280×1600 window would render 268 px keys. A `minCellSize` clamp in the same place would be worse than nothing — a cell larger than the box allows overflows it, so the clamp would trade a touch target for a layout error. The 44 pt floor is therefore a reservation the *screen* makes (`CalculatorKeypad.minGridHeight`), with the display's `Expanded` giving up the slack on a window too short for both. On a window too short to hold a 44 pt keypad at all, the cell follows the height down rather than overflowing, which is the honest degradation.

**Scope.** D-09's portrait-phone lock is untouched; a wide window is handled by capping and centring the panel rather than by claiming a new form factor. This is a layout correction: no calculation, key, callback, or token value changes, and the mockup's measured geometry — 24 px margins, 14 px gaps, 88 px keys — is exactly what renders.

**Supersedes:** nothing. **Amends:** D-27 (the grid now receives a box rather than a solved cell, which keeps the geometry in one place rather than two) and D-60 (the margin correction is preserved; this fixes how the gap reserved against it is actually rendered).

---

### D-70 — Header Chrome Is Pinned to the 24 px Optical Margin, and the Empty State Centres in Its Scroll View
**Decision:** The two header icons are placed by arithmetic rather than by `AppBar`'s and `IconButton`'s defaults. The calculator's top bar insets its row by `AppSizes.headerIconInset = screenHorizontal - (iconTouchTarget - rowIcon) / 2`, and `AppHeader` derives a matching `leadingWidth` and action inset so that its back arrow and trailing action land their *glyphs* — not their button boxes — on the measured 24 px margin (D-60). Separately, `EmptyState` centres by giving a `Center` a bounded minimum: `LayoutBuilder` + `SingleChildScrollView` + `ConstrainedBox(minHeight: constraints.maxHeight)`.

**Rationale:** Both are places where a Flutter default is not what the mockup measured, and neither is visible to a finder-based test that only checks for the widget. `AppBar` reserves a 56 px leading slot, adds an 8 px inset before its first action, and centres the leading *inside* the slot, so a stock `IconButton` header paints its 22 px glyph at x≈21 — three pixels inside the line every card, section header, and calculator key is built on. Only the rendered rect catches it. `header_alignment_test.dart` therefore asserts the glyph rects, not the presence of the buttons, and the walk measures every header in the app so one screen cannot drift off the line on its own.

The empty state is the mirror problem: a `Center` inside a vertical `SingleChildScrollView` is handed an *unbounded* main axis, so it collapses to its child's height and the block sticks to the top of the page. desing.md §9 asks for a "Centered illustration or icon", so the scroll view states the viewport as a **minimum** height for the `Center` to centre within, while content taller than the viewport (at a large Dynamic Type factor) still overflows the box and scrolls (D-54). The `minHeight` is what makes it centre rather than merely align; the scroll view is what keeps the centring from becoming a clip.

**Consequence:** the 24 px margin is now an *optical* contract — the glyph position — rather than a box position. `historyHorizontal` (D-72) deliberately breaks it for the History cards, which is why the two are asserted against different values.

**Supersedes:** nothing. **Amends:** D-60 (which fixed the margin's value; this fixes what is placed on it) and D-54 (the empty state's scroll fallback at the clamp).

---

### D-71 — The Settings Header Is the Title Alone, at a Compact Size

> **Amended 2026-10-01 — D-75.** The subtitle is now gone from *every* header, not
> just Settings', so the second paragraph below (the 28 pt compensation) no longer
> applies: Settings paints the shared 32 pt `screenTitle` like every other page.
> The first paragraph still stands as the reason the subtitle was dropped here
> first.
**Decision:** the Settings header drops its "Customize your calculator experience" subtitle, and its title is painted at 28 pt w700 through a new `AppTypography.screenTitleCompact` token instead of the shared 32 pt `screenTitle`. `AppHeader` gains an optional `titleStyle` that defaults to `screenTitle`, so the reduction is scoped to this one screen.

**Rationale:** the subtitle restated what the screen already says. Every row carries its own description — "Dark mode", "Key press sound", "2 decimal places", "Keep calculation history" — so the header's line was a fourth, vaguer version of the same information, and the *least* specific of them. It also made Settings the only 88 px header in the app: History and both legal screens have always been 56 px, so returning to the menu put a visibly taller bar in front of a shorter one. Removing the subtitle lets `AppHeader.preferredSize` fall back to its 56 px one-line height, which is the header the rest of the app uses.

The size drop is the compensation for that removal, not a second, independent change. A 32 pt w700 title is sized to sit above a 16 pt line; with the line gone, the same 32 pt reads as an oversized banner rather than a screen title. 28 pt is the bottom of `desing.md` §3's documented 28–34 band, so the reduction stays *inside* the design doc rather than deviating from it, and the existing range assertion in `design_system_test.dart` still holds without being rewritten.

The token is separate from `screenTitle` rather than a `copyWith(fontSize: 28)` at the call site, and that separation is the whole point of the exercise: the About hero card prints `AppInfo.name` in `screenTitle`, and an in-place size edit would have silently demoted the app's own name to 28 pt on a screen where it is the largest element. A named token keeps the change to one screen and leaves the brand mark alone.

An optional `titleStyle` on `AppHeader` is preferred over a `SettingsHeader` subclass, a second constructor, or a boolean `compact`. The back arrow, the 24 px leading arithmetic (**D-60**), and the `centerTitle` slot are already correct in the one component, and a second header would duplicate all three into a second thing to keep in sync — for a difference that is one style value. A boolean would be smaller still, but it encodes *why* the size differs nowhere; a style parameter lets the caller name the token and read as intent.

**Consequence:** Settings and History are now both 56 px bars whose titles differ by 4 pt. This is deliberate and visible when navigating between them; it is the cost of scoping the reduction to one screen rather than re-speccing every header. The D-54 subtitle-scaling clamp test moves from Settings to **About**, which is the only remaining screen where the enlarged subtitle is load-bearing. `store/play/screenshots/03-settings.png` is stale and needs `tool/generate_assets.ps1` to re-render.

**Supersedes:** nothing. **Amends:** D-48 (which added the subtitle, and whose table entry this reverses) and D-54 (its clamp test now covers About rather than Settings).

---

### D-72 — The History Screen Is Rebuilt Around Large, Inset Cards
**Decision:** The History list is redesigned in presentation only. Cards become 150 pt-minimum, 30 px-radius surfaces on a new `AppColors.surfaceRaised` (`#151517`), inset by a new `AppSpacing.historyHorizontal = 48` rather than the app's 24 px margin; the expression is painted at 28 pt and the result at 44 pt (`AppTypography.historyExpression` / `historyResult`, both re-specced), with the result in a `FittedBox(fit: scaleDown)` so it may shrink but never truncate. Day headings move from the shared uppercase `SectionHeader` to a new sentence-case `HistoryDayLabel` at 27 pt. The header uses a new start-aligned title and a bare outline trash at the larger `AppIconSize.large`, replacing `HeaderActionButton`'s orange badge. `AppHeader` gains optional `leadingSize` and `titleAlignment` parameters so the change is scoped to this screen. Grouping, persistence, the confirmation gate, tap-to-load, the fixed header, and the conditional bottom Clear History action are untouched (D-05, D-10, D-37, D-38).

**Rationale:** the redesign, taken from the History mockup, is a shift from a compact list to a spacious one, and the two do not share values: a 30 px radius on a 150 pt card is a different object from a 14 px radius on a 68 pt row, a 44 pt result is not a 21 pt one, and a 48 px inset reads as "this list is its own thing" where the 24 px line is the app's shared edge. Putting those numbers on the shared tokens would have restyled Settings' groups, the About card, the dialog, the decimal sheet, and every card edge in the app — so `historyHorizontal`, `historyCard`, and the two type styles are named History tokens, and `surface` stays the shared fill while `surfaceRaised` is the card's own.

The card's height is a `minHeight`, not a `SizedBox`. At 1× the content is a little under 150 and the card settles at the design's figure; at the 1.3× clamp (D-54) the same content grows past it and the card grows with it. A fixed 150 would clip the result at exactly the setting the app promises to support, so the floor is the design value and the ceiling is the user's text size. Placing the `ConstrainedBox` *outside* the 24 px inner padding is what makes `150` mean the card rather than the content area — inside, the padding would add on top and every card would be 198.

`HistoryDayLabel` is separate from `SectionHeader` rather than a fourth mode of it because the two differ in *identity*, not size: the shared component shouts a short uppercase label to group rows, and this one speaks a sentence at 27 pt to separate days. Overloading `SectionHeader` would move the choice to Settings, About, and the History list at once, for a change the decision only authorises on one screen.

The badge removal follows from the larger glyph. `HeaderActionButton`'s 48 pt accent circle existed to make a 22 px glyph read as a primary action; at 28 px, with a 32 pt start-aligned title beside it, the wash competes with the title for the same slot instead. A bare outline glyph in `textPrimary` (or `textSecondary` when there is nothing to clear) is the whole control, and `AppHeader` now derives a 56 pt target from the 28 px glyph so the action still clears the 44 pt floor and its glyph still lands 24 px from the edge — which is why the larger leading size is a *new optional parameter* with the old 22/48 arrangement as its default: the other four headers must not move.

**Consequence:** the header alignment suite now measures History's larger arrow and trash against derived geometry rather than a fixed `iconTouchTarget`, and the card has its own geometry suite (`history_responsive_test.dart`) because token assertions cannot see a margin or a radius. `store/play/screenshots/02-history.png` is stale and needs `tool/generate_assets.ps1` to re-render.

**Supersedes:** nothing (D-70's header alignment still holds; only the History cards sit off its 24 px line). **Amends:** D-10 (the History header keeps its back arrow, title, and conditional trash, but start-aligned and larger), D-38 (the bottom action still hides when empty; both actions keep the shared D-05 gate), and the `desing.md` §3 History type scale.

---

### D-74 — Every Header Is a `Row`, and Its Actions Are Bordered Squares

**Decision:** the `AppBar`-based `AppHeader` is replaced by three components in
`core/widgets/`: `AppIconButton` (a 48 px bordered square around a 22 px glyph),
`AppPageHeader` (a destination's own bar — an optional leading action, an optional
start-aligned title, and optional trailing actions) and `SecondaryPageHeader` (a
back box, a centred title, and an optional trailing action). `SecondaryPageScaffold`
wraps the frame every pushed screen shares: the black page background, a `SafeArea`,
and a column holding the header above an `Expanded` body. The calculator's private
`_CalculatorTopBar` is deleted in favour of `AppPageHeader`.

Every header action now rides the 24 px screen margin with its **box**, not its
glyph, because the box is the object a user sees; the glyph sits the difference
inboard. A secondary title is centred by *symmetry* rather than by a framework
flag: the row is `[48 px back box][12][expanded title][12][48 px action or blank]`,
so the title's own middle is the screen's middle whatever it says. Titles and
subtitles are one line with an ellipsis, and the bar is `AppSizes.headerHeight`
(56) as a *minimum*, so it yields to the second line a subtitle needs and to
Dynamic Type instead of clipping either.

**Rationale:** the headers were the last surface still built from a framework
primitive whose defaults the design had to be defended against. D-70 exists
because `AppBar` reserves a leading slot, insets its first action, and centres its
leading *inside* that slot, which put the glyph three pixels inside the line every
card, section header, and calculator key is built on. `AppHeader` answered that
with a derived `leadingWidth` and a derived action inset, and every one of those
numbers had to be kept in step with `AppSizes.iconTouchTarget` and the glyph
bucket by hand. A `Row` the component owns has no slot to derive, so the
arithmetic is not ported — it is deleted. The 48 px boxes then place themselves on
the margin the way every other surface does.

Drawing the box is the second half of that. The header actions were previously
bare glyphs, and a bare glyph on a black page three pixels off the shared line
reads as a squashed layout rather than as a control. A bordered square the size of
the touch floor reads as an object, and putting its *edge* on the margin is what
makes the header actions, the cards beneath them, and the keypad agree on one
vertical line.

The centring is deliberately geometric rather than `AppBar`'s `centerTitle`. The
framework flag centres the title in the space *between* the leading and the
actions, so a screen with an action and a screen without one put their titles at
two different x positions — two headers that look identical on the mockup
disagreeing on the device. An equal-width blank on the action-less side costs
nothing and removes the case.

`AppHeader`, `AppHeaderTitleAlignment`, `AppSizes.headerIconInset`, and the
calculator's `_CalculatorTopBar` are all removed. The `AppBarTheme` entry stays in
`AppTheme`: `AppBar` is still what a future system surface would use, and removing
it would be an unrelated change.

**Consequence:** `header_alignment_test.dart` measures the *box* of each header
action rather than its glyph, and asserts each secondary title's centre against
the screen's centre. The History title moves from start-aligned (D-72) to centred.
The History delete glyph returns to `AppIconSize.row` (22) because the box carries
the weight now — the 28 px glyph and the 56 pt target D-72 derived for it are no
longer needed, since the glyph is no longer what has to reach the margin.
`store/play/screenshots/*.png` are stale and need `tool/generate_assets.ps1` to
re-render.

**Supersedes:** D-72's start-aligned History title and its `AppIconSize.large`
header glyphs. **Amends:** D-70 (the 24 px margin still holds, but it is the
action's box rather than its glyph that rides it) and D-10 (the History header is
still a back arrow, a title, and a conditional trash).

---

## 4. Residual Unknowns

**Both are now closed.** Phase 9 decoded the four mockup PNGs and measured them
directly, which no earlier phase could do — Phases 2–8 each closed by recording
that the source images could not be read, so every geometric value until now came
from `desing.md`'s prose rather than from pixels.

| # | Item | Resolution | Where |
|---|------|-----------|-------|
| R-1 | **Toggle OFF track color** | **Closed as chosen, not measured.** All three mockup toggles are ON (track 44 × 25.5 px, `#F89508`); no mockup contains the OFF state, so no measurement is possible. `#2A2A2A` accepted as a design decision. | **D-61** |
| R-2 | **Exact calculator key diameter** | **Closed at 88 px** on the 442×890 canvas. The key rows measure 86.5–87.5 logical px; the 2–3 px excess was caused by the 20 px screen margin, not by the keys. Correcting the margin to its measured 24 px (**D-60**) fixed both. | **D-60** |

R-2 is the more instructive of the two. It was carried as "a range of 85–95 px, not
a single defensible value" because Phase 1 measured a *consequence* — the key size
falls out of the margin and the gap, and the margin was wrong. Correcting the cause
produced the value that the range had been bracketing.

Neither item was a blocker, and no phase was delayed waiting on them.

---

## 5. Decision Index

| ID | Subject | Closes |
|----|---------|--------|
| D-01 | Platform and stack | `struction.md` §15.1–4 |
| D-02 | History persistence | `struction.md` §15.3 |
| D-03 | Palette source of truth | `desing.md` §12 |
| D-04 | Project root and docs layout | `struction.md` §14 |
| D-05 | Clear History confirmation | `prd.md` §14.5 |
| D-06 | Percent semantics | `prd.md` §14.1, `feature.md` FEAT-CALC-005 |
| D-07 | Privacy / Terms destination | `prd.md` §14.3 |
| D-08 | Rate App behavior | `prd.md` §14.4 |
| D-09 | Orientation and form factors | `desing.md` §10, `struction.md` §15.5 |
| D-10 | History header layout | `desing.md` §6.2 |
| D-11 | Developer name | `prd.md` §14 (assumption 5) |
| D-12 | Application identity | `struction.md` §15.1 |
| D-13 | Mockup-to-screen mapping | `prd.md` §1, `desing.md` §6 |
| D-14 | Decimal places mid-calculation | `prd.md` §14.1 |
| D-15 | Individual history deletion | `prd.md` §14.2 |
| D-16 | Feedback dependencies | `feature.md` FEAT-FEEDBACK-001 |
| D-17 | Operator precedence / evaluation | `feature.md` FEAT-CALC-002, `struction.md` §5–6 |
| D-18 | Thousands separators | `feature.md` FEAT-CALC-001, `desing.md` §3 |
| D-19 | No backspace key in the engine | `desing.md:181` / `prd.md:297` keypad has no ⌫ |
| D-20 | Screen entry points and navigation graph | `prd.md` §7, `feature.md` navigation, `struction.md` §7 |
| D-21 | Decimal places rounds, never pads | Unspecified half of D-14 |
| D-22 | Android-only target for v1.0 | Platform scope implied by D-01 / D-08 |
| D-23 | `url_launcher` is transitive only | Apparent conflict with `struction.md` §15 |
| D-24 | Number formatter lives in `core/utils` | `struction.md` §11 vs §14 layering |
| D-25 | Component catalog is a debug-only route | "Optional but recommended" catalog in `phases.md` §Phase 3 |
| D-26 | Unmeasured colour tokens are named tokens | Unspecified divider color; part of R-1 |
| D-27 | Keys are sized by their container | R-2 sizing model |
| D-28 | `CalculatorButton` takes a variant, not a `CalculatorKey` | Keeps D-24 the only `core → features` import |
| D-29 | The wide `0` key is a stadium | Internal contradiction in `desing.md` §5.1 |
| D-30 | The engine owns numbers, the display owns formatting | D-14's mid-calculation requirement; `phases.md` §Phase 4 display wiring |
| D-31 | `2 + =` repeats the pending operator | Unanswered FEAT-CALC-002 edge case under D-17 |
| D-32 | Auto-shrink thresholds for the primary line | Unspecified numbers in `desing.md` §10 |
| D-33 | Entry limits live in the engine | Input validation, not presentation |
| D-34 | `FeedbackService` takes flags, not the provider | D-16 implementation; D-02 Phase 6 sequencing |
| D-35 | `CalculatorState` exposes `justEvaluated` | Recording needs to know an `=` produced a result; `phases.md` §Phase 5 |
| D-36 | `2 + =` is recorded as a completed calculation | D-31 repeats the pending operator, so it is a real evaluation; `prd.md` AC-002 |
| D-37 | Loading a history result produces a fresh usable value | `feature.md` FEAT-HIST-002; the result must be an input, not a finished display |
| D-38 | The header trash always renders; the bottom clear action hides when empty | `desing.md` §6.2 shows a fixed header and an in-list clear button |
| D-39 | Calculator depends on history; history never imports calculator | Prevents a feature import cycle; `struction.md` §9 |
| D-40 | History enablement is a repository concern, injected as a callback | D-02 defers settings persistence to Phase 6, but AC-005 must hold now |
| D-41 | Settings are a synchronous view over an async notifier | D-34 needs a synchronous read on every key press; Phase 4's "replace the type" note |
| D-42 | Settings are five primitive keys, and a bad key degrades one field | `struction.md` §10 key names; `getInt`/`getBool` throw on a type mismatch |
| D-43 | A write made during the initial load wins | Optimistic publish (**AC-004**) vs. a cold-start load resolving afterwards |
| D-44 | `preferencesProvider` moved to `core/storage/` | One plugin touch-point that neither feature owns; D-39's one-way rule |
| D-45 | The Theme row is display-only; the core theme provider is not rewired | Adding the second `core → features` import for a single-arm branch; D-24, D-28 |
| D-46 | Decimal Places is a modal sheet offering 0 to 6 | `prd.md` says "sub-screen" but no mockup exists; the range is unstated anywhere |
| D-47 | `AppSettings` gains value equality | `settingsProvider.select` compares with `==`; D-14 rebuild precision |
| D-48 | The Settings screen copy was brought into conformance with the docs | Phase 3 placeholders contradicted `desing.md` §6.3 and `feature.md` §C |
| D-49 | The store listing is a URL built from the package name | The dead `playStoreListingId` field |
| D-50 | The About screen uses the documented copy, not new prose | `desing.md` §6.4 subtitle; placeholder description from Phase 3 |
| D-51 | Rate App implements D-08 literally | `prd.md` AC-012 fallback; store-side prompt quota |
| D-52 | About carries a Terms row but no Privacy row | `desing.md` §6.4's three rows; D-07 destination residue |
| D-53 | Plugin calls run behind service seams and fail softly | FEAT-ABOUT-003 platform interaction, `struction.md` §12 |
| D-54 | Text scaling is clamped to 1.0×–1.3× app-wide | `prd.md` AC-007's unstated range; fixed-token layout at 2× |
| D-55 | Cold start is proven by restarting the scope; no lifecycle observer | Phase 8's app-lifecycle task |
| D-56 | Transitions are go_router's default; no route customises them | Phase 8's transitions/navigation task |
| D-57 | The `settings_provider.dart` re-export shim is collapsed | D-41's shim note; import hygiene |
| D-58 | A failed history read shows a fixed sentence and a retry | `struction.md` §12 error-copy rule; Phase 8's error-state task |
| D-59 | Interactive rows announce as one node; switches keep their own state | `prd.md` AC-007 accessibility; Phase 8's accessibility task |
| D-60 | Screen margin is 24 px, which also fixes the key diameter | R-2; `desing.md` §4's "~16–20 pt" prose vs the measured card edges |
| D-61 | R-1 closed as chosen, not measured | R-1; no mockup contains a toggle in the OFF state |
| D-62 | Release signing reads a git-ignored `key.properties` and fails loudly without one | Flutter template's debug-key fallback; the silent "accepted by no store" failure |
| D-63 | The size lever is ABI delivery, not obfuscation | Implicit "48 MB APK = shrinking problem" assumption |
| D-64 | R8 and resource shrinking are on, with near-empty keep rules | Flutter template's `isMinifyEnabled = false` |
| D-65 | Cloud backup and device transfer are both switched off | Privacy Policy's "history never leaves the device" claim |
| D-66 | Two-layer adaptive launcher icon, no monochrome layer | Flutter template's default `ic_launcher.png` |
| D-67 | Store artwork and screenshots are generated, not hand-committed | `phases.md` §Phase 10 "prepare store listings" |
| D-68 | Legal copy lives in a data file and its claims are test-gated | D-07's unspecified copy content |
| D-69 | The keypad renders the gaps it declares; the screen is one capped column | A UI pass on the 442×890 canvas: keys touching, grid off-centre, display detached from the `=` column |
| D-70 | Header chrome is pinned to the 24 px optical margin; the empty state centres in its scroll view | A UI pass: `AppBar`/`IconButton` defaults put the glyphs 3 px inside the line, and a `Center` in a scroll view does not centre |
| D-71 | The Settings header is the title alone, at a compact size | D-48's header subtitle; the 88 px bar no other screen has |
| D-72 | The History screen is rebuilt around large, inset cards | The History redesign: a compact list and a spacious one share none of their values |
| D-74 | Every header is a `Row`, and its actions are bordered squares | `AppBar`'s leading slot and action inset, which `AppHeader` had to derive around (D-70) |
| D-75 | No header carries a subtitle; every one is the title alone at the shared size | D-71's About subtitle — the last screen still passing one |
| D-76 | Every header sits 24 px below the safe area | The `AppBar`'s own inset, which left the gap to be guessed |
| D-77 | The History card takes Ethar's 14 px corner | D-72's 30 px "its own thing" corner, which the 88 pt card could not justify |
| D-78 | The display is two screens: the calculation above the output | The single bottom-aligned block §6.1 drew, with an 8 px gap between its lines |
| D-79 | The output line previews the calculation live, so `=` never moves the number | The output line showing the entry being typed, so `99 + 5` read `5` and the answer only appeared on `=` |
| D-80 | An operator with no left operand is ignored; `±` and `%` act on the operand, never the running total | `+` on a fresh calculator leaving a pending operator, so the next number rendered as `+ 5`; `2 + ±` negating the accumulator |

---

### D-75 — No Header Carries a Subtitle; Every One Is the Title Alone

**Decision:** the `subtitle` parameter is removed from `SecondaryPageHeader`, so no
screen can pass one. About — the only real screen that still did, with "Simple
calculator, powerful features" — is now `SecondaryPageHeader(title: 'About')`, as
is the debug component catalog. With the two-line header gone everywhere, D-71's
28 pt compensation for Settings is dropped too: Settings paints the shared 32 pt
`screenTitle` like every other page.

**Rationale:** D-71 already argued that the Settings subtitle restated what the
rows beneath it say. The same argument holds for About, and it holds harder —
"Simple calculator, powerful features" is marketing copy sitting above a hero card
that already says "A simple, fast and reliable calculator for your everyday needs",
so the header was a weaker restatement of text further down its own screen. Having
one screen out of six opt out of a shared component's behaviour is worse than
either uniform choice: the parameter had a single real caller, so it was surface
area maintained for nothing.

The parameter is **removed rather than left unused**, because a nullable subtitle
still on the constructor is an invitation: the next screen that wants a banner
passes one, and the two-line header returns without anyone deciding to bring it
back. Single-purpose is the cheaper thing to maintain.

The size change follows rather than leads. 28 pt existed to stop a 32 pt title
reading as an oversized banner once the line under it was gone — but that
reasoning was scoped to Settings *having* had a subtitle, and it never applied to
History or the legal screens, which have always been 32 pt with no second line. Now
that no header has one, keeping Settings smaller would make it the odd one out in
the opposite direction. One title size for all six headers is the state with
nothing to explain.
`AppTypography.screenTitleCompact` is kept: it is a documented `desing.md` §3 token
with its own range assertions, and it is now simply unused.

**Consequence:** D-71 is amended, not reversed — its reasoning about the subtitle
still stands, only its size outcome is superseded. The D-54 clamp test moves from
About's subtitle to About's title, since the header still has to fit a grown line.
`store/play/screenshots/03-settings.png` and `04-about.png` are both stale and need
`tool/generate_assets.ps1` to re-render.

**Supersedes:** nothing. **Amends:** D-71 (Settings returns to the shared size)
and D-48 (whose About subtitle is the last one standing).

---

### D-76 — Every Header Sits 24 px Below the Safe Area

**Decision:** A new token `AppSpacing.headerTopGap = 24` is applied as top padding
*inside* `AppPageHeader` and `SecondaryPageHeader` rather than by each screen. The
calculator screen's keypad reserve subtracts it alongside `AppSizes.headerHeight`,
because the padding sits outside the header's `ConstrainedBox` and the bar is
therefore `headerTopGap + max(headerHeight, content)` tall as laid out.

**Rationale:** A header resting flush against the status bar reads as trapped
rather than chosen. The gap is one `xl` step — the same step
`AppSpacing.screenHorizontal` already uses for the side margin, so the top and
side margins speak the same scale — and it matches what the QR Scanner app already
puts above all ten of its own headers. It is a named token rather than a bare `xl`
because a token whose *name* says "above the header" can be read at the call site,
where `AppSpacing.xl` in a header's padding would only say "medium-large".

Stating it in the two components rather than in the seven screens that use them is
the whole of the change: a new screen inherits the gap by constructing the shared
header, and cannot come out flush against the status bar by forgetting a
`SizedBox`. It stacks with the `SafeArea` inset rather than replacing it — one
clears the system, the other is the design's breathing room — which is also how the
scanner app composes the two.

The reserve subtraction is not optional. `AppSizes.headerHeight` bounds the *row*;
the padding is applied outside it. Leaving the reserve at 56 would overstate the
available height by a full 24 px, which does not merely look wrong — it pushes the
keypad's last row past `AppSpacing.bottomSafe` and becomes a render overflow on
every short viewport.

**Consequence:** One test changed rather than passed silently. On the shortest
History viewport (360×640) the extra 24 px costs exactly one card — four finish
whole where five did — so `history_responsive_test.dart`'s floor drops from 5 to 4.
The complaint that test exists for is unaffected: D-72's 150 pt card fitted three,
so a list that opens on entries rather than posters is still what the page does.
The cost is stated in the test rather than absorbed, because a threshold that
quietly moves with a layout change is a threshold that can move for any reason.
Screenshots of every screen in `store/play/screenshots/` are stale and need
`tool/generate_assets.ps1` to re-render.

**Supersedes:** nothing. **Amends:** D-74 (the header components now carry a top
padding) and D-69 (the keypad reserve names the bar's full height).

---

### D-77 — The History Card Takes Ethar's 14 px Corner

**Decision:** `AppRadius.historyCard` goes from 20 to **14**, the radius the Ethar
app gives its Create Task option cards (`Ethar/lib/src/features/tasks/task_editor.dart:490-556`
— `_TaskOption` draws `_appCard(radius: 14)` behind every Due date, Repeat, Time,
Priority, Category, and Reminder row, and gives the `InkWell` the same 14). The
token keeps its own name and its own doc comment; only the number moves. Nothing
else in the app changes: `AppRadius.card` is already 14, `AppRadius.tile` and
`AppRadius.iconButton` stay 12, and `AppRadius.dialog` stays 20.

**Rationale:** D-72 wanted History to read as "its own thing" and spent 30 px of
corner saying so; D-73 rescaled the card from 150 pt to 88 pt and correctly pulled
the radius back to 20, but it kept 20 on the *reasoning* that a single large
surface should be softer than the container its rows sit in. That reasoning was
never a design requirement — it was a description of how the value had been chosen,
re-read as an argument for keeping it. Nothing in desing.md asks for a History card
to be softer than a Settings group, and the two are the same object: a rounded
surface holding rows the user taps. So the number was carrying an argument it
could not make.

The real constraint was never in this app. These two are sibling apps a user moves
between, and the card is recognisable across both — Ethar's task option and this
app's history entry are the same gesture, the same row, the same surface. Twenty
against Ethar's fourteen is a difference no user can name but every eye registers
as "these are not quite the same app", which is the one thing a shared design
language exists to prevent. Fourteen also sits at the midpoint of desing.md §5.3's
12–16 range rather than at its top edge, so the change is toward the documented
specification, not away from it.

**Consequence:** `design_system_test.dart`'s History-geometry test asserted
`AppRadius.historyCard` > `AppRadius.card` — D-73's "softer than its group" written
as code. That assertion is now `equalTo` plus an explicit `14`, so the parity is
pinned in both directions: a future edit that moves one token and not the other
fails, and one that moves both is a deliberate edit rather than a silent one. The
token is *not* deleted and folded into `AppRadius.card`, though the two now hold the
same number: they are different objects at different sizes, and the day a 150 pt
card and a 68 pt row need different corners, a single shared value would make that
a breaking change instead of a one-line adjustment. `history_responsive_test.dart`
and `design_system_test.dart`'s rendered-widget assertions were already token-based
and needed no change beyond a stale "20 px" in a doc comment.

No layout, height, or spacing moved, so the row counts in the responsive tests are
untouched. `store/screenshots/02-history.png` is stale and needs
`tool/generate_assets.ps1` to re-render.

**Supersedes:** nothing. **Amends:** D-73 (the History card radius is 14, equal to
the grouped cards', rather than 20) and D-72 (the 30 px "its own thing" corner).
D-72's and D-73's *sizing* work — the 88 pt floor, the 24 px margin, the type
bands — is untouched and remains in force.

---

### D-78 — The Display Is Two Screens: the Calculation Above the Output

**Decision:** `CalculatorDisplay` splits the space it is given into two equal halves. The
**upper half** is the calculation screen — `AppTypography.expression`, right-aligned and
ellipsised, unchanged — and the **lower half** is the output screen — `AppTypography.resultLarge`,
stepping down to `resultMedium` past `compactResultLength`, right-aligned, scaled down by a
`FittedBox` only when it cannot fit. Each line centres in its own half, so the display no
longer aligns its block against the keypad: `mainAxisAlignment: end`, the `Flexible` expression,
and the 8 px `AppSpacing.sm` between the two lines are all gone, and the widget now carries a
`calculator-display` key so the split can be measured rather than inferred. `CalculatorDisplay.minimumHeight`
becomes **two result line boxes** — `2 × 66 = 132` at 1×, against 104 before — because the two
halves are equal and each must hold the taller line. `AppSpacing.calculatorDisplayGap` and the
1 px rule inside it are untouched, and the keypad's geometry at the 442×890 reference (88 px
cells, 496 px grid, 266 px display) is unchanged.

**Rationale:** the display was carrying two different things in one bottom-aligned block — the
sum the user is *writing* and the number it *produced* — with an 8 px gap as the only thing
separating them. Both change on the same keypress, and the vertical space §6.1 asks for sat
entirely above the pair, doing nothing. Giving the space to the two lines gives each of them
one job: the expression grows down from the top half, the result settles in the bottom half,
and the boundary between them is the display's own midline rather than a value someone has to
choose and then defend. The result also rises clear of the keys instead of resting on them —
at the reference canvas it moves 33 px up — while the ruled gap that separates the display from
the keypad stays exactly where it was (the request that produced this decision).

**Consequence:** the reservation grows from 104 to 132 at 1×, and that 28 px comes out of the
keypad wherever the screen is short enough for the keypad's height to be the binding axis. At
320×568 the cell falls from 56 to 50.4 px — still above `minTouchTarget`'s 44 px floor — and
the display lands on its 132 px minimum exactly. Below that the keypad wins and the display
compresses, as D-69 says it must. `calculator_layout_test.dart` bounded the display-to-keypad
gap by `calculatorDisplayGap × 2`; that bound is now *half the display*, because the result sits
in a half rather than against the keys, and the group is renamed to state the split. The two
`CalculatorDisplay.minimumHeight` assertions in `text_scaling_test.dart` moved with the formula,
and the second lost its `- AppSpacing.sm` term: the reservation is now two line boxes with no
layout constant between them, so it scales cleanly. `AppSpacing.sm` no longer has a caller in
the display and its desing.md §4 row no longer claims one.

**Supersedes:** desing.md §6.1's "the display is bottom-aligned" and the 8 px gap between its
two lines. **Amends:** D-69's display/keypad composition, whose ruled gap, capped column, and
measured cell are all unchanged.

---

### D-79 — The Output Line Previews the Calculation Live, so `=` Never Moves the Number

**Decision:** the lower half of the display shows what `=` *would* produce, updated on every
keystroke. It is derived in `display_resolver.dart` by the new pure `previewValue(state)`, which
folds `pending.apply(value, operand)` when an operand is in progress and otherwise falls back to
the entry or the running total. Nothing about the engine changes: the accumulator, the expression
terms, and history are untouched until an operator or `=` commits the fold, so D-17's left-to-right
evaluation and D-30's ownership of numbers by the engine both stand. The expression line carries
the operand being typed alongside the pending operator, so `99 + 5` reads in full above the `104`.
The preview is rounded to `decimalPlaces` (D-14) so it shows exactly what `=` will show, and the
digits still being typed are grouped but never rounded on the line above (D-30). A fold that is not
finite — `5 ÷ 0` — keeps showing the running total rather than flashing `Error` at a user who is
still typing the divisor; `Error` remains `=`'s answer for the finished calculation (desing.md §9).
As a consequence, `=` is a visual no-op: the number on screen is already the answer.

**Rationale:** the output line was showing the *entry* while a second operand was being typed, so
the calculation in progress had no visible answer. `99 + 5` displayed `99 +` above and `5` below,
and the user could not see the result of their own arithmetic until they committed it — the one
thing the large half of the display exists to show. The iOS, Android, and Windows calculators all
preview, and the preview is a projection of state rather than a second calculation: deriving it in
the resolver keeps the engine's contract ("nothing folds until it is committed") intact, and
`decimalPlaces` stays a formatting-only concern, so changing the setting re-renders the preview
without the engine ever being told about it.

**Consequence:** `resolveExpressionLine` appends the in-progress entry, so a state that used to
render as `100 +` now renders as `100 + 7` — the widget-test expectation in `cold_start_test.dart`
moves with it. `resolveDisplay` now routes through `previewValue`, and a lone number being typed
with no pending operator is still shown exactly as entered. Because the operator glyph is only
appended behind a committed term, a state the engine does not produce can no longer print a lone
`+` either.

---

### D-80 — An Operator Needs a Left Operand; `±` and `%` Act on the Operand, Never the Total

**Decision:** `_inputOperator` returns early when there is no entry and no value, so an operator
pressed on a fresh calculator — or right after an error, which leaves the same empty state — is
**ignored** rather than remembered, and the next digit starts the calculation. A number can
therefore never be printed behind an operator. Because the press changes nothing,
`CalculatorController.press` compares the new state against the previous one and returns early, so
a declined press produces no key feedback and no history write: a key that did nothing must not
look or sound like one that did. This also fixes a duplicate history entry, since a second `=` on
an unchanged result is now recognised as the no-op it is.

The same rule governs the two unary keys, both of which used to reach past a pending operator and
rewrite the running total. With an operator waiting and no operand typed, `%` does nothing and `±`
stages a sign for the operand to come, so `2 + ± 5` is `2 + (-5)` rather than `-2 + 5`. The staged
sign is held as a boolean flag rather than a lone `-` in the entry text, because a sign is not a
number and storing it as one would mean filtering it back out of every reader of `entry`,
`resolveExpressionLine` included; the first digit then rides on it (`-5`, and `-5` rather than
`-05` from `± 0 5`). On a fresh calculator `±` stages the sign too, so `± 5` is a way to type
`-5`, and a second press cancels it. A lone computed total with no operator waiting is still
negated in place, and `%` still divides the operand by 100 (D-06), never reinterpreting it against
the accumulator.

**Rationale:** `+ 5` on a fresh calculator is meaningless — the operator was being remembered with
nothing behind it, so the expression line printed `+` and the display read `+ 5`. Ignoring the key
is the honest response and matches every phone calculator. The unary fixes follow from the same
principle: `±` and `%` describe the *number the user is looking at*, and while an operator is
waiting that number is the operand still to be typed, not the accumulated total. Negating or
scaling the total instead silently changed a calculation the user had not finished, which is the
same class of defect as an operator with no left operand.

**Consequence:** the engine tests for "an operator after an error dismisses it" and "`±` does
nothing when there is no number to act on" now assert the new behaviour — the pending operator
stays `null`, and `±` signs the next number. `apply('+')` is now `CalculatorState.initial`, and
`resolveExpressionLine` has no lone-operator case left to render. D-31 (a trailing operator
repeats the running value) and D-19 (no backspace) are unaffected, and `2 + =` is still `4` —
that path has a left operand, so the operator is accepted.

---

### D-81 — Backspace Deletes One Character of the Editable Expression, Before or After `=`

**Decision:** the ⌫ control above the display keeps D-19's place *outside* the keypad
(it is not a twentieth `CalculatorKey`), and its single rule is: **each press deletes exactly
one character of the expression the user is editing — in every state.** There is no cascade
of targets (entry, then pending operator, then last committed term): the expression string
*is* the editing buffer, because the engine never replaces it with the result.

So `900 + 100 =` is `1000`, and the first ⌫ both leaves the result state and deletes a
character: the line reads `900 + 10` previewing `910`; ⌫ again gives `900 + 1`, then
`900 +`, then `900`, then `90`. A value loaded from history follows the same rule — its
first press shortens the number (`1000` → `100`) instead of "restoring" an expression that
was never replaced. Deleting back to empty clears the preview as well, so the display reads
`0` rather than freezing the last number it showed.

`CalculatorState.canBackspace` is simply `!isError && expression.isNotEmpty`, so the control
greys out exactly when a press would do nothing; the error state still declines, and `AC`
(or any key, which dismisses the error) is the documented way out.

**Rationale:** the previous implementation "restored" `_lastExpression` on the first press
after `=` — but in the expression-string engine that restore was always a no-op, because
`_expression` still held `900 + 100` behind the `1000`. The press looked dead: nothing on
screen changed, so a user read it as "delete does not work after a calculation", and a value
loaded from history had the same dead first press. Leaving the result state *and* deleting
in the same press makes every press visibly effective, matches the worked example above, and
folds the normal, post-result, and history-load cases into one code path.

The stale-preview fix rides on the same rule: `_recompute` clears the value when the
expression is empty. Freezing the old preview there made a fully-deleted calculator keep
showing its last result (`1`, `9`) instead of `0`, and let a stranded result outlive the
expression that produced it.

**Consequence:** a backspace is always an *edit of the expression*, never a calculation — it
clears `justEvaluated` without evaluating, so history never records one (the existing guard
in `CalculatorController._justCompletedACalculation` is unchanged). The keypad, its nineteen
keys, and every pixel of the display are untouched; only the engine's state transitions
changed.

**Known limits, stated rather than hidden:** the error state still declines — `AC` is the
documented way out of an error; the expression line blanks when only one bare number
remains, because the number itself is what the result line shows (the pinned D-18 layout);
a repeated `=` does not repeat the last operation (`2 + 2 = =` is `4`, which the engine
tests pin); and an operator is declined directly after `(` unless it is a minus, so `(+`
can never be typed into the parser.

---

### D-82 — A Five-Second Hold on Clear History Opens the Secret Screen

**Decision:** the History screen's **bottom** Clear History action carries a second gesture
alongside its tap. A hold of **five seconds** opens the secret PIN entry screen; **a tap is
unchanged** and still opens the confirmation gate (D-05). The header trash is deliberately left
alone: it is the always-present, screen-level delete (D-10), and hiding a second gesture there
would make the secret reachable from two places a user cannot tell apart. The bottom action is
the one reached for at the end of the list, which is where a deliberate gesture belongs.

The hold is a `GestureDetector` (`onLongPressStart`, `onLongPressEnd`, `onLongPressCancel`) with a
`Timer` of `SecretUnlock.holdDuration`, not Flutter's `onLongPress` alone — the framework's long
press fires at ~500 ms, and 500 ms is a tap that ran long, not a gesture that was held. The timer
starts on `onLongPressStart` and is cancelled on both end callbacks, so releasing early does
nothing and cannot leave a timer that fires against a disposed `State`.

**There is no progress indicator, no haptic, no sound, and no visible change while the button is
held.** This is the decision the feature rests on, and it is made *against* the obvious choice: a
filling ring or a tick would tell any user who happened to rest a thumb there that something is
happening, which turns a gesture nobody discovers by accident into one everybody does. The secret
screen is *meant* to be unreachable unless the user already knows. Five seconds is long enough
that no one reaches it by accident and short enough that the user who does know it never waits in
frustration.

**Rationale:** a visible entry point would not be a secret at all. Keeping the tap path unchanged
means the gesture is purely additive — D-05's gate is untouched, FEAT-HIST-003's contract is
untouched, and every existing test of that button still passes. Anchoring it to the bottom action
rather than the header keeps one delete affordance and one hidden one, so the screen never shows
two controls whose behaviour differs in an undiscoverable way.

**Consequence:** `history_screen.dart` gains an `onSecretRequested` callback and the widget that
detects the hold. Because the gesture is invisible there is **no affordance to test for at the
call site** — FEAT-SEC-001's tests pump the hold directly (`tester.startGesture` held for
`holdDuration`) rather than looking for a control. The button's existing key
(`history-clear-button`) is unchanged so current finders keep working. FEAT-HIST-003 and D-10 are
**amended**, not superseded.

---

### D-83 — The Secret PIN Is a Plain Key in `shared_preferences`, Defaulting to `0000`

**Decision:** the PIN is a **four-digit decimal string** stored under the single key `'secretPin'`
in `shared_preferences`, exactly as D-02 requires of every other preference, and it defaults to
**`'0000'`** when the key is absent. The feature lives in its own `features/secret/` module with its
own repository interface rather than joining `AppSettings`, because a PIN is not a user preference:
it is a credential, and that difference is what a reviewer is looking for when they open the file.

`SecretCode` is a value type that validates on construction — exactly four characters, each `0`–`9`
— and throws `FormatException` otherwise. Validation lives in the type rather than in an
`_isValid` check at the call site, so a malformed PIN cannot exist as a value: the repository cannot
load one and the setter cannot store one. The stored value is read back through the same
`_readOrNull` guard the settings repository uses, so a corrupt or hand-edited key degrades to the
default `0000` rather than bricking the screen (D-42's contract, reused verbatim).

**Rationale:** the plaintext store is the deliberate cost, stated plainly rather than buried.
`shared_preferences` is not encrypted, so on a rooted device the PIN is readable — a strictly
smaller claim than "the history is readable", and the same claim every other value in this app
already makes. The alternatives were rejected for concrete reasons: `flutter_secure_storage` would
add the app's **first new dependency** since Phase 1 (D-01, struction.md §15), breaking the
lockdown that has held through ten phases; a hash would gain nothing, because the threat here is
*reading* the store, not *brute-forcing* it — four digits is 10⁴ guesses, and a hash with no rate
limit (D-85) is no stronger than the plaintext it replaces.

**Consequence:** recorded as a known limitation in `phases.md` rather than presented as a security
guarantee. **No new package** is added. `SecretCode` needs unit tests for its validation and for
the corrupt-value fallback; the repository needs the same load/save round-trip test the settings
repository has (`settings_repository_test.dart` is the model).

---

### D-84 — The Secret Screen Is Blank, With One Overflow Dot in the Top-Left

**Decision:** once unlocked, the secret screen is an **empty black page** whose only content is a
single `AppIconButton(icon: Icons.more_vert)` in the **top-left**, sitting exactly where the
calculator's own header actions sit. No title, no subtitle, no logo, no empty-state illustration, no
"you found it" copy, and no back arrow of its own — the system back gesture is the only way out, so
the screen gives no hint that it is reachable or that it is anywhere at all.

The button is the **shared** `AppIconButton` (D-74), not a bespoke glyph, so it is the same 48 px
bordered square as every other header action in the app. That is the whole trick: the affordance
looks completely ordinary, because a control that looked special would announce the screen it lives
on. Its `tooltip` is `'Settings'` and it opens the secret Settings screen — a single
`SettingsGroup`-wrapped page holding **exactly one row, "Change PIN"** (the full Settings page is
deliberately *not* duplicated here).

**Rationale:** the blankness is the feature. A secret screen that congratulates the user for finding
it is a secret screen a screenshot spoils, and a screen that names itself in its title bar is one
every shoulder-surfer can read. Reusing the app's own button, in the app's own place, means the
whole discovery cost of the feature is carried by the five-second hold (D-82) alone. Shipping only
the PIN row rather than the full Settings page is the same instinct applied to scope: this screen's
job is to change the PIN, and duplicating the other four preferences inside a hidden page would
create a second place to maintain a setting with no user to reach it.

**Consequence:** the blank page is genuinely hard to test *by looking* — there is one control, so
the tests find it by key, not by text. `desing.md` gains §6.8 and §6.9 for the two screens, and
§12.2 records that **neither exists in any mockup** (D-13 maps all four mockups to real screens and
this is not one of them), so there is no pixel to match. **No new design token is added**: the page
uses `AppColors.background`, the button uses `AppIconButton`, the PIN row uses the existing
`SettingsGroup` / `SettingsRow` — if a new colour or size were needed for a blank page, the page
would not be blank.

---

### D-85 — A Wrong PIN Clears and Shakes; Nothing Is Locked

**Decision:** four wrong attempts are treated as four wrong attempts. The entered dots clear, the
indicator shakes, and the user may try again immediately. There is **no** attempt counter, **no**
lockout, **no** delay, and **no** self-destruct. On a correct code the entry screen pops and the
secret screen is revealed. Changing the PIN requires the **current** PIN to be entered first.

**Rationale:** a lockout is the kind of feature that looks like security and is actually a
denial-of-service tool aimed at the owner. The threat model has no attacker holding the device —
anyone standing at an unlocked phone clears the history from the same screen. Someone who mistypes
their own PIN and is locked out of the only page that can reset it has been punished for forgetting
a four-digit number they chose, and the recovery path would be a reinstall, which loses the history.
Rate limiting also costs a `DateTime` comparison and a persisted counter to protect something four
digits never made safe: 10⁴ combinations brute-forced in under a minute on any device, and D-83's
plaintext store means the code is readable without any guessing at all.

**Consequence:** the shake is the *only* wrong-PIN feedback, which is exactly why it is worth having
— it distinguishes "wrong" from "nothing happened" without a message that would confirm the screen
is real. Because reset requires the current PIN, a forgotten PIN has **no in-app recovery** and a
reinstall is the only route; this is recorded in `phases.md` as a known limitation rather than left
for a user to discover. The entry screen's test asserts the dots clear on a wrong code and that a
subsequent correct code still works.

### D-86 — A Floating White Home Button, a Reset PIN Route, and a Prompt That Explains Itself

**Decision:** three reversals of D-84 and §6.8, taken together because they answer one complaint: a user who
reached Secret Mode could not tell what they were looking at and could not get out.

1. **A floating white home button on both secret screens.** A **56 px white circle** in the
   **bottom-right**, black `home_outlined` glyph, carrying the tooltip and semantics label *"Back to
   calculator"*, navigating to `/` with `go`. It is the second control on the blank secret screen and the
   only exit from the PIN screen.
2. **"Reset PIN" as a second row in the secret settings page**, after "Change PIN", behind
   `AppConfirmationDialog`. It erases the stored code so the next unlock requires `0000`.
   A **"Forgot PIN?"** link on the PIN screen opens the same dialog.
3. **The PIN screen gains two strings of guidance**: "Enter your PIN" above the dots, and "Forgot PIN?"
   below them. Neither names the feature; neither names the code.

**Rationale:**

*The home button* reverses a decision that argued well — "the blankness is the feature", and a page that
shows nothing is a page a screenshot spoils. But the same decision that made the page blank also made it
**inescapable by the obvious route**, and that is the part that does not survive contact with a user. On the
PIN screen the system back gesture is not an exit from Secret Mode at all: it pops to History, leaving a user
who held the button by accident inside a hidden area with four dots, a keypad, and no way to reach the
calculator. A screen a user cannot leave teaches the wrong lesson — that the app has trapped them — and that
is a worse way to reveal a hidden feature than an extra button is. The button does **not** spoil the
*feature*: the five-second hold (D-82) still has to be known to reach either screen. What it spends is
deniability about a page's contents, and reachability is worth more when the alternative is a trapped user.

*Placement and palette* are the FAB position and the app's own inverted pair — `AppColors.textPrimary`
(white) behind `AppColors.textOnFunction` (black) — because that is a shape and contrast every phone user
already reads as "return to the main thing". **No new colour token is added.** D-84 warned that a blank page
needing a token would be the signal it had stopped being blank; it has stopped being blank, and recording
that it did so *without* opening the palette keeps the token files honest about what is product identity and
what is furniture.

*The reset route* completes D-85 rather than contradicting it. D-85 declined a lockout on the reasoning that
"the only recovery would be a reinstall, which loses the history" — this **is** that recovery, made
reachable. **The cost is stated plainly: anyone who reaches the screen can now wipe the PIN in one tap.** That
is a real reduction in the feature's only protection, and it is accepted because the threat model D-85 already
describes has no attacker holding the device, and because the alternative is a user locked out of the one
page that can change their code, with a reinstall as the answer.

*Why the dialog names `0000`* — the one place the feature ever speaks the code. §6.8 withholds it so a
bystander's screenshot cannot spoil it, but a user who has *forgotten* their PIN cannot act on the
withholding: the information is precisely what they need, and by the time the dialog is on screen they have
already committed to being here. The prompt above the dots says nothing about the code, and a test asserts
that.

**Consequence:** `SecretRepository` gains `clear()` (a `remove`, not a `save` of the default — nothing that
looks like a stored credential is left behind), and `SecretCodeNotifier` gains `reset()`. AC-020's "only
control" wording and "exactly one row" are amended; **AC-022** is added for the reset. D-84's clauses on
*content* — no title, no logo, no copy, no illustration, no back arrow — all still hold; only the control
count and the exit policy changed. The reset is deliberately **not** reachable from the Change PIN flow,
where offering a way to destroy the code being chosen would be a trap.

---

### D-91 — The Settings Card Takes Ethar's Recipe Whole: Outline, Shadow, and a 44 px Icon Tile

**Decision:** `SettingsGroup` paints `surface`, a 1 px `cardBorder` outline, radius `AppRadius.card`, and — **in the white theme only** — a `cardShadow` at blur 24 offset (0, 8). `SettingsRow`'s leading glyph becomes a 44 px `AppIconTile` (radius 13, `surfaceSoft` fill, 21 px glyph). `rowMinHeight` goes **56 → 64**, the group hairline moves from indent 16 to **72** with a new `endIndent` of 16, and `AppColors.divider` moves `#1A1A1B` → `#292D35`.

Source, verbatim: `Ethar/lib/src/features/settings/settings_components.dart`'s `_settingsCardDecoration`, `_SettingsIconTile`, `_SettingsRow`, and `_SettingsGroup`.

**Three tokens added, all copied rather than chosen.** `AppColors.surfaceSoft` (`#20232A` dark / `#FAFAFB` light) is the tile fill, `AppColors.cardBorder` (`#292D35` / `#ECEDEF`) is the outline, and `AppPalette.cardShadow` is a **nullable** `Color` — `null` in dark, `0x0D0F172A` in light. The null is the point: a `BoxShadow` list cannot say "no shadow", and a transparent black would make "absent" indistinguishable from "present and invisible" to anything reading the token. `lerp` therefore fades from whichever side has one rather than mixing a null.

**The outline is not decoration on a black page.** `#101011` on `#000000` is a difference a user can see and cannot point at; the 1 px edge is what makes a card an object rather than a slightly lighter patch. This is also why `divider` was retuned *upward* to meet it — a hairline darker than the outline around the card reads as a crease in the card, not as a boundary between rows. Ethar uses one value for both (`_SettingsColors.divider` **is** `border`), and so does this app now, under two names that say where each is drawn.

**The row height was forced, not chosen.** 44 px of tile plus the row's existing 20 px of vertical padding is 64 — at 56 the tile was either clipped or the padding squeezed. Ethar's `_SettingsRow` carries `minHeight: 64` for the same reason. The divider's 72 is the same arithmetic seen from the other side: it now starts where the **titles** start rather than under the leading icon, which was what made an icon look like it belonged to the row above.

**`ColoredBox` → `DecoratedBox`, and one public `decoration` helper.** A fill-only widget cannot draw an outline or a shadow, and a test should assert the *recipe* rather than the widget arrangement implementing it. `SettingsGroup.decoration(context)` is that seam; the internal `ClipRRect` stays, because the border has to sit on the same corner the rows are clipped to.

**One thing this cost, recorded because it was not obvious:** the trailing control is now `Flexible`. The 44 px tile took 22 px out of each row's fixed budget, and on the 320 px screen `about_screen_test` guards, an unbounded `Text` value (App Name, Version, Developer) pushed the row past its card. Ethar avoids this by bounding its value at `maxWidth: 105`; bounding rather than truncating blind is what stops the *title* from losing the space it needs to stay legible. **(Superseded on this point by D-92 — `Flexible` was the wrong tool for the bound, and the arrow and the switches floated mid-row as a result.)**

**Scope.** The change is in the shared component, so **Settings, About, both Secret pages, the decimal-places sheet, and the debug catalogue all take it at once**. That is the intent — the argument for a shared design language is that a user moving between two sibling apps meets the same object — but it means this was not a Settings-only edit, and any screen using `SettingsGroup` inherits the new height.

---

### D-92 — The Trailing Control Is Not a Flex Child: Theme's Arrow and the Three Switches Were Floating Mid-Row

**Decision:** `SettingsRow`'s trailing slot drops `Flexible` for a plain `ConstrainedBox(maxWidth: 105)` after an 8 px gap — Ethar's `_SettingsRow` arrangement, verbatim. The bound becomes the named `SettingsRow.trailingMaxWidth`. The Settings screen stops passing an explicit `chevron_right` as the Theme row's `trailing` and lets the row draw its own.

**What was actually wrong.** D-91 recorded that it made the trailing control `Flexible` "so the value is bounded". That solved the 320 px overflow and created a bug nobody could see in a token diff. `RenderFlex` divides the width left over between **flex children by flex factor**, and a loose `Flexible` never hands its unused share back — so the title's `Expanded` (flex 1) and the trailing's `Flexible` (flex 1) split the row's spare width **50/50**, and the trailing widget was drawn at the *start* of its own half. At the 442 px reference canvas that parked Theme's chevron **129 px** and each switch **91 px** short of the card's right edge, leaving the card's right padding visually bare on four of the eleven rows. A `Flexible` was never a bounding box; it is a *claim on half the remaining width*, and this row already had a claimant.

**The half nobody sees.** The title column was getting the same half. `"Keep calculation history"` wrapped onto two lines, so the History row rendered taller than its neighbours — a difference that reads as "this row is different" rather than as a bug.

**Why Ethar never had it.** Its `_SettingsRow` puts the value in a `ConstrainedBox`, which is **not** a flex child: `RenderFlex` lays out non-flex children first, at their own width, and only then measures the `Expanded`. The control lands at the row's end and the title takes everything left. Copying the *bound* without the *placement* is what D-91 did; D-92 copies both.

**Why the Theme row's explicit chevron went.** The row is tappable, so `SettingsRow` already draws a chevron — in the same 8 px gap and the same `ExcludeSemantics` as every navigational row. Passing one explicitly bought nothing visually and skipped the gap, which put Theme's arrow **8 px** right of App Version's, Privacy Policy's, and Terms of Service's. The affordance is unchanged; the alignment is now the same object as every other arrow on the screen.

**A bound, not a width.** 105 is a ceiling, not a size — a switch is 60 and a chevron 22, and neither should be stretched to fill it. Named rather than inlined so the test asserts the recipe against the same fact the widget reads, instead of restating `105` in two places and hoping they stay equal.

**Scope.** Same shared component as D-91, so Settings, About, the Secret pages, the decimal-places sheet, and the debug catalogue are all affected. The About screen's trailing values (App Name, Version, Developer) were the rows that motivated the original bound, so they are the ones the restored `ConstrainedBox` is really there for.

**Recorded but not changed.** Material 3's `Switch` with `MaterialTapTargetSize.padded` reserves **60 × 48** (`switchWidth 52 + 8` of horizontal padding, `switchHeight 48`), while the icon tile is 44. A toggle row therefore renders 72 px against 68 px for every other row. `MaterialTapTargetSize.shrinkWrap` would reserve 60 × 40, leave the painted 52 × 32 track and its centring untouched, and make every row 68 px — the whole row is the tap target either way, so no touch target is lost. Left alone here because it is a different defect with a different trade-off, not a consequence of the flex bug.

---

### D-93 — The History Card Takes Ethar's Task Card Whole: Outline, Shadow, Radius 12, and the Result as the Title

**Decision:** `HistoryCard` becomes a port of Ethar's `_TaskCard`
(`Ethar/lib/src/features/tasks/task_list.dart:363-550`) rather than a card that
converges on it. Four values change, and one of them is not a number:

1. **Outlined at rest.** The card gains a 1 px `AppPalette.cardBorder` outline.
2. **Shadowed.** It paints `AppPalette.cardShadow` at blur 22 / offset (0, 6) —
   Ethar's `_appCard` values — in whichever theme has one.
3. **Radius 12.** `AppRadius.historyCard` goes 14 → **12**.
4. **The lines swap rank.** The **result** is now the title — 17/w700 — and the
   **expression** is the meta row at 13/w400, preceded by a 17 px
   `schedule_rounded` glyph and a 5 px gap.

Plus the supporting measurements, all Ethar's: `AnimatedContainer` at 150 ms,
padding `EdgeInsets.symmetric(horizontal: 18, vertical: 17)` (new
`AppSpacing.historyCardHorizontal` / `historyCardVertical`), a 7 px title-to-meta
gap, and a selected border of 1.5 px (down from 2). The fill moves off the
`Material` onto the `AnimatedContainer`'s decoration so one widget owns the fill,
the outline, and the shadow together; the `Material` is now transparent.

**Rationale: the hierarchy flip is the substance; the rest is consistency.**
Ethar prints a task's title at 17/w700 over a 13 muted meta line
(`task_list.dart:496, 519`). Here the result takes the title's rank and the
expression takes the meta's, because the result is what the user came back to
read — `125 × 8` is how the row was made, `1,000` is what it is worth. D-73 led
with the expression at 16 over a 22 result, which put the setup above the answer,
and D-72 had pushed the result to 44 to fight for attention. Ethar does not make
a number bigger to win a card; it makes the number the *title*. So the result
drops from 22 to 17 and still reads first, because rank and scale are different
instruments and only one of them was being played too loudly.

The chrome is the same argument at the level of the surface. Three separate
decisions had each reasoned about this card in isolation: D-72 made it
borderless and shadowless because "on a black page the fill is the only edge",
D-77 matched its radius to Ethar's Create Task *option* rows, D-73 rescaled it
against desing.md's bands. Each was locally reasonable and the three together
produced a card that resembles its sibling only in the vaguest sense. Ethar
outlines every card in both themes; the outline, not the fill, is what makes a
`#151517` card an object on black. So the port takes the recipe whole, and the
three decisions' shared premise — that this card should be argued about
separately — goes with it.

**D-77's radius was tracking the wrong Ethar card.** It matched
`task_editor.dart`'s `_TaskOption` at 14; the *task card* is 12
(`task_list.dart:405`). Those are two different components that happen to share a
number, and a History entry is the same kind of object as the task card — a row
among peers, long-pressable, multi-selectable — not as an editor field row. Twelve
is also where desing.md §5.3's 12–16 band starts. `AppRadius.historyCard` keeps
its own name and is now asserted `isNot(AppRadius.card)` rather than equal to it:
the two must not drift back together.

**What was deliberately *not* ported.** Ethar's 34 px leading completion circle
has no meaning here — a calculation has no completed state, and inventing one
would put a checkbox on every row that does nothing. The trailing slot is
untouched: D-76's chevron/selection-circle pair stays, and the selection circle
stays at 28 rather than Ethar's 32, because it hangs on a card that is now
narrower and shorter than Ethar's row. Selection stays **white, not orange**
(D-76): selection is a mode, not a primary action, and nothing in a colour port
disturbs that reasoning. The dark theme draws no shadow, because `cardShadow` is
`null` there and a shadow on black is invisible — the same rule D-91's
`SettingsGroup` already follows.

**One consequence worth naming.** `Container` subtracts a border's width from its
child, so the `Material` inside the card now starts 1 px inboard of the 24 px app
margin (and 1.5 px when selected). The card's *outer edge* still sits exactly on
that margin — which is what D-73's alignment with the header's back arrow is
actually about — so the geometry contract holds, but it is now asserted on the
`AnimatedContainer` rather than the `Material`. Recording it because it is the
kind of one-pixel change that is invisible in review and obvious in a screenshot.

**Height is unchanged.** 17·1.25 + 7 + 13·1.3 is ~45 of content inside 34 of
padding, still under `AppSizes.historyCardMinHeight`'s 88, so the floor governs
and a 360 dp phone still fits four entries — the assertion `history_responsive_test`
has made since D-73.

**Supersedes:** D-72's borderless/shadowless rule and its 28/44 type scale; D-73's
expression-above-result order and its `cardPadding`-based padding; D-77's radius
14. **Unchanged by it:** the 24 px margin (D-73), the 88 px floor (D-72/D-73),
the day grouping, persistence, tap-to-load, the long-press gesture, the trailing
slot, and the selection palette (all D-76).

---

### D-110 — The Calculator Column Runs on a Tighter Margin, a Wider Gap, and a Larger Header
**Decision:** The calculator's single column — its header, display, and keypad —
leaves the screen at `AppSpacing.calculatorSideMargin = 16` rather than the
app-wide `screenHorizontal` 24. `CalculatorKeypad.keyGap` goes 14 → 16 and
`maxCellSize` 132 → 160. The calculator's two header actions take
`AppSizes.calculatorHeaderAction = 56` through a new optional `AppIconButton.size`
(which derives its glyph from a ratio rather than taking a second number), and
`AppPageHeader` takes an optional `horizontalPadding` so the calculator's bar
rides its own column while every other header keeps 24.

**Rationale:** The app looked right in every mockup and cramped on the device.
The cause was arithmetic nobody could see: the grid's cell is
`(width − 2·margin − 3·gap) / 4`, so the app's card margin was being *spent* on
air on a screen that has no cards at all. On the 442-wide reference canvas the
old numbers derived an 88 px key; the new ones derive 90.5 with 2 px more air on
every side. Widening the gap alone would have shrunk the keys — that is why the
two moved together and neither could be justified alone.

The header is the non-obvious half. A 48 px box above a 90 px key reads as a
header drawn for a *different, smaller* calculator, so the two header actions
scale to 56 — the bar's own height, and the app's existing rhythm, so it is not
a new size invented for one screen. They keep the identical fill, border, radius,
and glyph; this is a size, not a variant.

**Consequence:** `AppIconButton` takes two optional numbers, and `AppPageHeader`
one, so the 48 px / 24 px defaults still hold everywhere else — that is why the
new sizes are parameters rather than new widgets or a token edit.
`header_alignment_test.dart` now measures the calculator against **the keys below
it** rather than against the secondary headers' card margin (a bar sitting at a
correct 16 px but 8 px inboard of its own column is the drift worth catching),
and gained a second test asserting the secondary headers still sit at 24 and 48
— the counterpart that stops this from quietly becoming the app's margin.
`calculator_layout_test.dart` and `calculator_screen_test.dart` re-derive the
measured geometry: 90.5 / 410 / 516.5 rather than 88 / 394 / 496, and the R-2
diameter band moved with them, so a silent return to the compressed layout now
fails a test rather than passing one that was written for it.

**Supersedes:** D-60's 24 px margin and 14 px gap *for the calculator column
only* — both tokens stand, and every card edge in History, Settings, and About is
still measured at 24. D-69's `maxCellSize` 132. **Unchanged by it:** the palette,
the key variants and labels, the `_layout` arrangement, the wide `0` (D-29), the
two-line display and its right alignment (D-78/D-69), the backspace row (D-81),
the touch floor, and every other screen.

---

### D-111 — The Dark Theme's Keys Get a Glow, a Hard Edge, and Bigger Operator Glyphs
**Decision:** `AppColors.keyElevation` is **removed** and replaced by two palette
fields: `keyShadow` (dark `#1AFFFFFF` — a faint **white halo**, light
`#1F0F172A` — an ordinary dark shadow) and `keyBorder` (`#33333A` dark,
`#E4E6EA` light). `CalculatorButton` draws the halo from a `ShapeDecoration`
wrapping its `Material` and sets `elevation: 0`, so the depth is painted
explicitly rather than by the framework. Alongside that, `buttonDigit`
`#1E1E1E → #242428`, `buttonFunction` `#949494 → #A2A2A8`, and `ruleOnPage`
`#3A3A3C → #45454A`. The one key label size becomes three, chosen by variant:
`buttonLabel` 25 (digits, unchanged), `buttonOperatorLabel` 32/w600 (`+ − × ÷ =`),
`buttonFunctionLabel` 24/w600 (`AC`, `+/−`, `%`), resolved through a new
`CalculatorButtonVariant.labelStyle`.

**Rationale:** In the black theme the keys' shadow could not be seen, and the
cause was structural rather than a matter of degree. A `Material` casts its
elevation shadow in a colour the *framework* chooses — black in the dark theme —
and the page is `#000000`. A black shadow on a black page is invisible at every
elevation value, so raising the number could never have fixed it. What a dark
key can cast is the opposite of a shadow: a faint halo of its own light, which
is what `keyShadow` states here. The white theme keeps the conventional dark
shadow, so the two palettes are opposites on purpose, not for variety.

The halo alone is soft and a fill step is *implied*, so neither could say where
a key ended; `keyBorder` is the only one of the three that states a hard
boundary, which is why it does most of the work separating nineteen keys. The
fills were lifted one step for the same reason — a `#1E1E1E` key on a `#000000`
page is a difference you can see but not point at.

The symbols were the second half of the report and a different fault. Every key
shared one 25 px size, so `−` and `=` — a single short bar and two — were the
*quietest* marks on the pad despite being the column the pad is organised around.
Bearing them at 32/w600 sizes them as the spine they are. The function keys go the
other way, to 24: `AC` and `+/−` are the only multi-character labels, and at 25
they are the ones the `FittedBox` squeezed — a deliberately smaller label beats a
shrunk one.

**Consequence:** `keyElevation` no longer exists on the palette or in
`AppColors`; `AppPalette` gains `keyShadow` (nullable, lerped like `cardShadow`)
and `keyBorder`, and `CalculatorButtonVariant` gains `labelStyle`. The size lives
on the *variant*, not on the palette, because the three sizes are identical in
both themes — a colour field would wrongly imply they differ. The old
`buttonDigit`/`buttonFunction` literal assertions in `design_system_test.dart`
moved to the new values, and D-111 added three tests: the dark palette's glow,
edge, and fill are each asserted *lighter* than what they sit on (the
relationships, not the hexes, so the black-on-black pairing cannot silently
return); the light palette still casts a dark shadow; and each variant resolves
its own label size.

**Supersedes:** `keyElevation` (deleted), `buttonDigit`'s `#1E1E1E`,
`buttonFunction`'s `#949494`, and `ruleOnPage`'s `#3A3A3C`. **Unchanged by it:**
the light theme's key *geometry*, the variants' fills and foregrounds, the
`_layout` arrangement, the wide `0` (D-29), D-110's margin/gap/key size, and every
non-keypad screen.

---

### D-113 - Change PIN Says Which Step It Is On, Says Why an Entry Was Refused, and Keeps the New Code Until It Is Confirmed

**Decision:** the three-step Change PIN flow (`ChangePinScreen`) gains four
behaviours and reverses one.

1. **Each step's prompt is named**, and the wording is the bare verb:
   `"Enter current PIN"`, `"Enter new PIN"`, `"Confirm new PIN"` — replacing
   `"Enter your current PIN"`, `"Enter a new PIN"`, `"Enter the new PIN again"`.
2. **`SecretPinField.showErrors` is on for all three steps**, with a per-step
   `wrongPinMessage` drawn from a `_stepErrors` table: `"Incorrect PIN"` on step
   1, `null` on step 2, `"PINs do not match"` on step 3.
3. **A mismatched confirmation re-asks step 3** with `_pending` intact, clearing
   only the confirmation. **Reverses** the previous "a mismatch returns to step 2
   with the dots cleared".
4. **The header control is `Icons.arrow_back` with tooltip `Back`**, replacing
   `Icons.close`/`"Cancel"`, and it is step-aware: step 1 pops the route; step 2
   returns to step 1 and drops `_pending`; step 3 returns to step 2 and keeps it.
5. **A confirmed code shows `"PIN changed successfully"` for
   `ChangePinScreen.successPause` (1200 ms) and then pops** to the Secret settings
   page. `SecretPinField` gains one optional `successMessage` and paints it in the
   reserved status slot in `textSecondary`; the keypad and the back arrow are
   inert while it is up.

**Rationale:**

The old prompt wording was *more* informative and less usable. All three steps ask
the same four digits on the same pad, so the line above the dots is the only thing
distinguishing them, and "Enter the new PIN again" describes the previous step
rather than naming this one. Three short imperatives do the work the article and
the clause were doing, and none of them names the code, so §6.8 still holds.

The opt-in `showErrors` was reasoned from one of Change PIN's two rejections and
misapplied to both. The argument was that a user who mistypes a code they have
just chosen is being *asked to try again*, and painting red at them would make the
ordinary path look like a failure — true of step 2, which has **no rejection at
all** (any four digits is a legal new PIN, including the old one), and false of
step 1, which rejects a genuinely wrong code. D-88's own reasoning settles it: a
screen that stops accepting input without saying why is indistinguishable from a
broken one, and step 1 was exactly that. The remedy for the original worry is the
*wording*, not the absence of feedback, which is what `_stepErrors` supplies.

Sending a mismatch back to step 2 was punishing the user for a mistake they did not
make there. They typed the PIN they meant twice; the second attempt had the typo.
Discarding `_pending` makes them choose it a third time, and a third attempt is a
third chance to land somewhere they did not intend — and step 2 rejecting nothing
means the cost of returning is paid entirely by the user, with nothing gained by
the extra step. Re-asking keeps the candidate in memory, so nothing is written.

The back button is where the same reasoning meets navigation. A control that always
pops would drop a user out of the middle of a flow they are one step from
finishing, which is the cheapest version of the lost-work problem; and `Icons.close`
claimed a decision ("abandon this") that the flow does not offer. `arrow_back` is
the app's ordinary way out (History, Settings, the Secret unlock screen) and now
means exactly what it looks like: back, one step, or out.

The success line is the only evidence the user gets that the change happened, and
AC-021 persists the code *before* the flow ends so a crash cannot lose it — so the
flow can end immediately and still owe the user an answer. It is painted in the
reserved 18 px status slot rather than a `SnackBar` because the app has none, and
adding one would put a new component on the only screen that must not gain any
ink; `textSecondary` in the app's own caption type is the whole of the success
styling that exists, and D-84 forbids this feature adding a token.

**Consequence:** `SecretPinField` gains `successMessage` and a `color` on its
internal status line; nothing else about that widget moves, so the unlock screen
is byte-identical. `feature.md` FEAT-SEC-005's mismatch sentence is corrected. The
new code exists only in `_pending` until the confirmation matches, so **no**
interruption — the back arrow, the system gesture, or process death — can leave a
user locked out of a code they did not choose. `ChangePinScreen.successPause` is
published rather than private, for the reason D-82's hold duration is: a test must
pump the duration that ships.

**Unchanged by it:** the shared pad, its dots, the shake, the D-89 bottom anchor,
the `SecretCode.length` cap, `_checking`, backspace, `secret_controller.dart`, and
every non-Secret screen. The system back gesture still pops the route from any
step (D-56), which is safe precisely because nothing unconfirmed is ever written.

---

### D-114 - Every Vault Row Opens a Page, and the Eleven Pages Are One Screen

**Reverses** the file-manager pass's "nothing on this screen does anything", and
resolves the shape it raised: eleven rows that all drew a chevron, rippled on
press, and went nowhere.

**The rows navigate.** All eleven — Recent files, the six Categories cells, both
storages, Recycle bin, Analyse storage — push `/secret/browse/:place`. This is the
reversal the old test (`every control is enabled-looking and does nothing`) was
written to catch, which is why that test is **replaced rather than loosened**: it
tapped three rows and asserted the screen had not moved, and a passing suite is
what made this change safe to make.

**One route, one screen, eleven records.** The pages are the same three parts — a
title, the app's back button, an empty state — so eleven screen classes would have
differed only in three strings. Instead `vaultPlaces` holds the eleven records and
`VaultPlaceScreen` resolves `:place` against it. The app's own preference for a
named constant over a derived value applies to the *ids* (spelled out, because a
slug derived from a title could disagree with itself in two files) and not to the
titles and icons, which are shared.

**The rows read their place from the registry.** Both the grid cells and the five
`SettingsRow`s resolve a `VaultPlace` and take their label and glyph from it. This
is what makes "the row says the same thing as the page" structural: the old code
wrote `title: 'Images'` and `icon: Icons.image_outlined` next to a page that would
have had to repeat both, and nothing stopped a later edit moving one.

**Which header.** `SecondaryPageScaffold` + `SecondaryPageHeader`, so the back
button is the app's own and **pops** rather than `go`-ing to `/secret`. This is why
there is no `_SecretBackButton` here the way the PIN screen needed one: that screen
has no header, so it had to invent somewhere to put an exit. Here the header is
shared, the title is centred by the geometry D-74 established, and the button
returns to whichever screen was tapped to arrive — which is the ordinary meaning
of "one back button". The floating home button does **not** travel down; it belongs
to the Vault screen, and a 56 px circle over an empty page is a second exit the
rest of the app does not have.

**Search stays inert, and this is the surviving half of the old decision.** It is
now the only control on the Vault screen that is enabled-looking and does nothing.
A row can open a page saying "No images yet" because that is a fact; a search page
over a set of files that does not exist would be a claim the app cannot make. It
ships as furniture and arrives with the file list it searches.

**An unknown `:place` renders, and claims nothing.** `vaultPlaceById` returns
`null` and the screen falls back to a generic "Files". A path parameter can arrive
from a stale bookmark or a hand-typed URL, and on Android a throw there is a crash
on a visible screen. "Files" names no category, so a wrong segment lands on a page
that says nothing wrong rather than on whichever place happened to be first.

**Consequence:** `navigation_graph_test`'s path count goes 11 → 12, and the twelfth
is the app's only parameterised route. That suite pushes the *pattern*, so the
literal `:place` reaches `VaultPlaceScreen` from it — which is a second, independent
reason the fallback has to exist. `secret_flow_test` keeps its structural
assertions (keys, order, grid geometry, §6.8) and loses only the "does nothing"
half; `vault_place_pages_test.dart` drives all eleven rows through real taps and
adds the §6.8 naming check for the eleven pages.

**Unchanged by it:** the PIN screen, the overflow and Reset PIN, `SecretScreen`'s
own layout and keys, the storage figures on the rows, the D-56 platform transition,
and every non-Secret screen. **No file is read, listed, moved, or deleted** — the
pages are an honest empty state each, which is the same standard the old `_noop`
served and the reason the rows are enabled rather than grey.

---

### D-115 - The Vault's Overflow Opens the Shared Ethar Menu, Not a Drawer

**Decision:** The overflow button on the unlocked Secret screen opens a slide-in
panel from the left — the shared `MenuSlider`, configured here for the hidden
area — copied verbatim from Ethar's profile drawer (`Ethar/.../profile_drawer.dart`).
The panel is a general dialog (`MenuSlider.show` → `showGeneralDialog`), **not** a
`Scaffold.drawer`, and its single row, "Settings", leads to the hidden area's own
settings page (FEAT-SEC-004). The overflow's tooltip became 'Menu' because the
button no longer navigates; it opens a panel.

**Rationale — and what it reverses.** The first draft of this panel hand-rolled a
second copy of Ethar's geometry, the 340 ms animation, and eight colour getters
beside a `_SecretMenuDrawerTile` that was never defined — a compile error that no
test reached, because the screen mounted the drawer anyway
(`drawer: const SecretMenu()`, whose `build` returned `SizedBox.shrink()`). A
`Scaffold.drawer` could not have been the fix: the framework slides drawers at its
own speed under its own scrim, while Ethar's panel dims with a flat 54 % black,
animates 340 ms with `easeOutQuart`/`easeInCubic`, measures `(screenWidth × .86)
.clamp(300, 380)`, rounds the right edge at 18, and casts the 10/0/28 shadow.
`showGeneralDialog` is the call that makes the two apps' menus animate as the same
object — which is the point of the request, and why the numbers are *identical*
rather than *close*: a menu that is almost the same reads as a bug.

**Consequence:** `SecretScreen` drops its `drawer:` slot and its `Builder` (which
existed only to reach `Scaffold.of(context).openDrawer`); the overflow calls
`SecretMenu.show(context)` directly. Tests reach the panel's row through
`SecretMenu.settingsRowKey`, unchanged. The shared widget replaces the panel's
eight colour getters with `MenuColors`, which maps them onto the app's palette and
holds the two non-derivable decisions (the `softOrange` fill, the accent) in one
place.

**Unchanged by it:** the PIN screen and its exit, the Search inertness (D-114), the
storage rows and their figures, every key, and D-56 — this is a dialog route, not a
router page, so the no-custom-transition rule for *router* routes is untouched.

---

### D-117 - The Calculator's Settings Entry Is a Gear Button

**Decision:** The Calculator's top bar carries a **gear (settings) button** on the left
instead of a hamburger. It still opens Settings directly, keeps the tooltip 'Settings',
and the history clock still opens History on the right (D-20 unchanged).

**Rationale:** The user asked for the hamburger to be replaced with a gear, so the two
header controls read as what they do — a gear for Settings, a clock for History —
rather than a hamburger whose rows the app has never had.

**Consequence:** The header icon tests (`navigation_test`, `header_alignment_test`,
`calculator_layout_test`, and the `openSettings` harness) and every doc that named the
hamburger now name the gear button.

**Unchanged by it:** D-20's About / Privacy / Terms single-path rule, the root's
exactly-two-entry-points shape, and the AppPageHeader / AppSpacing / router internals.

### D-118 - The Gear Button Spins One Slow Turn Before Settings Opens

**Decision:** Tapping the Calculator's gear button turns the glyph one full
clockwise revolution over 700 ms (`Curves.easeInOutCubic`), and the push to
Settings happens only once the turn lands. The spin is on the glyph; the
bordered header box does not move.

**Rationale:** The user asked for a smooth, readable gear animation before the
screen changes. D-56 keeps every route on the platform's own transition, so the
*push* is not slowed to fit the animation — the push is delayed instead, which
puts the whole turn on screen without touching the router or the D-56 assertion
in `navigation_graph_test`.

**Consequence:** `navigation_test` gains a mid-spin case (still on the
calculator at 350 ms, Settings after settle, angle back at rest on return).
The gear is reached through the same `find.byIcon(Icons.settings)` /
`byTooltip('Settings')` handles as before, so `openSettings` and the header and
layout tests are unchanged. A tap that lands while the turn is running is
ignored, and a turn that lands with another route on top rewinds without
navigating.

---

### D-119 - The History Screen's Painted Trash Is the App's One Delete Glyph

**Decision:** every delete glyph in the app is `AppTrashIcon` (D-73), which the
History screen already used. Material's `Icons.delete_outline` and
`Icons.delete_forever_outlined` are no longer rendered anywhere. The four sites
that still carried a Material glyph are replaced: the Vault screen's **Recycle
bin** row and that place's empty page, the image gallery's **Trash** tab, its
"Trash is empty" illustration, and the **Delete** action in the Trash selection
bar (plus the debug-only component catalog's sample).

**Rationale:** the user asked for one delete glyph. The app had two: the
design's own solid trash (D-73) on History, the selection bar, and the image
viewer, and Material's outline trash on the Vault and the gallery — so the same
verb wore a different mark depending on which screen you were on. A single glyph
is the design system's own rule read literally: a control that does the same
thing should look the same everywhere.

**Consequence:** the shared components that draw a leading or illustration glyph
from an `IconData` — `AppIconTile`, `SettingsRow`, and `EmptyState` — gain an
optional `iconWidget` (the same escape hatch `AppIconButton` and
`AppSelectionAction` already have for the painted trash), and `VaultPlace.icon`
becomes nullable so the Recycle bin can carry no Material icon at all. A new
`vaultPlaceGlyph` resolves a place to the right glyph in one place, so the row
and the page it opens cannot disagree — the guarantee `vaultPlaces` exists to
make structural. `secret_flow_test` now asserts `AppTrashIcon` on the Vault
screen and the absence of `Icons.delete_outline`.

---

**End of Decision Record**
