import 'package:calculator/core/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

/// `groupThousands` backs the number formatter required by D-18, so the cases
/// below lock in the behaviour the Phase 3 formatter will depend on.
void main() {
  group('groupThousands', () {
    test('leaves values under one thousand untouched', () {
      expect(groupThousands('0'), '0');
      expect(groupThousands('7'), '7');
      expect(groupThousands('999'), '999');
    });

    test('inserts a separator every three integer digits', () {
      expect(groupThousands('1000'), '1,000');
      expect(groupThousands('1234'), '1,234');
      expect(groupThousands('1234567'), '1,234,567');
      expect(groupThousands('1000000000'), '1,000,000,000');
    });

    test('keeps the fractional part intact', () {
      expect(groupThousands('1234.89'), '1,234.89');
      expect(groupThousands('1234567.89'), '1,234,567.89');
      expect(groupThousands('1000.5'), '1,000.5');
    });

    test('handles negatives', () {
      expect(groupThousands('-1234'), '-1,234');
      expect(groupThousands('-1234567.89'), '-1,234,567.89');
    });

    test('returns non-numeric values unchanged', () {
      expect(groupThousands(''), '');
      expect(groupThousands('Error'), 'Error');
      expect(groupThousands('1e21'), '1e21');
      expect(groupThousands('abc'), 'abc');
    });
  });

  group('formatResult', () {
    test('rounds to decimalPlaces without padding (D-21)', () {
      // The setting is rounding precision, not a fixed number of decimals, so
      // a whole result must never acquire a decimal point.
      expect(formatResult(4, decimalPlaces: 2), '4');
      expect(formatResult(2 + 2), '4');
      expect(formatResult(4.5), '4.5');
      expect(formatResult(1 / 3), '0.33');
      expect(formatResult(2 / 3), '0.67');
      expect(formatResult(0.129, decimalPlaces: 2), '0.13');
      expect(formatResult(0.129, decimalPlaces: 4), '0.129');
      expect(formatResult(0.129, decimalPlaces: 0), '0');
    });

    test('inserts thousands separators (D-18)', () {
      expect(formatResult(1000), '1,000');
      expect(formatResult(125 * 8), '1,000');
      expect(formatResult(1234567), '1,234,567');
      expect(formatResult(1234567.89), '1,234,567.89');
      expect(formatResult(1234.5), '1,234.5');
    });

    test('keeps the sign outside the separators', () {
      expect(formatResult(-1234), '-1,234');
      expect(formatResult(-1234567.89), '-1,234,567.89');
    });

    test('defaults to two decimal places', () {
      expect(formatResult(1 / 3), '0.33');
      expect(formatResult(1 / 8), '0.13');
    });

    test('treats a negative precision as zero rather than throwing', () {
      expect(formatResult(1.6, decimalPlaces: -3), '2');
    });

    test('returns Error for non-finite values', () {
      expect(formatResult(double.infinity), 'Error');
      expect(formatResult(double.negativeInfinity), 'Error');
      expect(formatResult(double.nan), 'Error');
    });

    test('does not overflow with digits on extreme magnitudes', () {
      // formatNumber switches to scientific notation past 12 significant
      // digits, and the separator layer leaves that form alone.
      final formatted = formatResult(1e21);
      expect(formatted, contains('e'));
      expect(formatted, isNot(contains(',')));
    });

    test('is stable across the float noise a calculator accumulates', () {
      // 0.1 + 0.2 is 0.30000000000000004 in binary floating point; the result
      // must still read 0.3 rather than exposing the representation error.
      expect(formatResult(0.1 + 0.2), '0.3');
    });
  });
}
