/// Pure calculator logic (PRD §4, FEAT-CALC-001, D-17).
///
/// This file has no Flutter dependencies so it can be unit-tested in
/// isolation. The UI (presentation/calculator_screen.dart) only renders
/// [CalculatorState]; every key press is delegated to [CalculatorEngine].
///
/// Evaluation is strictly left-to-right, applying each operator as it is
/// pressed, with no `×÷` precedence over `+−` (D-17). So `2 + 3 × 4` = 20.
///
/// Two aspects are pinned in DECISIONS.md: the `backspace` key does not exist
/// (D-19 — the mockup shows no ⌫ key, see desing.md §6.1 and prd.md §14) and
/// formatting is layered with thousands separators (D-18).
///
/// **The engine owns values, not display strings.** [CalculatorState] carries
/// the typed entry, the computed value, the expression terms, and whether a
/// result was just completed; turning those into the two right-aligned text
/// lines needs `decimalPlaces`, which is a presentation concern (D-14). That
/// mapping lives in `presentation/display_resolver.dart` as a pure function, so
/// changing the setting re-renders without touching calculation state — and the
/// raw [CalculatorState.value] is exactly what Phase 5 stores as a history
/// entry's `resultValue`.
library;

/// The four basic operators shown on the keypad (desing.md §6.1).
enum CalculatorOperator {
  add('+'),
  subtract('−'),
  multiply('×'),
  divide('÷');

  const CalculatorOperator(this.symbol);

  /// Glyph used both on the keypad and in the expression line.
  final String symbol;

  double apply(double a, double b) {
    switch (this) {
      case CalculatorOperator.add:
        return a + b;
      case CalculatorOperator.subtract:
        return a - b;
      case CalculatorOperator.multiply:
        return a * b;
      case CalculatorOperator.divide:
        return a / b;
    }
  }
}

/// Every key on the 5×4 keypad (desing.md §6.1).
///
/// There is deliberately **no `backspace` member**: neither the mockup
/// `02_22_43` nor the specification includes a ⌫ key, only AC (D-19).
enum CalculatorKey {
  digit0('0', 'zero'),
  digit1('1', 'one'),
  digit2('2', 'two'),
  digit3('3', 'three'),
  digit4('4', 'four'),
  digit5('5', 'five'),
  digit6('6', 'six'),
  digit7('7', 'seven'),
  digit8('8', 'eight'),
  digit9('9', 'nine'),
  dot('.', 'decimal point'),
  ac('AC', 'all clear'),
  percent('%', 'percent'),
  plusMinus('±', 'plus minus'),
  add('+', 'add'),
  subtract('−', 'subtract'),
  multiply('×', 'multiply'),
  divide('÷', 'divide'),
  equals('=', 'equals');

  const CalculatorKey(this.label, this.semanticsLabel);

  /// Visible label on the keypad.
  final String label;

  /// Accessible name.
  final String semanticsLabel;

  bool get isDigit => name.startsWith('digit');

  int get digitValue => int.parse(label);

  CalculatorOperator? get operator {
    switch (this) {
      case CalculatorKey.add:
        return CalculatorOperator.add;
      case CalculatorKey.subtract:
        return CalculatorOperator.subtract;
      case CalculatorKey.multiply:
        return CalculatorOperator.multiply;
      case CalculatorKey.divide:
        return CalculatorOperator.divide;
      default:
        return null;
    }
  }
}

/// One committed number in the expression, plus the operator that introduced
/// it.
///
/// The expression line is rendered from a list of these rather than a single
/// string so thousands separators can be applied to each number independently
/// while the operators between them stay untouched (D-18) — `1000 × 8` reads
/// `1,000 × 8`.
///
/// [text] is the number **exactly as the user typed it**, so the expression line
/// echoes the input and the display never has to guess where a token ended.
class CalculatorExpressionTerm {
  const CalculatorExpressionTerm(this.text, {this.operatorBefore});

  /// Digits, decimal point, and any leading `-` from `±`, e.g. `1000`, `1.5`.
  final String text;

  /// Glyph of the operator joining this number to the previous one, or `null`
  /// for the first term.
  final String? operatorBefore;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalculatorExpressionTerm &&
          other.text == text &&
          other.operatorBefore == operatorBefore;

  @override
  int get hashCode => Object.hash(text, operatorBefore);

  @override
  String toString() => 'CalculatorExpressionTerm($text, $operatorBefore)';
}

/// Immutable snapshot rendered by the Calculator screen (desing.md §3).
class CalculatorState {
  const CalculatorState({
    this.terms = const <CalculatorExpressionTerm>[],
    this.entry,
    this.value,
    this.pendingOperator,
    this.isError = false,
    this.justEvaluated = false,
  });

  /// Numbers already folded into [value], oldest first. Empty until the first
  /// operator is pressed, which is why the expression line is blank for a
  /// single number the user is still typing.
  final List<CalculatorExpressionTerm> terms;

  /// The number currently being typed, as text, or `null` when the user is not
  /// typing. Holds its own `-` sign once `±` has been used on it.
  final String? entry;

  /// The last computed value: the running total while a chain is in progress,
  /// the final result after `=`. `null` when nothing has been computed yet and
  /// in the error state.
  final double? value;

  /// Operator pressed but not yet folded, shown as a trailing glyph on the
  /// expression line (`2 + 3 ×`).
  final CalculatorOperator? pendingOperator;

  /// True after an invalid operation such as division by zero. The expression
  /// line keeps its terms so the user can see what failed (desing.md §9).
  final bool isError;

  /// True when [value] is a result the user has just completed with `=`, rather
  /// than a running total they are still building.
  ///
  /// This is the engine's private `_justEvaluated` promoted onto the snapshot
  /// (**D-35**). Two things need to know the difference: the engine itself, which
  /// uses it to decide that the next digit starts a fresh calculation while an
  /// operator continues from the result; and Phase 5, which records a history
  /// entry when it flips true so only completed results — never a mid-chain
  /// running total — are stored. Re-deriving that from the rest of the state
  /// would mean guessing at what the user actually did.
  ///
  /// Cleared by the next key, so it is a one-shot signal about the current
  /// state rather than a property of the calculation.
  final bool justEvaluated;

  static const CalculatorState initial = CalculatorState();

  /// The number the primary line is showing, whether it is being typed or was
  /// computed. This is the value the unary keys `±` and `%` act on.
  double? get currentValue {
    final entry = this.entry;
    if (entry != null) return double.tryParse(entry);
    return value;
  }

  CalculatorState copyWith({
    List<CalculatorExpressionTerm>? terms,
    String? entry,
    double? value,
    CalculatorOperator? pendingOperator,
    bool? isError,
    bool? justEvaluated,
  }) {
    return CalculatorState(
      terms: terms ?? this.terms,
      entry: entry ?? this.entry,
      value: value ?? this.value,
      pendingOperator: pendingOperator ?? this.pendingOperator,
      isError: isError ?? this.isError,
      justEvaluated: justEvaluated ?? this.justEvaluated,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalculatorState &&
          other.isError == isError &&
          other.justEvaluated == justEvaluated &&
          other.entry == entry &&
          other.value == value &&
          other.pendingOperator == pendingOperator &&
          _termsEqual(other.terms, terms);

  @override
  int get hashCode => Object.hash(
        terms.length,
        entry,
        value,
        pendingOperator,
        isError,
        justEvaluated,
      );

  @override
  String toString() =>
      'CalculatorState(terms: $terms, entry: $entry, value: $value, '
      'pending: $pendingOperator, isError: $isError, '
      'justEvaluated: $justEvaluated)';
}

/// Lists do not compare by content, and `listEquals` lives in
/// `package:flutter/foundation.dart` — which this file must not import
/// (struction.md §5 keeps the engine free of Flutter).
bool _termsEqual(
  List<CalculatorExpressionTerm> a,
  List<CalculatorExpressionTerm> b,
) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Formats a computed value for the result/expression lines.
///
/// Integer results render without a decimal point (`616`); fractional values
/// trim trailing zeros; very large/small magnitudes fall back to scientific
/// notation so the display never overflows with meaningless digits.
///
/// The `decimalPlaces` setting controls **rounding precision only**
/// (D-14) — it does not pad the output with trailing zeros, so `2 + 2` still
/// displays `4`, never `4.00`. The rounding and thousands-separator layers
/// (D-18) are composed by `formatResult` in `core/utils/format.dart`, which is
/// the only `core → features` import in the tree (D-24).
String formatNumber(double value) {
  if (!value.isFinite) return 'Error';
  final s = value.toStringAsPrecision(12);
  if (s.contains('e')) {
    final parts = s.split('e');
    return '${_trimTrailingZeros(parts[0])}e${parts[1]}';
  }
  return _trimTrailingZeros(s);
}

String _trimTrailingZeros(String s) {
  if (!s.contains('.')) return s;
  var out = s.replaceAll(RegExp(r'0+$'), '');
  if (out.endsWith('.')) out = out.substring(0, out.length - 1);
  return out;
}

/// Stateful calculator engine.
///
/// Behaviour follows everyday simple-calculator conventions:
/// - Chained operations evaluate left-to-right as each operator is pressed, so
///   the result line always shows the running total (D-17). There is no parser
///   and no precedence table: an operator press folds whatever has been typed
///   into the running total immediately.
/// - Consecutive operators replace the pending one, so `2 + 3 +` followed by `−`
///   reads `2 + 3 −`.
/// - `=` folds the pending operation; `%` divides the number the primary line is
///   showing by 100 (D-06); `±` negates it; `AC` resets.
/// - After `=` a digit starts a fresh calculation while an operator continues
///   from the result.
/// - Division by zero and any other non-finite result produce an error state
///   that keeps the expression line intact (desing.md §9).
///
/// The engine never throws: every invalid path lands in [_setError] and is
/// reported as [CalculatorState.isError] (struction.md §12).
class CalculatorEngine {
  /// Digit cap on a single entry, so the display cannot be pushed past what a
  /// double represents and the user cannot type an unbounded literal. Matches
  /// the cap the platform calculators apply.
  static const int maxEntryDigits = 15;

  final List<CalculatorExpressionTerm> _terms = <CalculatorExpressionTerm>[];

  /// The number being typed, or `null`.
  String? _entry;

  /// The running total / last result, or `null`.
  double? _value;

  /// Operator pressed but not yet folded, or `null`.
  CalculatorOperator? _pending;

  /// Set by `=`, cleared by the next key. Distinguishes "a result is on screen"
  /// from "the user is mid-calculation", which is what makes a digit start over
  /// while an operator carries on from the result. Surfaced on the snapshot as
  /// [CalculatorState.justEvaluated] so history can see it too (**D-35**).
  bool _justEvaluated = false;

  bool _isError = false;

  CalculatorState get state => CalculatorState(
    terms: List<CalculatorExpressionTerm>.unmodifiable(_terms),
    entry: _entry,
    value: _value,
    pendingOperator: _pending,
    isError: _isError,
    justEvaluated: _justEvaluated,
  );

  /// Applies [key] and returns the new display state.
  CalculatorState apply(CalculatorKey key) {
    if (key.isDigit) return _inputDigit(key.digitValue);

    final operator = key.operator;
    if (operator != null) return _inputOperator(operator);

    return switch (key) {
      CalculatorKey.dot => _inputDot(),
      CalculatorKey.ac => _ac(),
      CalculatorKey.percent => _percent(),
      CalculatorKey.plusMinus => _plusMinus(),
      CalculatorKey.equals => _equals(),
      // Digits and the four operators returned above, so this arm is
      // unreachable; it keeps the switch total rather than falling through.
      _ => state,
    };
  }

  /// AC: start over.
  void reset() => _clear();

  /// Puts [value] on screen as a completed result (**D-37**).
  ///
  /// This is the entry point for loading a history item (feature.md
  /// FEAT-HIST-002), and it is deliberately the *same* state a freshly
  /// evaluated result produces, rather than a typed entry. Two consequences,
  /// both of them the behaviour a user expects:
  ///
  /// - The expression line stays blank and the primary line shows just the
  ///   value, so a loaded `1,000` does not print itself twice.
  /// - Pressing an operator collapses to `<value> +`, because [justEvaluated] is
  ///   set and `_inputOperator` already implements that continuation for
  ///   `125 × 8 =` followed by `+` (desing.md §6.1).
  ///
  /// Anything already on the keypad is discarded, so loading a history item is
  /// also a clear — the user asked to start from this number, not to append to
  /// an unfinished calculation.
  ///
  /// A non-finite [value] is ignored rather than loaded, so a corrupt stored
  /// entry cannot put the display into a state no key press can leave.
  void loadValue(double value) {
    if (!value.isFinite) return;
    _clear();
    _value = value;
    _justEvaluated = true;
  }

  CalculatorState _inputDigit(int digit) {
    _clearIfError();
    if (_justEvaluated) _clear();

    final current = _entry;
    if (current == null) {
      _entry = digit == 0 ? '0' : '$digit';
    } else if (current == '0') {
      // A leading zero is replaced rather than extended, so `0` then `5` shows
      // `5`. The lone `0` and `0.` are preserved, which is what lets the user
      // reach `0.5` (FEAT-CALC-001 validation).
      _entry = '$digit';
    } else if (_digitCount(current) >= maxEntryDigits) {
      return state;
    } else {
      _entry = '$current$digit';
    }

    _justEvaluated = false;
    return state;
  }

  CalculatorState _inputDot() {
    _clearIfError();
    if (_justEvaluated) _clear();

    final current = _entry;
    if (current == null) {
      _entry = '0.';
    } else if (!current.contains('.')) {
      // A second decimal point in the same number is ignored rather than
      // corrupting the literal (FEAT-CALC-001 validation).
      _entry = '$current.';
    }

    _justEvaluated = false;
    return state;
  }

  CalculatorState _inputOperator(CalculatorOperator operator) {
    // An operator pressed after an error only dismisses the error; there is no
    // left operand for it to act on.
    _clearIfError();

    if (_justEvaluated) {
      // Continuing from a result collapses the expression to that result, so
      // `125 × 8 =` followed by `+` reads `1,000 +` — what the iOS, Android, and
      // Windows calculators show.
      final result = _value;
      if (result != null) {
        _terms
          ..clear()
          ..add(CalculatorExpressionTerm(_formatValue(result)));
      } else {
        _clear();
      }
      _justEvaluated = false;
    } else if (_entry != null && !_commitEntry()) {
      return state;
    }

    _pending = operator;
    return state;
  }

  CalculatorState _equals() {
    if (_isError) return state;

    if (_entry != null) {
      if (!_commitEntry()) return state;
    } else if (_pending != null && _value != null) {
      // A trailing operator with no operand repeats the running value, so
      // `2 + =` is `4` rather than an error — the iOS, Android, and Windows
      // behaviour. The expression line is left as the user typed it. See D-31
      // for why this overrides feature.md's "malformed expression → Error".
      _value = _pending!.apply(_value!, _value!);
      if (!_isFiniteResult()) return state;
    }

    _pending = null;
    // The one place the flag is set: `=` is the only key that completes a
    // calculation, so this is also the only press history records (D-35, D-36).
    // A bare `=` with nothing computed leaves [value] null and the flag false,
    // so it records nothing.
    _justEvaluated = _value != null;
    return state;
  }

  CalculatorState _percent() {
    if (_isError) return state;
    _justEvaluated = false;

    // D-06: a plain division by 100, never reinterpreted against the
    // accumulator — `200 + 10 %` adds `0.1`, not `20`.
    final entry = _entry;
    if (entry != null) {
      final operand = double.tryParse(entry);
      if (operand == null) return _setError();
      _entry = _formatValue(operand / 100);
      return state;
    }

    final value = _value;
    if (value == null) return state;
    _value = value / 100;
    if (!_isFiniteResult()) return state;
    return state;
  }

  CalculatorState _plusMinus() {
    if (_isError) return state;
    _justEvaluated = false;

    final entry = _entry;
    if (entry != null) {
      final operand = double.tryParse(entry);
      if (operand == null) return _setError();
      _entry = _formatValue(-operand);
      return state;
    }

    final value = _value;
    if (value == null) return state;
    _value = -value;
    return state;
  }

  CalculatorState _ac() {
    _clear();
    return state;
  }

  /// Folds the typed entry into the running total and appends it to the
  /// expression. This is where left-to-right evaluation actually happens: the
  /// pending operator is applied the moment its right operand is complete
  /// (D-17).
  ///
  /// Returns `false` when the fold produced an invalid result, leaving the
  /// engine in the error state.
  bool _commitEntry() {
    final entry = _entry;
    if (entry == null) return true;

    final operand = double.tryParse(entry);
    if (operand == null) {
      _setError();
      return false;
    }

    final pending = _pending;
    _terms.add(CalculatorExpressionTerm(entry, operatorBefore: pending?.symbol));

    final current = _value;
    // A lone number with no pending operator simply becomes the value; with one,
    // this is the left-to-right fold.
    _value = current == null || pending == null ? operand : pending.apply(current, operand);
    _entry = null;

    if (!_isFiniteResult()) {
      _setError();
      return false;
    }
    return true;
  }

  /// Records an invalid state. The terms survive so the expression line still
  /// shows what was attempted (desing.md §9), and any key other than `AC`
  /// starts a fresh calculation from here.
  CalculatorState _setError() {
    _isError = true;
    _value = null;
    _entry = null;
    _pending = null;
    // An error is not a completed result, so nothing may be recorded from it.
    // Without this, `2 + 2 =` followed by `5 ÷ 0` would still be carrying the
    // previous press's flag and history would save a failed calculation.
    _justEvaluated = false;
    return state;
  }

  bool _isFiniteResult() => _value != null && _value!.isFinite;

  void _clearIfError() {
    if (_isError) _clear();
  }

  void _clear() {
    _terms.clear();
    _entry = null;
    _value = null;
    _pending = null;
    _justEvaluated = false;
    _isError = false;
  }

  /// Writes a value back into a text slot, normalizing negative zero so `±` on
  /// `0` reads `0` rather than `-0`.
  static String _formatValue(double value) =>
      value == 0 ? '0' : formatNumber(value);

  static int _digitCount(String entry) =>
      entry.codeUnits.where((unit) => unit >= 0x30 && unit <= 0x39).length;
}
