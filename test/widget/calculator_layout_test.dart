/// Keypad geometry and the vertical composition of the calculator screen
/// (**D-69**).
///
/// These assert the *rendered rects*, because the bug they exist for was never
/// visible to a test that only measured a cell. The grid used to reserve
/// `keyGap` in `gridWidth`/`gridHeight` and then lay its rows out from bare
/// cells with no separator between them, so every key was *touching* its
/// neighbour, every row fell `keyGap × 3` short of the width the grid
/// declared, and the 5-row column fell `keyGap × 4` short at the bottom. The
/// surplus was absorbed by whatever alignment happened to be in force, so the
/// failures showed up as 7 px of drift between the last row and the four above
/// it, a 42 px off-centre grid, and a keypad floating 80 px off the floor —
/// every one of them invisible to `expect(size.width, closeTo(...))`.
///
/// A golden image would catch them too, but it would also pass while a screen
/// quietly hard-coded the geometry that happens to look right. Measuring the
/// relationships — gap, centring, column alignment, edge alignment — states
/// what the layout has to *be*, so it fails for the reason the layout is wrong
/// rather than because a pixel moved.
library;

import 'package:calculator/core/design/app_spacing.dart';
import 'package:calculator/features/calculator/domain/calculator_engine.dart';
import 'package:calculator/features/calculator/presentation/calculator_keypad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

/// Reference canvas of mockup `02_22_43` (D-13), and the only size the
/// mockup's measured geometry (24 px margins, 14 px gaps, 88 px keys) is
/// stated against.
const Size reference = Size(442, 890);

/// The `prd.md` §12 floor, and the reservation
/// [CalculatorKeypad.minGridHeight] is built from.
const double touchFloor = 44;

/// Sub-pixel slack for a derived measurement.
///
/// Every rect here comes out of sums and halves of tokens, so the assertions
/// are about a relationship rather than about a last decimal place. A real
/// regression here is 7 px or more — the drift the bug left — so a one pixel
/// tolerance cannot hide one.
const double slack = 0.5;

Finder keyFor(CalculatorKey key) => find.byKey(ValueKey('key-${key.name}'));

/// The rendered rect of one key.
Rect rectOf(WidgetTester tester, CalculatorKey key) =>
    tester.getRect(keyFor(key));

/// The horizontal gap painted between two keys in the same row.
double rowGap(WidgetTester tester, CalculatorKey left, CalculatorKey right) =>
    rectOf(tester, right).left - rectOf(tester, left).right;

/// The vertical gap painted between the same column of two adjacent rows.
double columnGap(
  WidgetTester tester,
  CalculatorKey above,
  CalculatorKey below,
) => rectOf(tester, below).top - rectOf(tester, above).bottom;

/// The rect of the hero result line, which is what has to line up with the
/// operator column.
Rect resultRect(WidgetTester tester) =>
    tester.getRect(find.byKey(const Key('calculator-result')));

/// The expression line, for the same reason: it shares the display's right edge.
Rect expressionRect(WidgetTester tester) =>
    tester.getRect(find.byKey(const Key('calculator-expression')));

/// Loads the app at [size], restoring the view afterwards.
Future<void> pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await pumpApp(tester);
}

void main() {
  group('the grid paints the gaps it declares (D-69)', () {
    testWidgets('neighbouring keys are keyGap apart across a row', (
      tester,
    ) async {
      await pumpAt(tester, reference);

      for (final (left, right) in <(CalculatorKey, CalculatorKey)>[
        (CalculatorKey.ac, CalculatorKey.plusMinus),
        (CalculatorKey.plusMinus, CalculatorKey.percent),
        (CalculatorKey.percent, CalculatorKey.divide),
        (CalculatorKey.digit7, CalculatorKey.digit8),
        (CalculatorKey.digit8, CalculatorKey.digit9),
        (CalculatorKey.digit9, CalculatorKey.multiply),
        (CalculatorKey.digit4, CalculatorKey.digit5),
        (CalculatorKey.digit5, CalculatorKey.digit6),
        (CalculatorKey.digit6, CalculatorKey.subtract),
        (CalculatorKey.digit1, CalculatorKey.digit2),
        (CalculatorKey.digit2, CalculatorKey.digit3),
        (CalculatorKey.digit3, CalculatorKey.add),
        // The wide `0` is one stadium laid across columns one and two, so the
        // gap beside it is a real one rather than the notch its cell absorbed.
        (CalculatorKey.digit0, CalculatorKey.dot),
        (CalculatorKey.dot, CalculatorKey.equals),
      ]) {
        expect(
          rowGap(tester, left, right),
          closeTo(CalculatorKeypad.keyGap, slack),
          reason: '${left.label} and ${right.label} are not keyGap apart',
        );
      }
    });

    testWidgets('every pair of stacked rows is keyGap apart', (tester) async {
      await pumpAt(tester, reference);

      // Same column, consecutive rows. The last pair crosses the row that
      // spends two of its columns on the wide `0`, which is the one that used
      // to come up short.
      for (final (above, below) in <(CalculatorKey, CalculatorKey)>[
        (CalculatorKey.ac, CalculatorKey.digit7),
        (CalculatorKey.plusMinus, CalculatorKey.digit8),
        (CalculatorKey.percent, CalculatorKey.digit9),
        (CalculatorKey.divide, CalculatorKey.multiply),
        (CalculatorKey.digit7, CalculatorKey.digit4),
        (CalculatorKey.digit8, CalculatorKey.digit5),
        (CalculatorKey.digit9, CalculatorKey.digit6),
        (CalculatorKey.multiply, CalculatorKey.subtract),
        (CalculatorKey.digit4, CalculatorKey.digit1),
        (CalculatorKey.digit5, CalculatorKey.digit2),
        (CalculatorKey.digit6, CalculatorKey.digit3),
        (CalculatorKey.subtract, CalculatorKey.add),
        (CalculatorKey.digit1, CalculatorKey.digit0),
        (CalculatorKey.digit2, CalculatorKey.dot),
        (CalculatorKey.digit3, CalculatorKey.equals),
      ]) {
        expect(
          columnGap(tester, above, below),
          closeTo(CalculatorKeypad.keyGap, slack),
          reason: '${above.label} and ${below.label} are not keyGap apart',
        );
      }
    });

    testWidgets('no two keys touch', (tester) async {
      await pumpAt(tester, reference);

      // The blunt statement of the bug: tangent circles read as one blob, and
      // the mockup measures a 13 px gap on either side of every key.
      for (final (left, right) in <(CalculatorKey, CalculatorKey)>[
        (CalculatorKey.digit7, CalculatorKey.digit8),
        (CalculatorKey.digit1, CalculatorKey.digit2),
      ]) {
        expect(
          rectOf(tester, left).right,
          lessThan(rectOf(tester, right).left),
          reason: '${left.label} and ${right.label} touch',
        );
      }
    });
  });

  group('every row is in the same columns (D-69)', () {
    testWidgets('the orange column is unbroken from divide down to equals', (
      tester,
    ) async {
      await pumpAt(tester, reference);

      // The operator column is `÷ × − +` with `=` beneath it. Before D-69 the
      // last row was one gap wider — `0` absorbs the gap it straddles — so the
      // surplus was re-centred per row and `=` sat 7 px right of the four keys
      // above it. One assertion over all five is the whole regression.
      final rightEdges = [
        CalculatorKey.divide,
        CalculatorKey.multiply,
        CalculatorKey.subtract,
        CalculatorKey.add,
        CalculatorKey.equals,
      ].map((key) => rectOf(tester, key).right).toList();

      for (final edge in rightEdges) {
        expect(
          edge,
          closeTo(rightEdges.first, slack),
          reason: 'the operator column is not flush',
        );
      }
    });

    testWidgets('the 0 key starts on the digit column', (tester) async {
      await pumpAt(tester, reference);

      // The other half of the 7 px drift: the same re-centring pushed `0` 7 px
      // left of the 1/4/7 column it is supposed to continue.
      final leftEdges = [
        CalculatorKey.digit7,
        CalculatorKey.digit4,
        CalculatorKey.digit1,
        CalculatorKey.digit0,
      ].map((key) => rectOf(tester, key).left).toList();

      for (final edge in leftEdges) {
        expect(
          edge,
          closeTo(leftEdges.first, slack),
          reason: 'the leading column is not flush',
        );
      }
    });

    testWidgets('the 0 key ends on the 8 key, two columns wide', (
      tester,
    ) async {
      await pumpAt(tester, reference);

      // It spans columns one and two, so its right edge is column *two*'s —
      // the 8's. The 9 is column three, and the gap it stands in is the one the
      // spanning cell absorbed (D-29).
      expect(
        rectOf(tester, CalculatorKey.digit0).right,
        closeTo(rectOf(tester, CalculatorKey.digit8).right, slack),
      );
      expect(
        rectOf(tester, CalculatorKey.digit0).width,
        closeTo(
          rectOf(tester, CalculatorKey.digit8).width +
              CalculatorKeypad.keyGap +
              rectOf(tester, CalculatorKey.digit8).width,
          slack,
        ),
        reason: '0 is not two columns wide',
      );
    });
  });

  group('the screen edges are the measured margin (D-69)', () {
    testWidgets('the keypad has the same margin on both sides', (tester) async {
      await pumpAt(tester, reference);

      // Before D-69 each row was centred inside a box 42 px wider than the row,
      // so the grid sat 21 px inside the screen margin on both sides — and the
      // last row sat 14 px inside it, which is a third value nobody chose.
      final left = rectOf(tester, CalculatorKey.ac).left;
      final right =
          reference.width - rectOf(tester, CalculatorKey.equals).right;

      expect(left, closeTo(AppSpacing.screenHorizontal, slack));
      expect(right, closeTo(AppSpacing.screenHorizontal, slack));
      expect(
        left,
        closeTo(right, slack),
        reason: 'the keypad is not centred between the margins',
      );
    });

    testWidgets('the last row sits one bottomSafe above the floor', (
      tester,
    ) async {
      await pumpAt(tester, reference);

      // The 5-row column used to come up `keyGap × 4` short of the height the
      // grid declared, and that shortfall sat *below* the keys — so the whole
      // keypad floated 56 px off the floor on top of the bottom padding.
      expect(
        reference.height - rectOf(tester, CalculatorKey.equals).bottom,
        closeTo(AppSpacing.bottomSafe, slack),
      );
    });

    testWidgets('the result lands on the operator column', (tester) async {
      await pumpAt(tester, reference);

      // The display used to be sized against the full content width while the
      // keypad was centred at its natural size, so the two edges disagreed and
      // the disagreement grew with the window. Both lines share it now.
      expect(resultRect(tester).right, closeTo(rightEdge(tester), slack));
      expect(expressionRect(tester).right, closeTo(rightEdge(tester), slack));
    });
  });

  group('the display and the keypad are one interface (D-69)', () {
    testWidgets('the result sits a deliberate gap above the keys', (
      tester,
    ) async {
      await pumpAt(tester, reference);

      // Measured between the *painted* lines rather than their boxes: the
      // result's box is 66 px tall for a 60 px glyph, so a box-to-box
      // assertion would be measuring the type's own line height.
      final gap =
          rectOf(tester, CalculatorKey.ac).top - resultRect(tester).bottom;

      expect(
        gap,
        greaterThan(0),
        reason: 'the number is not clear of the keys',
      );
      expect(
        gap,
        lessThan(AppSpacing.calculatorDisplayGap * 2),
        reason: 'the display has drifted away from the keypad again',
      );
    });

    testWidgets(
      'the number sits directly above the keypad, not above the grid',
      (tester) async {
        await pumpAt(tester, reference);

        // The composition reads as one object only if the distance from the
        // number to the *first* key row is the same as to the last one plus the
        // whole grid — i.e. nothing is hiding between the display and the keys.
        final firstRow = rectOf(tester, CalculatorKey.ac).top;
        final lastRow = rectOf(tester, CalculatorKey.equals).bottom;

        expect(resultRect(tester).bottom, lessThan(firstRow));
        expect(lastRow, greaterThan(firstRow));
      },
    );
  });

  group('the geometry holds across viewport sizes (D-69, D-09)', () {
    // The four shapes a phone, a foldable, a tablet, and a desktop window
    // actually present. None of them is the mockup except the first, which is
    // the point: a layout that only fits the size it was drawn at is not
    // responsive.
    for (final size in <Size>[
      Size(320, 568),
      reference,
      Size(480, 1000),
      Size(768, 1024),
      Size(1280, 800),
      Size(1280, 1600),
    ]) {
      testWidgets(
        'nothing overflows at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          await pumpAt(tester, size);

          expect(
            tester.takeException(),
            isNull,
            reason: 'the calculator overflowed at $size',
          );
        },
      );

      testWidgets(
        'the margins stay symmetric at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          await pumpAt(tester, size);

          final left = rectOf(tester, CalculatorKey.ac).left;
          final right = size.width - rectOf(tester, CalculatorKey.equals).right;

          // Symmetry is the invariant at every size. The absolute figure is
          // only 24 while the window is narrower than the capped panel — past
          // that the surplus is distributed to the margins on purpose (D-69),
          // so the assertion becomes "at least the margin", not "exactly it".
          expect(left, closeTo(right, slack));
          expect(left, greaterThanOrEqualTo(AppSpacing.screenHorizontal - slack));
        },
      );

      testWidgets(
        'the operator column stays flush at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          await pumpAt(tester, size);

          expect(
            rectOf(tester, CalculatorKey.equals).right,
            closeTo(rectOf(tester, CalculatorKey.add).right, slack),
          );
        },
      );

      testWidgets(
        'the result tracks the column at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          await pumpAt(tester, size);

          expect(resultRect(tester).right, closeTo(rightEdge(tester), slack));
        },
      );
    }
  });

  group('the cell is bounded on both axes (D-69)', () {
    testWidgets('a wide desktop window does not render giant keys', (
      tester,
    ) async {
      // The panel is capped, so the cell follows the cap rather than the window.
      // Without [CalculatorKeypad.maxCellSize] a 1280x1600 window derives a
      // 268 px key from its own width.
      await pumpAt(tester, const Size(1280, 1600));

      final cell = rectOf(tester, CalculatorKey.digit5).width;
      expect(cell, lessThanOrEqualTo(CalculatorKeypad.maxCellSize));
      expect(
        cell,
        greaterThan(88),
        reason: 'the cap should not have shrunk a phone-sized key',
      );
    });

    testWidgets('the calculator stays a centred, calculator-sized column', (
      tester,
    ) async {
      await pumpAt(tester, const Size(1280, 1600));

      // Centred is the robust half of this: whatever the cap resolves to, the
      // surplus has to fall equally on both sides rather than leaving the grid
      // hard against one edge of a desktop window.
      final left = rectOf(tester, CalculatorKey.ac).left;
      final right = 1280 - rectOf(tester, CalculatorKey.equals).right;

      expect(left, closeTo(right, slack));
      expect(
        left,
        greaterThanOrEqualTo(
          (1280 - AppSizes.calculatorPanelMaxWidth) / 2,
        ),
        reason: 'the panel cap is not holding the column to its own width',
      );
    });

    testWidgets('keys keep the touch floor on the smallest supported phone', (
      tester,
    ) async {
      await pumpAt(tester, const Size(320, 568));

      for (final key in CalculatorKey.values) {
        expect(
          rectOf(tester, key).shortestSide,
          greaterThanOrEqualTo(touchFloor),
          reason: '${key.label} is under the prd.md §12 floor',
        );
      }
    });

    testWidgets('keys keep the touch floor at the text-scale clamp', (
      tester,
    ) async {
      // The clamp is what the display's reservation is read at (D-54), so the
      // keypad is being sized against a taller display here than at 1x.
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpAt(tester, const Size(320, 568));

      for (final key in CalculatorKey.values) {
        expect(
          rectOf(tester, key).shortestSide,
          greaterThanOrEqualTo(touchFloor),
          reason: '${key.label} is under the floor at the clamp',
        );
      }
    });

    testWidgets(
      'the keypad holds its floor on a window shorter than the reserve',
      (tester) async {
        // Below the documented minimum. There is not enough height to honour both
        // the display's minimum and the keypad's floor, so the honest degradation
        // is that the display compresses: the keys are the last thing to give
        // (D-69), because the keys are the whole interface.
        await pumpAt(tester, const Size(360, 480));

        expect(tester.takeException(), isNull);
        for (final key in CalculatorKey.values) {
          expect(
            rectOf(tester, key).shortestSide,
            greaterThanOrEqualTo(touchFloor),
            reason: '${key.label} gave way instead of the display',
          );
        }
      },
    );
  });

  group('the grid is the only place the geometry lives (D-27, D-69)', () {
    test('the derived cell still fills the box it was given', () {
      // The screen hands the grid a box and reads the grid's own answer back to
      // size the display, so the two agree by construction. These are the
      // numbers the mockup measured, and they are what proves the agreement
      // rather than a tautology.
      final cell = CalculatorKeypad.cellSizeFor(
        width: 442 - AppSpacing.screenHorizontal * 2,
        height: 682,
      );

      expect(cell, closeTo(88, 0.5));
      expect(CalculatorKeypad.gridWidth(cell), closeTo(394, 0.5));
      expect(CalculatorKeypad.gridHeight(cell), closeTo(496, 0.5));
    });

    test('the measured gap is a gap on both axes', () {
      // desing.md §12.1 measured 13 px horizontally and 15 px vertically, and
      // D-60 settled on the 14 px midpoint for both. The rendering has to match
      // that decision or the measured geometry is only nominal.
      expect(CalculatorKeypad.keyGap, 14);
      expect(CalculatorKeypad.columnCount, 4);
      expect(CalculatorKeypad.rowCount, 5);
    });

    test('the 44pt floor is a reservation, not a clamp', () {
      // A cell larger than its box overflows it, so the floor cannot live in
      // `cellSizeFor` — which is why `maxCellSize` has no matching minimum.
      final tooTall = CalculatorKeypad.cellSizeFor(
        width: 442 - AppSpacing.screenHorizontal * 2,
        height: 40,
      );

      expect(tooTall, lessThan(touchFloor));
      expect(tooTall, greaterThanOrEqualTo(0));
      expect(
        CalculatorKeypad.minGridHeight,
        closeTo(
          touchFloor * CalculatorKeypad.rowCount +
              CalculatorKeypad.keyGap * (CalculatorKeypad.rowCount - 1),
          0.01,
        ),
      );
    });

    test('the cell ceiling only ever shrinks it', () {
      final huge = CalculatorKeypad.cellSizeFor(width: 4000, height: 4000);
      expect(huge, CalculatorKeypad.maxCellSize);
    });
  });

  group('the measured geometry is unchanged (D-60, R-2)', () {
    testWidgets('the reference canvas still renders 88 px keys', (
      tester,
    ) async {
      await pumpAt(tester, reference);

      final key = rectOf(tester, CalculatorKey.digit5);
      expect(key.width, inInclusiveRange(86, 88.5));
      expect(key.width, key.height, reason: 'a round key must be square');
    });
  });
}

/// The right edge of the operator column — the line the display has to meet.
double rightEdge(WidgetTester tester) =>
    rectOf(tester, CalculatorKey.equals).right;
