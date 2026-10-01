/// Number formatting for the display, the history cards, and any other place a
/// computed value is shown to the user (desing.md §3, D-18).
library;

import '../../features/calculator/domain/calculator_engine.dart';

/// Formats a numeric display string with thousands separators (D-18).
///
/// Operates on plain calculator output such as `1234567.89`, `-1234`, or
/// `1e21`. Non-numeric values (e.g. `Error`) are returned unchanged.
String groupThousands(String value) {
  if (value.isEmpty) return value;
  if (!RegExp(r'^-?\d+\.?\d*$').hasMatch(value)) return value;

  final negative = value.startsWith('-');
  final s = negative ? value.substring(1) : value;

  final dotIndex = s.indexOf('.');
  final intPart = dotIndex == -1 ? s : s.substring(0, dotIndex);
  final fracPart = dotIndex == -1 ? '' : s.substring(dotIndex);

  final buffer = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write(',');
    buffer.write(intPart[i]);
  }

  return '${negative ? '-' : ''}$buffer$fracPart';
}

/// Renders a computed [value] for display, composing the three layers the
/// specification asks for.
///
/// 1. Rounds to [decimalPlaces] — **rounding only, never padding** (D-21), so
///    `2 + 2` reads `4` and never `4.00`.
/// 2. Runs the engine's [formatNumber], which trims trailing zeros and falls
///    back to scientific notation so the display cannot overflow with
///    meaningless digits.
/// 3. Inserts thousands separators (D-18): `1234567.89` -> `1,234,567.89`.
///
/// A non-finite value (division by zero, overflow) yields `Error`, matching
/// the error state the display renders (desing.md §9).
///
/// This is the single entry point for a *computed* value. A value the user is
/// still typing is not yet computed, so it passes through [groupThousands]
/// alone until it is evaluated.
String formatResult(double value, {int decimalPlaces = 2}) {
  if (!value.isFinite) return 'Error';

  final places = decimalPlaces < 0 ? 0 : decimalPlaces;
  final rounded = double.parse(value.toStringAsFixed(places));

  return groupThousands(formatNumber(rounded));
}
