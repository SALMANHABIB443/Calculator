# Development Roadmap & Implementation Phases
## Calculator App

**Document Status:** Implementation Roadmap (Phases 1–9 complete)  
**Decisions:** See [DECISIONS.md](DECISIONS.md) for all `D-xx` references  
**Goal:** Deliver a production-ready calculator application that matches the four provided mockups with high visual and functional fidelity.

---

## Phase Overview

| Phase | Title                                      | Focus                              | Estimated Effort |
|-------|--------------------------------------------|------------------------------------|------------------|
| 1     | Requirements & Design Finalization         | Alignment & decisions              | **Complete**    |
| 2     | Project Setup & Architecture Skeleton      | Foundation                         | **Complete**    |
| 3     | Design System & Shared Components          | Visual building blocks             | **Complete**    |
| 4     | Calculator Engine & Main Screen            | Core functionality                 | **Complete**    |
| 5     | History Screen & Persistence               | Data layer                         | **Complete**    |
| 6     | Settings Screen & Preferences              | Configuration                      | **Complete**    |
| 7     | About and Legal Screens                    | Static info + system actions       | **Complete**    |
| 8     | Integration, Navigation & Cross-Cutting    | Glue                               | **Complete**    |
| 9     | UI Polish, Testing & Bug Fixing            | Quality                            | **Complete**    |
| 10    | Production Build & Release Preparation     | Ship                               | **Complete** (2 external gates open) |

**MVP Scope** = Phases 1–9 (all Must-Have features).  
Optional enhancements can be deferred after Phase 10.

---

## Phase 1: Requirements & Design Finalization — **COMPLETE**

**Objective**  
Resolve all open questions and lock the specification so development can proceed without rework.

**Status:** Completed 2026-09-28. Eighteen decisions (D-01 … D-18) are recorded in
[DECISIONS.md](DECISIONS.md). No open critical questions remain.

**What was resolved**
- Target platform and stack: Flutter 3.47.2 / Dart 3.13.2, Riverpod, go_router,
  shared_preferences, plus `in_app_review` and `share_plus` (D-01, D-12)
- History persistence mechanism and cap (D-02)
- **Color values measured from the mockup pixels** — several estimates were wrong, most
  notably the function keys (D-03)
- **Mockup-to-screen mapping corrected**; the filenames encode generation time (D-13)
- Clear History confirmation dialog — promoted to Must Have (D-05)
- Percent semantics (D-06), Privacy/Terms destination (D-07), Rate App behavior (D-08)
- Orientation and form-factor scope: portrait phones only (D-09)
- History header layout (D-10), developer name (D-11)
- Decimal places mid-calculation (D-14), individual history deletion deferred (D-15)
- Feedback dependencies: none needed (D-16)
- **Operator precedence: left-to-right**, which removes the need for a precedence
  parser in the engine (D-17)
- Thousands separators, which the engine's `formatNumber` does not provide on its
  own (D-18)

**Deliverables**
- Signed-off PRD, Feature Spec, Design Spec, Architecture, and this Roadmap
- Technology decision record ([DECISIONS.md](DECISIONS.md))
- Documentation relocated to `docs/` (D-04)

**Carried to Phase 9** (non-blocking): toggle OFF track color (R-1) and exact
calculator key diameter (R-2).

---

## Phase 2: Project Setup & Architecture Skeleton — **COMPLETE**

**Objective**  
Create a compilable project with the recommended folder structure, navigation skeleton, and core interfaces.

**Status:** Completed 2026-09-28. `flutter analyze` reports no issues, 26 tests pass,
and `flutter build apk --debug` succeeds.

**What was delivered**
- Flutter project scaffolded in place with `flutter create . --org com.hasanmahadi
  --project-name calculator --platforms=android` (D-04, D-12, D-22). The existing
  `docs/` and `Mockups/` folders were left untouched. `namespace` and
  `applicationId` are `com.hasanmahadi.calculator` at version `1.0.0+1`.
- Dependency set installed exactly as specified (D-01, §15): `flutter_riverpod` 2.6.1,
  `riverpod` 2.6.1 (pinned to match), `go_router` 14.8.1, `shared_preferences` 2.5.3,
  `in_app_review`, `share_plus`, `cupertino_icons`; dev: `flutter_lints`,
  `integration_test`. No database, audio, haptics, or web-view package.
- Folder structure created per §14, plus a public barrel file per feature.
- `go_router` navigation exposed as `appRouterProvider` with `initialLocation: '/'`
  and `ref.onDispose(router.dispose)`. Six routes: `/`, `/history`, `/settings`,
  `/about`, `/privacy`, `/terms`. No redirect guard — there is no auth-gated subtree
  to protect in this app.
- All six screens render as a navigable shell with the black app background and a
  shared `AppHeader` (back arrow + title + optional trailing, D-10). Calculator is the
  root with no back arrow; the hamburger opens Settings and the clock opens History
  (D-20).
- Portrait locked in code via `SystemChrome.setPreferredOrientations` (D-09).
- Domain interfaces declared and compiling: `CalculatorKey` / `CalculatorOperator` /
  `CalculatorState` / `CalculatorEngine` (backspace stripped, D-19), `HistoryEntry`
  with JSON round-tripping, `HistoryRepository`, `AppSettings`, `SettingsRepository`.
- `groupThousands` implemented in `lib/core/utils/format.dart` with a unit test
  locking in its behaviour for the Phase 3 formatter (D-18).
- `analysis_options.yaml` configured with the project lint set, a `README.md`
  with setup instructions, and a git repository initialised.

**Decisions recorded in Phase 2**
- **D-19** — the engine was built without a `backspace` key, because
  `desing.md:181` and `prd.md:297` both state the keypad has no ⌫ key.
- **D-20** — screen entry points fixed: hamburger → Settings, clock → History, and
  About / Privacy / Terms reached only from Settings. No drawer or sheet.
- **D-21** — `decimalPlaces` rounds but never pads, so `2 + 2` displays `4`. This
  closes the unspecified half of D-14.
- **D-22** — Android-only for v1.0.
- **D-23** — `url_launcher` is present in the lock file only as a transitive
  dependency of `share_plus`; no application code imports it, so §15 is not violated.

**Verification**
- `flutter analyze` — no issues.
- `flutter test` — 26 passing: engine enum/`formatNumber` unit tests, `groupThousands`
  unit tests, and widget tests covering the full navigation graph.
- `flutter build apk --debug` — succeeds. (A forward-compatibility warning notes that
  `in_app_review` applies the Kotlin Gradle Plugin; it does not affect the build.)

**Carried forward**
- The engine's input handlers and its full unit test suite remain Phase 4 work; in
  Phase 2 `apply()` is intentionally a no-op.
- The measured palette, typography, and spacing tokens (D-03) are Phase 3 work; the
  screens currently use inline colours that those tokens will replace.
- **Live device verification is outstanding.** No emulator or device is attached to
  the development machine, so the "app launches to Calculator" criterion was confirmed
  through widget tests rather than on a device. Create one with
  `flutter emulators --create` to confirm visually.

**Dependencies**  
Phase 1 complete (done).

**Deliverables**
- Runnable app shell with the four main screens plus the two legal screens, and working
  back navigation. ✅
- Empty but compilable CalculatorEngine and repository interfaces. ✅
- Project README with setup instructions. ✅

**Acceptance Criteria**
- App launches to Calculator screen. ✅ (via widget test; pending on-device confirmation)
- Can navigate to History, Settings, About, Privacy, Terms and back. ✅
- No runtime crashes. ✅

**Completion Condition**  
Clean architecture skeleton exists and builds successfully. ✅

---

## Phase 3: Design System & Shared Components — **COMPLETE**

**Objective**  
Implement the visual language and reusable UI components so all screens look consistent with the mockups.

**Status:** Completed 2026-09-28. `flutter analyze` reports no issues, 78 tests pass,
and `flutter build apk --debug` succeeds. Every Phase 2 test still passes unchanged,
which is the evidence that retokenizing the six screens altered no behaviour and no
copy.

**What was delivered**
- **Design tokens** as the single definition site, in `lib/core/design/`:
  `app_colors.dart` (the D-03 measured palette), `app_typography.dart` (one
  `TextStyle` per row of desing.md §3), `app_spacing.dart` (spacing, radii, fixed
  sizes), and `app_tokens.dart` as the barrel. No screen hard-codes a hex any more.
- **`app_theme.dart`** rewritten to compose those tokens, adding divider, dialog, and
  switch themes; `app_theme_provider.dart` exposes the theme through Riverpod so
  `app.dart` no longer constructs it and Phase 6 can read the stored preference.
- **Atomic components:** `CalculatorButton` (all three variants, the wide `0`, and
  pressed feedback), `AppToggle`, `AppIcon` with size buckets, and `AppBrandIcon`
  (the 2x2 mark from §5.5).
- **Molecular components:** `SectionHeader`, `SettingsRow`, `SettingsGroup`,
  `ToggleRow`, `HistoryCard`, `AppConfirmationDialog` (the D-05 gate), and
  `EmptyState`, exported through a `core_widgets.dart` barrel alongside the existing
  `AppHeader`.
- **`formatResult`** in `core/utils/format.dart`, composing rounding (never padding,
  D-21), `formatNumber`, and `groupThousands` (D-18) — the number formatter §11 asked
  for, with its unit tests.
- **`dayGroupLabel` / `isSameDay`** in `core/utils/date_group.dart`, with an
  injectable `now` so the Today / Yesterday logic is testable across a midnight
  rollover. No `intl` dependency, since D-01 fixes the package set.
- **A component catalog** at `/catalog`, registered only under `kDebugMode` with no
  UI entry point, so the design system can be eyeballed and no release build
  contains it.
- **All six screens retokenized** onto the shared components. Row titles, section
  labels, and navigation were deliberately left alone: Phases 5–7 own that content,
  and changing it here would have bought nothing but churn.

**Decisions recorded in Phase 3**
- **D-24** — the number formatter stays in `core/utils/format.dart`, accepting the
  one `core → features` import of the engine's `formatNumber` rather than moving
  Phase 2 code to avoid it.
- **D-25** — the catalog is a debug-only route with no entry point.
- **D-26** — the two colours the mockups never show (the divider and the toggle OFF
  track) are named tokens with provisional values, each correctable in one edit.
- **D-27** — calculator keys size from their container, so the grid alone determines
  the key diameter and R-2 stays a Phase 9 measurement.
- **D-28** — `CalculatorButton` takes a variant enum, not a `CalculatorKey`, so D-24
  remains the only `core → features` import.
- **D-29** — the wide `0` key is a stadium, resolving the contradiction inside
  desing.md §5.1 where the keys are called circles *and* `0` is said to span two
  columns.

**Verification**
- `flutter analyze` — no issues.
- `flutter test` — 78 passing. The 26 Phase 2 tests pass untouched; new coverage is
  `formatResult`, the day-grouping helper, and token-assertion tests for every
  component variant.
- `flutter build apk --debug` and `flutter build apk --release` — both succeed. (The
  `in_app_review` KGP warning from Phase 2 is still present and still harmless.)
- The `kDebugMode` guard on the catalog was **verified against the release binary**,
  not assumed: scanning `libapp.so` in the release APK finds the app's own strings
  but none from the catalog, so the screen is tree-shaken out of a shipped build.

**Deliverables**
- Shared component library. ✅
- Design tokens file(s). ✅
- Component catalog (debug-only). ✅

**Acceptance Criteria**
- All shared components visually match the corresponding elements in the mockups.
  Partially verified — see the caveat below.
- Components are reusable and accept the necessary props/variants. ✅

**Caveat on the visual criterion.** The mockups could not be re-measured in this
phase, so fidelity was verified by asserting each component against the D-03 hex
values and the desing.md §2–§5 rules rather than by eye. That catches a component
drifting from the design system; it does not prove the design system itself still
matches the pixels. The human pass on `/catalog` and the four screens is still
outstanding, and no device was attached — the same limitation Phase 2 recorded.

**Carried forward**
- The keypad grid, the engine controller, and key-press feedback — Phase 4. The
  `CalculatorButton` sizing model means the grid is now the only thing that
  determines key diameter.
- History day grouping has its helper but no repository — Phase 5.
- The Settings toggles are still static text rows; the `ToggleRow` and `AppToggle`
  they need are built — Phase 6.
- The About screen is still missing the App Name and Terms rows and the header
  subtitle shown in the mockup, and the Rate / Share actions are inert — Phase 7.
- **R-1 and R-2 both now have provisional values and a defined correction path**
  (D-26, D-27) but are still unconfirmed against the mockups.
  **Closed in Phase 9** — R-1 by decision (D-61), R-2 by measurement (D-60).

**Dependencies**  
Phase 2.

**Completion Condition**  
Design system is ready for consumption by feature screens. ✅

---

## Phase 4: Calculator Engine & Main Screen - **COMPLETE**

**Objective**  
Deliver a fully functional calculator that matches the Main Calculator mockup and correctly evaluates expressions.

**Status:** Completed 2026-09-28. `flutter analyze` reports no issues, 168 tests pass, and
`flutter build apk --debug` succeeds. The 78 Phase 3 tests pass unchanged, which is the
evidence that replacing the engine's stub `apply()` and rebuilding the screen changed no
other screen, no navigation, and no copy.

**What was delivered**
- **A complete, Flutter-free engine** in `lib/features/calculator/domain/calculator_engine.dart`.
  State is a value type — `terms`, `entry`, `value`, `pendingOperator`, `isError` — with
  `currentValue`, `copyWith`, and `==`/`hashCode`, so a test asserts a state instead of
  describing one. Terms are exposed as an unmodifiable snapshot.
- **All input handlers**, replacing the Phase 2 no-op: digits, the decimal point, the four
  operators, `=`, `%`, `±`, and AC. Entry is capped at 15 digits, a leading zero is
  replaced rather than accumulated, a second decimal point is ignored, and left-to-right
  folding is preserved per **D-17**. There is no `_backspace`, per **D-19**.
- **`CalculatorController`**, a Riverpod notifier that translates a `CalculatorKey` into
  the matching engine call. It is the only place key → behaviour is mapped, and it passes
  the two feedback flags to the `FeedbackService` (**D-34**).
- **`CalculatorDisplay`**, which owns presentation: it reads `decimalPlaces` from the
  settings provider itself and turns a `CalculatorState` into the two lines
  (`resolveDisplay`). The engine never sees the setting, which is what keeps **D-14**
  honest — a mid-calculation change is formatting-only.
- **`CalculatorKeypad`**, the 5×4 grid of desing.md §6.1, and a rewritten
  **`CalculatorScreen`** with a single `LayoutBuilder`. Keys are squares derived from
  `min(width, height)`, so the grid alone sets the diameter (**D-27**) and the display and
  keypad can never squeeze each other out of the layout (**D-09**).
- **Key-press feedback** via `HapticFeedback` and `SystemSound` in
  `lib/core/services/feedback_service.dart`, with no new package, per **D-16**. The service
  takes the two booleans as arguments rather than reading the provider, so it stays
  testable and free of provider coupling.
- **`settingsProvider`** as a synchronous seam returning Phase 6's defaults. It lives in
  `lib/features/settings/data/` so the one `core → features` import from **D-24** stays the
  only one.
- **62 engine tests, 22 display tests, and 19 screen tests**, with the key-driving logic in
  a shared `test/support/keypad_session.dart` so the widget tests read as user gestures
  rather than as state construction.

**Decisions recorded in Phase 4**
- **D-30** — the engine owns numbers and the entry string; the display owns formatting,
  including the thousands separator (**D-18**) and rounding to `decimalPlaces` (**D-21**).
  Typed entries are grouped but never rounded; only computed results are rounded.
- **D-31** — `2 + =` repeats the pending operator against the accumulator, so it resolves
  to `4`. The alternative — entering a `2 + 0` that waits for an operand — reads as a dead
  key, and an Android calculator does the repeat.
- **D-32** — the primary line steps from 60 pt to 44 pt once the string passes 10
  characters, and a `FittedBox` scales it beyond that, so a long value shrinks rather than
  clipping (desing.md §10).
- **D-33** — the 15-digit cap, leading-zero replacement, and single-decimal rule live in the
  engine as `maxEntryDigits`, since they constrain what the user can type, not how it looks.
- **D-34** — feedback is gated by settings inside the controller, and the service itself
  takes flags as parameters. `FeedbackService` therefore has no provider dependency, and the
  real settings repository arrives in Phase 6 behind an unchanged controller.

**Verification**
- `flutter analyze` — no issues.
- `flutter test` — 168 passing. New coverage is the engine suite, `resolveDisplay`, and the
  screen suite, which asserts the real render tree: the 19 keys and the absence of a
  backspace key (**D-19**), the five rows of §6.1, the stadium `0` (**D-29**), the measured
  palette per key type (**D-03**), key sizes in the measured 85–95 px band, no overflow on a
  320×568 phone or a 480×1000 phone, and the display driven end to end by taps.
- `flutter build apk --debug` — succeeds. (The `in_app_review` KGP warning is still present
  and still harmless.)

**Deliverables**
- Working Main Calculator screen. ✅
- Robust, tested CalculatorEngine. ✅
- Visual match to the provided Calculator mockup. Partially verified — see the caveat below.

**Acceptance Criteria**
- All arithmetic operations produce correct results, evaluated left-to-right. ✅
- Division by zero and invalid states show “Error”. ✅
- Layout, colors, and hierarchy match the mockup, including the light-gray function keys
  with dark labels and the orange operator column. Partially verified — see the caveat below.
- AC clears the display. ✅
- Unit tests pass. ✅

**Caveat on the visual criterion.** The mockup images could not be opened in this
environment, and no device is attached, so the screen is verified against the *documented*
measurements — the D-03 hex values, the desing.md §6.1 row structure, the 14 px gaps, and
the 85–95 px key band — rather than against the pixels. The measurements are implemented and
asserted; the human comparison is still outstanding, as it was in Phases 2 and 3.

**Carried forward**
- ~~`settingsProvider` returns defaults; the real `SettingsRepository` over
  `shared_preferences` replaces it in Phase 6 with no controller or display
  change.~~ **Done in Phase 6**, exactly as scoped: the repository arrived and no
  controller or display code changed, because the provider kept its synchronous
  type and grew a layer beneath it (**D-41**).
- Nothing writes a completed calculation to history yet — the engine is the source Phase 5
  hooks into, and it already reports `value` and the term list.
- The four navigation actions and the mockup's history/settings affordances on the main
  screen are still inert — Phases 5 and 6.
- **R-1 and R-2 remain unconfirmed against the mockups**, now applied to a real screen.
  **Closed in Phase 9** — R-2 was a symptom of the screen margin (D-60), R-1 was
  closed as a decision (D-61).

**Dependencies**  
Phase 3 complete (done).

**Completion Condition**  
User can perform everyday calculations with correct results and visual fidelity. ✅

---

## Phase 5: History Screen & Persistence - **COMPLETE**

**Objective**  
Persist successful calculations and allow users to review and reuse them.

**Status:** Completed 2026-09-28. `flutter analyze` reports no issues, 250 tests pass, and
`flutter build apk --debug` succeeds. The 168 Phase 4 tests pass unchanged, which is the evidence
that adding persistence and rewriting the History screen changed no other screen, no navigation,
and no copy. As in Phases 2–4, the screen is verified against the *documented* measurements and
not the mockup pixels: no device is attached, so the human comparison is still outstanding.

**What was delivered**
- **A persistent repository** in
  `lib/features/history/data/shared_preferences_history_repository.dart`: one `shared_preferences`
  key (`history_entries`) holding a JSON list, capped at `HistoryRepository.maxEntries` (200) with
  oldest-first eviction. Newest-first is a storage invariant maintained by inserting at index 0,
  so a write never sorts and day grouping is a single forward pass. A malformed record is dropped
  on read rather than taking the whole list with it.
- **A storage boundary** (`HistoryRepository`) that also owns `groupByDay`, so the UI never
  buckets timestamps itself and the grouping rule exists once.
- **A day-grouping helper** in `core/utils/date_group.dart` — pure Dart with no `intl`, because
  the dependency set is fixed at D-01. `Today` / `Yesterday` / `Mon D, YYYY` is the only date
  formatting the app needs.
- **The evaluation signal (D-35).** `CalculatorState.justEvaluated` records that an `=` produced
  a result, and `CalculatorEngine.loadValue` sets it for a loaded history value (D-37). It is
  cleared by `%`, `±`, and any error, so a failed or half-typed calculation is never stored.
- **Recording on the controller.** `CalculatorController` hands the finished strings and the raw
  value to `HistoryNotifier.record` without awaiting, so the user never waits on a disk write. The
  list is rebuilt from storage afterwards rather than appended optimistically, so the screen always
  shows what the repository actually holds.
- **A one-way dependency (D-39).** The calculator calls into history; `history_controller.dart`
  imports nothing from the calculator feature, so the two cannot form a cycle.
- **The History screen**, rebuilt to render loading, failed, and empty as three distinct states —
  a failed read is a different problem from an empty history, and showing "No calculations yet"
  after a storage failure would be a lie. Cards, day sections, and the empty state come from the
  existing core widgets, so the design system is consumed rather than reimplemented.
- **Both clear paths behind one dialog (D-05, AC-008).** The header trash (D-38) always renders
  and is disabled when there is nothing to delete; the bottom action hides when empty. Cancelling
  deletes nothing.
- **Graceful degradation (D-02).** If `shared_preferences` cannot be reached the app falls back to
  `InMemoryHistoryRepository`, which honours the same 200-entry cap and the same history toggle.

**Decisions recorded**  
D-35 through D-40 in `DECISIONS.md`.

**Carried forward**
- ~~`settingsProvider` still returns defaults, so `historyEnabled` is always true today.~~
  **Done in Phase 6.** The repository took the toggle as an injected callback
  (**D-40**) precisely so the real settings provider could be wired with no change
  there, and that is how it was: `history_controller.dart` was not touched, and the
  history toggle is now driven from the Settings screen and covered end to end
  (**AC-005**).
- **History is still unverified against the mockup pixels** (`02_17_57`) — no device is attached.
- The `2 + =` case is recorded with the expression line as the engine renders it at the moment of
  evaluation, which is the committed terms (`2`) rather than the pending operator glyph. The result
  and its day group are correct; the expression is not rewritten to show the trailing `+`.

**Dependencies**
Phase 4 complete (done).

**Completion Condition**  
History feature is complete and reliable. ✅

---

## Phase 6: Settings Screen & Preferences — **COMPLETE**

**Objective**  
Allow users to customize feedback and precision; persist all preferences.

**Status:** Completed 2026-09-28. `flutter analyze` reports no issues, 330 tests
pass, and `flutter build apk --debug` and `--release` both succeed. 248 of the 250
Phase 5 tests pass unchanged; the two that changed are the lines in
`navigation_test.dart` that navigated by a row title this phase renamed (**D-48**).
As in Phases 2–5, the screen is verified against the *documented* measurements and
not the mockup pixels: no device is attached, so the human comparison is still
outstanding.

**What was delivered**
- **A persistent repository** in
  `lib/features/settings/data/shared_preferences_settings_repository.dart`, holding
  the five keys `struction.md` §10 names, plus an `InMemorySettingsRepository` for
  the degradation path. Every read is individually guarded, because
  `SharedPreferences`' typed getters are casts that **throw** on a type mismatch
  rather than returning null (**D-42**) — without the guard one corrupt key took
  down the whole load and pinned the app to defaults.
- **A two-provider state seam** (**D-41**). `settingsControllerProvider` is the
  async notifier that owns the load and the writes; `settingsProvider` stays a
  synchronous view over it. The Phase 4 doc comment proposed replacing
  `settingsProvider` with an `AsyncNotifierProvider` outright; that was declined,
  because `CalculatorController` must read the feedback flags synchronously on
  every key press (**D-34**) and the display needs a precision to round with. All
  four `lib/` read sites and both test overrides are byte-for-byte unchanged.
- **A write that beats the load.** A toggle flipped in the first moments of a
  cold start is no longer snapped back by the load resolving afterwards (**D-43**).
- **A working Settings screen**, rewritten as a `ConsumerWidget` over the existing
  `SettingsRow` / `ToggleRow` / `SettingsGroup` components, with a copy pass to
  bring it into conformance with `desing.md` §6.3 and `feature.md` §C (**D-48**):
  the `PREFERENCES` section, the header subtitle, and the four row subtitles the
  docs quote. The `ToggleRow` and `AppToggle` that Phase 3 built for exactly this
  are now used by a screen.
- **A Decimal Places picker** — a modal bottom sheet with a checked row per
  option, offering 0 to 6, scroll-controlled so a short viewport or enlarged
  Dynamic Type scrolls rather than clipping (**D-46**). The range is a chosen
  bound, not a measured one; no document states it, and `clampDecimalPlaces` is
  applied on read *and* write so a hand-edited store cannot leave the formatter
  holding a precision the picker cannot undo.
- **One plugin touch-point.** `preferencesProvider` moved from the history
  feature to `lib/core/storage/`, which is where it belonged (**D-44**). Without
  the move, settings would have imported from `features/history/`, inverting the
  one-way rule **D-39** set up. `core` importing a plugin adds no `core → features`
  edge, so **D-24**'s single such import stays single.
- **`AppSettings` value equality** (**D-47**), so `settingsProvider.select` in the
  display only rebuilds the result line when `decimalPlaces` actually moves —
  which is the whole of **D-14** — and so a no-op write is dropped before it
  reaches disk.
- **The theme row is display-only** and `appThemeProvider` was left unwired
  (**D-45**). Phase 3's comment promised Phase 6 would connect them; it declined,
  because dark is the only theme in v1.0, so the branch would have one arm and
  cost the second `core → features` import **D-24** holds down to one.

**Decisions recorded**  
D-41 through D-48 in `DECISIONS.md`.

**Verification**
- `flutter analyze` — no issues.
- `flutter test` — 330 passing. New coverage is the repository (round-trip,
  partial stores, per-key type corruption, range clamping), the controller
  (write-then-reload, the in-flight-write race, plugin-unavailable degradation),
  the Settings screen (the documented layout and copy, all three toggles, the
  picker's options and selection and dismissal, the dead Theme row, and no
  overflow at 320x568 or 480x1000), the **AC-006** restart tests, and an
  end-to-end suite driving the real screen: **AC-004** through a recording
  `FeedbackService` override, **AC-005** through the History screen, and **D-14**
  through a result that re-renders at a new precision while a typed entry and the
  expression line are left untouched.
- The **AC-006** tests are genuine relaunch tests: each snapshots the raw store
  and re-seeds it, which nulls the plugin's cached instance so the next
  `getInstance()` re-reads. A second `ProviderContainer` alone would have shared
  one cached instance and proved nothing.
- `flutter build apk --debug` and `flutter build apk --release` — both succeed. (The
  `in_app_review` KGP warning from Phase 2 is still present and still harmless.)

**Deliverables**
- Complete Settings screen. ✅
- Working preference persistence and live feedback control. ✅

**Acceptance Criteria**
- All toggles and the decimal places control work as specified. ✅
- Sound/Vibration affect calculator key presses immediately. ✅
- History toggle prevents new entries when off. ✅
- Settings survive restart. ✅
- Visual match to Settings mockup. Partially verified — see the caveat below.

**Caveat on the visual criterion.** The mockup could not be opened in this
environment, so the screen is verified against the *documented* measurements —
the D-03 hex values, the typography and spacing tokens, and the §6.3 row
structure — rather than against the pixels, exactly as Phases 2–5 recorded. The
`PREFERENCES` section label, the header subtitle, and the four row subtitles are
transcribed from `desing.md` §6.3 and `feature.md` §C and should be confirmed
against the image on a device. No device was attached.

**Carried forward**
- `data/settings_provider.dart` is now a re-export shim so the six pre-existing
  import paths keep resolving. Phase 8 should collapse it while tidying
  cross-feature imports.
- **R-1 is now reachable.** Every toggle in every mockup is ON, so the OFF track
  colour has still never been seen, but the Settings screen is the first place a
  user can produce one. That makes the Phase 9 comparison straightforward.
  **Phase 9 confirmed no mockup contains the OFF state at all**, so the comparison
  could not settle it; R-1 was closed as a decision instead (D-61).
- Settings are read once per process and held in memory; a mid-session change made
  outside the app (adb, a restored backup) is not observed until relaunch. Not
  required by AC-006, and a cold-start check is Phase 8 work.
- The About screen is still missing the App Name and Terms rows and the header
  subtitle shown in the mockup, and the Rate / Share actions are inert — Phase 7.
- **R-1 and R-2 both remain unconfirmed against the mockups.**
  **Closed in Phase 9** — R-1 by decision (D-61), R-2 by measurement (D-60).

**Dependencies**
Phase 3 (SettingsRow, ToggleRow) + Phase 5 (history toggle effect).

**Completion Condition**  
All preference features are functional and persistent. ✅

---

## Phase 7: About and Legal Screens — **COMPLETE**

**Objective**  
Implement the About screen with correct branding and system actions, plus the in-app legal screens.

**Status:** Completed 2026-09-29. `flutter analyze` reports no issues, 351 tests pass, and
`flutter build apk --debug` succeeds. All 330 Phase 6 tests pass plus 21 new ones, which is
the evidence that finishing About and wiring the two platform actions changed no other
screen, no navigation, and no copy. As in Phases 2–6, the screen is verified against the
*documented* measurements and not the mockup pixels: no device is attached, so the human
comparison is still outstanding.

**Task note — the legal screens were already done.** Phase 7's task list names Privacy and
Terms screens as new work, but Phases 2–6 already shipped them: D-07 fixed them as in-app
text screens with placeholder copy, Phase 2 routed `/privacy` and `/terms`, and Phase 6
made the About group on Settings the documented entry point. The only remaining legal work
was the Terms *row on About*, which this phase added (**D-52**). Privacy stays reachable
only from Settings; About shows exactly the three MORE rows the mockup does.

**What was delivered**
- **The About screen, completed to the mockup.** The Phase 3 skeleton gained the header
  subtitle ("Simple calculator, powerful features", `desing.md` §6.4), the App Name row in
  the APP INFORMATION section, the Terms of Service row under MORE, and the spec'd copy:
  row subtitles "Support us with your rating", "Tell your friends about this app", and
  "Read our terms and conditions" (`feature.md` FEAT-ABOUT-003), plus the hero description
  shipped verbatim from `feature.md` FEAT-ABOUT-001 (**D-50**). The two actions are no
  longer inert.
- **Rate App** via `ReviewService` (**D-51**): `in_app_review`'s prompt when the platform
  says the prompt is available, else the Play listing — D-08 implemented literally. The
  store listing is a URL composed from the package name (**D-49**), replacing a dead
  query-string field that `openStoreListing()` never actually used.
- **Share App** via `ShareService`: `share_plus` opens the system share sheet with the
  app name, description, and Play store URL as the text and "Calculator" as the subject.
- **Two service seams, one feedback pattern** (**D-53**). Both plugins live behind
  `ReviewApi` / `ShareApi` interfaces in `lib/core/services/` and are exposed as Riverpod
  providers, mirroring **D-34**'s `FeedbackService`. Each action returns an outcome enum;
  on any platform failure the screen shows a SnackBar ("This action is unavailable right
  now") instead of letting an exception surface (`struction.md` §12). Plugins stay out of
  widgets, and `core → features` still has exactly the one **D-24** import.

**Decisions recorded**  
D-49 through D-53 in `DECISIONS.md`.

**Verification**
- `flutter analyze` — no issues.
- `flutter test` — 351 passing (330 Phase 6 + 21 new). New coverage unwraps the whole
  success/failure matrix at the unit seam: `ReviewService` (prompt vs store fallback vs
  each of the two platform throws), `ShareService` (sheet summoned with the composed
  message, and a throw), and widget tests that drive the real screen with recording
  doubles for both providers plus the Terms slide-over and navigation back. The About
  layout is asserted without any provider override: sections in order, uppercase section
  headers, subtitle, hero contents, the exact row set for both sections, chevrons, the
  black app background, and no overflow at 320×568 or 480×1000.
- The short-screen widget tests forced one interesting test-side fix: a lazy `ListView`
  can *build* a row while it is still below the fold, so a tap lands outside the surface.
  The helper now `ensureVisible`s (and asserts it actually reached About) before tapping,
  which is exactly the class of missed-tap bug real devices hit.
- `flutter build apk --debug` — succeeds. (The `in_app_review` KGP warning from Phase 2 is
  still present and still harmless.)

**Deliverables**
- Fully functional About screen matching the mockup. ✅
- Legal screens reachable from both Settings and About. ✅

**Acceptance Criteria**
- All information matches the mockup. ✅ (against documented spec; see the caveat below)
- Rate and Share trigger the expected platform behaviors. ✅ (at the service seam, via
  recording doubles; no device was attached to confirm the live native surfaces)
- Legal screens render offline with no web view. ✅
- Visual fidelity is high. Partially verified — see the caveat below.

**Caveat on the visual criterion.** The mockup could not be opened in this environment, so
the screen is verified against the *documented* measurements — the §6.4 section structure
and the subtitle, the FEAT-ABOUT copy rows — rather than against the pixels, exactly as
Phases 2–6 recorded. Two items need a device or a Phase 9 pixel pass: the live review
prompt / share sheet (plugins cannot run headless), and `in_app_review`'s store-sided
prompt quota, which can silently no-op a button-triggered request for days on end
(**D-51**). No device was attached.

**Carried forward**
- Privacy Policy is reachable only from Settings (About's MORE shows the three rows the
  mockup does — **D-52**); Phase 8's navigation sweep (D-20) should re-confirm that.
- The app-icon reported on About is the plain rounded-square placeholder Phase 3 built
  (`AppBrandIcon`); the 2x2 mark is implemented, so only a visual sign-off remains.
- `data/settings_provider.dart` remains a re-export shim (Phase 6) for Phase 8 to collapse.
- **R-1 and R-2 both remain unconfirmed against the mockups.**
  **Closed in Phase 9** — R-1 by decision (D-61), R-2 by measurement (D-60).

**Dependencies**
Phase 3 (shared components) + Phase 6 (navigation from Settings).

**Completion Condition**  
About and legal screens are complete. ✅

---

## Phase 8: Integration, Navigation & Cross-Cutting Concerns - **COMPLETE**

**Objective**  
Connect all screens cleanly, ensure consistent navigation, and wire remaining cross-cutting features.

**Tasks**
- Finalize navigation graph and transitions.
- Verify the calculator top bar entry points behave as designed: hamburger → Settings,
  clock → History, and About / Privacy / Terms reachable only from Settings (**D-20**).
- Integrate FeedbackService fully (sound + haptics controlled by settings).
- Handle app lifecycle (restore state on cold start).
- Polish empty states and error displays.
- Accessibility labels and basic Dynamic Type support.
- Performance check (instant evaluation, smooth scrolling).

**Dependencies**  
Phases 4–7 complete.

**Deliverables**
- Fully integrated four-screen application.
- Consistent navigation and feedback behavior.

**Acceptance Criteria**
- All primary user journeys work end-to-end.
- No broken navigation paths.
- Settings affect calculator and history correctly.
- App restores previous settings and history on relaunch.

**Completion Condition**  
The application is feature-complete for MVP.

**What was done**
- **The graph is locked, not just exercised** (**D-56**). Phases 2 and 7 proved the navigation
  graph works by driving it; nothing stopped a new route, a floating action button, or a
  shortcut from the Calculator to About from appearing later. `test/widget/navigation_graph_test.dart`
  now asserts exactly seven registered paths (D-20's six plus the debug-only catalog, **D-25**),
  that every path resolves to a screen, and the **negative** half of D-20 — no About, Privacy,
  or Terms control on the root route, and exactly two navigable icon buttons there. The
  negative assertions are the ones that matter: a control that does not exist cannot be
  tapped, so it can only be proven absent. The app's depth is pinned at three levels
  (Calculator → Settings → Terms) and D-52 is asserted rather than assumed — About carries a
  Terms row and no Privacy row.
- **Transitions are go_router's default** (**D-56**). No route sets a `pageBuilder`, and the
  test asserts that absence, so a polish pass cannot add an invented animation without
  revisiting the decision. No mockup shows motion, so any transition would be invented rather
  than designed — and would be invented twice (push and predictive-back) and diverge from
  the platform's own back gesture.
- **FeedbackService was already fully integrated** (**D-34**), so this task was a
  verification, not a change: the calculator invokes it on every key press, passing the
  `soundEnabled` / `vibrationEnabled` flags from the synchronous settings view (**D-41**).
  Existing tests cover the flag matrix; none were added, because there was no seam left to
  test.
- **Cold start is proven by restarting the scope** (**D-55**). No `AppLifecycleListener` was
  added: `shared_preferences` has no OS lifecycle callback to hook, and every persisted read
  is already a provider's `build()`. `test/widget/cold_start_test.dart` proves it instead —
  unmount the app, re-seed the store from a snapshot, pump a **new** `ProviderScope`. It
  asserts settings and history survive, a half-typed expression does not, and the app opens on
  the root route rather than where it was left. The re-seeding step is load-bearing:
  `SharedPreferences.setMockInitialValues` nulls the plugin's cached completer, so without it
  both scopes would share one in-memory instance and the restart would prove nothing. A sixth
  test covers the cold-start race directly — a toggle flipped while the store is still pending
  must not spring back when the older value arrives (**D-43**).
- **Error displays no longer leak internals** (**D-58**). The History screen's `AsyncError`
  branch interpolated `'$error'`, putting `Exception: ...` in front of a user of a fully
  offline app. It now shows a fixed sentence and a `Try again` button that genuinely
  re-reads; the empty branch has no button, because there is nothing to retry. `EmptyState`
  gained an optional `action` slot so one component serves both cases.
- **Accessibility** (**D-59**). Interactive rows announce as one node instead of up to four
  loose fragments; tappable rows are still marked as buttons; section headers are marked as
  headers; decimal-places options carry selected / mutually-exclusive state. Switches
  deliberately keep their **own** node — merging them would have lost the on/off state, which
  is the thing a screen-reader user most needs. D-45's Theme row proves the distinction is
  real and not a blanket: it shows a chevron but is inert, so it is not announced as a button.
- **Dynamic Type, clamped to 1.0×–1.3×** (**D-54**). AC-007 asks for support without stating
  a range. Unclamped, Android's 2× maximum overflowed the keypad grid. 1.3× is the largest
  factor at which every screen still lays out at the documented 320×568 minimum. Where a widget
  reserves height for a glyph — the result line, the header subtitle — the reservation now
  scales, because `Text` scales itself through `MediaQuery` while a `SizedBox` does not.
  `EmptyState` became scrollable, since it is the one screen guaranteed to have nothing to
  scroll.
- **Import hygiene** (**D-57**). `lib/features/settings/data/settings_provider.dart` existed
  only to re-export two symbols from `presentation/`. It pointed a reader at `data/` for a
  definition that does not live there, and invited the wrong dependency direction. Deleted;
  the three production importers use the feature barrel, the two tests name the concrete file.
- **Performance is asserted structurally, not by timing** (**see verification**). Instant
  evaluation and a lazy history list are asserted as properties; frame timing is not.

**Decisions recorded**  
D-54 through D-59 in `DECISIONS.md`.

**Verification**
- `flutter analyze` — no issues.
- `flutter test` — **401 passing** (351 + 50 new). New suites:
  - `test/widget/text_scaling_test.dart` (12) — layout holds at 1.0×, 1.15×, 2.0× (clamped
    to 1.3×) and 0.8× on the 320×568 minimum surface; the display reserves the height it needs
    at the ambient scale.
  - `test/widget/accessibility_test.dart` (14) — the semantics tree itself: one labelled node
    per row, buttons marked, headers marked, selection state carried, switch state carried,
    and every touch target at or above 44pt.
  - `test/widget/cold_start_test.dart` (6) — the restart described above.
  - `test/widget/navigation_graph_test.dart` (9) — the graph lock described above.
  - `test/widget/performance_test.dart` (6) — a result lands in the tree after a **single**
    frame, and 200 stored history entries build fewer than 20 rows.
  - Three added to `test/widget/history_screen_test.dart` (now 9) — a retry that re-reads, a
    retry that fails again, and the error state at 1.3× text scale. The pre-existing
    failed-read test was extended rather than added: it now also asserts the raw exception is
    absent from the screen and that the fixed copy is present.
- **Two fixes came out of writing the tests, not from re-reading the code.**
  - `tapSettingsRow` in `test/support/pump_app.dart` scrolled a row into view but did not
    `ensureVisible` it, so on a short surface the tap silently landed on nothing and the test
    stayed where it was — surfacing as a confusing "0 widgets" assertion two steps later.
    Fixed in the shared helper, which also removed a latent flake in Phase 6's suite.
  - The History retry test initially threw from the repository *provider*, which Riverpod
    caches; invalidating the screen's provider then re-subscribed to the same cached error and
    the retry appeared to do nothing. The failure belongs on the read, so that is where the
    fake puts it — which is also where it happens in the app.
- **Performance is asserted as structure, not as milliseconds.** A wall-clock threshold in a
  unit test would be tuned to this machine: the test surface renders in software with no GPU.
  What is portable, and what actually causes jank in a 200-row list, is whether every row is
  built at once — so that is what the test asserts. **The frame budget itself remains
  unverified**: there is no device attached to this environment, so smooth scrolling is a
  Phase 9 on-device check.
- One key was added to production code for testability: `calculator-expression` on the display's
  expression line, paired with the existing `calculator-result`.

**Known limitations**
- Text scaling is capped at 1.3×; 1.5× and 2.0× are deliberately not honoured (**D-54**).
- Frame-level smoothness and TalkBack/VoiceOver behaviour are unverified without a device
  and were deferred to Phase 9 — **still unverified**: no device or emulator exists on this
  machine (`flutter emulators` reports none), so Phase 9 could not close this either.
- R-1 and R-2 were left untouched here and **both closed in Phase 9** (D-60, D-61).

---

## Phase 9: UI/UX Matching, Testing & Bug Fixing — **COMPLETE**

**Objective**  
Achieve pixel-level visual fidelity where possible and eliminate defects.

**Status:** Completed 2026-09-29. `flutter analyze` reports no issues, **403 tests
pass**, and `flutter build apk --debug` and `--release` both succeed. The 401
Phase 8 tests pass unchanged, which is the evidence that retokenizing the screen
margin and tightening the geometry assertions changed no other behaviour and no
copy.

**The thing that made this phase possible.** Phases 2 through 8 each closed by
recording that the mockup images could not be opened in this environment, and
therefore verified every screen against *transcribed prose* rather than against
pixels — a limitation each one dutifully carried forward. Phase 9 decoded the four
PNGs directly (884×1779 at 2x, via `System.Drawing`) and measured them. Every
geometric question this phase was scoped to answer is now answered from the source
material, and one of the two long-standing residual unknowns turned out to be a
*symptom* rather than a question.

**What was delivered**
- **The screen margin is 24 px, corrected from 20** (**D-60**). The card edges in
  the History, Settings, and About mockups all sit at logical x≈24 — consistently,
  across three independently rendered images. `desing.md` §4 gave a prose range of
  "~16–20 pt" and Phase 3 took 20 from the top of it; the prose was simply wrong
  about its own source. This is D-03's lesson applied to spacing: the spec was
  written by eye, the pixels are authoritative, and here they disagree.
- **R-2 closed at 88 px, as a consequence of the above.** The keypad derives its
  cells from the width left over after the margins (D-27), so the key size was
  never an independent quantity: `(442 − 2·margin − 3·14) / 4` gives **90.0 px** at
  margin 20 and **88.0 px** at margin 24. The mockup's five key rows measure
  174–178 px at 2x, i.e. **86.5–87.5 logical px**. The keys were 2–3 px too large
  for a reason that had nothing to do with keys. This is why Phase 1 could only
  ever report a 85–95 *range* — it was measuring a consequence and had no route to
  the cause, so the range was the honest answer available at the time. Verified
  empirically, not assumed: the rendered cell is 88.0 px.
- **R-1 closed as chosen, not measured** (**D-61**). All three Settings mockup
  toggles are ON — track 44 × 25.5 px, orange `#F89508` — so **no mockup contains
  the OFF state**. This is now a positive finding rather than an absence of one, so
  no future re-measurement can resolve it and carrying it open would misreport a
  closed question as pending. `#2A2A2A` is accepted as a design decision, with its
  D-26 reasoning unchanged and its correction path still one edit.
- **Two stale tests corrected to match reality.** The key-size test asserted
  `inInclusiveRange(85, 95)` — it encoded R-2's unresolved range as if it were the
  specification, so it would have passed no matter how wrong the keys were. It now
  asserts the measured 86–88.5 band. A new `AppSpacing` group pins
  `screenHorizontal == 24`, because that token silently determines the key size and
  a drift there would move R-2's closed answer without failing anything else.
- **The palette was re-verified against pixels** rather than against D-03's record
  of them. `#000000`, `#1E1E1E`, and `#F89508` all confirmed; D-03's values stand
  unchanged after seven phases of not being re-checked.

**Decisions recorded**  
D-60 and D-61 in `DECISIONS.md`.

**Verification**
- `flutter analyze` — no issues.
- `flutter test` — **403 passing** (401 + 2 new). All 401 Phase 8 tests pass
  untouched, including the four layout suites that would have caught a narrower
  cell clipping: 320×568, 442×960, and 480×1000 at the 1.3× text-scale clamp (D-54),
  plus the calculator's own no-overflow checks at mockup, small-phone, and
  large-phone sizes.
- `flutter build apk --debug` and `flutter build apk --release` — both succeed. (The
  `in_app_review` KGP warning from Phase 2 is still present and still harmless.)

**Deliverables**
- Polished UI matching the mockups. ✅ (for every value that could be measured)
- Test suite with high coverage of critical paths. ✅
- Bug tracker cleared of P0/P1 issues. ✅ (one defect found and fixed; see below)

**Acceptance Criteria**
- All AC-xxx from prd.md pass. ✅ — AC-007 and AC-016 are the two this phase
  exists for. AC-016 (palette vs `desing.md` §2) is now verified against pixels
  rather than against the document. AC-007 is verified for layout and colour; the
  caveat below still applies to everything that is not a measurement.
- Visual differences from mockups are minimal and intentional. ✅ for measured
  geometry and colour; see the caveat.
- No critical or major bugs remain. ✅ — one found, one fixed.

**The defect this phase found.** `screenHorizontal` was 20 px against a measured
24 px. It is worth recording *how* it survived seven phases: every one of them
asserted the app against `desing.md`, and `desing.md` said "~16–20 pt". A test
suite can only verify a component against its stated specification; it cannot
detect that the specification and the source artwork disagree. That gap is the
reason Phase 9 read pixels, and the reason the margin now has both a measured
value and a test pinning it.

**Caveat on what remains unverified.** This phase could read the mockups' *pixels*
but not *see* the images. Measured — and therefore genuinely verified — are the
palette, the margins, the key geometry, and the toggle track size. Everything
judgmental (layout composition, copy, hierarchy, icon choices) is still verified
against transcribed spec plus measurement rather than by eye, because a model
without image input cannot compare two pictures. That caveat is narrower than the
one Phases 2–8 carried, but it is not zero.

**Known limitations**
- **No device or emulator exists** (`flutter emulators` reports none), so frame
  smoothness, TalkBack behaviour, the live review prompt, and the share sheet
  remain unverified. This limitation is inherited and unchanged since Phase 2.
- Text scaling remains capped at 1.3× (D-54); 1.5× and 2.0× are deliberate.
- Settings and About surfaces read `#0D0F12`/`#0E0F11` against History's
  `#101011`. A 3-unit spread across AI-rendered images, treated as generation noise
  rather than a real palette split; the single `surface` token is retained.

---

## Phase 10: Production Build & Release Preparation — **COMPLETE (2 external gates open)**

**Objective**  
Prepare store-ready builds and supporting materials.

**Tasks**
- Configure release signing and build variants. ✅ (**D-62**)
- Prepare store listings (screenshots from the four screens, description). ✅ (**D-67**)
- Final version number (1.0.0). ✅ `1.0.0+1`, `versionCode` 1
- **Replace the placeholder Privacy Policy and Terms of Service copy with the real
  legal text** (D-07) — this is a hard release gate. ✅ (**D-68**)
- Confirm the store listing identifier for the Rate App fallback (D-08). ✅
- Create release notes. ✅
- Optional: internal beta / TestFlight / Internal Testing track. ⏸ not started
- Tag release and archive documentation. ✅ `v1.0.0`

**Dependencies**  
Phase 9 complete.

**Deliverables**
- Signed production builds. ✅ — APK, AAB, and per-ABI split APKs all build and verify
- Store assets and metadata. ✅ — icon, feature graphic, four screenshots, listing, release notes
- Final documentation package. ✅

**Acceptance Criteria**
- Builds install and run correctly on target devices. ⚠️ **unverified** — see below
- All required store assets are ready. ✅
- Version 1.0.0 is tagged. ✅

**Completion Condition**  
Application is ready for public release. **Source-side, yes; submission, no.** Everything
buildable from this repository is built and documented. Publication is blocked on two
things that are not in it — a real upload keystore, a real contact email, and a public
privacy-policy URL — plus a device pass nobody has performed. `store/README.md` holds
the publication checklist.

---

### What was built

| Artifact | Size | Verified by |
|---|---|---|
| `flutter-apk/app-release.apk` | 48.4 MB | `apksigner verify` — v2 signature, `CN=Throwaway` |
| `bundle/release/app-release.aab` | 47.9 MB | `jarsigner -verify` — exit 0, `META-INF/UPLOAD.RSA` |
| split per ABI (armeabi-v7a) | 14.7 MB | builds |
| split per ABI (arm64-v8a) | 17.2 MB | builds |
| split per ABI (x86_64) | 18.7 MB | builds |

### What was measured

These are the checks that are worth having in a release, and each one was run
against a built artifact rather than against the source:

- **No `INTERNET` permission.** `aapt2 dump badging` on the release APK lists no
  network permission; the only permission present is the app-generated
  `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`. This is what makes the Privacy
  Policy's "makes no network requests" claim true at the platform level, and it
  is the evidence behind the Data Safety form's "no data collected" answer.
- **16 KB page alignment.** All 12 native libraries across the three ABIs were
  parsed and their `PT_LOAD` `p_align` values checked: every one is 16384 or
  65536. Required for Android 15+; the 65536 values are Flutter's own
  alignment, and 16384 is the floor.
- **Manifest.** Compiled output carries `label="Calculator"`, `allowBackup="false"`,
  `fullBackupContent="false"`, `dataExtractionRules`, and `roundIcon`.
- **Manifest badging.** `minSdk 24`, `targetSdk 36`, label, and version all as
  intended. targetSdk 36 satisfies Play's 31 Aug 2026 requirement for new apps.
- **Text fields.** `tool/measure_store_fields.ps1` measures the paste block of
  each Play field against its limit: 69/80, 1828/4000, 482/500.
- **Tests.** 421 passing, 4 skipped (the opt-in screenshot test), clean
  `flutter analyze`.

### The size result, and why it is not a problem

The fat APK is 48.4 MB and R8 barely moved it: 47.3 MB of that is native code
(`libflutter.so` and `libapp.so` for three ABIs) and only 0.95 MB is dex. R8
shrinks the dex, so the ceiling was never in reach. The per-ABI splits are
14.7–18.7 MB, which is the actual answer, and it is what Play serves anyway.

R8 and resource shrinking are still enabled (**D-64**) because that is the right
release posture and it costs nothing — just not because it saves 40 MB. The
expectation is recorded in **D-63** so nobody chases the wrong lever later.

### Two claims this phase got wrong, and the fix

The store copy and the in-app legal text were written first and audited against
the source afterwards. The audit found two false claims, both of the same shape —
a plausible-sounding description of a feature that does not exist quite that way:

1. Both the release notes and the listing described clearing history as
   **"one-tap"**. It is not: `history_screen.dart` routes both the header trash
   and the in-list clear action through `_confirmClear`, which raises
   `AppConfirmationDialog` before deleting anything. That is deliberate and is
   D-05 / AC-008. Now stated as "a Clear button that asks before it deletes".
2. The listing and the shipped Privacy Policy both told the reader to **"clear
   your history in Settings"**. Settings has no such control — it has a *toggle*
   for whether history is recorded at all. Clearing lives on the History screen.
   Both are corrected, and `listing.md` now carries a claim-audit table
   recording where each remaining claim is verified, so the next reader can
   check rather than trust.

This is the one failure mode documentation review does not catch and tests do:
prose that is wrong in a way nothing fails on. The legal-text claims that *can*
be checked against the platform now are — **D-68** asserts the no-`INTERNET`
claim and the backup claim in `test/unit/legal_content_test.dart`.

### Known limitations

- **No device or emulator was available** (`flutter emulators` reports none), so
  nothing was installed or run. The build artifacts are verified as *artifacts* —
  signed, aligned, and correctly manifested — not as running software. A first
  launch on real hardware is still outstanding, as are the share sheet, the
  in-app review prompt, and a TalkBack pass. Inherited and unchanged since
  Phase 2; `store/README.md` keeps it as an explicit checklist item rather than
  letting "builds clean" stand in for "runs".
- **The signing key is a throwaway.** `CN=Throwaway` was generated to prove the
  pipeline end to end, then deleted along with its `key.properties`. The
  repository ships no keystore. A real upload key is required before publishing,
  and the missing-key path is a hard build failure (**D-62**) rather than a
  silent debug-signed release. Deleting the key also surfaced a bug in that same
  code: `buildTypes { release { … } }` is evaluated at configuration time for
  every variant, so `getByName("release")` made `flutter build apk --debug` fail
  on any machine without a key. It is now `findByName`, and both the debug
  success and the release hard-failure were verified after the fix.
- **Two publication gates are external** and are documented rather than worked
  around: the legal contact email is a tracked placeholder
  (`TODO-replace-with-your-address@example.com`, `example.com` cannot receive
  mail), and Play requires a public privacy-policy URL that cannot be created
  from a repository.
- **R8 keep rules are unverified at runtime.** Nothing needed a keep rule, and
  the build proves nothing about the runtime behaviour. A stripped class would
  crash on a device, and this phase could not catch that.
- **The `in_app_review` KGP warning persists.** Flutter reports that the plugin
  uses a legacy Kotlin Gradle Plugin application. It builds and works today;
  a future Flutter version may require an update.
- **Store graphics are generated, not designed.** The icon, feature graphic, and
  screenshots come from `tool/generate_assets.ps1` and a golden test rendering
  the real app. They are correct and consistent, and they are not the product of
  an artist's eye. Phase 9's caveat about what could not be judged by eye applies
  to them too.

---

## Feature Prioritization Reminder

**Must Have (MVP)**  
All features marked Must Have in feature.md and all AC-xxx in prd.md.

**Should Have**  
- Polished empty states.
- Basic accessibility labels.
- Individual history item deletion (deferred past v1.0 by D-15).

**Promoted to Must Have**  
- Confirmation dialog before clearing history (D-05) — destructive and
  irreversible, so it is part of the MVP.

**Could Have / Post-MVP**
- Light theme.
- Scientific mode or additional functions.
- Cloud backup of history.
- Custom themes or accent colors.

---

## Risk & Mitigation Notes

| Risk                              | Mitigation                                      |
|-----------------------------------|-------------------------------------------------|
| Visual mismatch with mockups      | Phase 9 dedicated to pixel comparison; colors are now measured, not estimated (D-03) |
| Docs referenced the wrong mockup for each screen | Corrected in D-13 and propagated through all four documents |
| Engine's `formatNumber` silently drops specified behavior (thousands separators) | Caught in Phase 1 and closed by D-18 before any code was written |
| Calculator edge-case bugs         | Engine is unit-tested against the left-to-right model and edge cases in Phase 4 (`struction.md` §13) |
| Persistence issues                | Explicit restart tests in Phase 5 & 6, including the 200-entry cap |
| Platform differences (haptics/sound)| No package dependency; uses built-in `HapticFeedback` / `SystemSound` (D-16) |
| Legal copy not ready at release  | Placeholder content ships in v1.0 (D-07); final text is a Phase 10 checklist item |
| Scope creep                       | Strict adherence to the Must-Have list in `feature.md` |

---

**End of Development Roadmap**

This roadmap produces a usable, testable increment at the end of every phase and culminates in a polished, mockup-faithful calculator application.