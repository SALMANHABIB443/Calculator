/// Unit coverage for [SecretCode] — the type that makes "four decimal digits"
/// unrepresentable rather than merely checked (D-83, AC-018).
library;

import 'package:calculator/features/secret/domain/secret_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a well-formed code', () {
    test('holds its digits', () {
      expect(SecretCode('1234').value, '1234');
    });

    test('keeps leading zeroes, which are digits and not padding', () {
      // `0001` and `0007` must not collapse to `1` or `7`: the stored value is
      // compared as a four-character string, so trimming would make a real code
      // unreachable.
      expect(SecretCode('0001').value, '0001');
      expect(SecretCode('0007').value, '0007');
    });

    test('is equal to another code with the same digits', () {
      expect(SecretCode('4321'), SecretCode('4321'));
      expect(SecretCode('4321').hashCode, SecretCode('4321').hashCode);
    });

    test('is not equal to a different code', () {
      expect(SecretCode('1234'), isNot(SecretCode('1235')));
    });
  });

  group('a malformed code', () {
    // The constructor is the guarantee: every one of these would otherwise be a
    // value in the system that the verifier, the storage key, and the comparison
    // all had to re-check.
    test('is rejected for being too short', () {
      expect(() => SecretCode('1'), throwsFormatException);
      expect(() => SecretCode('123'), throwsFormatException);
    });

    test('is rejected for being too long', () {
      expect(() => SecretCode('12345'), throwsFormatException);
    });

    test('is rejected for being empty', () {
      expect(() => SecretCode(''), throwsFormatException);
    });

    test('is rejected for holding non-digits', () {
      expect(() => SecretCode('12a4'), throwsFormatException);
      expect(() => SecretCode('    '), throwsFormatException);
      // A space is not a zero and a full-width digit is not a digit.
      expect(() => SecretCode('12 4'), throwsFormatException);
      expect(() => SecretCode('１２３４'), throwsFormatException);
    });

    test('is rejected for carrying a sign or a decimal point', () {
      expect(() => SecretCode('-123'), throwsFormatException);
      expect(() => SecretCode('12.4'), throwsFormatException);
    });
  });

  group('isWellFormed', () {
    // Exposed separately so a caller can *decide* before constructing — the
    // repository degrades on it, the tests seed on it.
    test('accepts exactly four digits', () {
      expect(SecretCode.isWellFormed('0000'), isTrue);
      expect(SecretCode.isWellFormed('9876'), isTrue);
    });

    test('rejects anything else, including null', () {
      expect(SecretCode.isWellFormed(null), isFalse);
      expect(SecretCode.isWellFormed(''), isFalse);
      expect(SecretCode.isWellFormed('123'), isFalse);
      expect(SecretCode.isWellFormed('12345'), isFalse);
      expect(SecretCode.isWellFormed('abcd'), isFalse);
    });

    test('agrees with the constructor on every case it covers', () {
      // The two must not drift: a value the predicate accepts and the
      // constructor throws on would make the repository's graceful degradation
      // an exception.
      for (final candidate in <String?>[null, '', '1', '12', '123', '1234',
        '12345', 'abcd', '12a4', '0000', '9999']) {
        final accepted = SecretCode.isWellFormed(candidate);
        if (!accepted) continue;
        expect(
          () => SecretCode(candidate!),
          returnsNormally,
          reason: 'isWellFormed accepted "$candidate" but construction threw',
        );
      }
    });
  });

  group('the default', () {
    test('is 0000 on a fresh install', () {
      // D-83 / AC-018, stated as one fact rather than spelled at call sites.
      expect(SecretCode.defaultCode.value, '0000');
    });
  });

  group('toString', () {
    test('does not leak the code', () {
      // The app never renders a PIN, so a stray interpolation — a log line, an
      // assertion message — must not turn one into a screenshot. The digits
      // getter exists for storage; this exists so nothing else can print them.
      expect(SecretCode('1234').toString(), isNot(contains('1234')));
    });
  });
}
