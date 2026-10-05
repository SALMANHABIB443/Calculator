/// Pure calculator logic (PRD Â§4, FEAT-CALC-001, D-17).
///
/// This file has no Flutter dependencies so it can be unit-tested in
/// isolation. The UI (presentation/calculator_screen.dart) only renders
/// [CalculatorState]; every key press is delegated to [CalculatorEngine].
///
/// Evaluation binds `×` and `÷` tighter than `+` and `−`, so `2 + 3 × 4` is
/// 14 — D-84 supersedes D-17's left-to-right rule (expression_evaluator.dart).
///
/// Two aspects are pinned in DECISIONS.md: the keypad itself stays at
/// nineteen keys with no backspace among them (D-19 — the ⌫ control sits
/// above the display and reaches the engine as `backspace()`, **D-81**), and
/// formatting is layered with thousands separators (D-18).
///
/// **The engine owns values, not display strings.** [CalculatorState] carries
/// the typed entry, the computed value, the expression terms, and whether a
/// result was just completed; turning those into the two right-aligned text
/// lines needs `decimalPlaces`, which is a presentation concern (D-14). That
/// mapping lives in `presentation/display_resolver.dart` as a pure function, so
/// changing the setting re-renders without touching calculation state â€” and the
/// raw [CalculatorState.value] is exactly what Phase 5 stores as a history
/// entry's `resultValue`.
library;

import 'expression_evaluator.dart';

/// The four basic operators shown on the keypad (desing.md Â§6.1).
enum CalculatorOperator {
  add('+', addGlyph),
  subtract('\u2212', subtractGlyph),
  multiply('\u00D7', multiplyGlyph),
  divide('\u00F7', divideGlyph);

  const CalculatorOperator(this.symbol, this.glyph);

  /// Glyph printed on the keypad and in the expression line.
  final String symbol;

  /// The glyph the parser reads.
  ///
  /// A separate field so the keypad's minus and the evaluator's minus are named
  /// rather than assumed equal. They are both U+2212 today; if they ever drift,
  /// every subtraction would parse as invalid, and this field is where that
  /// would be visible.
  final String glyph;

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

/// Every key on the 5Ã—4 keypad (desing.md Â§6.1, **D-84**).
///
/// There is deliberately **no `backspace` member**: the keypad stays at nineteen
/// keys (D-19) and the delete control sits above the rule on the screen, so it
/// is a method on the engine rather than a key (**D-81**).
///
/// `parentheses` replaces the `Â±` key: with a real parser behind it, a sign
/// toggle has nowhere to live â€” a negative operand is written `-` and
/// parentheses do the work `Â±` used to (D-84).
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
  parentheses('()', 'parentheses'),
  add('+', 'add'),
  subtract('\u2212', 'subtract'),
  multiply('\u00D7', 'multiply'),
  divide('\u00F7', 'divide'),
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

/// An immutable snapshot of what the calculator is showing.
///
/// A snapshot rather than a live view: a reference taken before a later press
/// cannot observe that press, and history records the state as it was when `=`
/// completed. Everything here is final, so a caller holding one holds a moment,
/// not the machine.
///
/// The expression is kept as the **input string** rather than a list of terms
/// (D-84). Once parentheses and `Ã—Ã·` precedence exist, the typed text *is* the
/// calculation â€” reconstructing it from folded terms would either lose the
/// brackets or re-parse on every keystroke. [expression] is what the expression
/// line prints, what backspace edits a character at a time (D-81), and what
/// [ExpressionEvaluator] reads.
class CalculatorState {
  const CalculatorState({
    required this.expression,
    required this.value,
    required this.isError,
    required this.justEvaluated,
    this.lastExpression,
    this.lastValue,
  });

  /// A calculator with nothing typed and no result.
  static const CalculatorState initial = CalculatorState(
    expression: '',
    value: null,
    isError: false,
    justEvaluated: false,
  );

  /// The expression exactly as keyed, e.g. `900+100` or `(5+5)`.
  final String expression;

  /// The running total while a chain is in progress, or the answer after `=`.
  ///
  /// This is the **live preview** (D-79): it tracks what `=` *would* produce for
  /// the expression as it stands, so the primary line shows `99 + 5` implying
  /// `104` rather than the digit being typed. `null` when nothing is computable
  /// yet, and in the error state.
  final double? value;

  /// The completed calculation, kept so history can record it and so the first
  /// backspace after `=` hands the whole expression back (D-83).
  final String? lastExpression;

  /// The value [lastExpression] produced.
  final double? lastValue;

  /// Whether the display should read `Error` (desing.md Â§9).
  ///
  /// The expression survives it, so the line above still shows what broke â€” and
  /// so `AC` or a fresh digit can clear it.
  final bool isError;

  /// Set by `=`, cleared by the next key. Distinguishes "a result is on screen"
  /// from "mid-calculation", which is what makes a digit start over while an
  /// operator carries on from the result. Surfaced on the snapshot so history can
  /// see it too (**D-35**).
  final bool justEvaluated;

  /// Whether the delete control should respond.
  ///
  /// False in the error state and on a fresh calculator, true whenever there is
  /// an expression to take characters off â€” the mirror of what
  /// [CalculatorEngine.backspace] will actually do, so the control can never be
  /// live and then do nothing.
  bool get canBackspace => !isError && expression.isNotEmpty;

  /// The digits still being typed, or `null` when the expression is more than one
  /// bare number.
  ///
  /// The primary line shows these **unrounded** (D-30): a user who has just
  /// pressed the sixth digit of `1.23456` must see that digit, not the `1.23` the
  /// `decimalPlaces` setting would round it to. The moment the expression gains an
  /// operator, a bracket, or a `%`, this is `null` and the line shows the preview
  /// instead — rounding then belongs to the answer, not to an entry in progress.
  String? get typedNumber {
    if (hasOperation) return null;
    if (expression.isEmpty) return null;
    for (var i = 0; i < expression.length; i++) {
      if (!isDigitGlyph(expression[i]) && expression[i] != dotGlyph) return null;
    }
    return expression;
  }

  /// Whether the expression line should print anything at all.
  ///
  /// False for a lone number â€” `125` carries no operation worth restating above
  /// itself â€” and false for a value loaded from history (**D-37**), where the
  /// line would print the primary number twice. A parenthesised or signed
  /// expression counts, because there *is* more than one thing in it.
  bool get hasOperation {
    for (var i = 0; i < expression.length; i++) {
      final character = expression[i];
      if (isBinaryOperatorGlyph(character) ||
          character == percentGlyph ||
          character == openParenthesis ||
          character == closeParenthesis) {
        return true;
      }
    }
    return false;
  }

  CalculatorState copyWith({
    String? expression,
    double? value,
    String? lastExpression,
    double? lastValue,
    bool? isError,
    bool? justEvaluated,
  }) {
    return CalculatorState(
      expression: expression ?? this.expression,
      value: value ?? this.value,
      lastExpression: lastExpression ?? this.lastExpression,
      lastValue: lastValue ?? this.lastValue,
      isError: isError ?? this.isError,
      justEvaluated: justEvaluated ?? this.justEvaluated,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CalculatorState &&
        other.expression == expression &&
        other.value == value &&
        other.lastExpression == lastExpression &&
        other.lastValue == lastValue &&
        other.isError == isError &&
        other.justEvaluated == justEvaluated;
  }

  @override
  int get hashCode => Object.hash(
    expression,
    value,
    lastExpression,
    lastValue,
    isError,
    justEvaluated,
  );

  @override
  String toString() =>
      'CalculatorState(expression: $expression, value: $value, '
      'isError: $isError, justEvaluated: $justEvaluated)';
}

/// Formats a computed value for the result/expression lines.
///
/// Integer results render without a decimal point (`616`); fractional values
/// trim trailing zeros; very large/small magnitudes fall back to scientific
/// notation so the display never overflows with meaningless digits.
///
/// The `decimalPlaces` setting controls **rounding precision only** (D-14) â€” it
/// does not pad the output with trailing zeros, so `2 + 2` still displays `4`,
/// never `4.00`. The rounding and thousands-separator layers (D-18) are composed
/// by `formatResult` in `core/utils/format.dart`, which is the only
/// `core â†’ features` import in the tree (D-24).
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

/// Stateful calculator engine, expression-string based (**D-84**).
///
/// The engine holds the **expression as typed** and re-evaluates it through
/// [ExpressionEvaluator] whenever the value shown has to change. That is the
/// opposite of the pre-parentheses design, which folded each operand into a
/// running total the moment an operator was pressed; it had to, because with no
/// parser there was nothing to re-evaluate. Once parentheses and `Ã—Ã·`
/// precedence are real, folding eagerly is wrong â€” `2+3Ã—4` must read `14` (D-17
/// became a property of the parser rather than of the engine), and `2Ã—(5+5)`
/// cannot be represented as a running total at all.
///
/// Conventions it follows:
/// - An operator press replaces a pending one, so `900+Ã—` reads `900Ã—`; one with
///   no left operand is declined (**D-80**), so `+5` can never be typed.
/// - `()` opens or closes depending on what the expression already implies
///   (**D-85**), so the single key serves both.
/// - `%` is contextual (**D-86**): under `Ã—` it is a plain divide-by-100, under
///   `+` or `âˆ’` a share of the left operand. That lives in the evaluator.
/// - After `=` a digit starts fresh while an operator continues from the result
///   (D-35); the first backspace hands the whole expression back (D-83).
/// - Division by zero and any other non-finite result produce an error state
///   that keeps the expression intact (desing.md Â§9).
///
/// The engine never throws: every invalid path lands in the error state and is
/// reported as [CalculatorState.isError] (struction.md Â§12).
class CalculatorEngine {
  /// Digit cap on a single number, so the display cannot be pushed past what a
  /// double represents and the user cannot type an unbounded literal. Matches
  /// the cap the platform calculators apply.
  static const int maxEntryDigits = 15;

  /// The expression as keyed, e.g. `900+100` or `(5+5)`.
  String _expression = '';

  /// The value of the last completed calculation, kept for the first backspace
  /// after `=` (D-83).
  String? _lastExpression;
  double? _lastValue;

  /// Whether the display should read `Error`.
  bool _isError = false;

  /// Whether the value shown is a result the user just completed with `=`
  /// (**D-35**).
  bool _justEvaluated = false;

  /// The previewed value for the expression as it stands, or `null`.
  ///
  /// What makes the primary line answer `99+5` with `104` rather than the digit
  /// being typed (**D-79**). Refreshed by [_recompute] on every key that changes
  /// the expression.
  double? _value;

  /// The current snapshot.
  CalculatorState get state => CalculatorState(
    expression: _expression,
    value: _value,
    lastExpression: _lastExpression,
    lastValue: _lastValue,
    isError: _isError,
    justEvaluated: _justEvaluated,
  );
  /// Applies [key] and returns the new display state.
  CalculatorState apply(CalculatorKey key) {
    if (key == CalculatorKey.ac) {
      _clear();
      return state;
    }

    // A key other than AC dismisses the error and starts from nothing, so the
    // user never presses AC twice after a typo (desing.md Â§9).
    if (_isError) _clear();

    if (_justEvaluated && key != CalculatorKey.equals) {
      _continueFromResult(key);
      if (_expression.isEmpty && key.operator != null) {
        // A `+` with no left operand is declined (D-80).
        _justEvaluated = false;
        return state;
      }
    }

    final next = switch (key) {
      CalculatorKey.parentheses => _applyParentheses(),
      _ when key.isDigit => _applyDigit(key.digitValue),
      CalculatorKey.dot => _applyDot(),
      CalculatorKey.percent => _applyPercent(),
      CalculatorKey.equals => _applyEquals(),
      _ when key.operator != null => _applyOperator(key.operator!),
      _ => null,
    };

    if (next != null) _expression = next;
    _recompute();
    return state;
  }

  /// Takes one character off the expression (**D-81**).
  ///
  /// The delete control is not a keypad key (D-19 keeps the pad at nineteen
  /// keys), so it is a method here rather than a [CalculatorKey].
  ///
  /// One rule in every state: **exactly one character off the expression the
  /// user is editing.** The engine never replaces the expression with the
  /// result, so after `=` there is nothing to hand back; leaving the result
  /// state and deleting in the same press is what keeps every press visibly
  /// effective. `900 + 100 =` is `1000`, and the first backspace is already
  /// `900 + 10` previewing `910`, then `900 + 1`, `900 +`, `900`. A value
  /// loaded from history ([loadValue]) follows the same rule, so its first
  /// press shortens the number instead of doing nothing.
  ///
  /// In the error state, or with nothing typed, it costs nothing --
  /// [CalculatorState.canBackspace] is false there too, so the control cannot
  /// be live and then do nothing.
  CalculatorState backspace() {
    if (_isError) return state;
    if (_expression.isEmpty) return state;

    // Leaving the result state in passing: [state.justEvaluated] is false
    // again, so [CalculatorController] knows a number keyed next belongs to
    // the expression rather than to a fresh calculation -- and because the
    // expression was never overwritten, the delete below already edits the
    // real calculation.
    _justEvaluated = false;
    _expression = _expression.substring(0, _expression.length - 1);
    _recompute();
    return state;
  }

  /// AC: start over.
  void reset() => _clear();

  /// Puts [value] on screen as a completed result (**D-37**).
  ///
  /// The entry point for loading a history item (feature.md FEAT-HIST-002).
  /// Whatever was on the keypad is discarded, so loading a history item is also a
  /// clear â€” the user asked to start from this number, not to append to an
  /// unfinished calculation.
  ///
  /// A non-finite [value] is ignored rather than loaded, so a corrupt stored
  /// entry cannot put the display into a state no key press can leave.
  void loadValue(double value) {
    if (!value.isFinite) return;
    _clear();
    _expression = _numberFor(value);
    _value = value;
    // The loaded number is the *result* of a calculation the user did not type,
    // so it is stored as the completed one: an operator pressed next continues
    // from it rather than starting over, and a backspace shortens it like any
    // other expression (D-81), so its first press is never a dead one.
    _lastExpression = _expression;
    _lastValue = value;
    _justEvaluated = true;
  }
  /// Rewrites the expression after `=`, before the next key is applied (**D-35**).
  ///
  /// A digit or a `.` begins a fresh calculation; an operator, `()`, or `%`
  /// continues from the result, so `125×8=` then `+` reads `1000+` and a
  /// percent after `=` stays a percent of the answer (`4%` previewing `0.04`)
  /// instead of stranding that answer with no expression behind it.
  void _continueFromResult(CalculatorKey key) {
    final result = _lastValue;
    _justEvaluated = false;
    final startsFresh = key.isDigit || key == CalculatorKey.dot;
    _expression = (startsFresh || result == null) ? '' : _numberFor(result);
  }

  /// A digit, appended to the number being typed or starting one.
  ///
  /// Returns `null` when the press is declined â€” a digit straight after a closing
  /// parenthesis or a `%`, or a number already at [maxEntryDigits] â€” so the
  /// caller leaves the expression untouched.
  String? _applyDigit(int digit) {
    final last = _lastCharacter;

    // A digit cannot follow a completed group or a `%`: `(5+5)2` is not a
    // calculation anyone means, and accepting it would silently turn the next
    // operator press into an implicit multiply.
    if (last == closeParenthesis || last == percentGlyph) return null;

    final current = _currentNumber;
    // No number in progress, so this digit starts one â€” appended to the
    // expression, not replacing it, or `(5` would read `5` and the group the
    // user just opened would vanish from under their finger.
    if (current == null) return '$_expression${digit == 0 ? '0' : '$digit'}';

    // A leading zero is replaced rather than extended, so `0` then `5` reads
    // `5`. The lone `0` and `0.` survive, which is what lets `0.5` be typed.
    if (current == '0') {
      return '${_expression.substring(0, _expression.length - 1)}$digit';
    }
    if (_digitsIn(current) >= maxEntryDigits) return null;
    return '$_expression$digit';
  }

  /// The decimal point: completes a number, or starts `0.` when there is none.
  String? _applyDot() {
    final current = _currentNumber;
    if (current != null) {
      // A second decimal point in the same number is ignored rather than
      // corrupting the literal (FEAT-CALC-001 validation).
      if (current.contains(dotGlyph)) return null;
      return '$_expression$dotGlyph';
    }
    // No number in progress: `0.` starts one, appended to whatever came before so
    // an open group or a pending operator survives.
    return '$_expression' '0$dotGlyph';
  }

  /// `%`, which the evaluator reads as contextual (**D-86**).
  ///
  /// Declined where it cannot be a value: leading the expression, or following
  /// an operator, an opening parenthesis, or another `%` â€” `%` is an operator to
  /// the parser, so nothing can come before it. A **closed group** is allowed
  /// (`(5+5)%`), which is how a computed total is turned into a percentage.
  String? _applyPercent() {
    if (_expression.isEmpty) return null;
    final last = _lastCharacter!;
    if (isBinaryOperatorGlyph(last) ||
        last == openParenthesis ||
        last == percentGlyph) {
      return null;
    }
    return '$_expression$percentGlyph';
  }

  /// `=`: evaluate the expression as it stands and record the result (**D-35**).
  ///
  /// The only key that sets [_lastExpression] and the only one that sets
  /// [_justEvaluated], so history records a completed result and never a
  /// mid-chain preview. Returns `null` -- it edits the expression only to
  /// complete a trailing operator (see below), so the line above the
  /// answer keeps showing what was typed.
  String? _applyEquals() {
    // A bare `=` on an untouched calculator does nothing at all.
    if (_expression.isEmpty) return null;

    // D-31: a trailing operator is pending on an operand, and `=` supplies it
    // by repeating the one already there -- `2+` completes to `2+2`, so
    // `2 + =` answers `4` rather than the `2` a plain repair would leave.
    final completed = _expressionRepeatingPendingOperand();
    if (completed != null) _expression = completed;

    final result = ExpressionEvaluator.evaluate(_expression, autoClose: true);
    if (!result.isSuccess) {
      _isError = true;
      _value = null;
      _justEvaluated = false;
      return null;
    }

    final value = result.value!;
    _lastExpression = _expression;
    _lastValue = value;
    _value = value;
    _justEvaluated = true;
    return null;
  }

  /// [_expression] with a trailing binary operator completed by the operand it
  /// is pending on, or `null` when there is nothing to repeat.
  ///
  /// `2+` repeats into `2+2` (so D-31's `2 + =` is `4`), `2+3+` into `2+3+3`:
  /// the last operand, not the running total, which is what a calculator
  /// carrying a pending operator does. The operand is everything after the
  /// last operator at the top level, so the group in `2+(3+4)+` repeats whole.
  /// Anything the parser would not accept on its own returns `null`, leaving
  /// the forgiving repair exactly as it was.
  String? _expressionRepeatingPendingOperand() {
    final trailing = _lastCharacter;
    if (trailing == null || !isBinaryOperatorGlyph(trailing)) return null;

    final pending = _expression.substring(0, _expression.length - 1);
    var depth = 0;
    var split = -1;
    for (var i = 0; i < pending.length; i++) {
      final character = pending[i];
      if (character == openParenthesis) {
        depth++;
      } else if (character == closeParenthesis) {
        if (depth > 0) depth--;
      } else if (depth == 0 && isBinaryOperatorGlyph(character)) {
        split = i;
      }
    }
    final operand = split < 0 ? pending : pending.substring(split + 1);
    if (operand.isEmpty) return null;
    if (!ExpressionEvaluator.isComplete(operand)) return null;
    return '$pending$trailing$operand';
  }

  /// An operator: appended, replacing one already pending.
  ///
  /// Declined when there is no left operand -- `+` on a fresh calculator would
  /// otherwise leave `+5` on the line (**D-80**), and `+(` is no better: a
  /// `(` waiting for its operand may only receive a `-`, which is how a
  /// negative operand stays typeable (`2+(−5)`).
  String? _applyOperator(CalculatorOperator operator) {
    if (_expression.isEmpty) return null;

    // Consecutive operators **replace** rather than stack, so `900+×` reads
    // `900×` and `2 + 3 +` followed by `−` reads `2 + 3 −`. Appending both
    // would leave `900+×` on the line, which no parser accepts and no user
    // meant.
    final last = _lastCharacter!;
    if (isBinaryOperatorGlyph(last)) {
      // Replacing the `−` that follows `(` must not turn `2+(−` into `2+(+`:
      // only a `-` may sit directly after an opening group.
      if (_expression.length >= 2 &&
          _expression[_expression.length - 2] == openParenthesis &&
          operator != CalculatorOperator.subtract) {
        return null;
      }
      final head = _expression.substring(0, _expression.length - 1);
      return '$head${operator.symbol}';
    }
    if (last == openParenthesis && operator != CalculatorOperator.subtract) {
      return null;
    }
    return '$_expression${operator.symbol}';
  }
  /// `()`: open a group, or close the innermost one (**D-85**).
  ///
  /// One key for both directions, decided by what the expression already
  /// implies, so the user never presses a key that does nothing:
  ///
  /// | after        | `()` does |
  /// |--------------|-----------|
  /// | nothing      | opens `(5` â€” a group must open |
  /// | `5`, `5+`, `5Ã—` | opens: after a value or an operator a group is still missing |
  /// | `(`          | opens: nesting, not closing â€” `(` has no operand yet |
  /// | `(5`         | closes: the group now has its operand |
  /// | `(5+`        | opens: the inner group is missing |
  /// | `(5+2`       | closes |
  /// | `(5+2)Ã—`     | opens: the operator is waiting for its right operand |
  /// | `50%`        | opens: a `%` is a value, so a group can multiply into it |
  ///
  /// The rule in one line: **close when the group has an operand the user could
  /// have finished, open otherwise.** Two `))` in a row is therefore
  /// unreachable â€” the second press sees a closed group and opens instead.
  String? _applyParentheses() {
    final last = _lastCharacter;

    // Nothing typed yet, or a group already open with no operand: nest. A
    // fresh `(` is never a multiplication, so it is appended bare.
    if (last == null || last == openParenthesis) {
      return '$_expression$openParenthesis';
    }

    // After a binary operator the operand is missing, so the group opens as the
    // operator's right operand â€” bare, because `+(` already reads "plus a group".
    // Only after a **closed group** does a new group need an explicit `Ã—`, since
    // `(5+5)(` would otherwise look like two adjacent groups.
    if (isBinaryOperatorGlyph(last)) {
      return '$_expression$openParenthesis';
    }

    // After a completed group, a new one multiplies into it.
    if (last == closeParenthesis) {
      return '$_expression$multiplyGlyph$openParenthesis';
    }

    // `%` is an operator to the evaluator, so a group after it is that operand.
    if (last == percentGlyph) {
      return '$_expression$multiplyGlyph$openParenthesis';
    }

    // After a digit or a decimal point the open group has its operand, so this
    // closes it.
    if (ExpressionEvaluator.openParentheses(_expression) == 0) {
      // Nothing is open â€” the group is implicit, so one opens multiplied in.
      return '$_expression$multiplyGlyph$openParenthesis';
    }
    return '$_expression$closeParenthesis';
  }

  // --- Expression helpers ---------------------------------------------------

  /// The last character of the expression, or `null` when it is empty.
  String? get _lastCharacter =>
      _expression.isEmpty ? null : _expression[_expression.length - 1];

  /// The number currently being typed, as the user has typed it, or `null`.
  ///
  /// `null` when the expression does not end in one â€” it is empty, ends in an
  /// operator or a bracket, or ends in `%` (which is an operator to the parser
  /// even though it is a value to the user). Reading the *typed text* rather than
  /// the last parsed factor is what lets `1.5` be extended to `1.55` and what
  /// makes backspace's substring edit agree with what is on screen.
  String? get _currentNumber {
    final buffer = StringBuffer();
    for (var i = _expression.length - 1; i >= 0; i--) {
      final character = _expression[i];
      if (isDigitGlyph(character) || character == dotGlyph) {
        buffer.write(character);
        continue;
      }
      break;
    }
    return buffer.isEmpty ? null : buffer.toString().split('').reversed.join();
  }

  /// How many digits [number] holds, ignoring the decimal point.
  static int _digitsIn(String number) =>
      number.split('').where(isDigitGlyph).length;

  /// [value] as the text the expression should carry.
  ///
  /// [formatNumber] rather than `toString`, so a value that came back from the
  /// parser prints the way it computed â€” `1000`, not `1000.0`.
  static String _numberFor(double value) => formatNumber(value);

  /// Refreshes [_value] â€” the preview â€” from the expression as it stands.
  ///
  /// Uses `autoClose: true` so a prefix a user is mid-way through still previews
  /// a number (`99+` shows `99`, `(5+5` shows `10`), and **never** sets the error
  /// state: an unfinished calculation must not flash `Error` at someone who is
  /// still typing the divisor â€” `=` is where it becomes an error (**D-79**).
  ///
  /// After `=` the value is the completed result and must not be recomputed, or
  /// `5Ã·0=` would slide from `Error` back to `5` the moment the display rebuilt.
  void _recompute() {
    if (_isError || _justEvaluated) return;
    final result = ExpressionEvaluator.evaluate(_expression, autoClose: true);
    if (result.isSuccess) {
      _value = result.value;
      return;
    }
    // The expression is gone: so is the preview. Freezing the last number
    // here is what made backspace-to-empty keep showing it instead of `0`.
    if (result.status == EvaluationStatus.empty) _value = null;
    // Any other unfinished status keeps the running total: a preview must not
    // flash `Error` at someone still typing the divisor (**D-79**).
  }

  /// AC: everything back to a blank calculator.
  void _clear() {
    _expression = '';
    _value = null;
    _lastExpression = null;
    _lastValue = null;
    _isError = false;
    _justEvaluated = false;
  }
}