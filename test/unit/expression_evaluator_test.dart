import 'package:calculator/features/calculator/domain/expression_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Evaluates [expression] exactly as it stands, failing the test if it cannot.
double valueOf(String expression) {
  final result = ExpressionEvaluator.evaluate(expression);
  expect(
    result.status,
    EvaluationStatus.success,
    reason: '`$expression` should evaluate: $result',
  );
  return result.value!;
}

/// The status [expression] evaluates to, with no repair applied.
EvaluationStatus statusOf(String expression) =>
    ExpressionEvaluator.evaluate(expression).status;

/// The number `=` would produce for [expression], closing what is unfinished.
double? autoClosed(String expression) =>
    ExpressionEvaluator.evaluate(expression, autoClose: true).value;

void main() {
  group('precedence (D-84, supersedes D-17)', () {
    test('× and ÷ bind tighter than + and −', () {
      expect(valueOf('2+3×4'), 14);
      expect(valueOf('2×3+4'), 10);
      expect(valueOf('100−20×2'), 60);
      expect(valueOf('100÷5−10'), 10);
    });

    test('chains of one kind stay left to right', () {
      expect(valueOf('100+7+49+450+10'), 616);
      expect(valueOf('100−10−20'), 70);
      expect(valueOf('100÷5÷2'), 10);
      expect(valueOf('2×3×4'), 24);
    });

    test('the mockup chain from desing.md still comes out right', () {
      expect(valueOf('100+7+49+450+10'), 616);
    });
  });

  group('parentheses', () {
    test('groups a simple sum', () {
      expect(valueOf('(5+5)'), 10);
      expect(valueOf('(5+5)×2'), 20);
      expect(valueOf('(10+5)÷3'), 5);
      expect(valueOf('2×(5+5)'), 20);
    });

    test('groups two sums', () {
      expect(valueOf('(2+3)×(4+5)'), 45);
    });

    test('nests', () {
      expect(valueOf('((2+3)×2)'), 10);
      expect(valueOf('((1+2)×(3+4))−5'), 16);
      expect(valueOf('2×(3+(4×(5−1)))'), 38);
    });

    test('multiplies implicitly against a group', () {
      expect(valueOf('2(3+4)'), 14);
      expect(valueOf('(1+2)(3+4)'), 21);
      expect(valueOf('(3+4)2'), 14);
      expect(valueOf('(3+4)2'), 14);
      expect(valueOf('2×(3+4)'), 14);
    });

    test('respects precedence across a group boundary', () {
      expect(valueOf('(1+2)×3+4'), 13);
      expect(valueOf('1+2×(3+4)'), 15);
    });

    test('a group may carry a percentage', () {
      expect(valueOf('(50+50)%'), 1);
    });
  });

  group('percent is contextual (D-86, supersedes D-06)', () {
    test('divides by 100 under ×', () {
      expect(valueOf('100×10%'), 10);
    });

    test('divides by 100 when it stands alone', () {
      expect(valueOf('50%'), 0.5);
    });

    test('is a share of the left operand under +', () {
      expect(valueOf('200+10%'), 220);
    });

    test('is a share of the left operand under −', () {
      expect(valueOf('200−10%'), 180);
    });

    test('uses the accumulated total as the base of a chain', () {
      expect(valueOf('100+10%+10%'), 121);
    });

    test('divides by 100 under ÷', () {
      expect(valueOf('100÷10%'), 1000);
    });

    test('is not contextual when it is part of a product', () {
      // `10 % × 2` is 0.2, so this is 200.2 rather than 204 — the percentage is
      // bound to ×, not to the + above it.
      expect(valueOf('200+10%×2'), closeTo(200.2, 1e-9));
    });
  });

  group('negatives', () {
    test('a result may be negative', () {
      expect(valueOf('5−8'), -3);
      expect(valueOf('2×(1−4)'), -6);
      expect(valueOf('(5−8)×2'), -6);
    });

    test('a unary minus is parsed', () {
      expect(valueOf('5×−2'), -10);
      expect(valueOf('(5−−3)'), 8);
      expect(valueOf('−5+8'), 3);
    });
  });

  group('decimals', () {
    test('parses a decimal literal', () {
      expect(valueOf('1.5+1.5'), 3);
      expect(valueOf('0.1+0.2'), closeTo(0.3, 1e-9));
    });

    test('parses a trailing dot as the number being typed', () {
      expect(valueOf('5.'), 5);
      expect(valueOf('5.+5'), 10);
    });
  });
}
