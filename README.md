# Calculator

A clean, minimal, dark-themed calculator for Android. Four screens — Calculator,
History, Settings, About — plus two in-app legal pages. Fully offline: no network
calls, no analytics, no ads.

Built to match the four design mockups in [`Mockups/`](Mockups/).

---

## Status

Implementation follows [`docs/phases.md`](docs/phases.md). Phases 1–10 are
**Complete**:

| Phase | Title | Status |
|-------|-------|--------|
| 1 | Requirements & Design Finalization | **Complete** |
| 2 | Project Setup & Architecture Skeleton | **Complete** |
| 3 | Design System & Shared Components | **Complete** |
| 4 | Calculator Engine & Main Screen | **Complete** |
| 5 | History Screen & Persistence | **Complete** |
| 6 | Settings Screen & Preferences | **Complete** |
| 7 | About and Legal Screens | **Complete** |
| 8 | Integration, Navigation & Cross-Cutting Concerns | **Complete** |
| 9 | UI/UX Matching, Testing & Bug Fixing | **Complete** |
| 10 | Production Build & Release Preparation | **Complete** — 2 external gates open |

The app is **feature-complete** and **release-ready from a source standpoint**:
463 passing tests, a clean `flutter analyze`, and a signed release APK, AAB,
and per-ABI split APKs that verify. See [`store/`](store/) for the listing
copy, generated assets, and the publication checklist.

**Two things block publication, and neither is in this repository:** the app
ships no upload keystore (release builds fail loudly without a
`key.properties`, `D-62`), and the legal contact email is a tracked placeholder
because `example.com` cannot receive mail. Play also requires a public
privacy-policy URL. Nothing has been installed or run on a device — no emulator
was available — so a first-launch pass is still outstanding. The full set is in
[`store/README.md`](store/README.md).

Phase 10 measured the built artifacts rather than trusting the build: it
confirmed no `INTERNET` permission in the release APK, 16 KB alignment across
all 12 native libraries, the manifest's backup attributes, and the Play text
field lengths. It also caught two false claims in its own store copy and
corrected them — the details are in [`docs/phases.md`](docs/phases.md) Phase 10.

**Read [`docs/DECISIONS.md`](docs/DECISIONS.md) before changing anything** — it is
the authoritative record of every product and technology decision (`D-01` … `D-72`).

One earlier result is worth knowing before touching the design system: Phase 9
compared every screen against the mockup **pixels** — the first phase able to;
Phases 2–8 each closed by noting the images could not be read. It corrected the
screen margin from 20 px to its measured 24 px, which incidentally fixed the
calculator key diameter (`D-60`), and closed both long-standing residual unknowns
(`D-60`, `D-61`).

### Design System

Every colour, text style, spacing value, and radius is a token in
`lib/core/design/`, measured from the mockup pixels in Phase 1 (`D-03`). No screen
hard-codes a hex value.

In a **debug build** there is a browsable catalog of every component at the
`/catalog` route (D-25). It has no button anywhere in the app — push the route
yourself — and it is not compiled into release builds at all.

---

## Prerequisites

| Tool | Version used |
|------|---------------|
| Flutter | 3.47.2 (stable) |
| Dart | 3.13.2 |
| Android SDK | 36.0.0 |
| JDK | 17 |

```bash
flutter doctor          # verify the Android toolchain
```

The project is **Android-only** for v1.0 (portrait phones, per `D-09`). No `ios/`,
`web/`, `windows/`, or `desktop/` folder is checked in.

---

## Getting Started

```bash
flutter pub get        # install dependencies
flutter run            # launch on a connected device or emulator
```

No emulator or device is attached by default on a fresh machine. Create one with:

```bash
flutter emulators --create
flutter emulators --launch <name>
```

## Development Commands

```bash
flutter analyze        # static analysis — must report "No issues found!"
flutter test           # unit + widget tests
flutter build apk --debug          # builds without any signing key
flutter build apk --release        # requires android/key.properties — see below
flutter build appbundle --release   # the artifact Play actually consumes
```

### Release signing

`release` builds read credentials from `android/key.properties`, which is
git-ignored along with the keystore it points at:

```properties
storeFile=calculator-upload.jks   # relative to android/
storePassword=…
keyAlias=upload
keyPassword=…
```

Without `storeFile`, a release build **fails immediately** with instructions
rather than silently falling back to the debug key — a debug-signed release
installs everywhere and is accepted by no store, which is a worse outcome than
a build error (`D-62`). `flutter build apk --debug` needs no key.

Generate an upload key with:

```bash
keytool -genkeypair -v -keystore android/calculator-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Back the keystore up outside this repository.** Losing it means never being
able to update the published app.

R8 and resource shrinking are on for release (`D-64`), and release artifacts are
verified in `docs/phases.md` Phase 10. Note that R8 barely changes the total
size here — 47.3 MB of the 48.4 MB fat APK is native code across three ABIs. Use
`--split-per-abi` or an App Bundle for size (`D-63`).

## Testing Layout

```
test/
├── unit/              # pure Dart: engine, formatters, repositories
├── widget/            # screen layout, navigation flow, cross-cutting concerns
└── integration/       # full journeys on a real device
```

421 tests pass as of Phase 10, with 4 skipped — the opt-in store-screenshot test
described below. `test/widget/design_system_test.dart` asserts every
component against its token values — the palette hexes, the type scale, the switch
tracks, the screen margin — so a component that stops consuming the design system
fails the suite rather than drifting quietly. Golden image tests were considered and
rejected *as a regression suite*: they are brittle across platforms and fonts, and
they would still pass if a screen hard-coded a hex that happened to look right.

Phase 10 later used golden rendering anyway, for a different job — generating the
four Play Store screenshots from the real app (`D-67`). That is consistent rather
than contradictory: the test is skipped unless `GENERATE_STORE_ASSETS` is defined,
so it never guards a build. It is a generator that happens to be written as a
test, which is also why CI would never compare those PNGs across machines.

Phase 8 added the cross-cutting suites that earlier phases could not write, because
there was no whole app to write them against:

| Suite | What it pins down |
|-------|-------------------|
| `text_scaling_test.dart` | Layout holds on the 320×568 minimum surface across the OS text-scale range. Scale is clamped to 1.0×–1.3× (`D-54`). |
| `accessibility_test.dart` | The semantics tree: one labelled node per row, button/header/selection state, switch state, and 44pt touch targets (`D-59`). |
| `cold_start_test.dart` | A genuine restart — unmount, re-seed the store, new `ProviderScope` — proving settings and history return while in-flight calculator state does not (`D-55`). |
| `navigation_graph_test.dart` | The registered route set, and the *negative* half of `D-20`: nothing reachable from the Calculator beyond Settings and History. |
| `performance_test.dart` | Structural, not timing: a result lands in one frame, and 200 history entries build a screenful rather than all of them. Frame smoothness still needs a device — Phase 9 could not close it, as no emulator exists. |

Two of these suites caught real defects while being written, which is the argument for
having them: a shared test helper was tapping rows that were built but off-screen (a
silent no-op), and the History retry was invalidating a provider that Riverpod had
already cached. Both are described in [`docs/phases.md`](docs/phases.md) Phase 8.

---

## Project Structure

Full rationale in [`docs/struction.md`](docs/struction.md) §14.

```
lib/
├── main.dart                  # entry point, portrait lock (D-09)
├── app.dart                   # MaterialApp.router + ProviderScope
├── core/
│   ├── config/                # AppInfo: name, version, developer (D-11, D-12)
│   ├── design/                # tokens: colors, typography, spacing, theme, providers
│   ├── storage/               # preferences + history storage (D-02)
│   ├── utils/                 # number formatting (D-18, D-21), day grouping
│   └── widgets/               # headers, AppIconButton, CalculatorButton, rows, dialog,
│                              # empty state
├── features/
│   ├── calculator/            # domain/ engine, presentation/ screen + widgets
│   ├── history/               # data/ repository, domain/ entry, presentation/
│   ├── settings/              # domain/ AppSettings, data/ repository
│   ├── about/                 # presentation/
│   └── legal/                 # data/ policy text (D-68), presentation/ screens (D-07)
└── routing/
    ├── app_router.dart        # go_router config as a Riverpod provider (D-01)
    └── app_routes.dart        # route path constants
```

**Architecture:** Clean / Layered (`docs/struction.md` §1). The domain layer holds
the calculator engine and repository *interfaces* and imports no Flutter code, so it
is unit-testable in isolation. Repositories are wired through Riverpod providers
so tests can substitute in-memory fakes. `core` never imports a feature, with one
deliberate and recorded exception: the number formatter reads the engine's
`formatNumber` (D-24).

## State & Navigation

- **State:** Riverpod 2.6.1 (`D-01`). The router is a `Provider<GoRouter>` disposed
  with the `ProviderScope`, so each scope gets a fresh navigation stack.
- **Navigation:** the Calculator is the root route `/`; History, Settings, About,
  Privacy, and Terms are pushed (`D-20`).

```
Calculator (Root /)
  ├── push → History    /history      (clock icon, top right)
  └── push → Settings   /settings     (hamburger, top left)
        ├── push → About     /about
        ├── push → Privacy   /privacy
        └── push → Terms     /terms
```

`/catalog` is registered in debug builds only and is a design tool, not part of
this graph (`D-25`). Phase 8 locks the graph down with tests: the registered path set
is asserted exactly, and so is the *absence* of any other way out of the Calculator
(`D-56`). Transitions are `go_router`'s platform default — no route customises its
page transition, because no mockup shows motion and inventing it would be inventing
the design.

State persists to `shared_preferences` and is restored on the next launch by the
providers' own `build()` — there is no lifecycle observer, and none is needed
(`D-55`). What is deliberately **not** restored is an in-flight calculation: the
app reopens at `0`, which is what `prd.md` §11 asks for.

---

## Dependencies

Locked in Phase 1 (`D-01`, `docs/struction.md` §15).

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` 2.6.1 | State management |
| `riverpod` 2.6.1 | Pinned to match `flutter_riverpod` exactly |
| `go_router` 14.8.1 | Declarative navigation |
| `shared_preferences` 2.5.3 | Settings + history persistence (`D-02`) |
| `in_app_review` ^2.0.12 | Native review prompt (`D-08`) |
| `share_plus` ^13.3.0 | System share sheet |

**Deliberately absent:** no database (history is a capped flat list, `D-02`), no
audio or haptics package (built-in `HapticFeedback` / `SystemSound` is used, `D-16`),
no web view, no HTTP client (the app is fully offline, NFR-005), and no `intl` — day
grouping spells out its twelve month names instead, so the dependency set stays
exactly as Phase 1 fixed it (`D-01`). `url_launcher` appears only as a transitive
dependency of `share_plus` (`D-23`).

---

## Changelog

### Header port (`D-74`)

Post-Phase-10 work: every page header is rebuilt as a `Row` the design system
owns, with bordered action boxes, **using the existing palette unchanged** — no
colour token was added, edited, or removed.

**Added**

- `AppIconButton` — a 48 px square with an `AppColors.surface` fill and an
  `AppColors.divider` border around a 22 px glyph. It stays a real `IconButton`,
  so tooltips, `find.byType(IconButton)`, and the accessibility layer keep
  working.
- `AppPageHeader` — a destination's top bar: optional leading action, optional
  start-aligned title, optional actions.
- `SecondaryPageHeader` — a back box, a centred title and optional subtitle, and
  an optional trailing action. The action-less side is filled with an equal-width
  blank, which is what centres the title.
- `SecondaryPageScaffold` — the frame every pushed screen shares: the black page,
  a `SafeArea`, and the header above an `Expanded` body.
- `AppRadius.iconButton` (12); `AppSizes.headerHeight` is now documented as a
  *minimum*.
- `D-74` in [`docs/DECISIONS.md`](docs/DECISIONS.md).

**Changed**

- Every header action now rides the 24 px screen margin with its *box* rather
  than its glyph, and the History title is centred instead of start-aligned.
- The History delete glyph is back to `AppIconSize.row` (22): the box it sits in
  carries the weight now, and D-72's 28 px glyph existed only to reach the margin.
- The calculator's top bar is `AppPageHeader`, inside the same capped column as
  the display and the keypad.
- The test suite is 506 passing (was 463), with 4 skipped.

**Removed**

- `AppHeader`, `AppHeaderTitleAlignment`, `AppSizes.headerIconInset`, and the
  calculator's private `_CalculatorTopBar`.

**Fixed**

- `store/play/screenshots/*.png` are stale and need `tool/generate_assets.ps1`
  to re-render.

---

### History screen redesign (`D-72`)

Post-Phase-10 work: the History page is rebuilt to the redesign mockup
**without touching grouping, persistence, the confirmation gate, or
tap-to-load**. Only presentation, plus the tokens and one shared component it
needed.

**Added**

- `AppColors.surfaceRaised` (`#151517`) — the History card fill, one step above
  the shared `surface`, so the other cards in the app are untouched.
- `AppSpacing.historyHorizontal` (48), `historyCardGap` (12),
  `historyGroupGap` (44); `AppRadius.historyCard` (30);
  `AppSizes.historyCardMinHeight` (150).
- `AppTypography.historyDayLabel`; `historyExpression` re-specced to 28 pt and
  `historyResult` to 44 pt.
- `AppIconSize.large` (28) and `AppIconSize.illustration` (40).
- `HistoryDayLabel` — the sentence-case 27 pt day heading, with
  `Semantics(header: true)`.
- `AppHeader.titleAlignment` (new `AppHeaderTitleAlignment` enum) and
  `AppHeader.leadingSize`, both optional with the previous behaviour as the
  default.
- `test/widget/history_responsive_test.dart` — the card's geometry across the
  supported phone widths.
- `D-70` (backfilled — it was referenced from five places but had no body) and
  `D-72` in [`docs/DECISIONS.md`](docs/DECISIONS.md).

**Changed**

- The History cards: 150 pt-minimum, 30 px-radius `surfaceRaised` surfaces inset
  48 px, with the result in a `FittedBox` so it shrinks rather than truncating,
  and a 28 px chevron.
- The History header: title start-aligned beside a 28 px back arrow, and the
  trash is a bare outline glyph.
- Day headings are now sentence case (`Today`, not `TODAY`); the empty-state
  glyph is 40 px instead of 44.
- The test suite is 463 passing (was 421), with 4 skipped.

**Removed**

- `HeaderActionButton`, unused once the History trash lost its accent badge.
- The orange badge and filled `delete_rounded` glyph on the History action.

**Fixed**

- `header_alignment_test.dart` walked to the Settings row "About", which does
  not exist — the row is "App Version" and "About" is a section label that
  renders uppercased — so the walk never measured About, Privacy, or Terms.
- A latent seed-order bug in `history_screen_test.dart`: entries were passed
  newest-first to `mockHistoryStore`, which reverses its input, putting "Today"
  at the *bottom* of the screen. The taller cards exposed it by pushing that
  group off the fold.
- `store/play/screenshots/02-history.png` is stale and needs
  `tool/generate_assets.ps1` to re-render.

---

## Related Documentation

| Document | Contents |
|----------|----------|
| [`docs/prd.md`](docs/prd.md) | Product requirements, acceptance criteria (`AC-xxx`) |
| [`docs/feature.md`](docs/feature.md) | Feature list with Must / Should / Could priority |
| [`docs/desing.md`](docs/desing.md) | Design spec, measured tokens, screen layouts |
| [`docs/struction.md`](docs/struction.md) | Architecture and project structure blueprint |
| [`docs/phases.md`](docs/phases.md) | 10-phase implementation roadmap |
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | Decision record — the authoritative source |
| [`store/README.md`](store/README.md) | Listing copy, generated assets, publication checklist |
| [`store/listing.md`](store/listing.md) | Play descriptions, Data Safety answers, claim audit, open gates |

---

## Legal

The Privacy Policy and Terms of Service are real, final text in
`lib/features/legal/data/legal_content.dart`, with their platform claims
test-gated (`D-68`). Two release gates remain open and are documented rather
than worked around:

1. `legalContactEmail` is `TODO-replace-with-your-address@example.com`.
   `example.com` is IANA-reserved and cannot receive mail — safe to commit, not
   to publish. `test/unit/legal_content_test.dart` asserts the placeholder is
   present, so supplying a real address fails that test on purpose.
2. Play requires a **public privacy-policy URL**, reachable outside the app.
   Publish the in-app text verbatim at a URL you control.

The app's central privacy claim is enforced, not just asserted: the release APK
declares no `INTERNET` permission, and both cloud backup and device-to-device
transfer are excluded (`D-65`). Neither was verified on a device — no emulator
was available in this environment.

## License

See [`LICENSE`](LICENSE).
