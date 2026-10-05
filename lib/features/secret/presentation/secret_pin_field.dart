import '../../../../core/design/app_palette.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/widgets/core_widgets.dart';
import '../domain/secret_code.dart';

/// The PIN keypad: four dot indicators above a `0`–`9` and backspace pad.
///
/// **Shared by both entry screens on purpose.** The unlock screen and the three
/// steps of Change PIN ask for exactly the same thing — four digits, never
/// shown, checked the moment the fourth lands — and the one thing that must not
/// differ between them is how they look. A second copy of this widget would be a
/// second place for a "show a hint on the first screen" change to land, and the
/// hint is the one thing this feature must never do.
///
/// No new design token: the dots are [context.appColors.textPrimary] and
/// [context.appColors.textSecondary], and the keys are the shared [CalculatorButton], so
/// this screen is built from the same values as the calculator's own keypad
/// (D-84).
class SecretPinField extends StatefulWidget {
  const SecretPinField({
    super.key,
    required this.onSubmit,
    this.autofocusFirstKey = true,
    this.prompt,
    this.showErrors = false,
    this.wrongPinMessage,
    this.lockoutMessage,
    this.successMessage,
    this.inputEnabled = true,
  });

  /// Whether a rejected entry paints the error state (D-88).
  ///
  /// **Opt-in, and off by default, because this widget is shared.** It was off
  /// for the unlock screen's sake, Change PIN never turning it on: its three steps
  /// ask for the same four digits, and rejecting one there was judged not the
  /// same event — the user being *asked to try again* rather than being told off,
  /// and red at them for mistyping a code they had just chosen would make the
  /// ordinary path look like a failure (D-113).
  ///
  /// **That reasoning covered only one of Change PIN's two rejections** and took
  /// the wrong remedy for it. Step 1 rejects a code that is genuinely wrong, and
  /// it was rejecting it silently — which is indistinguishable from a stuck
  /// keypad — while step 2 has no rejection at all, so there was nothing there to
  /// soften. Both steps now paint, and the thing that keeps the ordinary path
  /// from reading as a failure is [wrongPinMessage]: `_stepErrors` in
  /// `change_pin_screen.dart` says which of the two rejections this is, so the
  /// step that mistyped a code the user is choosing says so and nothing else is
  /// borrowed from the unlock screen's harsher case.
  final bool showErrors;

  /// The line under the indicator after a rejected entry, or null for the
  /// built-in default (D-88).
  ///
  /// Caller-supplied for the same reason [prompt] is: the wording belongs to the
  /// screen that knows what the user was trying to do.
  final String? wrongPinMessage;

  /// The line shown once an entry has been **accepted**, or null (D-113).
  ///
  /// A caller-supplied parameter for the same reason [wrongPinMessage] is: this
  /// widget owns the slot and the type, the screen owns the wording, and a
  /// confirmed code is something only the screen that confirmed it can report.
  ///
  /// **Painted in [context.appColors.textSecondary], not [context.appColors.danger].**
  /// The palette carries one semantic signal and it means "this input is wrong"
  /// ([AppColors.danger]); green would be a second one, and D-84 holds that
  /// Secret Mode introduces no token. A neutral line in the same caption type is
  /// the whole of the success styling the app has, and on a screen whose only
  /// other coloured line is an error, a message that is *not* red already reads
  /// as confirmation.
  final String? successMessage;

  /// The line shown while the screen is locked, or null when it is not (D-88).
  ///
  /// A separate parameter from [wrongPinMessage] because the two are not the same
  /// sentence: one reports a wrong answer, the other reports that the question is
  /// not currently being asked at all. [SecretLockoutNotifier.lockoutMessage]
  /// supplies it, countdown included.
  final String? lockoutMessage;

  /// Whether the keypad accepts input at all (D-88).
  ///
  /// False during a lockout. Every key is handed a null callback, which is the
  /// same signal the shared [CalculatorButton] already treats as "disabled", so
  /// the locked pad looks like a disabled pad rather than like a broken one — the
  /// button's own pressed-state treatment applies with no new styling here.
  final bool inputEnabled;

  /// The line above the dots, or null for none (D-86).
  ///
  /// A caller-supplied string rather than a constant here because the screens
  /// asking the same question are asking it in different circumstances, and only
  /// the unlock screen is the one a user who cannot get in is looking at.
  ///
  /// Whatever a caller passes **must not name the default code**. §6.8 withholds
  /// it so a screenshot cannot spoil the feature, and the recovery route for a
  /// forgotten PIN is the reset flow — which does name it, deliberately, to
  /// someone who has already committed to being here.
  final String? prompt;

  /// Called once four digits are in.
  ///
  /// Returns whether the code was accepted. A `false` result clears the dots and
  /// shakes them (AC-019) — the widget owns that reaction so both screens shake
  /// identically, and so a caller cannot accept a wrong code by forgetting to
  /// return.
  final Future<bool> Function(SecretCode entered) onSubmit;

  /// Whether the first key grabs focus on open.
  ///
  /// Off for Change PIN, where the previous step's keypad is still on screen and
  /// stealing focus mid-transition makes the dots fill themselves.
  final bool autofocusFirstKey;

  @override
  State<SecretPinField> createState() => _SecretPinFieldState();
}

class _SecretPinFieldState extends State<SecretPinField>
    with SingleTickerProviderStateMixin {
  /// Digits entered so far, capped at [SecretCode.length].
  ///
  /// Held as a `String` rather than a list of ints so constructing the
  /// [SecretCode] on submit is a single call with no parsing step that could
  /// disagree with [SecretCode]'s own validation.
  String _entered = '';

  /// Drives the rejection shake (AC-019).
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  /// Whether a submission is in flight, so a fast double-tap on the fourth
  /// digit cannot check the same code twice — and, more importantly, so a
  /// second code cannot be entered while the first is still being compared.
  bool _checking = false;

  /// Whether the last completed entry was rejected (D-88).
  ///
  /// The **only** thing that paints the error state, and it is set from exactly
  /// one place: [onSubmit] returning false. Nothing infers a rejection from a
  /// digit count, a timer, or a rebuild, so a partial entry can never leave the
  /// indicator red — the error describes a *judged* code, and an unjudged one is
  /// not a wrong one.
  bool _rejected = false;

  /// **The `3 : 4` flex split this screen used to lay itself out by is gone** (D-88).
  /// Neither half was ever centred: each swallowed its own slack in its own
  /// `Expanded` box, and the leftover met in the middle as a **248 px** gap that
  /// no spacing token had chosen — the prompt drifted up away from the user and
  /// the pad drifted down away from it. There is no ratio left to tune now that
  /// [build] anchors one group to the bottom and sizes the pad from the height
  /// actually left over: the same decision, made once instead of twice.
  ///
  /// **And the group is anchored to the bottom, not centred in the screen**
  /// (D-89) — see [_bottomAnchor] for the measurement and [build] for why the
  /// slack collects above the prompt rather than being shared out around it.

  /// Appends a digit, and checks the code once it is complete.
  Future<void> _append(String digit) async {
    // The locked check is here as well as on the key itself, because the keys
    // are disabled through a null callback and a null callback is a *visual*
    // contract — anything holding a captured non-null reference could still call
    // through it. The guard inside the handler is the one that actually holds.
    if (!widget.inputEnabled || _checking ||
        _entered.length >= SecretCode.length) {
      return;
    }
    setState(() {
      _entered += digit;
      // Typing again clears the error immediately (D-88): the message describes
      // the code just rejected, and once the user is typing a new one it is
      // stale. Clearing on the first digit rather than after the fourth means
      // the indicator returns to normal as soon as the user starts their retry.
      _rejected = false;
    });
    if (_entered.length == SecretCode.length) await _submit();
  }

  /// Removes the last digit. Never checks anything (feature.md FEAT-SEC-002).
  void _backspace() {
    if (!widget.inputEnabled || _checking || _entered.isEmpty) return;
    setState(() {
      _entered = _entered.substring(0, _entered.length - 1);
      _rejected = false;
    });
  }

  /// Hands the completed code to [SecretPinField.onSubmit] and reacts to a
  /// rejection.
  Future<void> _submit() async {
    // A second, in-flight guard at the top. [_append] already sets [_checking]
    // before awaiting, but this is the only place a code is judged, and a
    // duplicate call here would be judged twice and counted twice — the one
    // route by which rapid tapping could spend a user's three attempts in one.
    if (_checking) return;

    setState(() => _checking = true);
    final accepted = await widget.onSubmit(SecretCode(_entered));
    if (!mounted) return;

    if (accepted) {
      // The dots are left as they are. The screen is about to be replaced (or
      // the flow is about to advance) and clearing them first would flash an
      // empty field on the way out.
      setState(() => _checking = false);
      return;
    }

    // Clear, flag, and shake, in that order, so the shake is visibly about the
    // code that was just rejected rather than about empty dots (AC-019, D-88).
    //
    // The flag is set only when [showErrors] is on, so Change PIN's three steps
    // keep their existing silent-rejection behaviour untouched.
    setState(() {
      _entered = '';
      _checking = false;
      _rejected = widget.showErrors;
    });
    await _shake.forward(from: 0);
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  /// The gap between the label and the dots it labels (D-88).
  ///
  /// [AppSpacing.sm], down from `lg`. This is the tightest relationship on the
  /// screen — the label and the dots are one thought — and at `lg` the line read
  /// as a separate caption above an unrelated row of marks.
  static const double _labelGap = AppSpacing.sm;

  /// The gap between the dots and the message slot beneath them (D-88).
  static const double _statusGap = AppSpacing.sm;

  /// The gap between the message slot and the keypad (D-88).
  ///
  /// `md`, down from `xl`. The pad is a large block of mass and the dots are
  /// four small marks; a wide gap is what tells the eye they are not one thing.
  static const double _keypadGap = AppSpacing.md;

  /// How far the pad's bottom edge is lifted off the bottom of the screen, as a
  /// fraction of the height this widget is given (D-89).
  ///
  /// **A fraction of the box, not a token.** The screen hands this widget
  /// whatever is left after the screen's own padding and safe area, which differs
  /// between the unlock screen and Change PIN and across devices; a fixed number
  /// of px would read as a different gap on each. A share of the height is the
  /// one measurement that means the same thing everywhere.
  static const double _bottomAnchor = 0.20;

  /// The height reserved beneath the pad so it clears the bottom edge (D-89).
  ///
  /// **Taken out of the budget before the pad is sized**, not added afterwards.
  /// Adding it afterwards is what would overflow a short window: the pad would
  /// already have claimed the leftover height and the gap would have to come out
  /// of it, which is a silent negative. Subtracting first means a window too
  /// short for a full-size pad *and* the gap shrinks the pad — it can never
  /// push the group off the bottom.
  double _bottomGap(double availableHeight) =>
      math.max(0, availableHeight * _bottomAnchor);

  /// The tallest the keypad ever renders (D-88).
  ///
  /// Four [maxCellSize] cells and the three [keyGap]s between them — the exact
  /// height of a full-size pad. Exposed to [build] so the pad's box can be capped
  /// at the size of its own content, which is what gives the `Center` around it
  /// something to distribute.
  static double get maxGridHeight =>
      _PinKeypad.gridHeight(_PinKeypad.maxCellSize);

  /// Height reserved for the message line whether or not there is one (D-88).
  ///
  /// **Reserved unconditionally**, and this is what keeps the layout stable.
  /// Collapsing the slot when no message is showing would make the whole anchored
  /// group jump on the frame the error appears, because the pad is sized from
  /// whatever height the rest of the group leaves — type a wrong code and the
  /// prompt and every key would slide downward under the user's finger. Holding
  /// the slot costs 18 px on a screen with plenty of it to spare.
  static const double _statusHeight = 18;

  /// The line the message slot shows, or null when it shows nothing (D-88).
  ///
  /// The lockout wins over the wrong-code message: a user who is being told to
  /// wait cannot act on being told they were wrong, and showing both would put
  /// two red sentences under four dots. A [SecretPinField.successMessage] wins
  /// over both, for the opposite reason — it is the verdict on an entry that was
  /// *accepted*, so it is the only one of the three that is still true, and a
  /// stale "wrong PIN" or a countdown cannot outlive the flow it belonged to.
  String? get _statusMessage {
    final locked = widget.lockoutMessage;
    if (locked != null) return locked;
    final success = widget.successMessage;
    if (success != null) return success;
    if (!_rejected) return null;
    return widget.wrongPinMessage ?? 'Wrong PIN';
  }

  /// Whether the line in the slot is a **complaint** rather than a report.
  ///
  /// Split out from [_statusMessage] rather than folded into it, because the two
  /// are the same sentence with different colours and the colour is the whole of
  /// the difference: a lockout and a rejected code are both [AppColors.danger],
  /// and an accepted one is the app's ordinary label colour. It walks the *same*
  /// precedence as [_statusMessage], deliberately — asking "is any of these set?"
  /// instead would paint a lockout in the success colour on any screen that ever
  /// had both, which no screen does today and no screen should.
  bool get _statusIsError {
    if (widget.lockoutMessage != null) return true;
    if (widget.successMessage != null) return false;
    return _rejected;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The height the prompt assembly and the message slot will actually
        // occupy. Measured rather than assumed, because the label's height
        // depends on the user's text scale and the pad must not be sized on the
        // assumption that it does not.
        final reserved =
            (widget.prompt == null ? 0.0 : _labelTextHeight(context)) +
            _labelGap * (widget.prompt == null ? 0 : 1) +
            _SecretPinFieldDots.size +
            _statusGap +
            _statusHeight +
            _keypadGap;

        // The gap under the pad, claimed from the height available *before* the
        // pad is sized — see [_bottomGap] for why the order is what matters.
        final bottomGap = _bottomGap(constraints.maxHeight);

        // The pad is sized from the height **actually left over**, not from a
        // share of the screen. That is the whole of the layout: the group below is
        // one `Column` that ends on the pad, so the pad cannot claim unspent room
        // — it is handed only what is left after the dots have taken theirs *and*
        // after the bottom gap has taken its share, and `cellSizeFor` may only
        // ever shrink from there, so a short window compresses the pad instead of
        // overflowing.
        //
        // **And it is capped at the height a full-size pad would occupy**, so a
        // tall window does not stretch the group to fill the screen — which would
        // leave `MainAxisAlignment.end` with no slack to distribute and pin the
        // prompt back to the top. Take the lesser of the two, so a short window
        // still yields.
        final padHeight = math.min(
          // `0.0` and not `0`: `math.max` is generic over `num`, so an `int`
          // literal here makes the whole expression a `num` and the enclosing
          // `math.min` a `num` too — which `SizedBox.height` will not take.
          math.max(0.0, constraints.maxHeight - reserved - bottomGap),
          maxGridHeight,
        );

        // **Ends on the pad, not centred** (D-89). The group used to sit inside a
        // `Center`, which put the dots and the keypad in the middle of the screen
        // and left a band of nothing above them and a smaller one below. This
        // screen has one task and it happens at the bottom of the phone, under the
        // thumb that has to use it, so the slack now collects in one place — above
        // the prompt — and the middle of the screen is simply empty.
        //
        // `MainAxisAlignment.end` and not a `Spacer()` above the group: the two
        // agree when the group fits, but when it does not the `Spacer` still
        // claims 0 and lets the group overflow past the bottom edge, whereas
        // `end` packs the overflow at the top where it is at least clipped by the
        // screen rather than by nothing.
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
              AnimatedBuilder(
                animation: _shake,
                builder: (context, child) {
                  // A decaying sine rather than a constant offset: a shake that
                  // holds its displacement reads as a layout error, and one that
                  // does not decay reads as a stuck screen.
                  final t = _shake.value;
                  final offset =
                      math.sin(t * math.pi * 4) * (1 - t) * AppSpacing.md;
                  return Transform.translate(
                    offset: Offset(offset, 0),
                    child: child,
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (widget.prompt != null) ...<Widget>[
                      // Secondary type, not the row title: this is a label on a
                      // form, and a user who reaches the area needs it readable,
                      // not emphatic.
                      Text(
                        widget.prompt!,
                        style: context.type.body.copyWith(
                          color: context.appColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: _labelGap),
                    ],
                    _PinDots(
                      filled: _entered.length,
                      hasError: _rejected,
                      key: const Key('secret-pin-dots'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: _statusGap),
              // Always the same height, so appearing and disappearing cannot
              // move the anchored group — see [_statusHeight].
              SizedBox(
                height: _statusHeight,
                child: Center(
                  child: _StatusLine(
                    message: _statusMessage,
                    isError: _statusIsError,
                  ),
                ),
              ),
              const SizedBox(height: _keypadGap),
              SizedBox(
                height: padHeight,
              child: _PinKeypad(
                onDigit: _append,
                onBackspace: _backspace,
                autofocusFirstKey: widget.autofocusFirstKey,
                inputEnabled: widget.inputEnabled,
              ),
            ),
            // The lift off the bottom edge, as a child rather than as padding on
            // the column so it is visible in the same place the pad was sized
            // for: one number, read once, used for both.
            SizedBox(height: bottomGap),
          ],
        );
      },
    );
  }

  /// The rendered height of the prompt label at the current text scale.
  double _labelTextHeight(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: widget.prompt ?? '', style: context.type.body),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.height;
  }
}

/// The one line of feedback under the indicator (D-88).
///
/// Separate from [_PinDots] because it has a different job and a different
/// lifetime: the dots describe the entry, this describes the *verdict* on it.
///
/// **Caption type, not body.** The brief for this screen is that the error must
/// be legible without becoming the subject of the page — a full-size red line
/// under four dots would outrank the keypad it is describing. `caption` is the
/// app's smallest text token.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.message, this.isError = true});

  /// The line to show, or null to show nothing.
  final String? message;

  /// Whether this line is a **complaint** and so wears [AppColors.danger].
  ///
  /// Defaults to true, so every existing caller — the lockout and the wrong-code
  /// message — keeps the colour it has always had and nothing about the unlock
  /// screen moves. False is for an accepted entry, which is reported in the
  /// app's neutral label colour: the palette carries no success token (D-84
  /// forbids Secret Mode adding one) and red under a code that was accepted would
  /// be a false claim.
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null) return const SizedBox.shrink();

    return Text(
      text,
      key: const Key('secret-pin-status'),
      // `danger` rather than `accent` for the complaint: this is the app
      // rejecting an input, not offering an action. Destructive *confirms* stay
      // orange; nothing on this screen is an action.
      style: context.type.caption.copyWith(
        color: isError ? context.appColors.danger : context.appColors.textSecondary,
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Four indicators, filled left to right. The code is never rendered as
/// characters — not even masked (feature.md FEAT-SEC-002).
class _PinDots extends StatelessWidget {
  const _PinDots({
    required this.filled,
    required this.hasError,
    super.key,
  });

  /// How many digits are in, so how many dots are solid.
  final int filled;

  /// Whether the last completed entry was rejected (D-88).
  ///
  /// Repaints **both** the fill and the outline, and that is the point: a red
  /// outline alone around empty circles is easy to miss at a glance, and a red
  /// fill alone is invisible on the frame after the entry clears (which is
  /// immediately). Doing both means the indicator is red from the first frame
  /// and stays red whether or not any dots happen to be filled.
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    // Read once so the fill and the outline cannot disagree — the failure this
    // guards is a red ring around grey dots, which looks like a rendering fault.
    final activeColor = hasError
        ? context.appColors.danger
        : context.appColors.textPrimary;
    final idleColor = hasError
        ? context.appColors.danger
        : context.appColors.textSecondary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (var i = 0; i < SecretCode.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.lg),
          // One semantics node for the whole row rather than four, so a screen
          // reader says "PIN entry" instead of walking an empty dot that says
          // nothing (D-59). The error is announced by [_StatusLine], which is a
          // real text node — announcing it here too would say it twice.
          Semantics(
            label: 'PIN entry, $filled of ${SecretCode.length} digits entered',
            child: Container(
              width: _SecretPinFieldDots.size,
              height: _SecretPinFieldDots.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled ? activeColor : Colors.transparent,
                border: Border.all(
                  color: idleColor,
                  width: _SecretPinFieldDots.border,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Sizes local to the PIN field.
///
/// A nested holder rather than two `AppSpacing` entries because **no new design
/// token is introduced for Secret Mode** (D-84) — the dot's diameter and its
/// hairline have no counterpart anywhere in `desing.md` to name, so they are
/// stated here as this widget's own proportions and everything visible still
/// comes from the shared colour tokens.
abstract final class _SecretPinFieldDots {
  static const double size = 14;
  static const double border = 1;
}

/// The `0`–`9` and backspace pad, styled on the calculator's own grid.
///
/// Three columns of digits plus a final row holding backspace and `0`, which is
/// the calculator's arrangement with the function keys removed — this pad has no
/// operators, because there is no arithmetic to do here.
class _PinKeypad extends StatelessWidget {
  const _PinKeypad({
    required this.onDigit,
    required this.onBackspace,
    required this.autofocusFirstKey,
    required this.inputEnabled,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// Whether the `1` key takes focus when the pad mounts.
  final bool autofocusFirstKey;

  /// Whether any key accepts input (D-88).
  ///
  /// Honoured by handing each key a **null** callback rather than by ignoring
  /// taps: a null `onPressed` is the shared [CalculatorButton]'s own existing
  /// signal for "disabled", so the locked pad renders in the button's established
  /// disabled treatment instead of a second, subtly-different one invented here.
  final bool inputEnabled;

  static const int columnCount = 3;
  static const int rowCount = 4;

  /// Gap between neighbouring keys, in logical px.
  ///
  /// The calculator's own grid measures 14 (D-60); this pad is a smaller echo of
  /// it rather than a copy, and `AppSpacing.md` is the step below that. Held as
  /// its own name so the pad's rhythm is one edit here rather than a token edit
  /// that would also move every other 12 px gap in the app.
  static const double keyGap = 12;

  /// Largest square cell the pad will ever lay out at.
  ///
  /// **86 — the calculator's own key on the 442×890 reference canvas** (D-60),
  /// reused here deliberately. desing.md §6.8 asks only for a pad "sized
  /// smaller" and gives no number, and §12.2 item 9 records that this screen
  /// exists in no mockup at all, so there is no pixel to match. The calculator's
  /// measured cell is the only figure in the app that is both evidence-backed and
  /// the right *kind* of value: the pad has to read as a smaller echo of the
  /// instrument the user already knows, not as a second, larger one.
  ///
  /// **86 rather than 88, and the half pixel is load-bearing.** The calculator
  /// derives `(442 − 48 − 16×3) / 4 = 86.5` on this canvas, so an 88 cap here
  /// would render the "smaller echo" a pixel and a half *larger* than the thing
  /// it echoes — the exact inversion the ceiling exists to prevent. `secret_layout_test.dart`
  /// asserts the relationship rather than the number, so the two move together.
  ///
  /// This ceiling is also the whole fix. The pad used to hand `Expanded` to every row
  /// and cell, so it derived its size from whatever box the screen gave it —
  /// (394 − 2×12) / 3 = **123 px** on the reference canvas, 40 % wider than the
  /// keys it is meant to echo, and the "oversized pad" a user reports. A
  /// ceiling can only ever shrink a cell, so unlike a floor it can never
  /// overflow its box.
  static const double maxCellSize = 86;

  static double gridWidth(double cellSize) =>
      cellSize * columnCount + keyGap * (columnCount - 1);

  static double gridHeight(double cellSize) =>
      cellSize * rowCount + keyGap * (rowCount - 1);

  /// The largest square cell that fits [width] × [height] without clipping.
  ///
  /// Whichever axis is tighter decides, exactly as the calculator's own
  /// `cellSizeFor` does, so the pad shrinks on a short window instead of
  /// overflowing and stops growing on a tall one. Only the [maxCellSize] ceiling
  /// is applied here, and deliberately no matching floor: a cell larger than the
  /// box it is given overflows it, so clamping upward would trade a touch target
  /// for a render error. The `prd.md` §12 floor is asserted from the rendered
  /// rects in `secret_layout_test.dart` instead, where a window too short to
  /// hold it is visible as a failing measurement rather than as a silent clamp.
  static double cellSizeFor({required double width, required double height}) {
    final byWidth = (width - keyGap * (columnCount - 1)) / columnCount;
    final byHeight = (height - keyGap * (rowCount - 1)) / rowCount;
    return math.max(0.0, math.min(byWidth, byHeight)).clamp(0.0, maxCellSize);
  }

  /// Laid out as `1 2 3 / 4 5 6 / 7 8 9 / ⌫ 0`, so the digits keep their
  /// calculator positions and a user who knows one keypad knows this one.
  static const List<List<String>> _rows = <List<String>>[
    <String>['1', '2', '3'],
    <String>['4', '5', '6'],
    <String>['7', '8', '9'],
    <String>['backspace', '0'],
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // One derived cell, shared by every key, rather than a box per `Expanded`
        // child — the geometry is decided once here and the grid is built from
        // it, so a key cannot come out one size and its neighbour another.
        final cellSize = cellSizeFor(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
        );

        // **Top**-aligned, not centred, and this is the other half of the fix
        // described in `SecretPinField`: the keys are clamped to [maxCellSize], so
        // this box is usually far taller than the grid it holds, and `Center`
        // spent the difference above *and* below — pushing the pad away from the
        // prompt it belongs to. Hanging the grid from the top leaves all of it in
        // one place, at the floor, where the safe-area padding already accounts
        // for it.
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: gridWidth(cellSize),
            height: gridHeight(cellSize),
            child: Column(
              // Stated rather than inherited, for the reason
              // `CalculatorKeypad` states it (D-69): the rows total exactly
              // [gridWidth], so stretching is redundant here — but it is the
              // property that keeps the grid correct if a row ever differs in
              // width, instead of leaving the surplus to be re-centred per row.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var row = 0; row < _rows.length; row++) ...[
                  if (row > 0) const SizedBox(height: keyGap),
                  _buildRow(_rows[row], cellSize, isFirst: row == 0),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRow(
    List<String> row,
    double cellSize, {
    required bool isFirst,
  }) {
    return SizedBox(
      height: cellSize,
      child: Row(
        children: <Widget>[
          for (var column = 0; column < row.length; column++) ...[
            if (column > 0) const SizedBox(width: keyGap),
            SizedBox(
              width: cellSize,
              height: cellSize,
              child: row[column] == 'backspace'
                  // Null while locked, which is what makes the key inert. The
                  // backspace is a real button in its own right and gets the same
                  // treatment as the digits — a locked pad where `⌫` still works
                  // would be a pad the user can edit while they wait.
                  ? _BackspaceKey(
                      onPressed: inputEnabled ? onBackspace : null,
                    )
                  : _DigitKey(
                      label: row[column],
                      onPressed: inputEnabled
                          ? () => onDigit(row[column])
                          : null,
                      // Only the `1` key, and only when the caller asked: an
                      // `autofocus` on every key would fight itself, and Change
                      // PIN's between-steps rebuild must not pull focus into the
                      // pad at all.
                      autofocus: autofocusFirstKey && isFirst && column == 0,
                    ),
            ),
          ],
          // The last row holds two keys in a three-wide grid, so a trailing gap
          // keeps `0` in the middle column instead of letting it drift up against
          // the backspace the way an unterminated `Row` would.
          if (row.length < columnCount)
            SizedBox(width: keyGap * (columnCount - row.length)),
        ],
      ),
    );
  }
}

/// A digit key, delegating the look to the shared [CalculatorButton].
class _DigitKey extends StatelessWidget {
  const _DigitKey({
    required this.label,
    required this.onPressed,
    required this.autofocus,
  });

  final String label;

  /// Null while the pad is locked (D-88), which is exactly what the shared
  /// [CalculatorButton] treats as disabled.
  final VoidCallback? onPressed;

  /// Whether this key takes focus when the pad mounts.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final key = CalculatorButton(
      // The label is the digit, and the digit is also the accessible name — the
      // one case where [CalculatorButton]'s default is right.
      label: label,
      variant: CalculatorButtonVariant.digit,
      onPressed: onPressed,
    );

    if (!autofocus) return key;

    // A locked pad takes no focus (D-88): the autofocus wrapper is what wires up
    // hardware-keyboard digits, and leaving it on would let a user type a code
    // into a screen that is refusing to read it.

    // A `Focus` wrapper rather than a field: this screen takes no text input, it
    // only wants the hardware keyboard's digits to work, and `autofocus` on a
    // bare key does nothing without one.
    return Focus(autofocus: true, child: key);
  }
}

/// The backspace key: a [function]-variant circle, matching the calculator's own
/// `⌫` so the two keypads read as the same instrument.
///
/// The glyph is literally the same [AppBackspaceIcon] the calculator draws, at the
/// same [AppIconSize.row] it gets there — "the same instrument" is the claim this
/// key makes, and a shared drawing is what makes it true rather than merely
/// intended (**D-112**). It is left without a `semanticLabel`, so the
/// [Semantics] below stays the only accessible name for the key.
class _BackspaceKey extends StatelessWidget {
  const _BackspaceKey({required this.onPressed});

  /// Null while the pad is locked (D-88).
  ///
  /// Handed straight to [InkWell.onTap], where a null is the framework's own
  /// "this does nothing" — so the disabled backspace keeps its exact silhouette
  /// and loses only the ripple, rather than being tinted into a state this
  /// widget would then have to invent a style for.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Sized from the smaller axis, like [CalculatorButton], so the key is
      // round rather than an ellipse in a row that is shorter than it is wide.
      final side = math.min(
        constraints.maxWidth,
        constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : constraints.maxWidth,
      );

      return Semantics(
        button: true,
        label: 'Delete last digit',
        child: ExcludeSemantics(
          child: Material(
            color: context.appColors.buttonFunction,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(side / 2)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Center(
                child: AppBackspaceIcon(color: context.appColors.textOnFunction),
              ),
            ),
          ),
        ),
      );
    },
  );
}
