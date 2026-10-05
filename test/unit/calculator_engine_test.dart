import 'package:calculator/features/calculator/domain/calculator_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keypad_session.dart';

/// The expression line for a session keyed as a string.
String exprOf(String session) => apply(session).expression;

/// The value shown after a session keyed as a string.
double? valueOf(String session) => apply(session).value;

void main() {
  group('the () key decides open or close (D-85)', () {
    // The specification's table, row for row. A session types `()` where the
    // user presses the key, so this is the behaviour of the real keypad and not
    // a string the harness assembled behind its back.
    const table = <String, String>{
      '': '(',
      '5': '5×(',
      '5+': '5+(',
      '5×': '5×(',
      '()': '((',
      '()5': '(5)',
      '()5+': '(5+(',
      '()5+2': '(5+2)',
      '()5+2()': '(5+2)×(',
      '5+2': '5+2×(',
    };

    table.forEach((typed, expected) {
      test('`$typed` then () is `$expected`', () {
        expect(exprOf('$typed()'), expected);
      });
    });

    test('nests rather than closing early', () {
      expect(exprOf('()()'), '((');
    });

    test('closes as soon as the open group has an operand', () {
      expect(exprOf('()5()'), '(5)');
    });

    test('a % is a value, so the next () multiplies into a group', () {
      expect(exprOf('50%()'), '50%×(');
    });

    test('never emits two closing parentheses in a row', () {
      for (var seed = 0; seed < 40; seed++) {
        final engine = CalculatorEngine();
        for (var i = 0; i < seed; i++) {
          engine.apply(CalculatorKey.parentheses);
        }
        engine.apply(CalculatorKey.parentheses);
        expect(engine.state.expression.contains('))'), isFalse);
      }
    });
  });

  group('backspace removes exactly one character (D-81)', () {
    test('takes an operator off', () {
      expect(applyThenBackspace('900+', 1).expression, '900');
    });

    test('takes one digit at a time', () {
      expect(applyThenBackspace('900+100', 1).expression, '900+10');
      expect(applyThenBackspace('900+100', 2).expression, '900+1');
      expect(applyThenBackspace('900+100', 3).expression, '900+');
      expect(applyThenBackspace('900+100', 4).expression, '900');
    });

    test('walks the whole expression back to empty, never past it', () {
      final engine = CalculatorEngine();
      for (final key in keysFor('900+100')) {
        engine.apply(key);
      }
      for (var i = 0; i < 20; i++) {
        engine.backspace();
      }
      expect(engine.state.expression, isEmpty);
      expect(engine.state.canBackspace, isFalse);
    });

    test('works with decimals', () {
      expect(applyThenBackspace('1.5', 1).expression, '1.');
      expect(applyThenBackspace('1.5', 2).expression, '1');
    });

    test('works with parentheses', () {
      expect(applyThenBackspace('()5+5()', 1).expression, '(5+5');
      expect(applyThenBackspace('()5+5()', 2).expression, '(5+');
      expect(applyThenBackspace('()5+5()', 3).expression, '(5');
    });

    test('on an empty expression it costs nothing', () {
      final engine = CalculatorEngine()..backspace();
      expect(engine.state, CalculatorState.initial);
      expect(engine.state.canBackspace, isFalse);
    });

    test('updates the preview', () {
      expect(applyThenBackspace('900+100', 1).value, 910);
    });
  });

  group('backspace after equals restores the calculation (D-83)', () {
    test('the first press hands back the whole expression', () {
      expect(applyThenBackspace('900+100=', 1).expression, '900+100');
    });

    test('and leaves the calculator editable, not locked', () {
      final state = applyThenBackspace('900+100=', 1);
      expect(state.justEvaluated, isFalse);
      expect(state.isError, isFalse);
      expect(state.canBackspace, isTrue);
    });

    test('repeated backspace keeps working', () {
      expect(applyThenBackspace('900+100=', 2).expression, '900+10');
      expect(applyThenBackspace('900+100=', 3).expression, '900+1');
      expect(applyThenBackspace('900+100=', 4).expression, '900+');
    });

    test('a digit after restoring extends the expression again', () {
      final engine = CalculatorEngine();
      for (final key in keysFor('900+100=')) {
        engine.apply(key);
      }
      engine.backspace();
      engine.apply(CalculatorKey.digit5);
      expect(engine.state.expression, '900+1005');
    });

    test('the answer is still shown after the restore', () {
      expect(applyThenBackspace('900+100=', 1).value, 1000);
    });
  });

  group('AC resets everything (D-83)', () {
    test('from a completed calculation', () {
      final state = apply('125×8=AC');
      expect(state.expression, isEmpty);
      expect(state.value, isNull);
      expect(state.lastExpression, isNull);
      expect(state.lastValue, isNull);
      expect(state.justEvaluated, isFalse);
      expect(state.isError, isFalse);
      expect(state, CalculatorState.initial);
    });

    test('from an error', () {
      expect(apply('5÷0=AC'), CalculatorState.initial);
    });

    test('from an open parenthesis', () {
      expect(apply('()5+AC'), CalculatorState.initial);
    });
  });

  group('digits', () {
    test('a leading zero is replaced rather than accumulated', () {
      expect(exprOf('05'), '5');
      expect(exprOf('0.5'), '0.5');
      expect(exprOf('00'), '0');
    });

    test('type after an operator', () {
      expect(exprOf('5+2'), '5+2');
    });

    test('type after a closing parenthesis is refused', () {
      expect(exprOf('()5+5()2'), '(5+5)');
    });

    test('after equals a digit starts a new calculation', () {
      expect(exprOf('2+2=7'), '7');
    });

    test('a lone zero is preserved', () {
      expect(exprOf('0'), '0');
    });
  });

  group('the decimal point', () {
    test('completes a number', () {
      expect(exprOf('5.'), '5.');
    });

    test('is refused when the number already has one', () {
      expect(exprOf('5.2.'), '5.2');
    });

    test('starts 0. after an operator', () {
      expect(exprOf('5+.'), '5+0.');
    });

    test('starts 0. after a multiply', () {
      expect(exprOf('5×.'), '5×0.');
    });

    test('works inside parentheses', () {
      expect(exprOf('()5+.'), '(5+0.');
    });

    test('a lone decimal point starts a number', () {
      expect(exprOf('.'), '0.');
    });
  });

  group('operators', () {
    test('a pending operator is replaced, keeping the number', () {
      expect(exprOf('900+×'), '900×');
      expect(exprOf('900+−'), '900−');
    });

    test('one with nothing to its left is ignored', () {
      expect(exprOf('+'), isEmpty);
    });

    test('one after a closing parenthesis is allowed, so a group can be used', () {
      expect(exprOf('()5+5()×'), '(5+5)×');
      expect(valueOf('()5+5()×2='), 20);
    });

    test('after equals it continues from the result', () {
      expect(exprOf('900+100=+'), '1000+');
    });
  });

  group('percent (D-86)', () {
    test('divides by 100 under multiply', () {
      expect(valueOf('100×10%='), 10);
    });

    test('divides by 100 on its own', () {
      expect(valueOf('50%='), 0.5);
    });

    test('is a share of the left operand under add', () {
      expect(valueOf('200+10%='), 220);
    });

    test('is a share of the left operand under subtract', () {
      expect(valueOf('200−10%='), 180);
    });

    test('works inside parentheses', () {
      expect(valueOf('()200+10%='), 220);
      expect(valueOf('()50+50()%='), 1);
    });

    test('refuses to lead an expression', () {
      expect(exprOf('%'), isEmpty);
    });

    test('attaches to a group', () {
      expect(exprOf('()5+5()%'), '(5+5)%');
    });
  });

  group('parentheses calculate (D-84)', () {
    test('the specification examples', () {
      expect(valueOf('()5+5()='), 10);
      expect(valueOf('()5+5()×2='), 20);
      expect(valueOf('()10+5()÷3='), 5);
      expect(valueOf('2×()5+5()='), 20);
      expect(valueOf('()2+3()×()4+5()='), 45);
      expect(valueOf('()()2+3()×2='), 10);
    });

    test('precedence applies across the whole expression', () {
      expect(valueOf('2+3×4='), 14);
    });

    test('an unclosed group is completed by =', () {
      expect(valueOf('()5+5='), 10);
      expect(exprOf('()5+5'), '(5+5');
    });
  });

  group('equals and the result state', () {
    test('keeps the expression and the result apart', () {
      final state = apply('900+100=');
      expect(state.expression, '900+100');
      expect(state.value, 1000);
      expect(state.justEvaluated, isTrue);
      expect(state.lastExpression, '900+100');
      expect(state.lastValue, 1000);
    });

    test('a repeated equals changes nothing', () {
      expect(valueOf('2+2=='), 4);
    });

    test('division by zero reports the error state', () {
      final state = apply('5÷0=');
      expect(state.isError, isTrue);
      expect(state.justEvaluated, isFalse);
      expect(state.value, isNull);
    });

    test('an operator after a result continues from it', () {
      expect(exprOf('900+100=+'), '1000+');
    });

    test('a digit after a result starts over', () {
      expect(exprOf('900+100=5'), '5');
    });

    test('= on an untouched calculator does nothing', () {
      expect(apply('='), CalculatorState.initial);
    });

    test('an error clears on the next key', () {
      final state = apply('5÷0=7');
      expect(state.expression, '7');
      expect(state.isError, isFalse);
    });
  });

  group('error handling', () {
    test('division by zero never throws', () {
      expect(() => apply('5÷0='), returnsNormally);
    });

    test('an empty group errors rather than crashing', () {
      expect(() => apply('()()='), returnsNormally);
    });

    test('backspace is refused in the error state', () {
      expect(applyThenBackspace('5÷0=', 1).isError, isTrue);
    });

    test('a huge number is handled without throwing', () {
      expect(() => apply('999999999999999×999999999999999='), returnsNormally);
    });
  });

  group('loadValue (D-37)', () {
    test('puts the value on screen as a result', () {
      final engine = CalculatorEngine()..loadValue(1000);
      expect(engine.state.expression, '1000');
      expect(engine.state.value, 1000);
      expect(engine.state.justEvaluated, isTrue);
    });

    test('an operator continues from it', () {
      final engine = CalculatorEngine()..loadValue(1000);
      engine.apply(CalculatorKey.add);
      expect(engine.state.expression, '1000+');
    });

    test('a digit starts a fresh calculation', () {
      final engine = CalculatorEngine()..loadValue(1000);
      engine.apply(CalculatorKey.digit5);
      expect(engine.state.expression, '5');
    });

    test('it discards whatever was on the keypad', () {
      final engine = CalculatorEngine();
      for (final key in keysFor('125×8')) {
        engine.apply(key);
      }
      engine.loadValue(1000);
      expect(engine.state.expression, '1000');
    });

    test('a non-finite value is ignored', () {
      final engine = CalculatorEngine()..loadValue(double.infinity);
      expect(engine.state, CalculatorState.initial);
    });
  });

  group('the state snapshot', () {
    test('compares by content', () {
      expect(apply('1+1'), apply('1+1'));
      expect(apply('1+1'), isNot(apply('1+2')));
    });

    test('an old reference cannot observe later presses', () {
      final engine = CalculatorEngine();
      final first = engine.apply(CalculatorKey.digit5);
      engine.apply(CalculatorKey.digit5);
      expect(first.expression, '5');
    });

    test('copyWith replaces only what it names', () {
      final state = apply('5+5');
      expect(state.copyWith(isError: true).expression, '5+5');
      expect(state.copyWith(isError: true).isError, isTrue);
    });

    test('canBackspace mirrors the expression', () {
      expect(CalculatorState.initial.canBackspace, isFalse);
      expect(apply('5').canBackspace, isTrue);
      expect(apply('5÷0=').canBackspace, isFalse);
    });
  });

  group('justEvaluated (D-35)', () {
    test('is set only by =', () {
      expect(apply('1+1').justEvaluated, isFalse);
      expect(apply('1+1=').justEvaluated, isTrue);
    });

    test('is cleared by the next key', () {
      expect(apply('1+1=5').justEvaluated, isFalse);
    });

    test('an error never sets it, so nothing is recorded', () {
      expect(apply('5÷0=').justEvaluated, isFalse);
    });
  });

  group('the keypad', () {
    test('has no backspace key', () {
      expect(
        CalculatorKey.values.map((k) => k.name),
        isNot(contains('backspace')),
      );
      expect(CalculatorKey.ac.label, 'AC');
    });

    test('covers the 5x4 keypad, with () where the sign toggle used to be', () {
      expect(CalculatorKey.values.map((k) => k.label).toSet(), {
        '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
        '.',
        'AC', '%', '()',
        '+', '−', '×', '÷', '=',
      });
    });

    test('the parentheses key has an accessible name', () {
      expect(CalculatorKey.parentheses.semanticsLabel, 'parentheses');
    });

    test('maps the four operator keys to operators', () {
      expect(CalculatorKey.add.operator, CalculatorOperator.add);
      expect(CalculatorKey.subtract.operator, CalculatorOperator.subtract);
      expect(CalculatorKey.multiply.operator, CalculatorOperator.multiply);
      expect(CalculatorKey.divide.operator, CalculatorOperator.divide);
      expect(CalculatorKey.parentheses.operator, isNull);
    });
  });

  group('formatNumber', () {
    test('renders integers without a decimal point', () {
      expect(formatNumber(0), '0');
      expect(formatNumber(616), '616');
      expect(formatNumber(-42), '-42');
    });

    test('trims trailing zeros rather than padding', () {
      expect(formatNumber(4), '4');
      expect(formatNumber(4.50), '4.5');
    });

    test('returns Error for non-finite values', () {
      expect(formatNumber(double.infinity), 'Error');
      expect(formatNumber(double.nan), 'Error');
    });
  });
}
