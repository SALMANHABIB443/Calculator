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
/// four operator glyphs, `%`, `±`, `=`, and `AC`.
List<CalculatorKey> keysFor(String sequence) => [
  for (final character in sequence.split('')) _keyFor(character),
];

/// Applies [keys] to a fresh engine and returns the final state.
CalculatorState applyKeys(List<CalculatorKey> keys) {
  final engine = CalculatorEngine();
  var state = engine.state;
  for (final key in keys) {
    state = engine.apply(key);
  }
  return state;
}

/// [applyKeys] over a session written as a string, e.g. `apply('125×8=')`.
CalculatorState apply(String sequence) => applyKeys(keysFor(sequence));

CalculatorKey _keyFor(String character) => switch (character) {
  '.' => CalculatorKey.dot,
  '+' => CalculatorKey.add,
  '-' || '−' => CalculatorKey.subtract,
  '×' => CalculatorKey.multiply,
  '÷' => CalculatorKey.divide,
  '=' => CalculatorKey.equals,
  '%' => CalculatorKey.percent,
  '±' => CalculatorKey.plusMinus,
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
