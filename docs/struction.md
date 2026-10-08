# Software Architecture & Project Structure
## Calculator App

**Document Status:** Implementation Blueprint (frozen, Phase 1)  
**Stack:** Flutter 3.47.2 / Dart 3.13.2 — Riverpod, go_router, shared_preferences (D-01)  
**Decisions:** See [DECISIONS.md](DECISIONS.md) for all `D-xx` references  
**Goal:** Provide a clear, maintainable structure that matches the mockups and requirements.

---

## 1. Recommended Application Architecture

**Pattern:** Clean / Layered Architecture with clear separation of concerns.

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                    │
│  (Screens / UI Components / View Models / Hooks)         │
├─────────────────────────────────────────────────────────┤
│                    Application Layer                     │
│  (Use Cases / Navigation / State Coordination)           │
├─────────────────────────────────────────────────────────┤
│                     Domain Layer                         │
│  (Calculator Engine / Entities / Business Rules)         │
├─────────────────────────────────────────────────────────┤
│                  Infrastructure Layer                    │
│  (Local Storage / Settings / Platform Feedback)          │
└─────────────────────────────────────────────────────────┘
```

**Key Benefits**
- Calculator logic is independent of UI framework.
- Easy to unit-test the engine.
- Settings and History can be swapped (e.g., different storage backends) without touching UI.
- Matches the four-screen structure cleanly.

---

## 2. Screen and Module Organization

| Module / Screen     | Responsibility                                      |
|---------------------|-----------------------------------------------------|
| Calculator          | Input handling, display, evaluation trigger         |
| History             | List display, load item, clear all                  |
| Settings            | Preference management and persistence               |
| About               | Static information + system actions (share/rate)    |
| Legal               | Privacy Policy / Terms of Service in-app text        |
| Navigation          | Routing between the four screens                    |
| Shared / Common     | Reusable UI components, theme tokens, utilities     |

---

## 3. Component Architecture

**UI Components (Presentation)**
- Atomic: `CalculatorButton`, `ToggleSwitch`, `Icon`, `Text`
- Molecular: `SettingsRow`, `HistoryCard`, `SectionHeader`
- Organisms: `ButtonGrid`, `HistoryList`, `SettingsList`, `AppHeader`
- Screens: Full-page compositions

**Domain Components**
- `CalculatorEngine` — pure functions / class for parsing & evaluation
- `HistoryRepository` — interface for storage
- `SettingsRepository` — interface for preferences

---

## 4. Separation of UI, Business Logic, and Data

| Concern              | Location                  | Notes                                      |
|----------------------|---------------------------|--------------------------------------------|
| UI Rendering         | Screens + Components      | No business rules                          |
| Input Handling       | ViewModel / Controller    | Maps button presses to engine commands     |
| Calculation Logic    | Calculator Engine         | Pure, testable, framework-agnostic         |
| History Management   | History Service + Repo    | Append, query by day, clear                |
| Settings Management  | Settings Service + Repo   | Get / set / observe changes                |
| Feedback (Sound/Haptic)| Platform Service        | Called from input handler based on settings|

---

## 5. Calculator Engine Responsibilities

The engine is the heart of the application and must be isolated.

**Responsibilities**
- Accept sequential input (digits, operators, functions).
- Maintain current expression / intermediate state.
- Evaluate on “=” using **left-to-right, apply-as-pressed** semantics (D-17).
- Handle special operations: AC, +/−, %.
- Format output according to decimal places setting and thousands separators (D-18).
- Return structured results or errors (never throw to UI).

**Recommended Interface (Conceptual)**
```
InputToken: Digit | Operator | Function | Equals | Clear
Result: { expression: string, value: number | null, error: string | null, display: string }
```

**Evaluation Strategy**
- **No parser is required.** Each operator is applied to the running accumulator as
  it is pressed, which is exactly how the iOS, Android, and Windows calculators behave
  (D-17). This removes the shunting-yard / recursive-descent machinery entirely.
- `eval()` of raw strings is avoided for security and predictability.
- There is deliberately **no** `×÷`-over-`+−` precedence, so `2 + 3 × 4` = `20`.

**Engine Ownership**
The engine lives at `lib/features/calculator/domain/calculator_engine.dart` and
is first-party to this app: `CalculatorEngine`, `CalculatorKey`,
`CalculatorOperator`, `CalculatorState`, and `formatNumber`. It implements the
left-to-right model of D-17 and the `/100` percent behavior of D-06 directly,
and imports nothing from Flutter (see §1). Only the formatting layer is extended
for D-18.

The `backspace` key and its handler are deliberately **not** part of the engine,
because the keypad specification has no ⌫ key (**D-19**).

---

## 6. Expression Handling and Mathematical Evaluation

1. Key presses are appended to the engine's internal token list.
2. An operator press folds the current entry into the accumulator immediately.
3. On Equals:
   - Validate the pending operation is well formed.
   - Apply the pending operation.
   - Apply decimal places and thousands-separator formatting.
   - Emit result + expression string for history.
4. Error cases (division by zero, empty expression) return a structured error object
   rather than throwing.

**Supported Operations (MVP)**
- Binary: +, −, ×, ÷
- Unary: +/− (sign), % (percentage)
- Clear: AC

---

## 7. Navigation Architecture

**Chosen Approach**
- `go_router` (D-01), with the router exposed as a Riverpod `Provider` so it is
  created and disposed per `ProviderScope` (`lib/routing/app_router.dart`).
- Main Calculator is the root route (`/`).
- History, Settings, About, Privacy, and Terms are pushed on the stack.
- Back gestures / buttons pop the stack.

**Navigation Map** (D-20, D-117 — the gear button opens Settings directly; there is no
drawer, and About / Privacy / Terms hang off Settings rather than the root)
```
Calculator (Root /)
  ├── push → History      /history      # clock icon, top right
  └── push → Settings     /settings     # gear button, top left
        ├── push → About     /about
        ├── push → Privacy   /privacy
        └── push → Terms     /terms
```

Passing state when loading a history item uses a shared state store (the calculator
provider) rather than route parameters, so the value survives the pop.

**Secret Mode routes (D-82, D-84, D-86)**
```
History /history
  └── push → Secret Unlock   /secret/unlock     # ONLY via the 5s hold
        └── replace → Secret  /secret            # on a correct code
              └── push → Secret Settings  /secret/settings
                    ├── push → Change PIN  /secret/change-pin   # pops back here
                    └── Reset PIN → confirm → replace → /secret  # the code is gone
```
The unlocked Secret screen's overflow opens the shared Ethar-style menu panel
(D-115) rather than a drawer; its single row, Settings, is the route above. The
panel is a dialog, so the D-56 platform-transition rule for *router* routes is
untouched.
The unlock screen is entered **only** by the five-second hold, so it is pushed rather than
reached by a deep link, and a correct code **replaces** it rather than pushing on top — leaving
the entry screen on the stack under the secret screen would put a back gesture that returns to a
PIN prompt in front of the user. `history_screen.dart` knows the *route name* and nothing about
`features/secret/`; the dependency arrow points one way, into `routing`, so the §4 one-way rule
survives the new entry point (see §16).

A confirmed **Reset PIN** also replaces the stack with `/secret`, for the same reason in reverse:
the page the user is on, and the page behind it, both need the code that has just been erased.
**Change PIN** pops back to `/secret/settings` and keeps its three steps in one route — three
screens, one entry, so the back arrow inside the flow is the only navigation between them (D-113).

---

## 8. State Management Approach

**Chosen:** Riverpod 2.6.1 (D-01).

**Core Global State**
- Current calculator expression & result
- History list
- Settings (sound, vibration, decimalPlaces, historyEnabled, theme)

**Local UI State**
- Button press animations
- Scroll position
- Temporary confirmation dialogs

Settings changes are observed so that sound/vibration feedback updates immediately.

**Persistence pattern.** Preferences follow a Riverpod `AsyncNotifier` shape with
graceful degradation: if the platform channel is unavailable (unit tests,
unsupported hosts) the controller falls back to in-memory defaults so the app
still runs.

---

## 9. History Storage and Persistence Architecture

**Data Model**
```
HistoryEntry {
  id: string (UUID)
  expression: string
  result: string          // formatted
  resultValue: number     // raw for potential reuse
  timestamp: Date
}
```

**Storage** (D-02)
- `shared_preferences`, one key holding a JSON-encoded list.
- Capped at **200 entries**, oldest evicted first.
- A relational database is unnecessary at this volume; `shared_preferences` also keeps
  the dependency list minimal and works on every target platform.
- Grouped by day in the presentation layer (“Today”, “Yesterday”) rather than by
  storing a day column.

**Repository Interface**
- `getAllGroupedByDay()`
- `add(entry)` — no-op when history is disabled
- `clearAll()`
- `isEnabled()` (respects settings toggle)

---

## 10. Settings Storage and Configuration

**Settings Keys**
- `soundEnabled`: Boolean (default true)
- `vibrationEnabled`: Boolean (default true)
- `decimalPlaces`: Integer (default 2) — rounding precision only; never pads
  trailing zeros, so `2 + 2` renders `4` (**D-21**)
- `historyEnabled`: Boolean (default true)
- `theme`: String (“dark”) — only dark supported in v1.0

**Persistence**
- `shared_preferences` (D-02).
- Load on app start; write on every change.
- Reactive so UI and feedback services stay in sync.

### Secret PIN Storage (D-83)

**Key**
- `secretPin`: String, exactly four decimal digits, default `"0000"`.

Kept in its **own** repository and its **own** `features/secret/` module rather than folded into
`AppSettings`. A PIN is a credential, not a preference, and the separate boundary is what makes that
visible to whoever opens the file next.

**Rules**
- `shared_preferences`, like every other store here — **plaintext, not encrypted**. The code is
  readable on a rooted device, which is a strictly smaller claim than the history's and the same
  claim the rest of this app's data already makes. Recorded as a known limitation in `phases.md`.
- **No new dependency.** `flutter_secure_storage` was rejected (D-83): it would be the first
  package added since Phase 1, breaking the §15 lockdown.
- **No hashing.** The threat is *reading* the store, not *brute-forcing* it, and even with D-88's rate
  limit a hash of four digits is no stronger against the former — which is the only one that matters.
- Validation lives in the `SecretCode` **type** (constructor throws `FormatException`), so a
  malformed code cannot exist as a value — not at the call site, not in storage.
- Reads go through the same `_readOrNull` guard as the settings repository, so a corrupt or
  hand-edited value degrades to `0000` instead of taking down the screen (D-42's contract).
- **A 30-second lockout on the third wrong code** (D-88), counting and deadline kept in a
  `SecretLockoutNotifier` beside the code rather than in the screen, and persisted under
  `'secretLockoutUntil'` so a force-quit does not reset it. D-85's "no lockout" was reversed.
- Changing the PIN requires the current PIN, and the reset row sits behind the code, so a forgotten
  one still has **no in-app recovery** — a known limitation, not an oversight (D-85, D-86, D-88).

---

## 11. Shared Components and Utilities

**Shared UI**
- AppHeader
- SectionHeader
- SettingsRow / ToggleRow
- HistoryCard
- CalculatorButton (with variants)
- Loading / Empty state components
- Confirmation dialog (used by Clear History, D-05)

**Utilities**
- Number formatter (thousands separators + decimal places) — composes `groupThousands`
  with the engine's `formatNumber` (D-18), in `lib/core/utils/format.dart`.
- Date grouping helper (“Today”, “Yesterday”, older)
- Haptic & sound wrappers — `HapticFeedback` / `SystemSound`, **no new packages** (D-16)
- Error message mapper

---

## 12. Error Handling Architecture

- Domain layer returns Result types or error enums (never raw exceptions to UI).
- Presentation layer maps errors to user-visible messages (“Error”).
- Logging of unexpected errors for debugging (optional).
- No network errors expected (fully offline app, NFR-005).

---

## 13. Testing Architecture

| Layer              | Test Type              | Focus                                      |
|--------------------|------------------------|--------------------------------------------|
| Calculator Engine  | Unit tests             | All operations, edge cases, left-to-right folding |
| Repositories       | Unit / Integration     | Persistence, clear, grouping, 200 cap      |
| ViewModels / Controllers | Unit tests       | State transitions, command handling        |
| UI Screens         | Snapshot / Widget tests| Layout matches mockups                     |
| End-to-End         | UI Automation          | Full calculation → history → load flow     |

**Critical Test Cases**
- Basic arithmetic correctness
- Left-to-right evaluation (`2 + 3 × 4` = `20`, D-17)
- Division by zero
- Percent divides by 100 (D-06)
- Decimal places formatting, including a mid-calculation change (D-14)
- Thousands separators (D-18)
- History toggle on/off
- History 200-entry cap with oldest-first eviction (D-02)
- Persistence across restart (integration)

---

## 14. Project Structure

`flutter create .` is run in the project root, which already contains `docs/` and
`Mockups/`.

```
calculator/                      # Apps/Calculator — project root (D-04)
├── Mockups/                     # Design source assets (4 PNGs)
├── docs/                        # This documentation package
│   ├── prd.md
│   ├── feature.md
│   ├── desing.md
│   ├── struction.md
│   ├── phases.md
│   └── DECISIONS.md             # Phase 1 decision record
├── lib/
│   ├── main.dart
│   ├── app.dart                  # MaterialApp.router + ProviderScope
│   ├── core/
│   │   ├── config/               # AppInfo: name, version, developer (D-11, D-12)
│   │   ├── design/               # colors, typography, spacing, themes, tokens barrel
│   │   ├── storage/              # preferences controller, history store (D-02)
│   │   ├── utils/                # number formatter (D-18), date grouping
│   │   └── widgets/              # AppHeader, SectionHeader, SettingsRow, ToggleRow,
│   │                             # HistoryCard, CalculatorButton, dialogs, empty states
│   ├── features/
│   │   ├── calculator/
│   │   │   ├── calculator.dart   # public exports
│   │   │   ├── domain/           # CalculatorEngine (no Flutter imports)
│   │   │   └── presentation/     # screen, controller, widgets/
│   │   ├── history/
│   │   │   ├── history.dart
│   │   │   ├── data/             # history repository over shared_preferences
│   │   │   └── presentation/
│   │   ├── settings/
│   │   │   ├── settings.dart
│   │   │   └── presentation/
│   │   ├── secret/                 # Hidden Secret Mode (D-82, D-83, D-84, D-85,
│   │   │   │                       # D-86, D-88, D-113)
│   │   │   ├── secret.dart
│   │   │   ├── domain/            # SecretCode — validates four digits on construction
│   │   │   ├── data/              # secret repository over shared_preferences
│   │   │   └── presentation/      # unlock, blank screen, settings, change PIN,
│   │   │                          # SecretPinField, lockout controller (D-88)
│   │   ├── about/
│   │   │   ├── about.dart
│   │   │   └── presentation/
│   │   └── legal/                # Privacy + Terms in-app text screens (D-07)
│   │       ├── legal.dart
│   │       └── presentation/
│   └── routing/
│       └── app_router.dart       # go_router config (D-01)
├── test/
│   ├── unit/
│   ├── widget/
│   └── integration/
├── pubspec.yaml
└── README.md
```

**Notes on Structure**
- The Calculator Engine stays completely free of UI and platform imports.
- Repositories are wired through Riverpod providers so they can be overridden in tests.
- The layer naming above is Dart-specific, adapted from the framework-agnostic
  original, and is the layout this project actually uses.

---

## 15. Dependency Set

Locked in Phase 1 (D-01).

| Package                  | Purpose                                          |
|--------------------------|--------------------------------------------------|
| `flutter`                | SDK                                             |
| `flutter_riverpod` ^2.6.1 | State management                               |
| `go_router` ^14.8.1      | Declarative navigation                           |
| `shared_preferences` ^2.5.3 | Settings + history persistence (D-02)       |
| `in_app_review`          | Rate App native review prompt (D-08)             |
| `share_plus`             | Share App system sheet                           |
| `cupertino_icons`        | Icons                                            |

Dev: `flutter_lints`, `flutter_test`, `integration_test`.

**Explicitly NOT used:** a database package (D-02), an audio or haptics package
(D-16), a web-view package (D-07), a URL launcher (D-07), an HTTP client (NFR-005).

> **Note:** `url_launcher` nevertheless appears in `pubspec.lock`, pulled in
> transitively by `share_plus`. No application code imports it, so the intent above
> holds; see **D-23**.

**Platform scope:** Android only for v1.0 (**D-22**). Only the `android/` platform
folder is generated.

---

## 16. Module Communication Summary

```
UI Button Press
    → ViewModel / Controller
        → CalculatorEngine.input(token)
        → FeedbackService.play(settings)   # HapticFeedback / SystemSound
        → (on Equals) HistoryService.add(...)  # skipped when history disabled
        → UI updates from new state

Settings Toggle
    → SettingsService.set(...)
        → Persistent storage write
        → Notify observers (FeedbackService, HistoryService)

History Item Tap
    → Load result into the calculator store
        → Navigation pop to Calculator

Secret Unlock (5s hold on History's bottom Clear History — D-82)
    → HistoryScreen.onSecretRequested()
        → Navigation push /secret/unlock            # History knows a route,
                                                    # not the Secret feature
            → SecretCodeNotifier.verify(entered)
                → SecretRepository.load()            # 'secretPin', default '0000'
                → wrong → clear + shake + "Wrong PIN"; 3rd in a row → 30s
                  lock, persisted under 'secretLockoutUntil' (D-88)
                → right → registerSuccess(), Navigation replace → /secret
                    → overflow tap → push /secret/settings
                        → Change PIN → verify current, enter new, confirm
                            → mismatch → re-ask confirm, keep the candidate
                              (D-113)
                            → match → SecretRepository.save(new)
                              # persisted immediately, then "PIN changed
                              # successfully" for 1200 ms, then pop
                        → Reset PIN → confirm → repository.reset() (erases)
                          → Navigation go /secret
```

---

**This architecture prioritizes testability, maintainability, and fidelity to the provided mockups.**

**End of Architecture Document**
