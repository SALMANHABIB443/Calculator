import 'package:calculator/features/calculator/domain/calculator_engine.dart';
import 'package:calculator/features/calculator/presentation/display_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keypad_session.dart';

/// The two lines the calculator paints, for a session keyed as a string.
CalculatorDisplayState displayOf(String session, {int decimalPlaces = 2}) =>
    resolveDisplay(apply(session), decimalPlaces: decimalPlaces);

/// The expression line alone, for a session keyed as a string.
String expressionOf(String session) => resolveExpressionLine(apply(session));

void main() {
  group('resolveDisplay — the primary line', () {
    test('shows 0 before anything is keyed', () {
      final display = displayOf('');
      expect(display.result, '0');
      expect(display.expression, isEmpty);
      expect(display.isError, isFalse);
    });

    test('shows the number being typed, without rounding it', () {
      expect(displayOf('1').result, '1');
      expect(displayOf('1.23456').result, '1.23456');
    });

    test('groups the number being typed, since it is not yet a result', () {
      expect(displayOf('1000').result, '1,000');
    });

    test('rounds a computed result to decimalPlaces', () {
      expect(displayOf('1÷3=').result, '0.33');
      expect(displayOf('1÷3=', decimalPlaces: 4).result, '0.3333');
      expect(displayOf('1÷3=', decimalPlaces: 0).result, '0');
    });

    test('never pads trailing zeros', () {
      // D-21: rounding precision, not display width.
      expect(displayOf('2+2=').result, '4');
      expect(displayOf('2+2=', decimalPlaces: 4).result, '4');
      expect(displayOf('1.5+1.5=').result, '3');
    });

    test('applies thousands separators to a computed result', () {
      expect(displayOf('125×8=').result, '1,000');
      expect(displayOf('1234567+1=').result, '1,234,568');
    });

    test('groups a negative result too', () {
      expect(displayOf('1000±=').result, '-1,000');
    });
  });

  group('resolveDisplay — the secondary line', () {
    test('is blank while a single number is being typed', () {
      expect(displayOf('125').expression, isEmpty);
    });

    test('shows the operator once one is pressed', () {
      expect(displayOf('100+').expression, '100 +');
      expect(displayOf('100+7').expression, '100 +');
    });

    test('accumulates every term in a chain', () {
      expect(displayOf('100+7+49+450+10=').expression, '100 + 7 + 49 + 450 + 10');
    });

    test('groups each term independently of the operators', () {
      expect(displayOf('1000×8+').expression, '1,000 × 8 +');
    });

    test('drops the trailing operator once equals is pressed', () {
      expect(displayOf('125×8=').expression, '125 × 8');
    });

    test('collapses to the result when a chain is continued', () {
      expect(displayOf('125×8=+').expression, '1,000 +');
    });

    test('is blank again when a new calculation starts after equals', () {
      expect(displayOf('125×8=7').expression, isEmpty);
    });

    test('shows a lone pending operator without a leading space', () {
      // Reachable by pressing `+` on a fresh calculator.
      expect(displayOf('+').expression, '+');
    });

    test('keeps a negative sign in front of its term', () {
      expect(displayOf('5×3±=').expression, '5 × -3');
    });
  });

  group('resolveDisplay — the error state', () {
    test('shows Error and retains the expression', () {
      // desing.md §9.
      final display = displayOf('5÷0=');
      expect(display.result, 'Error');
      expect(display.expression, '5 ÷ 0');
      expect(display.isError, isTrue);
    });

    test('reports the error for 0 ÷ 0 as well', () {
      expect(displayOf('0÷0=').isError, isTrue);
    });

    test('clears once a new calculation starts', () {
      final display = displayOf('5÷0=7');
      expect(display.isError, isFalse);
      expect(display.result, '7');
      expect(display.expression, isEmpty);
    });
  });

  group('resolveDisplay — decimalPlaces is formatting-only', () {
    test('changing it re-renders a result without touching the calculation', () {
      // D-14. The engine state is the same object in both renders; only the
      // projection onto text changes.
      final state = apply('1÷3=');
      expect(
        resolveDisplay(state, decimalPlaces: 2).result,
        '0.33',
      );
      expect(
        resolveDisplay(state, decimalPlaces: 6).result,
        '0.333333',
      );
    });

    test('changing it never rewrites an entry the user is still typing', () {
      final state = apply('1.23456');
      for (final places in [0, 2, 6]) {
        expect(
          resolveDisplay(state, decimalPlaces: places).result,
          '1.23456',
          reason: 'a typed entry must not be rounded to $places places',
        );
      }
    });

    test('changing it does not disturb the expression line', () {
      final state = apply('1000×8+');
      expect(
        resolveDisplay(state, decimalPlaces: 0).expression,
        resolveDisplay(state, decimalPlaces: 8).expression,
      );
    });
  });

  group('resolveExpressionLine', () {
    // Extracted in Phase 5 so the history feature can record the same string
    // the display shows. These cases pin the behaviour the cards depend on.
    test('is blank while a single number is being typed', () {
      expect(expressionOf(''), isEmpty);
      expect(expressionOf('125'), isEmpty);
    });

    test('joins the terms with their operators', () {
      expect(expressionOf('2+2='), '2 + 2');
      expect(expressionOf('100+7+49+450+10='), '100 + 7 + 49 + 450 + 10');
    });

    test('appends an operator awaiting its operand', () {
      expect(expressionOf('2+'), '2 +');
      expect(expressionOf('1000×8+'), '1,000 × 8 +');
    });

    test('drops the pending operator once = is pressed', () {
      // Before `=`, `2 +` is waiting for an operand; after it, the same two
      // terms read as a finished sum with no trailing glyph.
      expect(expressionOf('2+'), '2 +');
      expect(expressionOf('2+2='), '2 + 2');
    });

    test('collapses to the result when the user continues from one', () {
      expect(expressionOf('125×8=+'), '1,000 +');
    });

    test('groups each number independently, leaving operators untouched', () {
      expect(expressionOf('1234567×8='), '1,234,567 × 8');
    });

    test('keeps a lone operator readable rather than leading with a space', () {
      expect(expressionOf('+'), '+');
    });

    test('keeps the failed expression so the user can see what broke', () {
      expect(expressionOf('5÷0='), '5 ÷ 0');
    });

    test('is blank for a value loaded from history (D-37)', () {
      // Loading must not print the number twice, and the history controller
      // resolves the expression line from the same state the display does.
      final engine = CalculatorEngine()..loadValue(1000);
      expect(resolveExpressionLine(engine.state), isEmpty);
    });
  });
}
