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

/// The expression line for [state] — the terms, their operators, and any
/// operator the user has pressed but not yet supplied an operand for.
///
/// Built from segments rather than by concatenating, so a pending operator
/// with no committed term behind it — reachable by pressing `+` on a fresh
/// calculator, or on one that just errored — reads `+` rather than ` +`.
///
/// Each number is grouped independently (D-18), so `1000 × 8` reads
/// `1,000 × 8` and the operator glyphs are never disturbed.
String resolveExpressionLine(CalculatorState state) {
  final segments = <String>[];
  for (final term in state.terms) {
    final operatorBefore = term.operatorBefore;
    if (operatorBefore != null) segments.add(operatorBefore);
    segments.add(groupThousands(term.text));
  }
  final pending = state.pendingOperator;
  if (pending != null) segments.add(pending.symbol);
  return segments.join(' ');
}

/// Resolves the two display lines for [state] at [decimalPlaces] precision.
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

  final entry = state.entry;
  final value = state.value;
  final result = entry != null
      ? groupThousands(entry)
      : value != null
      ? formatResult(value, decimalPlaces: decimalPlaces)
      : '0';

  return CalculatorDisplayState(
    expression: line,
    result: result,
    isError: false,
  );
}
