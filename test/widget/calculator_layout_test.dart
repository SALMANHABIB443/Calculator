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
import 'package:calculator/core/widgets/app_icon_button.dart';
import 'package:calculator/features/calculator/domain/calculator_engine.dart';
import 'package:calculator/features/calculator/presentation/calculator_keypad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keypad_session.dart';
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

/// The rect of the display's **output line**, which is what has to line up with
/// the operator column (D-69). It sits in the display's lower half.
Rect lineRect(WidgetTester tester) =>
    tester.getRect(find.byKey(const Key('calculator-display-line')));

/// The rect of the display's **calculation line**, in the upper half (D-78).
///
/// It has to be measured with *something* in it: the line is blank while a lone
/// number is being typed, and a blank `Text` inside the `FittedBox` has no box
/// of its own — it renders zero-sized at an undefined offset, so every
/// arithmetic on its rect would be `NaN`. Use [pumpWithCalculation].
Rect expressionRect(WidgetTester tester) =>
    tester.getRect(find.byKey(const Key('calculator-expression')));

/// The whole display block, which holds the two lines.
Rect displayRect(WidgetTester tester) =>
    tester.getRect(find.byKey(const Key('calculator-display')));

/// The backspace control on its own row (D-81).
Rect backspaceRect(WidgetTester tester) =>
    tester.getRect(find.byKey(const Key('calculator-backspace')));

/// Loads the app at [size], restoring the view afterwards.
Future<void> pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await pumpApp(tester);
}

/// Loads the app at [size] with [session] keyed on it, so **both** display lines
/// have content to measure.
///
/// The two halves of the display are only observable when the calculation line
/// has something on it — an empty expression renders as no box at all. Keying a
/// real `9 × 9 =` gives the layout both lines: the expression `9 × 9` above and
/// the output `81` below.
Future<void> pumpWithCalculation(
  WidgetTester tester,
  Size size, {
  String session = '9×9=',
}) async {
  await pumpAt(tester, size);
  for (final key in keysFor(session)) {
    await tester.tap(keyFor(key));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  group('the grid paints the gaps it declares (D-69)', () {
    testWidgets('neighbouring keys are keyGap apart across a row', (
      tester,
    ) async {
      await pumpAt(tester, reference);

      for (final (left, right) in <(CalculatorKey, CalculatorKey)>[
        (CalculatorKey.ac, CalculatorKey.parentheses),
        (CalculatorKey.parentheses, CalculatorKey.percent),
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
        (CalculatorKey.parentheses, CalculatorKey.digit8),
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

    testWidgets('the display line lands on the operator column', (
      tester,
    ) async {
      await pumpAt(tester, reference);

      // The display used to be sized against the full content width while the
      // keypad was centred at its natural size, so the two edges disagreed and
      // the disagreement grew with the window. The line shares the column now.
      expect(lineRect(tester).right, closeTo(rightEdge(tester), slack));
    });
  });

  group('the display is two screens, calculation above output (D-78)', () {
    testWidgets('the calculation is above the output, inside the block', (
      tester,
    ) async {
      await pumpWithCalculation(tester, reference);

      // The split is the whole point: the expression the user is building sits in
      // the upper half and the answer in the lower one, so both are readable at
      // once and `=` never has to move a number to reveal the result.
      final display = displayRect(tester);
      final expression = expressionRect(tester);
      final line = lineRect(tester);

      expect(
        expression.top,
        greaterThanOrEqualTo(display.top - slack),
        reason: 'the calculation has drifted out of the display block',
      );
      expect(
        expression.bottom,
        lessThanOrEqualTo(line.top + slack),
        reason: 'the output has risen above the calculation',
      );
      expect(line.bottom, lessThanOrEqualTo(display.bottom + slack));
    });

    testWidgets('the output sits clear of the keys, not against them', (
      tester,
    ) async {
      await pumpWithCalculation(tester, reference);

      // The result rises into the lower half of the display rather than resting
      // on the keypad, so there is space under it that is neither line.
      final firstRow = rectOf(tester, CalculatorKey.ac).top;
      expect(
        lineRect(tester).bottom,
        lessThan(firstRow),
        reason: 'the output has drifted out of the display and onto the keys',
      );
    });

    testWidgets('each line centres in its own half', (tester) async {
      await pumpWithCalculation(tester, reference);

      // Two equal halves: the boundary between them is the display's own
      // midline, so each line's centre is a quarter of the way down or up from
      // it. This is the relationship the split claims, measured rather than
      // assumed — a layout that merely stacked the two lines would still put
      // both in the right places but not at these centres.
      final display = displayRect(tester);
      final half = display.height / 2;

      expect(
        expressionRect(tester).center.dy,
        closeTo(display.top + half / 2, slack),
      );
      expect(
        lineRect(tester).center.dy,
        closeTo(display.top + half + half / 2, slack),
      );
    });

    testWidgets('nothing of the display reaches the keys', (tester) async {
      await pumpWithCalculation(tester, reference);

      // The whole composition, not just the number: both lines and the block that
      // holds them sit above the first key row, so there is nothing hidden
      // between the display and the keys.
      final firstRow = rectOf(tester, CalculatorKey.ac).top;
      final lastRow = rectOf(tester, CalculatorKey.equals).bottom;

      expect(expressionRect(tester).bottom, lessThan(firstRow));
      expect(lineRect(tester).bottom, lessThan(firstRow));
      expect(displayRect(tester).bottom, lessThan(firstRow));
      expect(lastRow, greaterThan(firstRow));
    });
  });

  group('the backspace sits on the column, above the rule (D-81)', () {
    testWidgets('it shares the display and keypad left edge', (tester) async {
      await pumpAt(tester, reference);

      // The column is the screen's own left margin (D-69): the header's leading
      // box, the display, and the keypad's first key all ride it, and so does
      // this — a control on a different edge would be the one thing on the
      // screen that does not.
      expect(
        backspaceRect(tester).left,
        closeTo(rectOf(tester, CalculatorKey.ac).left, slack),
      );
    });

    testWidgets('it is between the display and the first key row', (
      tester,
    ) async {
      await pumpAt(tester, reference);

      final backspace = backspaceRect(tester);

      // Below the display block and above the keypad, which is the gap the rule
      // draws in — not overlapping either, which is why it is a slot in the
      // column rather than a corner of the display's box.
      expect(
        backspace.top,
        greaterThanOrEqualTo(displayRect(tester).bottom - slack),
      );
      expect(backspace.bottom, lessThan(rectOf(tester, CalculatorKey.ac).top));
    });

    testWidgets('it keeps the 44pt touch floor', (tester) async {
      await pumpAt(tester, reference);

      // It is not a keypad key, but it is a target the user has to hit while
      // reading a number, so it is held to the same floor (prd.md §12). Dropping
      // the border must not shrink the target along with the ink.
      expect(backspaceRect(tester).shortestSide, greaterThanOrEqualTo(touchFloor));
    });

    testWidgets('it paints no border, unlike the header actions above it', (
      tester,
    ) async {
      await pumpAt(tester, reference);

      // The reason the border went: a bordered box on the display's own row read as a
      // fifth screen-level action, competing with the output directly above it.
      // The Settings and History boxes in the header keep theirs, so the
      // assertion is a *difference* — if the backspace simply stopped rendering
      // as an action at all, this would pass while the control had broken, which
      // is why it reads the flag rather than the pixels.
      expect(
        tester.widget<AppIconButton>(
          find.byKey(const Key('calculator-backspace')),
        ).bordered,
        isFalse,
      );
      for (final icon in <IconData>[Icons.menu, Icons.history]) {
        expect(
          tester
              .widget<AppIconButton>(
                find.ancestor(
                  of: find.byIcon(icon),
                  matching: find.byType(AppIconButton),
                ),
              )
              .bordered,
          isTrue,
          reason: 'the header actions keep the box D-74 put them in',
        );
      }
    });

    testWidgets('the keypad still holds its floor with the row in the budget', (
      tester,
    ) async {
      await pumpAt(tester, reference);

      // The row costs 48 px of a fixed canvas. Reserving it in the screen's
      // budget is what keeps it from being paid for out of the keypad, so the
      // keys are still the measured 88 px rather than a shorter cell.
      final key = rectOf(tester, CalculatorKey.digit5);
      expect(key.width, inInclusiveRange(86, 88.5));
      expect(
        reference.height - rectOf(tester, CalculatorKey.equals).bottom,
        closeTo(AppSpacing.bottomSafe, slack),
      );
    });
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

          expect(lineRect(tester).right, closeTo(rightEdge(tester), slack));
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
