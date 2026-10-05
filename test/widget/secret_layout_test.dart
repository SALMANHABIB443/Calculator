/// Rendered geometry of the Secret PIN pad (desing.md §6.8).
///
/// This suite exists because the bug it guards was **invisible to every other
/// test in the app**. The pad handed `Expanded` to each row and cell and let
/// `CalculatorButton` take `min(width, height)`, so on the 442×890 reference
/// canvas it derived a **123 px** key — 40 % wider than the calculator's own
/// measured 88 px keys it is explicitly built to echo. Nothing threw: the keys
/// were square, evenly gapped, inside their box, and every flow test typed a
/// PIN through them successfully. The pad was simply enormous.
///
/// So these assert the *rendered rects* and the *relationships* between them —
/// the cell ceiling, the gaps actually painted, the centring, the square-ness —
/// for the same reason `calculator_layout_test.dart` does: a token assertion
/// cannot see a margin, and a "did not throw" assertion cannot see a size.
library;

import 'package:calculator/core/design/app_spacing.dart';
import 'package:calculator/core/widgets/core_widgets.dart';
import 'package:calculator/features/calculator/presentation/calculator_keypad.dart';
import 'package:calculator/features/history/domain/history_entry.dart';
import 'package:calculator/features/secret/presentation/secret_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

/// Reference canvas of mockup `02_22_43` (D-13) — the only size the calculator's
/// measured 88 px key is stated against.
const Size reference = Size(442, 890);

/// The `prd.md` §12 touch-target floor.
const double touchFloor = 44;

/// The pad's ceiling: the calculator's own key (D-60), on the reference canvas.
///
/// **86, not 88.** D-110 widened the calculator's `keyGap` to 16, which moved
/// its measured key to `(442 − 48 − 16×3) / 4 = 86.5`. An 88 ceiling here would
/// have made the "smaller echo" larger than the instrument it echoes — the
/// precise inversion this ceiling exists to prevent — so the two are kept
/// together and the relationship below is what actually guards them.
const double pinCeiling = 86;

/// Sub-pixel slack, for the same reason `calculator_layout_test.dart` keeps one:
/// every rect here is a sum of tokens, and the regression being guarded is tens
/// of pixels wide.
const double slack = 0.5;

/// One seeded entry so History's bottom Clear History button renders at all
/// (D-38 hides it when there is nothing to clear).
List<HistoryEntry> seeded() => <HistoryEntry>[
  seededEntry(
    expression: '2 + 2',
    result: '4',
    resultValue: 4,
    timestamp: DateTime(2026, 10, 3, 9),
  ),
];

/// Opens History and holds its bottom action for the shipped five seconds, which
/// is the only route to the PIN screen (D-82).
Future<void> openPinScreen(WidgetTester tester, {Size? at}) async {
  tester.view.physicalSize = (at ?? reference) * 1;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await pumpApp(tester, history: seeded());
  await openHistory(tester);

  final button = find.byKey(const Key('history-clear-button'));
  expect(button, findsOneWidget);

  final gesture = await tester.startGesture(tester.getCenter(button));
  await tester.pump(secretHoldDuration);
  await tester.pumpAndSettle();
  await gesture.up();
  await tester.pumpAndSettle();

  expect(find.byType(SecretUnlockScreen), findsOneWidget);
}

/// The rendered rect of one digit key, found by its label.
Rect digitRect(WidgetTester tester, String label) =>
    tester.getRect(find.widgetWithText(CalculatorButton, label));

/// The rect of the backspace key.
///
/// Found through its **glyph**, then walked up to the enclosing `Material` —
/// the glyph finder alone would measure the 22 px icon rather than the key it
/// sits in, and the key is what has to be square. `_BackspaceKey` draws its own
/// `Material` rather than reusing `CalculatorButton`, so that is the nearest
/// common ancestor of the glyph and the button box.
Rect backspaceRect(WidgetTester tester) {
  final glyph = find.byType(AppBackspaceIcon);
  final key = find.ancestor(of: glyph, matching: find.byType(Material));
  return tester.getRect(key.first);
}

/// The rect of the whole dot indicator.
Rect dotsRect(WidgetTester tester) =>
    tester.getRect(find.byKey(const Key('secret-pin-dots')));

void main() {
  group('the pad is a smaller echo of the calculator, not a second instrument', () {
    testWidgets('the reference canvas renders 86 px keys, not 123', (
      tester,
    ) async {
      await openPinScreen(tester);

      // The reported bug. The pad used to derive its cell from the full width it
      // was given — (394 − 2×12) / 3 = 123 — and render keys a third wider than
      // the calculator's.
      final five = digitRect(tester, '5');
      expect(five.width, closeTo(pinCeiling, slack));
      expect(five.height, closeTo(pinCeiling, slack));
    });

    testWidgets('the pad never exceeds the calculator key it echoes', (
      tester,
    ) async {
      await openPinScreen(tester);

      // The ceiling is expressed as a relationship to the calculator rather than
      // as a bare 88, because that is the *reason* for the number: the pad has
      // to read as a scaled-down version of an instrument the user already knows.
      // If the calculator's key ever moves, this fails and the pad is re-decided
      // rather than silently left oversized against it.
      final calculatorKey = CalculatorKeypad.cellSizeFor(
        width: reference.width - 48,
        height: 682,
      );

      expect(pinCeiling, lessThanOrEqualTo(calculatorKey));
    });

    testWidgets('every key is square and identically sized', (tester) async {
      await openPinScreen(tester);

      // One derived cell for the whole grid, so no key can come out a different
      // size from its neighbour — the failure a per-`Expanded` layout invites.
      final referenceKey = digitRect(tester, '5');
      for (final label in <String>[
        '1',
        '2',
        '3',
        '4',
        '6',
        '7',
        '8',
        '9',
        '0',
      ]) {
        final rect = digitRect(tester, label);
        expect(rect.width, closeTo(referenceKey.width, slack), reason: label);
        expect(rect.height, closeTo(referenceKey.height, slack), reason: label);
      }

      final backspace = backspaceRect(tester);
      expect(backspace.width, closeTo(referenceKey.width, slack));
      expect(backspace.height, closeTo(referenceKey.height, slack));
    });
  });

  group('the painted geometry (D-69: a reserved gap is not a gap)', () {
    testWidgets('the horizontal gap between two keys is the stated 12', (
      tester,
    ) async {
      await openPinScreen(tester);

      final gap = digitRect(tester, '2').left - digitRect(tester, '1').right;
      expect(gap, closeTo(12, slack));
    });

    testWidgets('the vertical gap between two rows is the stated 12', (
      tester,
    ) async {
      await openPinScreen(tester);

      final gap = digitRect(tester, '4').top - digitRect(tester, '1').bottom;
      expect(gap, closeTo(12, slack));
    });

    testWidgets('the pad is centred in the column', (tester) async {
      await openPinScreen(tester);

      // With the cell clamped, the grid is 288 wide inside a 394-wide column, so
      // there is real surplus to centre — 53 px a side. Under the old layout the
      // grid filled the width exactly and this assertion had nothing to measure.
      final left = digitRect(tester, '1').left;
      final right = digitRect(tester, '3').right;

      expect(reference.width - 24 - right, closeTo(left - 24, slack));
    });

    testWidgets('the last row keeps 0 in the middle column', (tester) async {
      await openPinScreen(tester);

      // The final row holds backspace and `0` in a three-wide grid, so `0` lands
      // in the **middle** column — the one `2` and `5` occupy above it, exactly
      // as on the calculator. A trailing gap is what holds it there; an
      // unterminated `Row` would pack both keys to the start and drag `0` left
      // against the backspace.
      final zero = digitRect(tester, '0');
      final backspace = backspaceRect(tester);
      final two = digitRect(tester, '2');

      expect(zero.center.dx, closeTo(two.center.dx, slack));
      expect(zero.left, greaterThan(backspace.right));
    });
  });

  group('the prompt is anchored to the bottom, not centred (D-89)', () {
    /// The height `SecretPinField` is actually given on the unlock screen: the
    /// window less the screen's own top and bottom padding.
    ///
    /// Derived from the tokens rather than written as a number, because the
    /// anchor is a fraction of *this* box — a hard-coded 842 would pass on the
    /// reference canvas and quietly assert the wrong thing the moment a padding
    /// token moved.
    double fieldHeight(Size window) =>
        window.height - AppSpacing.headerTopGap - AppSpacing.bottomSafe;

    /// The gap the brief asks for, as a share of the box the field is given.
    const double anchor = 0.20;

    testWidgets('the pad sits 20% of the height above the bottom edge', (
      tester,
    ) async {
      await openPinScreen(tester);

      // The bottom row is the bottom of the pad, so its lower edge is what the
      // anchor is stated against — not the dots, and not the pad's box.
      final padBottom = digitRect(tester, '0').bottom;
      final expected = reference.height -
          AppSpacing.bottomSafe -
          fieldHeight(reference) * anchor;

      expect(padBottom, closeTo(expected, slack));
    });

    testWidgets('the space is one band above the prompt, not split around it', (
      tester,
    ) async {
      await openPinScreen(tester);

      // The defect in its own terms, and the reason it cannot be stated as
      // "nothing is near the middle": the pad is 380 px tall and legitimately
      // reaches past the halfway line, so what is being asserted is not where
      // the pad is but **how the leftover height is spent**.
      //
      // Under the old `Center` the slack was shared — half above the prompt and
      // half below the pad, the two equal by construction. Anchored, all of it
      // collects above and the only band below is the anchor itself, so the one
      // above is necessarily the larger. Equal bands would mean the group had
      // drifted back to the middle, which is exactly the regression guarded.
      final above = tester.getRect(find.text('Enter your PIN')).top -
          AppSpacing.headerTopGap;
      final below = reference.height -
          AppSpacing.bottomSafe -
          digitRect(tester, '0').bottom;

      expect(above, greaterThan(below));
      // And the prompt is clear of the top padding rather than pinned to it —
      // the other half of "not centred", since a centred group of this height
      // happens to clear it by only a few px.
      expect(above, greaterThan(reference.height * 0.2));
    });

    testWidgets('the gap is a share of the height, so it scales with the window', (
      tester,
    ) async {
      // Twice the reference height: a fixed px gap would halve its relationship
      // to the screen here, and the pad would ride much closer to the floor than
      // the same fraction on a phone.
      const tall = Size(1280, 1600);
      await openPinScreen(tester, at: tall);

      final padBottom = digitRect(tester, '0').bottom;
      final expected = tall.height -
          AppSpacing.bottomSafe -
          fieldHeight(tall) * anchor;

      expect(padBottom, closeTo(expected, slack));
      // And the pad is still the calculator's key, not stretched to fill.
      expect(digitRect(tester, '5').width, closeTo(pinCeiling, slack));
    });

    testWidgets('a short window gives up the gap before it gives up the pad', (
      tester,
    ) async {
      // The order the two claims are made in. A window too short for both the
      // full-size pad and a fifth of its height must shrink the pad and still
      // honour the anchor — the reverse would push the group off the bottom.
      const short = Size(360, 560);
      await openPinScreen(tester, at: short);

      expect(tester.takeException(), isNull);

      final padBottom = digitRect(tester, '0').bottom;
      final expected =
          short.height - AppSpacing.bottomSafe - fieldHeight(short) * anchor;

      expect(padBottom, closeTo(expected, slack));
      // Shrunk, but never below the touch floor it has to keep.
      expect(
        digitRect(tester, '5').shortestSide,
        greaterThanOrEqualTo(touchFloor),
      );
    });
  });

  group('the dots sit in the upper half (desing.md §6.8)', () {
    testWidgets('the dots are not pinned to the top of the screen', (
      tester,
    ) async {
      await openPinScreen(tester);

      // The old column declared `mainAxisAlignment: center` while its keypad
      // child was `Expanded` — so the alignment was inert, the keypad absorbed
      // every pixel of slack, and the dots were pushed flush against the top
      // padding where they read as a status line rather than as the prompt.
      final dots = dotsRect(tester);
      expect(dots.center.dy, greaterThan(reference.height * 0.2));
    });

    testWidgets('the dots sit above the pad', (tester) async {
      await openPinScreen(tester);

      expect(dotsRect(tester).bottom, lessThan(digitRect(tester, '1').top));
    });

    testWidgets('the dots are horizontally centred', (tester) async {
      await openPinScreen(tester);

      expect(dotsRect(tester).center.dx, closeTo(reference.width / 2, slack));
    });

    testWidgets('the label sits immediately above the dots, not at the top', (
      tester,
    ) async {
      await openPinScreen(tester);

      // The defect the prompt's arrival exposed. The line used to be a direct
      // child of the column with the `Expanded` below it, so the line was pinned
      // to the top padding while the dots centred in their own box far beneath —
      // two halves of one question a hand's width apart, and no way to read the
      // label as belonging to the dots.
      final label = tester.getRect(
        find.text('Enter your PIN'),
      );
      final dots = dotsRect(tester);

      // One token's worth of slack, nothing more: close enough to read as the
      // line above the dots, not so close that the two collide.
      expect(label.bottom, lessThan(dots.top));
      expect(dots.top - label.bottom, lessThanOrEqualTo(AppSpacing.xl));
    });

    testWidgets('the pad sits just below the dots, not adrift below them', (
      tester,
    ) async {
      await openPinScreen(tester);

      // The measured regression. The prompt assembly and the pad each `Center`ed
      // themselves in the share they were given, and since the keys are clamped
      // to 88 px their box had a lot of slack to spend — so each half pushed the
      // gap open from its own side and the dots ended up **248 px** above the `1`
      // key. Not a spacing value: the leftover of two independent centring
      // operations, five times the gap actually written on the screen.
      //
      // The floor is what the `Forgot PIN?` link costs — it is a real widget with
      // real padding, and it belongs between the indicator it recovers and the
      // pad. The ceiling allows one `lg` step on top of that, so the layout can
      // breathe but cannot drift back into a void.
      expect(
        digitRect(tester, '1').top - dotsRect(tester).bottom,
        lessThanOrEqualTo(112),
      );
    });
  });

  group('the pad still shrinks rather than clipping (prd.md AC-015)', () {
    testWidgets('a short window gives way without overflowing', (
      tester,
    ) async {
      // The window the old layout handled worst: too short for an 88 px pad, so
      // the cell has to follow the height down rather than clip.
      await openPinScreen(tester, at: const Size(360, 560));

      expect(tester.takeException(), isNull);

      final five = digitRect(tester, '5');
      expect(five.shortestSide, greaterThanOrEqualTo(touchFloor));
      expect(five.width, lessThanOrEqualTo(pinCeiling + slack));
    });

    testWidgets('a wide window does not inflate the pad into a tablet grid', (
      tester,
    ) async {
      // The second half of the same defect. The pad used to cap itself at
      // `calculatorPanelMaxWidth` (480) — a token documented as the
      // *calculator's* column — so on a desktop window three columns across 480
      // would have derived a 152 px key.
      await openPinScreen(tester, at: const Size(1280, 1600));

      expect(tester.takeException(), isNull);
      expect(digitRect(tester, '5').width, closeTo(pinCeiling, slack));
    });
  });
}
