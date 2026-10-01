# Product Requirements Document (PRD)
## Calculator App — Version 1.0.0

**Document Status:** Frozen for v1.0 Implementation (Phase 1 complete)  
**Primary Source of Truth:** Provided UI Mockups (Main Calculator, History, Settings, About)  
**Decisions:** See [DECISIONS.md](DECISIONS.md) — all open questions are resolved there  
**Last Updated:** 2026-09-28  

---

## 1. Product Overview

A modern, dark-themed mobile calculator application focused on simplicity, speed, and reliability for everyday arithmetic. The app provides a clean standard calculator interface, persistent calculation history, customizable preferences (sound, vibration, decimal places, history retention), and an About section with app information.

The application consists of exactly **four main screens**:
1. Main Calculator
2. History
3. Settings
4. About

All visual design, layout, component hierarchy, and primary interactions are derived directly from the four provided mockups.

### 1.1 Mockup Reference

The mockup filenames encode generation time, not screen identity. The correct mapping is:

| Mockup File                              | Screen               |
|------------------------------------------|----------------------|
| `Mockups/ChatGPT Image Sep 28, 2026, 02_17_57 AM.png` | **History**    |
| `Mockups/ChatGPT Image Sep 28, 2026, 02_22_43 AM.png` | **Main Calculator** |
| `Mockups/ChatGPT Image Sep 28, 2026, 02_25_36 AM.png` | **Settings**   |
| `Mockups/ChatGPT Image Sep 28, 2026, 02_30_45 AM.png` | **About**       |

Established in Phase 1 by D-13. Mockups are 884x1779 px at 2x (logical 442x890), portrait.

---

## 2. Product Vision and Objectives

**Vision**  
Deliver a fast, beautiful, and distraction-free calculator that feels native on modern mobile devices while giving users control over feedback (sound/vibration), precision, and history.

**Objectives**
- Provide accurate basic arithmetic operations with clear visual feedback.
- Allow users to review and reuse past calculations.
- Offer meaningful customization without complexity.
- Maintain a consistent dark visual identity matching the mockups.
- Ensure data (history and settings) persists across app sessions.

---

## 3. Problem Statement and Intended User Needs

**Problem**  
Many built-in or basic calculators lack history, customization of feedback, and a polished modern dark interface. Users often need to re-enter previous calculations or cannot control haptic/audio feedback.

**User Needs**
- Quick entry and evaluation of everyday calculations.
- Ability to recall recent results without retyping.
- Control over key-press sound and vibration.
- Adjustable decimal precision.
- Clear information about the app and its developer.

---

## 4. Target Users and Use Cases

**Primary Users**
- General mobile users performing basic arithmetic (shopping, tipping, simple math).
- Users who prefer dark interfaces.
- Users who value calculation history and haptic/audio feedback.

**Primary Use Cases**
- UC-01: Perform a multi-step calculation and view the result.
- UC-02: Review today’s and previous calculations from History.
- UC-03: Tap a history item to load the expression/result back into the calculator.
- UC-04: Toggle sound and vibration feedback.
- UC-05: Change decimal places precision.
- UC-06: Clear calculation history.
- UC-07: View app version, developer, and legal information.

---

## 5. Product Scope

**In Scope (MVP)**
- Standard calculator operations: +, −, ×, ÷, %, +/−, decimal point, AC (All Clear).
- Expression display + large result display.
- Calculation history grouped by day (Today / Yesterday).
- Settings: Theme (Dark mode shown), Sound, Vibration, Decimal Places, History retention toggle.
- About screen with app identity, version, developer, Rate, Share, Terms.
- In-app Privacy Policy and Terms of Service screens (placeholder legal copy, D-07).
- Persistent storage of history and settings.
- Navigation between the four screens.
- Portrait orientation, phone form factor (D-09).

**Out of Scope (for v1.0)**
- Scientific functions, graphing, unit conversion, currency conversion.
- Light theme (mockups show only dark mode; theme selector exists but only “Dark mode” is shown).
- Cloud sync, accounts, or multi-device history.
- Advanced expression editing (backspace / cursor movement) — only AC is shown.
- Complex chained operations beyond standard calculator behavior; evaluation is strictly
  left-to-right with no `×÷` precedence over `+−` (D-17).
- Individual history item deletion (bulk clear only, D-15).
- Landscape and tablet layouts (D-09).

---

## 6. The Four Main Application Screens

| Screen          | Purpose                                      | Entry Points                          |
|-----------------|----------------------------------------------|---------------------------------------|
| Main Calculator | Perform calculations                         | App launch (default), History item, Settings/About back |
| History         | View and reuse past calculations             | History icon on Calculator, Settings (if enabled) |
| Settings        | Customize appearance and preferences         | Hamburger menu / navigation           |
| About           | App information, version, legal, rate/share  | From Settings or navigation           |

Supporting screens: **Privacy Policy** and **Terms of Service** (in-app text, D-07),
reached from Settings and About.

---

## 7. Functional Requirements

### FR-001 — Calculator Input & Evaluation
- User can enter digits 0–9, decimal point, and operators.
- Expression is shown in a secondary line; result in large primary display.
- Pressing `=` evaluates the current expression and displays the result.
- Evaluation is **strictly left-to-right**, each operator applied as it is pressed.
  There is no `×÷`-over-`+−` precedence: `2 + 3 × 4` = `20` (D-17).
- `AC` clears the current expression and result.
- `+/-` toggles the sign of the current number.
- `%` divides the current value by 100 (D-06).
- Division by zero and invalid expressions must be handled gracefully (see Error Handling).

**Source:** Main Calculator mockup + standard phone-calculator conventions.

### FR-002 — History Recording
- After a successful evaluation (`=`), the expression and result are stored in history.
- History is grouped by day (“Today”, “Yesterday”).
- Each history item shows expression (top) and result (bottom, larger).
- Tapping a history item loads it back into the calculator (expression and/or result).
- History can be cleared via the trash icon or “Clear History” button, **after confirmation** (D-05).

**Source:** History mockup (explicit) + Settings “Keep calculation history” toggle.

### FR-003 — Settings Management
- Sound toggle: enables/disables key-press sound (default ON).
- Vibration toggle: enables/disables haptic feedback on key press (default ON).
- Decimal Places: selectable precision (shown as “2 decimal places”, default 2). Changing it
  affects **result formatting only** — it re-renders the current result and applies to the
  next evaluation, without altering an expression still being entered (D-14).
- History toggle: enables/disables saving of calculations (default ON).
- Theme: currently shows “Dark mode” (only mode present in mockups).
- Settings persist across sessions.

**Source:** Settings mockup (explicit).

### FR-004 — About Information
- Displays app icon, name “Calculator”, version “1.0.0”, short description.
- Shows App Name, Version, Developer (“Hasan Mahadi”, D-11).
- Provides Rate App (native review prompt with store-page fallback, D-08), Share App
  (system share sheet), and Terms of Service actions.

**Source:** About mockup (explicit).

### FR-005 — Legal Content
- Privacy Policy and Terms of Service render as in-app text screens (D-07).
- Content is real, final legal text, held as structured data in
  `lib/features/legal/data/legal_content.dart` with its platform claims test-gated
  (D-68). The contact email remains a tracked placeholder — see `store/README.md`.

**Source:** Inferred (destination and content unprovided — `prd.md` §14).

### FR-006 — Navigation
- From Calculator: hamburger menu (left) opens navigation or Settings; history icon (right) opens History.
- Back arrows return to previous screen.
- History uses a back arrow (left), title “History”, and trash icon (right) (D-10).
- Settings contains links to App Version, Privacy Policy, and Terms of Service, which open
  About and the in-app legal screens respectively.

**Source:** All mockups (explicit navigation affordances).

---

## 8. Non-Functional Requirements

| ID       | Category          | Requirement                                                                 |
|----------|-------------------|-----------------------------------------------------------------------------|
| NFR-001  | Performance       | Calculation evaluation must feel instantaneous (< 50 ms for basic ops).     |
| NFR-002  | Persistence       | History and settings must survive app kill and device restart.              |
| NFR-003  | Visual Fidelity   | UI must match the provided dark-theme mockups as closely as possible.       |
| NFR-004  | Accessibility     | Support Dynamic Type / system font scaling; sufficient contrast (dark UI).  |
| NFR-005  | Offline           | Fully functional without network connectivity.                              |
| NFR-006  | Reliability         | No crashes on invalid input; graceful error display.                        |
| NFR-007  | Platform          | Modern mobile (iOS/Android); portrait phones, responsive to phone sizes (D-09). |
| NFR-008  | Dependencies      | Fully functional offline; no network calls. Only the Rate App action may open a store. |

---

## 9. User Journeys and Primary Workflows

**Journey 1 — Quick Calculation**
1. User opens app → lands on Calculator.
2. Enters numbers and operators.
3. Presses `=` → result appears, expression moves to secondary line.
4. History is automatically updated (if enabled).

**Journey 2 — Reuse History**
1. User taps history icon → History screen.
2. Taps a previous calculation → returns to Calculator with expression/result loaded.
3. Continues calculation if desired.

**Journey 3 — Customize Feedback**
1. User opens Settings.
2. Toggles Sound or Vibration.
3. Changes take effect immediately on next key press.

**Journey 4 — Clear History**
1. User opens History.
2. Taps trash icon or “Clear History”.
3. Confirmation dialog appears → user confirms → history emptied (D-05).

**Journey 5 — Read Legal Content**
1. User opens Settings (or About).
2. Taps “Privacy Policy” or “Terms of Service”.
3. In-app text screen renders the policy (D-07).

---

## 10. Navigation and Screen Relationships

```
App Launch
    └── Main Calculator (default)
            ├── History icon → History
            │       └── Back / item tap → Main Calculator
            ├── Hamburger / menu → Settings
            │       ├── Back → Main Calculator
            │       ├── App Version → About
            │       ├── Privacy Policy → Privacy Policy screen
            │       ├── Terms of Service → Terms of Service screen
            │       └── Theme / Decimal Places → sub-screens
            └── (From Settings) About
                    ├── Rate App → native review prompt / store page
                    ├── Share App → system share sheet
                    ├── Terms of Service → Terms of Service screen
                    └── Back → Settings
```

---

## 11. Data Persistence Requirements

- **History**: List of calculation records (id, expression, result, resultValue, timestamp).
  Grouped by calendar day. Survives app restarts. Respects “Keep calculation history”
  toggle. Persisted as a single JSON-encoded list in `shared_preferences`, capped at
  **200 entries** with oldest-first eviction (D-02).
- **Settings**: Boolean flags (sound, vibration, historyEnabled), integer (decimalPlaces),
  theme identifier. Stored in `shared_preferences` (D-02).
- No user accounts or cloud storage required for v1.0.
- The in-flight calculator expression is **not** persisted; the app restores settings
  and history on cold start, and the calculator opens cleared.

---

## 12. Accessibility and Usability Requirements

- All interactive elements must have sufficient touch target size (≥ 44 pt recommended).
- High contrast text on dark backgrounds.
- Support for system accessibility features (VoiceOver / TalkBack labels on buttons).
- Clear visual hierarchy: result is the most prominent element on Calculator.

---

## 13. Error Handling and Edge Cases

| Scenario                    | Expected Behavior                                      | Source          |
|-----------------------------|--------------------------------------------------------|-----------------|
| Division by zero            | Display “Error” on the primary display                 | Inferred        |
| Invalid expression          | Display “Error”                                        | Inferred        |
| Empty history               | Show empty state message                               | Specified        |
| History disabled            | New calculations are not saved                         | Explicit (Settings) |
| History cap reached         | Oldest entry evicted once 200 entries exist (D-02)     | D-02            |
| App restart                 | Restore last settings and history; calculator cleared  | Required        |
| Multiple rapid key presses  | Debounce or queue input cleanly                        | Inferred        |
| Very large / small numbers  | Scientific notation once the display would overflow     | Specified        |
| Decimal places changed mid-calculation | Current result re-renders; in-flight expression untouched (D-14) | D-14 |
| Clear History tapped        | Confirmation dialog shown; nothing deleted until confirmed (D-05) | D-05 |

---

## 14. Assumptions and Resolved Questions

**Assumptions (confirmed)**
- Only Dark mode is required for v1.0 (Theme row exists but only Dark is shown).
- Decimal Places defaults to 2 and is selectable via a sub-screen or picker.
- Tapping a history item loads the result into the calculator (common pattern).
- No backspace / delete last digit button is present; only AC.

**Resolved in Phase 1** — full rationale in [DECISIONS.md](DECISIONS.md).

| # | Question | Resolution | Decision |
|---|----------|------------|----------|
| 1 | Behavior when Decimal Places changes mid-calculation | Formatting-only: re-renders the current result, leaves an in-flight expression untouched, applies to the next evaluation | D-14 |
| 2 | Whether history items can be individually deleted | **No.** Bulk clear only; individual deletion deferred past v1.0 | D-15 |
| 3 | Content and destination of Privacy Policy / Terms of Service | In-app text screens with placeholder legal copy, replaced before release | D-07 |
| 4 | Whether Rate App opens the native store review prompt | Yes — `in_app_review`, falling back to the store listing | D-08 |
| 5 | Confirmation dialog before clearing history | **Yes**, required | D-05 |

Also resolved: target platform and stack (D-01, D-12), history persistence mechanism
(D-02), color values (D-03), project layout (D-04), percent semantics (D-06),
orientation and form factors (D-09), History header layout (D-10), developer name
(D-11), mockup-to-screen mapping (D-13), feedback dependencies (D-16), and operator
precedence (D-17).

---

## 15. Acceptance Criteria

| ID     | Criteria                                                                 | Priority |
|--------|--------------------------------------------------------------------------|----------|
| AC-001 | Calculator correctly evaluates +, −, ×, ÷, %, +/− and displays result, left-to-right (D-17). | Must |
| AC-002 | Successful calculations appear in History under the correct day.         | Must     |
| AC-003 | Tapping a history item returns user to Calculator with data loaded.      | Must     |
| AC-004 | Sound and Vibration toggles affect key-press feedback immediately.       | Must     |
| AC-005 | “Keep calculation history” toggle prevents new entries when off.         | Must     |
| AC-006 | Settings and History persist after force-quit and relaunch.              | Must     |
| AC-007 | UI matches the four provided mockups in layout, colors, and hierarchy.   | Must     |
| AC-008 | Clear History shows a confirmation, then removes all entries and shows the empty state. | Must |
| AC-009 | About screen displays correct version, developer (“Hasan Mahadi”), and actions. | Must |
| AC-010 | App handles division by zero and invalid input without crashing.         | Must     |
| AC-011 | Privacy Policy and Terms of Service open as in-app text screens.         | Must     |
| AC-012 | Rate App raises the native review prompt, or opens the store listing as fallback. | Must |
| AC-013 | Share App opens the system share sheet.                                  | Must     |
| AC-014 | History is capped at 200 entries, evicting oldest first (D-02).         | Must     |
| AC-015 | App is locked to portrait and the keypad scales without clipping on small and large phones (D-09). | Must |
| AC-016 | Calculated colors match the measured palette in `desing.md` §2 (D-03).   | Must     |

---

**End of Product Requirements Document**