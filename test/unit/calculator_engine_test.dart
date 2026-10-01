import 'package:calculator/features/calculator/domain/calculator_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keypad_session.dart';

/// The numbers the engine has committed, oldest first. Asserting on the term
/// list rather than a rendered string keeps this file independent of
/// `resolveDisplay`, which `calculator_display_test.dart` covers.
List<String> textsOf(CalculatorState state) =>
    state.terms.map((term) => term.text).toList();

/// The operator that introduced each committed term; `null` for the first.
List<String?> operatorsOf(CalculatorState state) =>
    state.terms.map((term) => term.operatorBefore).toList();

void main() {
  group('CalculatorKey', () {
    test('exposes a label and an accessible name for every key', () {
      for (final key in CalculatorKey.values) {
        expect(key.label, isNotEmpty, reason: '$key has no visible label');
        expect(
          key.semanticsLabel,
          isNotEmpty,
          reason: '$key has no semantics label',
        );
      }
    });

    test('has no backspace key', () {
      // D-19: the mockup and the specification show AC only, no ⌫.
      expect(
        CalculatorKey.values.map((k) => k.name),
        isNot(contains('backspace')),
      );
      expect(CalculatorKey.ac.label, 'AC');
    });

    test('covers the 5x4 keypad from desing.md §6.1', () {
      final labels = CalculatorKey.values.map((k) => k.label).toSet();
      expect(
        labels,
        {
          '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
          '.',
          'AC', '%', '±',
          '+', '−', '×', '÷', '=',
        },
      );
    });

    test('identifies digits and their values', () {
      expect(CalculatorKey.digit7.isDigit, isTrue);
      expect(CalculatorKey.digit7.digitValue, 7);
      expect(CalculatorKey.dot.isDigit, isFalse);
      expect(CalculatorKey.ac.isDigit, isFalse);
    });

    test('maps the four operator keys to operators', () {
      expect(CalculatorKey.add.operator, CalculatorOperator.add);
      expect(CalculatorKey.subtract.operator, CalculatorOperator.subtract);
      expect(CalculatorKey.multiply.operator, CalculatorOperator.multiply);
      expect(CalculatorKey.divide.operator, CalculatorOperator.divide);
      expect(CalculatorKey.equals.operator, isNull);
      expect(CalculatorKey.ac.operator, isNull);
    });
  });

  group('CalculatorOperator', () {
    test('uses the glyphs from the mockup', () {
      expect(CalculatorOperator.add.symbol, '+');
      expect(CalculatorOperator.subtract.symbol, '−'); // U+2212 minus
      expect(CalculatorOperator.multiply.symbol, '×'); // U+00D7 times
      expect(CalculatorOperator.divide.symbol, '÷'); // U+00F7 divide
    });

    test('applies each arithmetic operation', () {
      expect(CalculatorOperator.add.apply(2, 3), 5);
      expect(CalculatorOperator.subtract.apply(2, 3), -1);
      expect(CalculatorOperator.multiply.apply(2, 3), 6);
      expect(CalculatorOperator.divide.apply(6, 3), 2);
    });
  });

  group('formatNumber', () {
    test('renders integers without a decimal point', () {
      expect(formatNumber(0), '0');
      expect(formatNumber(616), '616');
      expect(formatNumber(-42), '-42');
    });

    test('trims trailing zeros rather than padding to decimalPlaces', () {
      // D-14: decimalPlaces controls rounding precision only, so a whole
      // number stays `4` and is never displayed as `4.00`.
      expect(formatNumber(4), '4');
      expect(formatNumber(4.50), '4.5');
      expect(formatNumber(0.5), '0.5');
    });

    test('falls back to scientific notation for extreme magnitudes', () {
      // `toStringAsPrecision` emits an explicit exponent sign, e.g. `1e+21`.
      final formatted = formatNumber(1e21);
      expect(formatted, contains('e'));
      expect(formatted, endsWith('21'));
    });

    test('returns Error for non-finite values', () {
      expect(formatNumber(double.infinity), 'Error');
      expect(formatNumber(double.nan), 'Error');
    });
  });

  group('CalculatorEngine — digit input', () {
    test('starts empty, with nothing computed and no error', () {
      final state = CalculatorEngine().state;
      expect(state, CalculatorState.initial);
      expect(state.terms, isEmpty);
      expect(state.entry, isNull);
      expect(state.value, isNull);
      expect(state.currentValue, isNull);
      expect(state.isError, isFalse);
    });

    test('appends digits to the entry being typed', () {
      final state = apply('125');
      expect(state.entry, '125');
      expect(state.currentValue, 125);
    });

    test('replaces a leading zero rather than extending it', () {
      // FEAT-CALC-001 validation: leading zeros are handled, not accumulated.
      expect(apply('0').entry, '0');
      expect(apply('05').entry, '5');
      expect(apply('105').entry, '105');
    });

    test('keeps the lone zero and 0. so 0.5 is reachable', () {
      expect(applyKeys([CalculatorKey.digit0, ...keysFor('.5')]).entry, '0.5');
    });

    test('starts a decimal entry at 0.', () {
      expect(apply('.5').entry, '0.5');
    });

    test('ignores a second decimal point in the same number', () {
      expect(apply('1.5.5').entry, '1.55');
    });

    test('caps the number of digits in one entry', () {
      final state = applyKeys(List<CalculatorKey>.filled(
        CalculatorEngine.maxEntryDigits + 5,
        CalculatorKey.digit9,
      ));
      expect(
        state.entry!.length,
        CalculatorEngine.maxEntryDigits,
      );
    });

    test('starts a new entry once an operator has been pressed', () {
      final state = apply('1+2');
      expect(state.entry, '2');
      expect(state.value, 1);
    });
  });

  group('CalculatorEngine — operators and left-to-right folding', () {
    test('folds each operator as it is pressed, with no precedence', () {
      // D-17: 2 + 3 × 4 is 20, not 14.
      expect(apply('2+3×4=').value, 20);
    });

    test('shows the running total while the next entry is typed', () {
      final state = apply('100+7');
      expect(state.value, 100);
      expect(state.entry, '7');
      // The operator stays pending until the operand after it is complete, so
      // the expression line reads `100 +` while `7` is being typed.
      expect(state.pendingOperator, CalculatorOperator.add);
    });

    test('appends the pending operator to the expression, not the terms', () {
      final state = apply('100+');
      expect(textsOf(state), ['100']);
      expect(state.pendingOperator, CalculatorOperator.add);
      expect(state.value, 100);
    });

    test('reproduces the mockup chain: 100 + 7 + 49 + 450 + 10 = 616', () {
      final state = apply('100+7+49+450+10=');
      expect(state.value, 616);
      expect(textsOf(state), ['100', '7', '49', '450', '10']);
      expect(operatorsOf(state), [null, '+', '+', '+', '+']);
      expect(state.pendingOperator, isNull);
    });

    test('125 × 8 = 1000, the history-card example in feature.md', () {
      final state = apply('125×8=');
      expect(state.value, 1000);
      expect(textsOf(state), ['125', '8']);
      expect(operatorsOf(state), [null, '×']);
    });

    test('each of the four operations is correct', () {
      expect(apply('7+3=').value, 10);
      expect(apply('7-3=').value, 4);
      expect(apply('7×3=').value, 21);
      expect(apply('7÷2=').value, 3.5);
    });

    test('a chain of mixed operators folds strictly left to right', () {
      // 1 − 2 = −1, then × 3 = −3, then + 10 = 7.
      expect(apply('1-2×3+10=').value, 7);
    });

    test('replaces the pending operator when two are pressed in a row', () {
      final state = apply('2+3×-');
      expect(state.pendingOperator, CalculatorOperator.subtract);
      expect(textsOf(state), ['2', '3']);
      expect(operatorsOf(state), [null, '+']);
      expect(state.value, 5);
    });

    test('records the minus glyph as U+2212, not a hyphen', () {
      final state = apply('5-2=');
      expect(operatorsOf(state), [null, '−']);
      expect(state.value, 3);
    });

    test('equals on a lone number just shows it', () {
      final state = apply('42=');
      expect(state.value, 42);
      expect(textsOf(state), ['42']);
      expect(state.pendingOperator, isNull);
    });

    test('equals on an untouched calculator does nothing', () {
      expect(apply('='), CalculatorState.initial);
    });

    test('a trailing operator repeats the running value rather than erroring', () {
      // D-31. feature.md's "malformed expression → Error" is read as covering
      // genuinely unevaluable input; a trailing operator is near-universal
      // shorthand for reusing the accumulator.
      final state = apply('2+=');
      expect(state.value, 4);
      expect(state.isError, isFalse);
      expect(state.pendingOperator, isNull);
    });
  });

  group('CalculatorEngine — after equals', () {
    test('a digit starts a fresh calculation', () {
      final state = apply('125×8=7');
      expect(state.terms, isEmpty);
      expect(state.entry, '7');
      expect(state.value, isNull);
    });

    test('a decimal point also starts a fresh calculation', () {
      final state = apply('125×8=.');
      expect(state.terms, isEmpty);
      expect(state.entry, '0.');
    });

    test('an operator continues from the result', () {
      final state = apply('125×8=+');
      expect(state.value, 1000);
      expect(state.pendingOperator, CalculatorOperator.add);
      expect(textsOf(state), ['1000']);
    });

    test('a second equals on the same result changes nothing', () {
      expect(apply('8×8==').value, 64);
    });

    test('the completed chain stays on the expression line', () {
      final state = apply('9+1=');
      expect(textsOf(state), ['9', '1']);
      expect(state.pendingOperator, isNull);
    });

    test('continuing after a result chains from the new value', () {
      final state = apply('125×8=+2=');
      expect(state.value, 1002);
      expect(textsOf(state), ['1000', '2']);
      expect(operatorsOf(state), [null, '+']);
    });
  });

  group('CalculatorEngine — percent', () {
    test('divides the number being typed by 100', () {
      // D-06.
      final state = apply('50%');
      expect(state.entry, '0.5');
      expect(state.currentValue, 0.5);
    });

    test('divides a computed result by 100', () {
      final state = apply('8×8=%');
      expect(state.value, 0.64);
    });

    test('never reinterprets the percentage against the accumulator', () {
      // D-06: 200 + 10 % adds 0.1, not 20.
      expect(apply('200+10%=').value, closeTo(200.1, 1e-9));
    });

    test('50 % = evaluates to 0.5', () {
      final state = apply('50%=');
      expect(state.value, 0.5);
    });

    test('does nothing when there is no number to act on', () {
      expect(apply('%'), CalculatorState.initial);
    });
  });

  group('CalculatorEngine — sign toggle', () {
    test('negates the number being typed and can negate it back', () {
      expect(apply('5±').entry, '-5');
      expect(apply('5±±').entry, '5');
      expect(apply('5±').currentValue, -5);
    });

    test('negates a fractional entry', () {
      expect(apply('1.5±').entry, '-1.5');
    });

    test('never produces negative zero', () {
      final state = apply('0±');
      expect(state.entry, '0');
      expect(state.currentValue, 0);
    });

    test('negates a computed result in place', () {
      final state = apply('8×8=±');
      expect(state.value, -64);
    });

    test('a negated entry still folds correctly', () {
      // `5 × ±3 =` — the sign is applied to the entry, so this is 5 × −3.
      expect(apply('5×3±=').value, -15);
    });

    test('does nothing when there is no number to act on', () {
      expect(apply('±'), CalculatorState.initial);
    });
  });

  group('CalculatorEngine — errors', () {
    test('division by zero reports Error on equals', () {
      final state = apply('5÷0=');
      expect(state.isError, isTrue);
      expect(state.value, isNull);
      expect(textsOf(state), ['5', '0']);
    });

    test('division by zero reports Error as soon as the fold is applied', () {
      // The pending operator is applied when its right operand is committed,
      // which is the next operator press, not the last digit (D-17).
      final state = apply('5÷0×');
      expect(state.isError, isTrue);
      expect(textsOf(state), ['5', '0']);
    });

    test('is not in error before the invalid fold happens', () {
      final state = apply('5÷0');
      expect(state.isError, isFalse);
      expect(state.entry, '0');
      expect(state.value, 5);
    });

    test('0 ÷ 0 reports Error, covering NaN as well as infinity', () {
      expect(apply('0÷0=').isError, isTrue);
    });

    test('a digit after an error starts a fresh calculation', () {
      final state = apply('5÷0=');
      expect(state.isError, isTrue);

      final recovered = apply('5÷0=7');
      expect(recovered.isError, isFalse);
      expect(recovered.entry, '7');
      expect(recovered.terms, isEmpty);
    });

    test('an operator after an error dismisses it and starts over', () {
      final state = apply('5÷0=+');
      expect(state.isError, isFalse);
      expect(state.terms, isEmpty);
      expect(state.entry, isNull);
      expect(state.value, isNull);
      expect(state.pendingOperator, CalculatorOperator.add);
    });

    test('the unary keys leave an error state untouched', () {
      for (final key in keysFor('%±=')) {
        final state = applyKeys([...keysFor('5÷0='), key]);
        expect(
          state.isError,
          isTrue,
          reason: '${key.label} should not clear an error',
        );
      }
    });
  });

  group('CalculatorEngine — all clear', () {
    test('clears both lines and all internal state', () {
      expect(apply('125×8AC'), CalculatorState.initial);
    });

    test('clears an error state', () {
      expect(apply('5÷0=AC'), CalculatorState.initial);
    });

    test('reset() has the same effect as the AC key', () {
      final engine = CalculatorEngine()
        ..apply(CalculatorKey.digit9)
        ..reset();
      expect(engine.state, CalculatorState.initial);
    });
  });

  group('CalculatorEngine — the state snapshot', () {
    test('is immutable, so an old reference cannot observe later presses', () {
      final engine = CalculatorEngine();
      final before = engine.apply(CalculatorKey.digit1);
      final after = engine.apply(CalculatorKey.digit2);
      expect(before.entry, '1');
      expect(after.entry, '12');
      expect(identical(before.terms, after.terms), isFalse);
    });

    test('compares by content rather than identity', () {
      final engine = CalculatorEngine()..apply(CalculatorKey.digit1);
      expect(
        engine.state,
        const CalculatorState(
          terms: <CalculatorExpressionTerm>[],
          entry: '1',
        ),
      );
    });

    test('terms are exposed as an unmodifiable list', () {
      final engine = CalculatorEngine()..apply(CalculatorKey.digit1);
      expect(
        () => engine.state.terms.add(
          const CalculatorExpressionTerm('9'),
        ),
        throwsUnsupportedError,
      );
    });

    test('copyWith replaces only the named fields', () {
      const state = CalculatorState(entry: '1', isError: true);
      final updated = state.copyWith(entry: '2');
      expect(updated.entry, '2');
      expect(updated.isError, isTrue);
    });
  });

  group('CalculatorEngine — justEvaluated (D-35)', () {
    test('is false on the initial state', () {
      expect(CalculatorState.initial.justEvaluated, isFalse);
    });

    test('is set by = and is the only thing that sets it', () {
      final engine = CalculatorEngine();
      for (final key in [
        CalculatorKey.digit2,
        CalculatorKey.add,
        CalculatorKey.digit3,
        CalculatorKey.multiply,
        CalculatorKey.digit4,
      ]) {
        engine.apply(key);
        expect(
          engine.state.justEvaluated,
          isFalse,
          reason: '$key is not a completed evaluation',
        );
      }
      expect(engine.apply(CalculatorKey.equals).justEvaluated, isTrue);
    });

    test('is a one-shot flag cleared by the next key', () {
      final engine = CalculatorEngine()
        ..apply(CalculatorKey.digit2)
        ..apply(CalculatorKey.add)
        ..apply(CalculatorKey.digit2)
        ..apply(CalculatorKey.equals);
      expect(engine.state.justEvaluated, isTrue);

      engine.apply(CalculatorKey.digit5);
      expect(engine.state.justEvaluated, isFalse);
    });

    test('a bare = on a fresh calculator records nothing', () {
      final engine = CalculatorEngine()..apply(CalculatorKey.equals);
      expect(engine.state.justEvaluated, isFalse);
      expect(engine.state.value, isNull);
    });

    test('is cleared by %, so 2 + 2 = % cannot record twice', () {
      // The regression this guards: % and ± transform a result without
      // completing a new one, so history must not save a second entry for the
      // same calculation.
      final engine = CalculatorEngine()
        ..apply(CalculatorKey.digit2)
        ..apply(CalculatorKey.add)
        ..apply(CalculatorKey.digit2)
        ..apply(CalculatorKey.equals);
      expect(engine.apply(CalculatorKey.percent).justEvaluated, isFalse);

      final other = CalculatorEngine()
        ..apply(CalculatorKey.digit2)
        ..apply(CalculatorKey.add)
        ..apply(CalculatorKey.digit2)
        ..apply(CalculatorKey.equals);
      expect(other.apply(CalculatorKey.plusMinus).justEvaluated, isFalse);
    });

    test('is cleared by an error, so a failed calculation is never recorded', () {
      final engine = CalculatorEngine()
        ..apply(CalculatorKey.digit2)
        ..apply(CalculatorKey.add)
        ..apply(CalculatorKey.digit2)
        ..apply(CalculatorKey.equals);
      expect(engine.state.justEvaluated, isTrue);

      // A digit starts fresh from the result, then 5 ÷ 0 fails.
      engine
        ..apply(CalculatorKey.digit5)
        ..apply(CalculatorKey.divide)
        ..apply(CalculatorKey.digit0);
      final failed = engine.apply(CalculatorKey.equals);

      expect(failed.isError, isTrue);
      expect(failed.justEvaluated, isFalse);
    });

    test('2 + = is recorded as a completed evaluation (D-36)', () {
      // D-31 makes the repeat resolve to 4. D-36 records it rather than
      // special-casing an operator the engine already handled.
      final state = apply('2+=');
      expect(state.value, 4);
      expect(state.justEvaluated, isTrue);
    });

    test('participates in equality and copyWith', () {
      const base = CalculatorState(value: 4);
      expect(base, const CalculatorState(value: 4));
      expect(
        base,
        isNot(const CalculatorState(value: 4, justEvaluated: true)),
      );
      expect(
        const CalculatorState(value: 4).copyWith(justEvaluated: true),
        const CalculatorState(value: 4, justEvaluated: true),
      );
    });
  });

  group('CalculatorEngine — loadValue (D-37)', () {
    test('puts the value on screen as a completed result', () {
      final engine = CalculatorEngine()..loadValue(1000);
      final state = engine.state;

      expect(state.value, 1000);
      expect(state.justEvaluated, isTrue);
      expect(state.isError, isFalse);
      expect(state.entry, isNull);
      // No terms, so the expression line stays blank rather than repeating the
      // number the primary line already shows.
      expect(state.terms, isEmpty);
    });

    test('discards whatever was on the keypad', () {
      final engine = CalculatorEngine()
        ..apply(CalculatorKey.digit7)
        ..apply(CalculatorKey.add)
        ..apply(CalculatorKey.digit7);
      expect(engine.state.pendingOperator, CalculatorOperator.add);

      engine.loadValue(5);
      expect(engine.state.terms, isEmpty);
      expect(engine.state.pendingOperator, isNull);
      expect(engine.state.value, 5);
    });

    test('an operator continues from the loaded value', () {
      // The same path `125 × 8 =` then `+` already takes, so loading a history
      // item behaves like a result the user just produced.
      final engine = CalculatorEngine()..loadValue(1000);
      final state = engine.apply(CalculatorKey.add);

      expect(textsOf(state), ['1000']);
      expect(state.pendingOperator, CalculatorOperator.add);
      expect(state.value, 1000);
    });

    test('a digit starts a fresh calculation from the loaded value', () {
      final engine = CalculatorEngine()..loadValue(1000);
      final state = engine.apply(CalculatorKey.digit5);

      expect(state.entry, '5');
      expect(state.terms, isEmpty);
    });

    test('= after loading a value yields the value unchanged', () {
      final engine = CalculatorEngine()..loadValue(42);
      expect(engine.apply(CalculatorKey.equals).value, 42);
    });

    test('ignores a non-finite value', () {
      final engine = CalculatorEngine()..loadValue(double.infinity);
      expect(engine.state, CalculatorState.initial);
    });

    test('a non-finite load leaves existing state untouched', () {
      final engine = CalculatorEngine()..apply(CalculatorKey.digit7);
      engine.loadValue(double.nan);
      expect(engine.state.entry, '7');
    });
  });
}
