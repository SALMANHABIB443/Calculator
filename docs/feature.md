# Feature Specification
## Calculator App — Complete Feature-by-Feature Breakdown

**Document Status:** Implementation-Ready (frozen, Phase 1)  
**Cross-Reference:** prd.md (FR-xxx, AC-xxx), [DECISIONS.md](DECISIONS.md) (D-xx)  
**Primary Source:** Four provided mockups in `../Mockups/` (mapping per D-13)  

---

## Feature Organization

Features are grouped by screen and functional category. Each feature includes:
- Feature ID
- Name & Priority
- Description
- User Interaction
- Expected Behavior
- UI Components
- State & Data
- Validation / Errors
- Related Requirements

**Priority Legend**  
- **Must Have** — Required for MVP  
- **Should Have** — Strongly recommended  
- **Could Have** — Nice-to-have / future  

---

## A. Main Calculator Screen

### FEAT-CALC-001 — Number & Operator Input
**Priority:** Must Have  

**Description**  
Allows the user to build a mathematical expression using digits, decimal point, and basic operators.

**User Interaction**  
- Tap digit buttons (0–9)  
- Tap decimal point (.)  
- Tap operators: ÷, ×, −, +  
- Tap % and +/−  

**Expected Behavior**  
- Digits append to the current number.  
- Operators are inserted between numbers.  
- Secondary display shows the full expression (e.g., “125 × 8”).  
- Primary display shows the current number or intermediate result.  
- Thousand separators appear in the result when appropriate (e.g., “1,000”) — D-18.  

**UI Components**  
- Digit buttons (circular, `#1E1E1E` fill, white text)  
- Operator buttons (circular, `#F89508` fill, white text)  
- AC, +/−, % buttons (circular, `#949494` fill, near-black text)  
- Wide “0” button  
- Secondary expression label  
- Primary result label  

**State Changes**  
- Updates current expression string  
- Updates display values  

**Validation**  
- Prevent multiple decimal points in a single number.  
- Handle leading zeros appropriately.  

**Related:** FR-001, AC-001  

---

### FEAT-CALC-002 — Evaluate Expression (=)
**Priority:** Must Have  

**Description**  
Computes the result of the current expression when the equals button is pressed.

**User Interaction**  
- Tap the orange “=” button.  

**Expected Behavior**  
- Expression is evaluated **strictly left-to-right**, each operator applied as it is
  pressed. There is **no** `×÷`-over-`+−` precedence, so `2 + 3 × 4` = `20` (D-17).
  This matches the iOS, Android, and Windows calculators.
- Result is shown in large primary display.  
- Expression moves to secondary line.  
- If history is enabled, the calculation is saved.  
- After `=`, a digit starts a fresh calculation while an operator continues from the result.  

**UI Components**  
- Orange circular “=” button (`#F89508`, white label)  

**State Changes**  
- Result stored  
- Expression archived to history (if enabled)  
- Ready for new input or continuation  

**Error Handling**  
- Division by zero → display “Error”  
- Malformed expression → display “Error”  

**Related:** FR-001, FR-002, AC-001, AC-010  

---

### FEAT-CALC-003 — All Clear (AC)
**Priority:** Must Have  

**Description**  
Resets the calculator to initial state.

**User Interaction**  
- Tap “AC” button.  

**Expected Behavior**  
- Clears both expression and result displays.  
- Resets internal calculation state.  

**UI Components**  
- Gray circular “AC” button (`#949494`, near-black label)  

**Related:** FR-001  

---

### FEAT-CALC-004 — Sign Toggle (+/−)
**Priority:** Must Have  

**Description**  
Changes the sign of the currently displayed number.

**User Interaction**  
- Tap “+/−” button.  

**Expected Behavior**  
- Positive number becomes negative and vice versa.  
- Updates both display and internal value.  

**Related:** FR-001  

---

### FEAT-CALC-005 — Percentage (%)
**Priority:** Must Have  

**Description**  
Applies percentage operation to the current number.

**User Interaction**  
- Tap “%” button.  

**Expected Behavior**  
- The current value is divided by 100: `50 %` → `0.5` (D-06).
- This is the simple semantic, with no contextual reinterpretation against the
  accumulator (i.e. `200 + 10 %` adds `0.1`, not `20`).

**Related:** FR-001  

**Note:** Resolved in Phase 1 as D-06. The engine's `_percent` handler implements
exactly this division-by-100 behavior.

---

### FEAT-CALC-006 — Display Formatting
**Priority:** Must Have  

**Description**  
Formats numbers for readability according to current decimal places setting and locale.

**Expected Behavior**  
- Large result uses appropriate decimal places (default 2 from Settings).  
- **Thousands separators are applied by default** — `1,000`, `1,234,567.89` (D-18).
  There is no user setting to disable this in v1.0.  
- Fractional values trim trailing zeros; very large or very small magnitudes fall
  back to scientific notation so the display never overflows.  
- Expression line uses smaller text in the secondary color.  
- The result label auto-shrinks when the value is very long.  

**Related:** FR-003 (Decimal Places), D-14, D-18  

---

## B. History Screen

### FEAT-HIST-001 — History List
**Priority:** Must Have  

**Description**  
Displays past calculations grouped by day.

**User Interaction**  
- Scroll through list.  
- Tap any history item.  

**Expected Behavior**  
- Groups: “Today”, “Yesterday” (and older days if data exists).  
- Each card shows:  
  - Expression (top, smaller)  
  - Result (bottom, larger, bold)  
- Cards have right chevron indicating tappable.  
- Card surface is `#101011` on the `#000000` background.  

**UI Components**  
- Section headers (“Today”, “Yesterday”)  
- History item cards (dark rounded rectangles)  
- Expression + Result text  
- Chevron icons  

**Empty State**  
- Centered message: “No calculations yet” with a subtle icon.  

**Related:** FR-002, AC-002, AC-003  

---

### FEAT-HIST-002 — Load History Item
**Priority:** Must Have  

**Description**  
Allows reuse of a previous calculation.

**User Interaction**  
- Tap a history card.  

**Expected Behavior**  
- Navigates back to Main Calculator.  
- Loads the result value into the calculator display (the recommended common pattern).  

**Related:** FR-002, AC-003  

---

### FEAT-HIST-003 — Clear History
**Priority:** Must Have  

**Description**  
Removes all stored calculations, behind a confirmation gate.

**User Interaction**  
- Tap trash icon in header **or** tap “Clear History” button at bottom.  
- Confirm in the dialog.  

**Expected Behavior**  
- A confirmation dialog appears first. Nothing is deleted until confirmed.  
- On confirm, all history entries are deleted.  
- Screen shows empty state.  
- Cancelling leaves history untouched.  

**UI Components**  
- Header trash icon  
- Bottom “Clear History” button with trash icon (orange text `#F89508`)  
- Confirmation dialog (alert style, orange destructive action)  

**Note:** The dialog is not in the mockup but is **required** by D-05 — the action is
destructive and irreversible.

**Amendment (D-82):** the **bottom** action also carries a hidden second gesture — a **five-second
hold** opens the Secret Mode entry screen (FEAT-SEC-001). **The tap path above is entirely
unchanged** and remains the only way to clear history; the hold never deletes anything, never skips
the dialog, and carries no visible indicator of any kind. The header trash is deliberately not part
of this gesture, so the screen keeps one always-visible delete control and one hidden one.

**Related (amended):** FR-002, FR-007, AC-008, AC-017

---

### FEAT-HIST-004 — History Persistence & Toggle
**Priority:** Must Have  

**Description**  
History is stored locally and respects the Settings toggle.

**Expected Behavior**  
- When “Keep calculation history” is OFF, new calculations are not saved.  
- Existing history remains until cleared.  
- Data survives app restarts.  
- Storage is a single JSON-encoded list in `shared_preferences`, capped at **200
  entries** with oldest-first eviction (D-02).

**Related:** FR-002, FR-003, AC-005, AC-006, AC-014  

---

## C. Settings Screen

### FEAT-SET-001 — Theme Selection
**Priority:** Must Have (UI) / Could Have (functionality)

**Description**  
Allows selection of appearance theme.

**User Interaction**  
- Tap the Theme row.  

**Expected Behavior**  
- Currently shows “Dark mode”.  
- Only Dark mode is present in mockups; Light mode is out of scope for v1.0.  

**UI Components**  
- Sun icon + “Theme” / “Dark mode” + chevron  

**Related:** FR-003  

---

### FEAT-SET-002 — Sound Toggle
**Priority:** Must Have  

**Description**  
Enables or disables key-press sound feedback.

**User Interaction**  
- Toggle the switch.  

**Expected Behavior**  
- Default: ON  
- When ON, each calculator key press plays a short click via
  `SystemSound.play(SystemSoundType.click)` — no audio package required (D-16).  
- Change takes effect immediately.  

**UI Components**  
- Speaker icon + “Sound” / “Key press sound” + orange toggle (`#F89508` track)  

**Related:** FR-003, AC-004  

---

### FEAT-SET-003 — Vibration Toggle
**Priority:** Must Have  

**Description**  
Enables or disables haptic feedback on key press.

**User Interaction**  
- Toggle the switch.  

**Expected Behavior**  
- Default: ON  
- When ON, each key press triggers `HapticFeedback.selectionClick()` (D-16).  
- Immediate effect.  

**UI Components**  
- Phone icon + “Vibration” / “Vibrate on key press” + orange toggle  

**Related:** FR-003, AC-004  

---

### FEAT-SET-004 — Decimal Places
**Priority:** Must Have  

**Description**  
Controls the number of decimal places shown in results.

**User Interaction**  
- Tap the row → opens picker or sub-screen.  

**Expected Behavior**  
- Current value displayed: “2 decimal places” (default).  
- Changing the value updates future result formatting.  
- Changing it **mid-calculation is formatting-only**: the current result re-renders
  with the new precision, and an expression still being typed is left untouched (D-14).  

**UI Components**  
- “123” icon + “Decimal Places” / “2 decimal places” + chevron  

**Related:** FR-003, FEAT-CALC-006  

---

### FEAT-SET-005 — History Retention Toggle
**Priority:** Must Have  

**Description**  
Controls whether new calculations are saved to history.

**User Interaction**  
- Toggle the switch.  

**Expected Behavior**  
- Default: ON  
- When OFF, successful evaluations are not written to history storage.  

**UI Components**  
- Clock icon + “History” / “Keep calculation history” + orange toggle  

**Related:** FR-003, AC-005  

---

### FEAT-SET-006 — About Links from Settings
**Priority:** Must Have  

**Description**  
Provides access to app version, privacy policy, and terms.

**User Interaction**  
- Tap App Version, Privacy Policy, or Terms of Service rows.  

**Expected Behavior**  
- App Version opens the About screen.  
- Privacy Policy and Terms of Service open their in-app text screens (FEAT-LEGAL-001).  

**UI Components**  
- Info icon, Shield icon, Document icon + labels + chevrons  

**Related:** FR-004, FR-005  

---

## D. About Screen

### FEAT-ABOUT-001 — App Identity
**Priority:** Must Have  

**Description**  
Presents the application branding and short description.

**UI Components**  
- App icon (four circular operator buttons in a 2×2 grid: two orange, two light gray)  
- Title “Calculator”  
- Version “1.0.0”  
- Description text: “A simple, fast and reliable calculator for your everyday needs.”  

**Related:** FR-004, AC-009  

---

### FEAT-ABOUT-002 — App Information Section
**Priority:** Must Have  

**Description**  
Structured list of metadata.

**Items**  
- App Name → Calculator  
- Version → 1.0.0  
- Developer → Hasan Mahadi (D-11)  

**UI Components**  
- Document, Tag, Shield icons + labels + values + chevrons  

**Related:** FR-004  

---

### FEAT-ABOUT-003 — More Actions
**Priority:** Must Have  

**Description**  
Additional user actions.

**Items**  
- Rate App — “Support us with your rating”  
- Share App — “Tell your friends about this app”  
- Terms of Service — “Read our terms and conditions”  

**Expected Behavior**  
- Rate App: raise the **native in-app review prompt** via `in_app_review`, falling back
  to opening the platform store listing when the prompt is unavailable (D-08).  
- Share App: open the system share sheet via `share_plus` with an app link / message.  
- Terms of Service: open the in-app Terms screen (FEAT-LEGAL-001).  

**Related:** FR-004, AC-009, AC-012, AC-013  

---

## E. Legal Content

### FEAT-LEGAL-001 — In-App Privacy Policy & Terms of Service
**Priority:** Must Have  

**Description**  
Renders the app's legal documents without leaving the app or requiring a network
connection.

**User Interaction**  
- Tap “Privacy Policy” or “Terms of Service” from Settings or About.  
- Read the content, then use the back arrow to return.  

**Expected Behavior**  
- Each document renders as a scrollable screen of text on the standard dark surface.  
- Content is **real, final legal text**, held as structured section data in
  `lib/features/legal/data/legal_content.dart`; `legal_screens.dart` is presentation
  only. Its platform claims — no `INTERNET` permission, backup excluded — are asserted
  in `test/unit/legal_content_test.dart` so a claim that stops being true fails a test
  (D-68). The contact email is still a tracked placeholder.  
- Fully offline: no web view, no external URL, no additional dependency.  

**UI Components**  
- Standard `AppHeader` (back arrow + title)  
- Scrollable body text using the secondary/primary text tokens  

**Validation / Errors**  
- If content is empty, show a short “content coming soon” placeholder rather than a
  blank screen.  

**Related:** FR-005, AC-011  

**Note:** Content and destination were never provided in the source requirements;
D-07 resolves the destination as an in-app page so v1.0 ships something functional.

---

## F. Cross-Cutting Features

### FEAT-NAV-001 — Screen Navigation
**Priority:** Must Have  

**Description**  
Movement between the four main screens.

**Entry Points**  
- Calculator → History (clock icon)  
- Calculator → Settings (hamburger menu — inferred)  
- Settings → About (via App Version)  
- Settings / About → Privacy Policy, Terms of Service  
- Back arrows on History, Settings, About, and the legal screens  

**Related:** FR-006  

---

### FEAT-PERSIST-001 — Local Data Persistence
**Priority:** Must Have  

**Description**  
All user data (history + settings) is stored locally and restored on launch. History
uses a JSON list in `shared_preferences` capped at 200 entries (D-02).

**Related:** NFR-002, AC-006, AC-014  

---

### FEAT-FEEDBACK-001 — Key Press Feedback
**Priority:** Must Have  

**Description**  
Sound and/or vibration on every calculator button press according to current Settings.

**Implementation:** No new packages. Uses `HapticFeedback.selectionClick()` and
`SystemSound.play(SystemSoundType.click)` from `flutter/services` (D-16).

**Related:** FEAT-SET-002, FEAT-SET-003, AC-004  

---

## G. Secret Mode

**Priority:** Must Have  
**Added by:** Phase 11  
**Not in any mockup.** D-13 maps all four mockups to real screens and this is not one of them, so
there is no pixel to match. Every screen below is designed from the app's existing tokens alone.

Secret Mode is a hidden area reached by holding the History screen's bottom Clear History button for
five seconds (D-82) and entering a four-digit PIN, `0000` by default (D-83). It is deliberately
unfurnished: the screen after unlock is blank, carrying a single overflow button in the top-left
(D-84) and the floating home button D-86 added. It exists to change the PIN and to reset it, and
nothing else — the full Settings page is **not** duplicated here. Three wrong codes lock the screen
for 30 seconds (**D-88**), and there is no recovery from inside the lock screen itself.

---

### FEAT-SEC-001 — Hidden Unlock Gesture
**Priority:** Must Have

**Description**
A five-second hold on the History screen's **bottom** Clear History button opens the Secret Mode PIN
entry screen.

**User Interaction**
- Press and hold “Clear History” at the bottom of the History list for **five seconds**.
- Release before five seconds → nothing happens at all.

**Expected Behavior**
- Holding for the full duration opens the PIN entry screen.
- Releasing early does nothing: no dialog, no navigation, no visual change.
- **A tap is unchanged** and still opens the Clear History confirmation (FEAT-HIST-003, D-05).
- The hold is **invisible**: no progress ring, no haptic, no sound, no colour change. This is
  deliberate (D-82) — feedback would make the gesture discoverable by accident, which defeats it.
- The header trash does **not** carry this gesture (D-10).

**UI Components**
- The existing bottom Clear History button, unchanged in appearance.
- No new control is added to the History screen.

**Validation / Errors**
- A hold that starts and is released early must cancel cleanly, leaving no pending action.

**Related:** FEAT-HIST-003, FR-007, AC-017

---

### FEAT-SEC-002 — Secret PIN Entry
**Priority:** Must Have

**Description**
A black screen that asks for a four-digit PIN and reveals the secret screen when it matches.

**User Interaction**
- Tap digits `0`–`9` to enter the code.
- Tap backspace to remove the last digit.
- Enter four digits → the code is checked automatically (no Enter key).

**Expected Behavior**
- Four filled/empty dots indicate progress. **The PIN itself is never displayed** — not masked with
  asterisks, simply not shown as characters.
- On a **correct** code the entry screen is **replaced** by the secret screen (FEAT-SEC-003), not pushed on
  top of it, so no back gesture can return the user to a prompt they have already answered.
- On a **wrong** code the dots clear, the indicator shakes, and **"Wrong PIN"** appears in the status line
  under them. The next entry is allowed immediately.
- **Three wrong codes in a row lock the screen for 30 seconds** (**D-88**, reversing D-85's "no lockout" —
  10⁴ codes are otherwise free in under a minute). While locked the pad is inert and the status line counts
  down: "Too many attempts. Try again in 30s". The deadline is persisted, so force-quitting the app does
  not buy three more attempts, and a correct code clears the counter.
- The default code is **`0000`** when nothing has been stored (D-83).
- **Nothing on this screen names the feature or the code.** Its entire copy is the prompt "Enter your PIN"
  and the two error strings above (D-86, **D-88**) — the original rule (no hint, no label, no title) stands
  apart from the two additions that were made on purpose.

**UI Components**
- Four dot indicators, centred.
- A keypad styled on the calculator's own (`0`–`9` plus backspace), reusing existing tokens.
- Black background (`AppColors.background`).

**State & Data**
- The entered digits are in-memory only and discarded on leave.
- The stored code is read from the `'secretPin'` key (D-83); a corrupt value falls back to `0000`.

**Validation / Errors**
- Fewer than four digits: nothing is checked and nothing happens.
- A stored value that is not four digits degrades to the default rather than erroring.

**Related:** FR-007, AC-018, AC-019

---

### FEAT-SEC-003 — Secret Screen & Overflow Menu
**Priority:** Must Have

**Description**
The unlocked secret screen: an empty black page whose only content is one overflow button in the
top-left (D-84) and, as of **D-86**, a floating white home button in the bottom-right.

**User Interaction**
- Tap the top-left overflow button → opens the secret Settings screen (FEAT-SEC-004).
- Tap the bottom-right home button → returns to the calculator with `go`, leaving nothing of Secret Mode
  on the stack (D-86).
- System back gesture → returns to the previous screen.

**Expected Behavior**
- The screen is **blank** of content: no title, no logo, no empty-state illustration, no copy of any kind.
- The header button is the **shared** `AppIconButton` (D-74), in the same position and of the same
  48 px bordered size as every other header action in the app, so it looks entirely ordinary.
- There is **no back arrow** of its own. The system back gesture remains, and the floating home button is
  the way out of Secret Mode — **D-86** reversed "the system back gesture is the only exit", because on the
  PIN screen that gesture leaves a user who cannot guess the code trapped in the hidden area.
- The home button is a 56 px white circle: `AppColors.textPrimary` behind `AppColors.textOnFunction`, both
  pre-existing tokens. **No new colour token is introduced.**

**UI Components**
- One `AppIconButton` (`Icons.more_vert`), tooltip `Settings`.
- One floating `Material`/`InkWell` circle, `Icons.home_outlined`, semantics label "Back to calculator".
- **No new design token is introduced.**

**Related:** FR-007, AC-020

---

### FEAT-SEC-004 — Secret Settings (Change PIN)
**Priority:** Must Have

**Description**
A minimal settings page holding two rows, reached from the secret screen's overflow button.

**User Interaction**
- Tap "Change PIN" → the Change PIN flow (FEAT-SEC-005).
- Tap "Reset PIN" → a confirmation dialog; confirmed, the stored PIN is erased and the user returns to the
  secret screen (D-86).

**Expected Behavior**
- The page contains **exactly two rows**, "Change PIN" then "Reset PIN" (**D-86**; D-84 specified one). The
  full Settings page is **not** duplicated here — this screen's only job is the PIN (D-84).
- "Reset PIN" is last because it is destructive, and confirms through `AppConfirmationDialog`, whose
  message names `0000` — the one place the feature speaks the code, because the user asking is a user who
  has forgotten theirs.
- A reset **erases** the stored value rather than writing `0000` back, and **survives a restart**.
- **Anyone who reaches this page can wipe the PIN in one tap.** This is the accepted cost recorded in
  D-86, weighed against a user locked out with only a reinstall available.
- Ordinary system back returns to the secret screen.

**UI Components**
- Standard secondary page header with a back action and the title "Settings".
- One `SettingsGroup` containing two `SettingsRow`s (lock + chevron, restart glyph in `accent` + chevron),
  reusing the same components as the main Settings screen.

**Related:** FEAT-SEC-003, FEAT-SEC-006, FR-007, AC-020, AC-022

---

### FEAT-SEC-005 — Change PIN
**Priority:** Must Have

**Description**
A three-step flow in one route: verify the current PIN, enter a new one, confirm it.

**User Interaction**
1. Enter the **current** PIN — the prompt reads "Enter current PIN".
2. Enter a **new** four-digit PIN — "Enter new PIN".
3. Confirm it — "Confirm new PIN".

The header control is a back arrow with the tooltip "Back" (**D-113**). It steps backwards instead of
abandoning the flow: step 3 returns to step 2 with the candidate kept, step 2 returns to step 1 with it
discarded, and step 1 leaves the flow.

**Expected Behavior**
- Step 1 rejects an incorrect current PIN, says **"Incorrect PIN"**, clears the entry and does not advance
  (D-85: no lockout, immediate retry).
- Step 2 cannot be wrong: any four digits is a legal new PIN, including the current one, so it advances on
  every input and shows no error of any kind (**D-113**).
- Steps 2 and 3 must match. A mismatch clears **only** the confirmation, says **"PINs do not match"** and
  re-asks step 3 with the candidate intact (**D-113**). The earlier behaviour returned to step 2 with the
  dots cleared, which made the user choose a third time over a typo made in the second attempt.
- On success the new code is persisted immediately, **"PIN changed successfully"** is shown for 1200 ms, and
  the flow then returns to the secret settings page. The pause is deliberate: AC-021 persists the code
  *before* the flow ends so an interruption cannot lose it, which leaves the user owed an answer.
- Input and the back arrow are inert while that line is up.
- A forgotten PIN is recovered through **FEAT-SEC-006** (D-86), which replaced the reinstall-only route
  D-85 left as a known limitation.

**State & Data**
- The new code is written to the `'secretPin'` key on success (D-83).
- Until the confirmation matches, the candidate exists only in the screen's own memory, so leaving the
  flow at any point — the arrow, the system gesture, or process death — can never lock a user out of a
  code they did not choose (**D-113**).
- It survives an app restart and is the code the next unlock must match.
- The flow offers **no** reset affordance of its own: a way to destroy the code being chosen, sitting two
  screens away from where it is entered, is a trap rather than a convenience (D-86).

**UI Components**
- The shared §6.8 PIN entry screen three times over — one prompt line, four dots, the shared keypad, the
  same bottom anchor (**D-89**) — with the prompt as the only thing telling the steps apart.
- Rejections reuse the field's existing treatment (`AppColors.danger`, cleared entry, shake); success is a
  caption in the same reserved status line, in **`textSecondary`**. No `Snackbar` is introduced: the app
  has none, and this is the one screen that must not gain ink (**D-84**, **D-113**).

**Validation / Errors**
- All three steps reject anything that is not four digits; `SecretCode` refuses to hold a malformed
  value at all.
- The flow's only two refusals are the two strings above, and neither ever speaks the code (§6.8).

**Related:** FEAT-SEC-002, FR-007, AC-021

---

### FEAT-SEC-006 — Forgotten PIN Recovery
**Priority:** Must Have

**Description**
The route out of a forgotten PIN: one confirmation dialog that erases the stored code, reachable from the
secret settings page only (**D-86**, narrowed by **D-88**).

**User Interaction**
- Read "Enter your PIN" above the dots on the PIN screen.
- Get into Secret Mode with the code, then tap "Reset PIN" in the secret settings page → the confirmation
  dialog.
- Confirm → the stored code is erased and `0000` becomes the code that opens the area, and the user lands on
  the secret screen, whose other row needs the PIN they have just forgotten.

**Expected Behavior**
- **There is no "Forgot PIN?" link on the PIN screen** (**D-88**, reversing D-86). With the 30-second
  lockout in place it was also an unlimited bypass of it — one tap, no waiting, three fresh attempts. The
  reset survives only where reaching it means already being past both the lockout and the code.
- The confirmation dialog **does** name `0000`. It is the only place the feature speaks the code, and it is
  deliberate: a bystander's screenshot must not spoil the feature, but a user who has forgotten their PIN
  cannot act on the withholding.
- Cancelling changes nothing.
- The reset **erases** the `'secretPin'` key rather than writing `0000` back, so the store holds nothing
  that looks like a stored credential, and it **survives a restart**.
- **Anyone who reaches the settings page can wipe the PIN in one tap.** The accepted trade is recorded in
  D-86, against a user locked out with only a reinstall (D-85).
- **A user who has forgotten the PIN and cannot get in has no in-app recovery** — only a reinstall, which
  costs the history. That is the sharpest edge in the feature and it stands (D-85).

**UI Components**
- One `SettingsRow` in `accent` with a restart glyph and a chevron, ordered after "Change PIN".
- The shared `AppConfirmationDialog`, matching every other destructive confirmation in the app.

**Related:** FEAT-SEC-002, FEAT-SEC-004, FR-007, AC-022

---

## Feature Priority Summary

| Priority    | Count | Key Features                                      |
|-------------|-------|---------------------------------------------------|
| Must Have   | 25    | All core calculator, history, settings, about, legal pages, feedback, and the five Secret Mode features (Section G) |
| Should Have | 1     | Polished empty states (state messages are specified; illustration is not) |
| Could Have  | 3     | Light theme, individual history item deletion (D-15), scientific mode |

**Deferred past v1.0** (explicitly out of scope per D-15 and `prd.md` §5):
individual history item deletion, light theme, scientific functions, cloud sync.

**Also rejected, not deferred** — considered for Secret Mode and declined on the record:
PIN hashing and encrypted storage (D-83); an in-place PIN reset from the lock screen (D-86, withdrawn by
**D-88** once the lockout made it a bypass). Neither was postponed; both were turned down, and the reasons
are in the decision records.

**Reversed after the fact** — specified here first, changed in the code and in the records:
attempt lockout and rate limiting (**D-85 → D-88**, which locks for 30 seconds on the third wrong code),
and the "Forgot PIN?" link on the PIN screen (**D-86 → D-88**).

---

**End of Feature Specification**
