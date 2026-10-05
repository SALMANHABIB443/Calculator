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
    this.onForgotPin,
    this.prompt,
  });

  /// Whether the "Forgot PIN?" link appears below the dots (D-86).
  ///
  /// Opt-in rather than always-on because this widget is shared: the unlock
  /// screen gets the link, and Change PIN's three steps must not, or a user
  /// halfway through setting a new code would be offered a way to destroy the
  /// code they are in the middle of choosing. Showing it is a per-screen
  /// decision, not a property of the question being asked.
  final VoidCallback? onForgotPin;

  /// The line above the dots, or null for none (D-86).
  ///
  /// A caller-supplied string rather than a constant here for the same reason
  /// [onForgotPin] is caller-supplied: the two screens ask the same question in
  /// different circumstances, and only the unlock screen is the one a lost-PIN
  /// user is looking at.
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

  /// Slack given to the dot row, and to the keypad, above and below it.
  ///
  /// desing.md §6.8 puts the dots "centred in the upper half" and the keypad
  /// below them. A ratio rather than a fixed height because the two halves have
  /// to share whatever the window offers: on the 442×890 reference canvas this
  /// lands the dots at roughly the middle of the upper half, which reads as the
  /// prompt the screen is asking for, while a short window compresses both
  /// rather than pushing the pad off the floor.
  ///
  /// The **keypad** takes the larger share on purpose, and this is the second
  /// time it has moved. The pad's keys are already clamped to 88 px
  /// ([CalculatorButton]'s own `min(width, height)`), so every pixel of slack
  /// handed to the pad is slack it cannot spend — it centres inside a roomier box
  /// and paints exactly the same keys. The dots have no such ceiling: their box
  /// is the only thing that decides where on the screen the question appears. So
  /// the surplus goes where it changes something, and the prompt assembly sits at
  /// about 45 % of the height instead of a third — down from the top edge,
  /// closer to the keypad the user is about to press, and reading as the
  /// beginning of an action rather than as a status line.
  static const int _dotsShare = 3;
  static const int _keypadShare = 4;

  /// Appends a digit, and checks the code once it is complete.
  Future<void> _append(String digit) async {
    if (_checking || _entered.length >= SecretCode.length) return;
    setState(() => _entered += digit);
    if (_entered.length == SecretCode.length) await _submit();
  }

  /// Removes the last digit. Never checks anything (feature.md FEAT-SEC-002).
  void _backspace() {
    if (_checking || _entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  /// Hands the completed code to [SecretPinField.onSubmit] and reacts to a
  /// rejection.
  Future<void> _submit() async {
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

    // Clear and shake, in that order, so the shake is visibly about the code
    // that was just rejected rather than about empty dots (AC-019, D-85).
    setState(() {
      _entered = '';
      _checking = false;
    });
    await _shake.forward(from: 0);
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        // The prompt line and the dots are **one centred assembly**, not two
        // widgets sharing a column. The line used to be a direct child of this
        // column with the `Expanded` below it, which pinned the line to the very
        // top of the screen and dropped the dots into a box further down — two
        // halves of one question, a hand's width apart, with nothing joining
        // them.
        //
        // **Bottom**-aligned in its share, and that is the load-bearing part of
        // this layout. Both halves of the screen used to `Center` themselves in
        // the box they were given, so each one swallowed its own slack and then
        // the two swallowed boxes met in the middle: the prompt drifted up away
        // from the user, the pad drifted down away from it, and the space
        // between them was whatever was left over. On the 442×890 canvas that
        // measured **248 px** — the gap was not a spacing decision at all, it was
        // the accumulated unspent room of two independent centring operations,
        // and it was five times the [AppSpacing.lg] actually written between them.
        //
        // So the slack is spent in one place instead of two: the prompt assembly
        // sits at the **bottom** of its share, hard against the pad it labels, and
        // the pad hangs from the **top** of its own (see [_PinKeypad]). Nothing
        // is centred any more, and the distance between the dots and the `1` key
        // is the gap written below — a number someone chose — rather than a
        // remainder.
        Expanded(
          flex: _dotsShare,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedBuilder(
              animation: _shake,
              builder: (context, child) {
                // A decaying sine rather than a constant offset: a shake that
                // holds its displacement reads as a layout error, and one that
                // does not decay reads as a stuck screen. Two full oscillations
                // is enough to be legible and short enough not to delay the
                // retry.
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
                    // Tight, not [AppSpacing.xl]: the gap here is inside one
                    // assembly, and the xl sized for separating the label from a
                    // screen edge would tear the line away from the dots it
                    // labels — the thing this change exists to fix.
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  _PinDots(
                    filled: _entered.length,
                    // Keyed so a test can find the indicator it expects to
                    // shake, matching how every other screen in the app publishes
                    // its handles.
                    key: const Key('secret-pin-dots'),
                  ),
                ],
              ),
            ),
          ),
        ),
        // The one gap on this screen that is actually written down: the pad's
        // top edge to the indicator it follows. A full `xl` step read as two
        // unrelated objects sharing a screen, because the pad is a large block of
        // mass and the dots are four small marks — a wide gap is what tells the
        // eye they are not one thing. `lg` is a step down, matching the gap
        // *inside* the assembly above it, so the assembly and the pad it belongs
        // to now read as one column with consistent internal spacing.
        const SizedBox(height: AppSpacing.lg),
        // The recovery link, directly under the dots it belongs to rather than
        // pushed to the bottom of the screen: a user who has forgotten their PIN
        // is looking at the prompt, not at the floor, and a link marooned above
        // the keypad reads as part of the furniture.
        if (widget.onForgotPin != null) ...[
          const SizedBox(height: AppSpacing.xl),
          TextButton(
            key: const Key('secret-forgot-pin'),
            onPressed: widget.onForgotPin,
            style: TextButton.styleFrom(
              // [textSecondary] rather than [accent]: this is not the app's
              // primary action, and an orange link on this screen would be the
              // only accent-coloured thing on a black page — a louder mark than
              // the plain label it accompanies. The underline is the affordance.
              foregroundColor: context.appColors.textSecondary,
              textStyle: context.type.rowSubtitle,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                // The vertical padding is what makes this a 48 px target rather
                // than a line of text; a link that is not comfortably tappable is
                // not a recovery route.
                vertical: AppSpacing.md,
              ),
            ),
            child: const Text('Forgot PIN?'),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Expanded(
          flex: _keypadShare,
          child: _PinKeypad(
            onDigit: _append,
            onBackspace: _backspace,
            autofocusFirstKey: widget.autofocusFirstKey,
          ),
        ),
      ],
    );
  }
}

/// Four indicators, filled left to right. The code is never rendered as
/// characters — not even masked (feature.md FEAT-SEC-002).
class _PinDots extends StatelessWidget {
  const _PinDots({required this.filled, super.key});

  /// How many digits are in, so how many dots are solid.
  final int filled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (var i = 0; i < SecretCode.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.lg),
          // One semantics node for the whole row rather than four, so a screen
          // reader says "PIN entry" instead of walking an empty dot that says
          // nothing (D-59).
          Semantics(
            label: 'PIN entry, $filled of ${SecretCode.length} digits entered',
            child: Container(
              width: _SecretPinFieldDots.size,
              height: _SecretPinFieldDots.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    i < filled ? context.appColors.textPrimary : Colors.transparent,
                border: Border.all(
                  color: context.appColors.textSecondary,
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
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// Whether the `1` key takes focus when the pad mounts.
  final bool autofocusFirstKey;

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
  /// **88 — the calculator's own measured key** on the 442×890 reference canvas
  /// (D-60), reused here deliberately. desing.md §6.8 asks only for a pad
  /// "sized smaller" and gives no number, and §12.2 item 9 records that this
  /// screen exists in no mockup at all, so there is no pixel to match. The
  /// calculator's measured cell is the only figure in the app that is both
  /// evidence-backed and the right *kind* of value: the pad has to read as a
  /// smaller echo of the instrument the user already knows, not as a second,
  /// larger one.
  ///
  /// This ceiling is the whole fix. The pad used to hand `Expanded` to every row
  /// and cell, so it derived its size from whatever box the screen gave it —
  /// (394 − 2×12) / 3 = **123 px** on the reference canvas, 40 % wider than the
  /// 88 px keys it is meant to echo, and the "oversized pad" a user reports. A
  /// ceiling can only ever shrink a cell, so unlike a floor it can never
  /// overflow its box.
  static const double maxCellSize = 88;

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
                  ? _BackspaceKey(onPressed: onBackspace)
                  : _DigitKey(
                      label: row[column],
                      onPressed: () => onDigit(row[column]),
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
  final VoidCallback onPressed;

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

    // A `Focus` wrapper rather than a field: this screen takes no text input, it
    // only wants the hardware keyboard's digits to work, and `autofocus` on a
    // bare key does nothing without one.
    return Focus(autofocus: true, child: key);
  }
}

/// The backspace key: a [function]-variant circle, matching the calculator's own
/// `⌫` so the two keypads read as the same instrument.
class _BackspaceKey extends StatelessWidget {
  const _BackspaceKey({required this.onPressed});

  final VoidCallback onPressed;

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
                child: Icon(
                  Icons.backspace_outlined,
                  size: AppSizes.rowIcon,
                  color: context.appColors.textOnFunction,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}