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

**Related:** FR-002, AC-008  

**Note:** The dialog is not in the mockup but is **required** by D-05 — the action is
destructive and irreversible.

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

## Feature Priority Summary

| Priority    | Count | Key Features                                      |
|-------------|-------|---------------------------------------------------|
| Must Have   | 19    | All core calculator, history, settings, about, legal pages, feedback |
| Should Have | 1     | Polished empty states (state messages are specified; illustration is not) |
| Could Have  | 3     | Light theme, individual history item deletion (D-15), scientific mode |

**Deferred past v1.0** (explicitly out of scope per D-15 and `prd.md` §5):
individual history item deletion, light theme, scientific functions, cloud sync.

---

**End of Feature Specification**
