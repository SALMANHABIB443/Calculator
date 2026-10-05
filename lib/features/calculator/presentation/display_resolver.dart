/// Turns engine state into the two display strings (desing.md §3).
///
/// Split out of `calculator_display.dart` because the two consumers of this
/// logic do not have the same dependencies. The widget needs `material` and
/// `flutter_riverpod`; the history feature's notifier needs neither — it only
/// wants the strings to put in a card (D-39). Keeping the pure half in its own
/// Flutter-free file means the history feature can depend on it without
/// dragging in the display widget, which imports the calculator controller, which
/// writes history. That would be a cycle.
///
/// This is the only place `decimalPlaces` is applied, and it is deliberately
/// **outside** the engine (D-30). The engine holds values, so changing the
/// setting re-renders the current result at a new precision without touching
/// the calculation — exactly what D-14 asks for — and the rounding a user is
/// still typing is never disturbed, because a typed [CalculatorState.entry] goes
/// through separators only.
///
/// Pure, so it is unit-tested without pumping a widget.
library;

import '../../../core/utils/format.dart';
import '../domain/calculator_engine.dart';
import '../domain/expression_evaluator.dart';

/// The two strings the calculator display paints, resolved from the engine's
/// state (desing.md §3).
class CalculatorDisplayState {
  const CalculatorDisplayState({
    required this.expression,
    required this.result,
    required this.isError,
  });

  /// Secondary line, blank while a single number is being typed.
  final String expression;

  /// Primary line: the entry being typed, the computed value, or `Error`.
  final String result;

  final bool isError;
}

/// The expression line for [state] — the expression as typed, with thousands
/// separators applied to each number independently.
///
/// Built by walking the expression rather than by printing [CalculatorState.expression]
/// directly, so `1000×8+` reads `1,000 × 8 +` and the operator glyphs are never
/// disturbed (D-18). The walk is what lets a *typed* number keep its exact digits
/// on the line above while the primary line rounds a preview (D-30): the line is
/// an echo of what was keyed, never a re-rendering of a computed value.
///
/// Blank while a single number is being typed — `125` on its own carries no
/// operation worth restating — and blank for a value loaded from history
/// (**D-37**), where printing the number above itself would print it twice.
String resolveExpressionLine(CalculatorState state) {
  if (!state.hasOperation) return '';

  final parts = <String>[];
  final buffer = StringBuffer();
  for (var i = 0; i < state.expression.length; i++) {
    final character = state.expression[i];
    if (_isNumberGlyph(character)) {
      buffer.write(character);
      continue;
    }
    _flush(parts, buffer);
    parts.add(character);
  }
  _flush(parts, buffer);
  return parts.join(' ');
}

/// Whether [character] belongs to the number being printed rather than to the
/// arithmetic between numbers.
///
/// The parser's minus is deliberately **not** one of them: it is the glyph both
/// the subtract operator and a negative operand's sign, and only the character
/// before it can say which — `5-3` is an operation, `-3` is a value. Deciding
/// that here would mean tracking position, so instead the sign stays glued to the
/// operator and `5 × -3` prints as `5 ×- 3`. Grouping a lone `-` with the digits
/// it introduces is left to [CalculatorState.hasOperation]'s caller, which is
/// where the sign matters and here it does not.
bool _isNumberGlyph(String character) =>
    isDigitGlyph(character) || character == dotGlyph;

/// Pushes the pending digits out as a grouped number, leaving the buffer empty.
void _flush(List<String> parts, StringBuffer buffer) {
  if (buffer.isEmpty) return;
  parts.add(groupThousands(buffer.toString()));
  buffer.clear();
}

/// Resolves the two display lines for [state] at [decimalPlaces] precision.
///
/// The primary line is the **preview** [CalculatorState.value] whenever there is
/// one, so `99+5` already reads `104` (D-79). A number still being typed is the
/// exception: it is shown exactly as keyed, unrounded, because a user reading
/// the digit they just pressed must see that digit (D-30). `1.23456` shows
/// `1.23456`; the moment it becomes part of a calculation it is a preview and
/// rounds like one.
CalculatorDisplayState resolveDisplay(
  CalculatorState state, {
  required int decimalPlaces,
}) {
  final line = resolveExpressionLine(state);

  if (state.isError) {
    // desing.md §9: the secondary line retains the expression so the user can
    // see what failed.
    return CalculatorDisplayState(
      expression: line,
      result: 'Error',
      isError: true,
    );
  }

  // The digits still being typed, unrounded and unformatted (D-30). `null` the
  // moment the expression is anything more than one bare number, because then the
  // primary line is showing a preview rather than an entry.
  final typed = state.typedNumber;
  final result = typed != null
      ? groupThousands(typed)
      : state.value != null
      ? formatResult(state.value!, decimalPlaces: decimalPlaces)
      : '0';

  return CalculatorDisplayState(
    expression: line,
    result: result,
    isError: false,
  );
}
