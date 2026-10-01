import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/widgets/core_widgets.dart';
import '../domain/calculator_engine.dart';

/// The 5×4 keypad of desing.md §6.1.
class CalculatorKeypad extends StatelessWidget {
  const CalculatorKeypad({
    required this.availableWidth,
    required this.availableHeight,
    required this.onKeyPressed,
    super.key,
  });

  /// Gap between neighbouring keys, in logical px.
  ///
  /// desing.md §4 asks for "evenly spaced circular buttons with consistent
  /// gaps" without a value. Phase 9 measured the mockup pixels and found the
  /// horizontal gap at 13 px and the vertical gap at 15 px; 14 is the midpoint
  /// and is within 1 px of both, so the grid uses one value for both axes
  /// rather than a token per axis for a difference this small (**D-60**).
  ///
  /// Phase 1 could only measure a *range* of 85–95 px for the keys (R-2), which
  /// is why `CalculatorButton` sizes from its box instead of from a diameter
  /// token: the grid is the only place the geometry lives (D-27). Once the
  /// screen margin was corrected to its measured 24 px in Phase 9, the grid
  /// maths on the 442×890 mockup canvas yields an 88 px cell — inside the
  /// 86.5–87.5 px the key rows actually measure — which closed R-2.
  ///
  /// The gap is laid out as a real child rather than reserved in arithmetic
  /// (**D-69**). A reserved gap is not a gap: the rows used to be built from
  /// bare cells with no separator between them, so every key touched its
  /// neighbour and each row came up `keyGap × 3` short of the width
  /// [gridWidth] declares.
  ///
  /// It stays at 14 on every screen, and cannot usefully grow (**D-69**): while
  /// the grid is width-bound its height is `1.25 × width + keyGap / 4`, so
  /// widening the gap buys 1.75 px of height for 5.25 px of key diameter, and
  /// where the height is the binding axis the grid already fills it exactly.
  static const double keyGap = 14;

  static const int columnCount = 4;
  static const int rowCount = 5;

  /// Smallest side a key may shrink to, per the `prd.md` §12 touch-target floor.
  ///
  /// A floor the grid applies to *itself* would be meaningless — a cell larger
  /// than the box allows overflows it, so clamping upward would trade a touch
  /// target for a layout error. It is therefore a reservation the screen makes
  /// through [minGridHeight], and only a window too short to hold a 44 pt
  /// keypad at all lets the cell follow the height down (**D-69**).
  static const double minTouchTarget = 44;

  /// Height of the smallest keypad that still gives every key a 44 pt target.
  ///
  /// The screen reserves this before sizing the display, so on a window too
  /// short for both the *display* yields the space rather than the keys
  /// (**D-69**).
  static const double minGridHeight =
      minTouchTarget * rowCount + keyGap * (rowCount - 1);

  /// Largest side a key may grow to.
  ///
  /// A genuine upper bound, unlike the floor above: it only ever shrinks the
  /// cell, so it can never overflow its box. Without it a 1280×1600 window
  /// would derive a 268 px key from its own width (**D-69**). Nothing reaches
  /// it in portrait — the reference 442×890 canvas derives 88 — but it is what
  /// makes a resizable desktop window render a calculator-sized calculator.
  static const double maxCellSize = 132;

  /// Width of the box this grid lays out in.
  ///
  /// The grid derives its own cell from this and [availableHeight] rather than
  /// being handed a pre-solved one, which keeps the geometry in the one place
  /// that owns it (**D-69**, amending D-27).
  final double availableWidth;

  /// Height of the box this grid lays out in. See [availableWidth].
  final double availableHeight;

  final ValueChanged<CalculatorKey> onKeyPressed;

  static double gridWidth(double cellSize) =>
      cellSize * columnCount + keyGap * (columnCount - 1);

  static double gridHeight(double cellSize) =>
      cellSize * rowCount + keyGap * (rowCount - 1);

  /// The largest square cell that fits [width] × [height] without clipping.
  ///
  /// Whichever axis is tighter decides the size, so the grid shrinks on a small
  /// phone instead of overflowing (D-09, prd.md AC-015) and stops growing on a
  /// tall one. Only the [maxCellSize] ceiling is applied here — see
  /// [minTouchTarget] for why there is deliberately no matching floor.
  static double cellSizeFor({required double width, required double height}) {
    final byWidth = (width - keyGap * (columnCount - 1)) / columnCount;
    final byHeight = (height - keyGap * (rowCount - 1)) / rowCount;
    return math.max(0.0, math.min(byWidth, byHeight)).clamp(0.0, maxCellSize);
  }

  /// Maps a key to its fill and label colours.
  ///
  /// The mapping lives here rather than on `CalculatorButton` so the design
  /// system never imports a feature's domain enum — that would be a second
  /// `core → features` import on top of D-24 (D-28).
  static CalculatorButtonVariant variantOf(CalculatorKey key) {
    if (key.operator != null || key == CalculatorKey.equals) {
      return CalculatorButtonVariant.operator;
    }
    return switch (key) {
      CalculatorKey.ac ||
      CalculatorKey.percent ||
      CalculatorKey.plusMinus => CalculatorButtonVariant.function,
      _ => CalculatorButtonVariant.digit,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cellSize = cellSizeFor(
      width: availableWidth,
      height: availableHeight,
    );

    return SizedBox(
      width: gridWidth(cellSize),
      height: gridHeight(cellSize),
      child: Column(
        // Stated rather than inherited. The rows now total exactly
        // [gridWidth], so stretching is redundant here — but it is the property
        // that makes the grid correct if a row ever differs in width, rather
        // than leaving the surplus to be re-centred per row, which is how `0`
        // and `=` drifted 7 px out of their columns (**D-69**).
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var row = 0; row < _layout.length; row++) ...[
            if (row > 0) const SizedBox(height: keyGap),
            _buildRow(_layout[row], cellSize),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(List<_KeySpec> row, double cellSize) {
    return SizedBox(
      height: cellSize,
      child: Row(
        children: [
          for (var column = 0; column < row.length; column++) ...[
            if (column > 0) const SizedBox(width: keyGap),
            _buildCell(row[column], cellSize),
          ],
        ],
      ),
    );
  }

  Widget _buildCell(_KeySpec spec, double cellSize) {
    return SizedBox(
      // A spanning cell absorbs the gaps it straddles, so the `0` key is one
      // stadium laid across columns one and two rather than two keys plus a
      // hole (**D-29**).
      width: cellSize * spec.columnSpan + keyGap * (spec.columnSpan - 1),
      height: cellSize,
      child: CalculatorButton(
        key: ValueKey('key-${spec.key.name}'),
        label: spec.key.label,
        semanticLabel: spec.key.semanticsLabel,
        variant: variantOf(spec.key),
        isWide: spec.columnSpan > 1,
        onPressed: () => onKeyPressed(spec.key),
      ),
    );
  }
}

/// One key and how many columns it spans.
class _KeySpec {
  const _KeySpec(this.key, [this.columnSpan = 1]);

  final CalculatorKey key;

  /// The `0` key spans two columns, which is why it renders as a stadium
  /// rather than a circle (D-29).
  final int columnSpan;
}

/// Row-major keypad layout, exactly as desing.md §6.1 draws it: the orange
/// operator column is `÷ × − +` with `=` beneath it, and the function keys
/// `AC ± %` sit in the top-left corner.
const List<List<_KeySpec>> _layout = <List<_KeySpec>>[
  <_KeySpec>[
    _KeySpec(CalculatorKey.ac),
    _KeySpec(CalculatorKey.plusMinus),
    _KeySpec(CalculatorKey.percent),
    _KeySpec(CalculatorKey.divide),
  ],
  <_KeySpec>[
    _KeySpec(CalculatorKey.digit7),
    _KeySpec(CalculatorKey.digit8),
    _KeySpec(CalculatorKey.digit9),
    _KeySpec(CalculatorKey.multiply),
  ],
  <_KeySpec>[
    _KeySpec(CalculatorKey.digit4),
    _KeySpec(CalculatorKey.digit5),
    _KeySpec(CalculatorKey.digit6),
    _KeySpec(CalculatorKey.subtract),
  ],
  <_KeySpec>[
    _KeySpec(CalculatorKey.digit1),
    _KeySpec(CalculatorKey.digit2),
    _KeySpec(CalculatorKey.digit3),
    _KeySpec(CalculatorKey.add),
  ],
  <_KeySpec>[
    _KeySpec(CalculatorKey.digit0, 2),
    _KeySpec(CalculatorKey.dot),
    _KeySpec(CalculatorKey.equals),
  ],
];
