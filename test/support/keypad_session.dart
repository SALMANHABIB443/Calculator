/// Shared helpers for driving the calculator in tests.
///
/// The calculator has no backspace key (D-19), so a test cannot "correct" a
/// press — it has to replay the whole session. [keysFor] makes that readable by
/// accepting a calculation written the way a user would key it, so a test reads
/// `apply('125×8=')` rather than eighteen enum values.
library;

import 'package:calculator/features/calculator/domain/calculator_engine.dart';

/// Types [sequence] as a session on the keypad, so a test reads the way the
/// calculation is keyed: `2+3×4` is `2 + 3 × 4`. Supports the digits, `.`, the
/// four operator glyphs, `%`, `()`, `=`, and `AC`.
///
/// `()` is the one two-character glyph, so the sequence is scanned rather than
/// split: a naive split would try to key `(` and `)` separately and fail.
List<CalculatorKey> keysFor(String sequence) {
  final keys = <CalculatorKey>[];
  for (var i = 0; i < sequence.length; i++) {
    if (sequence.startsWith('()', i)) {
      keys.add(CalculatorKey.parentheses);
      i++;
      continue;
    }
    keys.add(_keyFor(sequence[i]));
  }
  return keys;
}

/// Applies [keys] to a fresh engine and returns the final state.
CalculatorState applyKeys(List<CalculatorKey> keys) {
  final engine = CalculatorEngine();
  for (final key in keys) {
    engine.apply(key);
  }
  return engine.state;
}

/// [applyKeys] over a session written as a string, e.g. `apply('125×8=')`.
CalculatorState apply(String sequence) => applyKeys(keysFor(sequence));

/// Types [sequence] on the keypad, then presses ⌫ [backspaces] times.
///
/// The backspace control is not a [CalculatorKey] (D-19 keeps the keypad at
/// nineteen keys), so a test cannot spell one as `⌫` in a session string the
/// way it spells a digit. This takes the same shape as [apply] for the same
/// reason: a test reads the way the user keys it, then the deletion that
/// follows.
CalculatorState applyThenBackspace(String sequence, int backspaces) {
  final engine = CalculatorEngine();
  for (final key in keysFor(sequence)) {
    engine.apply(key);
  }
  for (var i = 0; i < backspaces; i++) {
    engine.backspace();
  }
  return engine.state;
}

CalculatorKey _keyFor(String character) => switch (character) {
  '.' => CalculatorKey.dot,
  '+' => CalculatorKey.add,
  '-' || '−' => CalculatorKey.subtract,
  '×' => CalculatorKey.multiply,
  '÷' => CalculatorKey.divide,
  '=' => CalculatorKey.equals,
  '%' => CalculatorKey.percent,
  '()' => CalculatorKey.parentheses,
  // A bare ( or ) in a session stands for the key that produces it, so a
  // test can spell out a group the way the user assembles it.
  '(' => CalculatorKey.parentheses,
  'A' || 'C' => CalculatorKey.ac,
  _ when character.codeUnitAt(0) >= 0x30 &&
      character.codeUnitAt(0) <= 0x39 =>
    CalculatorKey.values.firstWhere(
      (key) => key.digitValue == int.parse(character),
    ),
  _ => throw ArgumentError.value(
    character,
    'character',
    'is not a calculator key',
  ),
};
