import 'package:calculator/app.dart';
import 'package:calculator/core/design/app_colors.dart';
import 'package:calculator/core/widgets/core_widgets.dart';
import 'package:calculator/features/calculator/domain/calculator_engine.dart';
import 'package:calculator/features/calculator/presentation/calculator_keypad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keypad_session.dart';

/// Logical canvas of mockup `02_22_43` (D-13): 884×1779 px at 2x.
const Size mockupSize = Size(442, 890);

/// A small phone, used to check the keypad shrinks instead of clipping (D-09).
const Size smallPhoneSize = Size(320, 568);

Future<void> pumpCalculator(WidgetTester tester, {Size? surface}) async {
  if (surface != null) {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
  await tester.pumpWidget(const ProviderScope(child: CalculatorApp()));
  await tester.pumpAndSettle();
}

/// Taps the keys of [session] in order, each one settled so the display
/// repaints between presses.
Future<void> tapSequence(WidgetTester tester, String session) async {
  for (final key in keysFor(session)) {
    await tester.tap(find.byKey(ValueKey('key-${key.name}')));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// The primary display line as rendered.
String resultText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('calculator-display-line'))).data!;

/// The secondary display line — the expression as keyed — as rendered.
///
/// The upper half of the display (desing.md §3), read alongside [resultText]
/// because the two have to agree: a backspace that changes one without the
/// other is the bug this file guards against.
String expressionText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('calculator-expression'))).data!;

Finder keyFor(CalculatorKey key) => find.byKey(ValueKey('key-${key.name}'));

/// The colour filling the key's surface.
Color fillOf(WidgetTester tester, CalculatorKey key) => tester
    .widget<Material>(
      find
          .descendant(of: keyFor(key), matching: find.byType(Material))
          .first,
    )
    .color!;

void main() {
  group('keypad layout', () {
    testWidgets('renders all 19 keys, and no backspace (D-19)', (
      tester,
    ) async {
      await pumpCalculator(tester);

      expect(find.byType(CalculatorButton), findsNWidgets(19));
      for (final key in CalculatorKey.values) {
        expect(keyFor(key), findsOneWidget, reason: '${key.name} is missing');
      }
    });

    testWidgets('lays the keys out as desing.md §6.1 draws them', (
      tester,
    ) async {
      await pumpCalculator(tester);

      // The five rows of desing.md §6.1. The orange operator column runs
      // `÷ × − +` with `=` beneath it, and the function keys sit top-left. The
      // last row holds three keys because `0` spans two columns (D-29).
      final rows = <List<CalculatorKey>>[
        [
          CalculatorKey.ac,
          CalculatorKey.parentheses,
          CalculatorKey.percent,
          CalculatorKey.divide,
        ],
        [
          CalculatorKey.digit7,
          CalculatorKey.digit8,
          CalculatorKey.digit9,
          CalculatorKey.multiply,
        ],
        [
          CalculatorKey.digit4,
          CalculatorKey.digit5,
          CalculatorKey.digit6,
          CalculatorKey.subtract,
        ],
        [
          CalculatorKey.digit1,
          CalculatorKey.digit2,
          CalculatorKey.digit3,
          CalculatorKey.add,
        ],
        [CalculatorKey.digit0, CalculatorKey.dot, CalculatorKey.equals],
      ];

      Offset centreOf(CalculatorKey key) => tester.getCenter(keyFor(key));

      for (var row = 0; row < rows.length; row++) {
        final keys = rows[row];
        for (var column = 0; column < keys.length; column++) {
          final here = centreOf(keys[column]);
          if (column + 1 < keys.length) {
            final next = centreOf(keys[column + 1]);
            expect(
              here.dy,
              closeTo(next.dy, 0.01),
              reason: 'row $row is not level',
            );
            expect(
              next.dx,
              greaterThan(here.dx),
              reason: 'row $row does not advance left to right',
            );
          }
          if (row > 0) {
            expect(
              here.dy,
              greaterThan(centreOf(rows[row - 1][column]).dy),
              reason: 'row $row is not below row ${row - 1}',
            );
          }
        }
      }
    });

    testWidgets('the 0 key spans two columns as a stadium (D-29)', (
      tester,
    ) async {
      await pumpCalculator(tester);

      final wide = tester.getSize(keyFor(CalculatorKey.digit0));
      final round = tester.getSize(keyFor(CalculatorKey.digit1));

      expect(wide.height, round.height);
      expect(wide.width, greaterThan(round.width));
      // Two columns plus the gap between them.
      expect(wide.width, closeTo(round.width * 2 + CalculatorKeypad.keyGap, 1));
    });

    testWidgets('uses the measured palette for every key type (D-03)', (
      tester,
    ) async {
      await pumpCalculator(tester);

      expect(fillOf(tester, CalculatorKey.digit5), AppColors.buttonDigit);
      expect(fillOf(tester, CalculatorKey.dot), AppColors.buttonDigit);
      expect(fillOf(tester, CalculatorKey.ac), AppColors.buttonFunction);
      expect(fillOf(tester, CalculatorKey.percent), AppColors.buttonFunction);
      expect(fillOf(tester, CalculatorKey.parentheses), AppColors.buttonFunction);
      expect(fillOf(tester, CalculatorKey.add), AppColors.accent);
      expect(fillOf(tester, CalculatorKey.equals), AppColors.accent);
    });

    testWidgets('the function keys carry dark labels on the light fill', (
      tester,
    ) async {
      await pumpCalculator(tester);

      final label = tester.widget<Text>(
        find.descendant(
          of: keyFor(CalculatorKey.ac),
          matching: find.text('AC'),
        ),
      );
      expect(label.style?.color, AppColors.textOnFunction);
    });
  });

  group('keypad sizing', () {
    testWidgets('keys match the diameter measured off the mockup (R-2, D-60)', (
      tester,
    ) async {
      await pumpCalculator(tester, surface: mockupSize);

      // Phase 9 read the mockup pixels and measured the five key rows at
      // 86.5–87.5 logical px (174–178 px at 2x). Phase 1 could only report a
      // 85–95 range, which is what left R-2 open; the range is now a band with
      // a known cause. 88 is the cell the grid derives from the corrected 24 px
      // margin, and 87.5 is the top of the measured band, so 88.5 is the ceiling.
      final size = tester.getSize(keyFor(CalculatorKey.digit5));
      expect(size.width, inInclusiveRange(86, 88.5));
      expect(size.width, size.height, reason: 'a round key must be square');
    });

    testWidgets('scales down on a small phone without clipping (D-09)', (
      tester,
    ) async {
      await pumpCalculator(tester, surface: smallPhoneSize);

      final size = tester.getSize(keyFor(CalculatorKey.digit5));
      expect(size.width, greaterThan(0));
      expect(size.width, size.height);
      // The bottom row must sit inside the safe area, not past the screen edge.
      expect(
        tester.getBottomLeft(keyFor(CalculatorKey.equals)).dy,
        lessThanOrEqualTo(smallPhoneSize.height),
      );
    });

    testWidgets('scales up on a large phone without overflowing', (
      tester,
    ) async {
      await pumpCalculator(tester, surface: const Size(480, 1000));

      expect(
        tester.takeException(),
        isNull,
        reason: 'a large phone must not overflow',
      );
    });

    testWidgets('the display and the keypad never squeeze each other', (
      tester,
    ) async {
      for (final size in [mockupSize, smallPhoneSize, const Size(480, 1000)]) {
        await pumpCalculator(tester, surface: size);
        expect(tester.takeException(), isNull, reason: 'failed at $size');
      }
    });
  });

  group('key presses drive the display', () {
    testWidgets('typing digits updates the primary line', (tester) async {
      await pumpCalculator(tester);
      expect(resultText(tester), '0');

      await tapSequence(tester, '125');
      expect(resultText(tester), '125');
    });

    testWidgets('previews the result while the operand is being typed (D-79)', (
      tester,
    ) async {
      // The reported bug: typing `99 + 5` showed `99 +` above and `5` below, so
      // the answer was invisible until `=` was pressed.
      await pumpCalculator(tester);

      await tapSequence(tester, '99');
      await tapSequence(tester, '+');
      expect(find.text('99 +'), findsOneWidget);
      expect(resultText(tester), '99');

      await tapSequence(tester, '5');
      expect(find.text('99 + 5'), findsOneWidget);
      expect(resultText(tester), '104');
    });

    testWidgets('equals does not move the number the preview already showed', (
      tester,
    ) async {
      await pumpCalculator(tester);

      await tapSequence(tester, '99+5');
      final previewed = resultText(tester);
      final expression = find.text('99 + 5');

      await tapSequence(tester, '=');

      expect(resultText(tester), previewed);
      expect(expression, findsOneWidget);
    });

    testWidgets('never prints an operator in front of a number (D-80)', (
      tester,
    ) async {
      await pumpCalculator(tester);

      // `+` first is declined, so the `5` is not rendered as `+ 5`.
      await tapSequence(tester, '+');
      await tapSequence(tester, '5');
      expect(resultText(tester), '5');
      expect(find.textContaining('+ 5'), findsNothing);

      await tapSequence(tester, 'AC');
      await tapSequence(tester, '5÷0=');
      await tapSequence(tester, '+');
      await tapSequence(tester, '7');
      expect(resultText(tester), '7');
      expect(find.textContaining('+ 7'), findsNothing);
    });

    testWidgets('shows the running total, not an error, mid-calculation (D-79)', (
      tester,
    ) async {
      await pumpCalculator(tester);

      // The user is still typing the divisor; Error belongs to the finished `=`.
      await tapSequence(tester, '5÷0');
      expect(resultText(tester), '5');

      await tapSequence(tester, '=');
      expect(resultText(tester), 'Error');
    });

    testWidgets('computes left to right and groups the result (D-17, D-18)', (
      tester,
    ) async {
      await pumpCalculator(tester);

      await tapSequence(tester, '2+3×4=');
      expect(resultText(tester), '20');

      await tapSequence(tester, 'AC');
      await tapSequence(tester, '125×8=');
      expect(resultText(tester), '1,000');
    });

    testWidgets('reproduces the mockup chain on screen', (tester) async {
      await pumpCalculator(tester);

      await tapSequence(tester, '100+7+49+450+10=');
      expect(resultText(tester), '616');
      expect(find.text('100 + 7 + 49 + 450 + 10'), findsOneWidget);
    });

    testWidgets('AC clears both lines', (tester) async {
      await pumpCalculator(tester);

      await tapSequence(tester, '125×8=');
      expect(resultText(tester), '1,000');

      await tapSequence(tester, 'AC');
      expect(resultText(tester), '0');
      expect(find.text('125 × 8'), findsNothing);
    });

    testWidgets('division by zero shows Error, not a crash (AC-010)', (
      tester,
    ) async {
      await pumpCalculator(tester);

      await tapSequence(tester, '5÷0=');
      expect(resultText(tester), 'Error');
      expect(find.text('5 ÷ 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('recovers from an error on the next digit', (tester) async {
      await pumpCalculator(tester);

      await tapSequence(tester, '5÷0=');
      await tapSequence(tester, '7');
      expect(resultText(tester), '7');
    });

    testWidgets('percent and sign toggle both reach the display', (
      tester,
    ) async {
      await pumpCalculator(tester);

      await tapSequence(tester, '50%');
      expect(resultText(tester), '0.5');

      await tapSequence(tester, 'AC');
      await tapSequence(tester, '5±');
      expect(resultText(tester), '-5');
    });

    testWidgets('a leading zero is replaced rather than accumulated', (
      tester,
    ) async {
      await pumpCalculator(tester);

      await tapSequence(tester, '05');
      expect(resultText(tester), '5');
    });
  });

  group('display sizing', () {
    testWidgets('steps the result down a size when the value gets long', (
      tester,
    ) async {
      await pumpCalculator(tester);

      // Short value: the large hero style.
      await tapSequence(tester, '123');
      final large = tester.widget<Text>(
        find.byKey(const Key('calculator-display-line')),
      );
      expect(large.style?.fontSize, 60);

      // Long value: one step down, and still fully visible.
      await tapSequence(tester, 'AC');
      await tapSequence(tester, '123456789012');
      final compact = tester.widget<Text>(
        find.byKey(const Key('calculator-display-line')),
      );
      expect(compact.style?.fontSize, 44);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a very long value still fits without clipping', (
      tester,
    ) async {
      await pumpCalculator(tester, surface: smallPhoneSize);

      await tapSequence(tester, '99999999999999');
      expect(resultText(tester), '99,999,999,999,999');
      expect(tester.takeException(), isNull);
    });
  });

  group('backspace after a calculation (D-81)', () {
    Finder backspace() => find.byKey(const Key('calculator-backspace'));

    /// Whether the control is live, read from the action rather than the pixels:
    /// a control that greyed itself out instead of acting is exactly the bug.
    bool isEnabled(WidgetTester tester) =>
        tester.widget<AppIconButton>(backspace()).onPressed != null;

    Future<void> tapBackspace(WidgetTester tester) async {
      await tester.tap(backspace());
      await tester.pump();
    }

    testWidgets('it reopens the expression behind a result', (
      tester,
    ) async {
      await pumpCalculator(tester);

      await tapSequence(tester, '125×8=');
      expect(resultText(tester), '1,000');
      expect(expressionText(tester), '125 × 8');

      // Before the fix the control cleared the expression here and shredded the
      // result instead, so the `8` could never be corrected.
      expect(isEnabled(tester), isTrue);

      await tapBackspace(tester);
      expect(expressionText(tester), '125 ×');
      expect(resultText(tester), '125');

      await tapBackspace(tester);
      expect(expressionText(tester), '125');

      await tapBackspace(tester);
      expect(expressionText(tester), '');
      expect(resultText(tester), '12');

      await tapBackspace(tester);
      expect(resultText(tester), '1');
    });

    testWidgets('the worked example: 900+100= then backspace', (
      tester,
    ) async {
      await pumpCalculator(tester);

      await tapSequence(tester, '900+100=');
      expect(resultText(tester), '1,000');

      // The expression comes back one character at a time, and the output line
      // previews what `=` would now give.
      await tapBackspace(tester);
      expect(expressionText(tester), '900 + 10');
      expect(resultText(tester), '910');

      await tapBackspace(tester);
      expect(expressionText(tester), '900 + 1');
      expect(resultText(tester), '901');

      await tapBackspace(tester);
      expect(expressionText(tester), '900 +');

      // The user is not trapped: the walk continues to `900` and into `90`.
      await tapBackspace(tester);
      expect(expressionText(tester), '900');
      expect(resultText(tester), '900');
      expect(isEnabled(tester), isTrue);

      await tapBackspace(tester);
      expect(resultText(tester), '90');
    });

    testWidgets('a digit after backspacing a result continues the operand', (
      tester,
    ) async {
      await pumpCalculator(tester);

      await tapSequence(tester, '125×8=');
      await tapBackspace(tester);
      expect(expressionText(tester), '125 ×');

      // The reopened operand is typed into, not replaced: `125 × 7` = `875`.
      await tapSequence(tester, '7');
      expect(expressionText(tester), '125 × 7');
      expect(resultText(tester), '875');
    });

    testWidgets('a digit after taking back an operator extends the number', (
      tester,
    ) async {
      await pumpCalculator(tester);

      await tapSequence(tester, '900+');
      await tapBackspace(tester);
      expect(expressionText(tester), '900');
      // Before the fix the control was dead here, and the next digit printed
      // itself beside the stale `900` (`900 5` over a result of `5`).
      expect(isEnabled(tester), isTrue);

      await tapSequence(tester, '5');
      expect(expressionText(tester), '');
      expect(resultText(tester), '9,005');
    });

    testWidgets('it still deletes a typed entry, a digit at a time', (
      tester,
    ) async {
      await pumpCalculator(tester);

      await tapSequence(tester, '123');
      await tapBackspace(tester);
      expect(resultText(tester), '12');

      await tapBackspace(tester);
      expect(resultText(tester), '1');

      // One more press empties the calculator and the control greys out,
      // rather than behaving like AC on a populated display.
      await tapBackspace(tester);
      expect(resultText(tester), '0');
      expect(isEnabled(tester), isFalse);
    });

    testWidgets('repeated backspace never crashes and ends empty', (
      tester,
    ) async {
      await pumpCalculator(tester);

      await tapSequence(tester, '900+10.5=');
      expect(isEnabled(tester), isTrue);

      // Pressing well past the end of the expression is harmless.
      for (var i = 0; i < 25; i++) {
        await tapBackspace(tester);
      }
      expect(tester.takeException(), isNull);
      expect(resultText(tester), '0');
      expect(expressionText(tester), '');
      expect(isEnabled(tester), isFalse);
    });

    testWidgets('backspace declines after division by zero', (
      tester,
    ) async {
      await pumpCalculator(tester);

      await tapSequence(tester, '5÷0=');
      expect(resultText(tester), 'Error');
      // `AC` is the documented way out of an error, so the control greys out
      // rather than pressing a key that would do nothing.
      expect(isEnabled(tester), isFalse);

      await tapSequence(tester, 'AC');
      expect(resultText(tester), '0');
      expect(expressionText(tester), '');
    });

    testWidgets('AC resets the calculator completely', (
      tester,
    ) async {
      await pumpCalculator(tester);

      await tapSequence(tester, '900+100=');
      await tapSequence(tester, 'AC');

      expect(expressionText(tester), '');
      expect(resultText(tester), '0');
      expect(isEnabled(tester), isFalse);

      // And it is a fresh calculator, not a display that kept the old value.
      await tapSequence(tester, '7=');
      expect(resultText(tester), '7');
    });
  });
}
