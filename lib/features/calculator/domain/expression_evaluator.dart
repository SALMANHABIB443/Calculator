/// The expression evaluator (**D-84**, **D-85**, **D-86**).
///
/// Recursive-descent parser over the expression string the keypad builds, with
/// real operator precedence, nesting, implicit multiplication, and contextual
/// percentages. It replaces the folding accumulator of **D-17**, which had no
/// way to hold a parenthesised group.
///
/// The grammar, in the order it is parsed:
///
/// ```text
/// expression := term (('+' | '-') term)*        // additive, left to right
/// term       := factor (('Ã—' | 'Ã·') factor)*    // multiplicative, tighter
///              | factor ( '(' expression ')' )*  // implicit multiplication
/// factor     := number '%'* | '(' expression ')' '%'* | '-' factor
/// ```
///
/// So `2 + 3 Ã— 4` is `14`, and `(2 + 3) Ã— (4 + 5)` is `45`.
///
/// **Percent is contextual, and this is the single rule** (**D-86**). A `%` is a
/// postfix on the factor it follows, and what it means depends on the operator
/// it binds to:
///
/// - Under `Ã—` or `Ã·`, or standing alone, it divides by 100:
///   `50 %` ? `0.5`, `100 Ã— 10 %` ? `10`.
/// - Under `+` or `-`, it is a share *of the left operand*:
///   `200 + 10 %` ? `220`, `200 - 10 %` ? `180`.
///
/// This is the iOS/Android behaviour, and it is what makes both of the
/// specification's examples hold at once. Chained percentages compose normally,
/// because a percentage is resolved to a number at the point it is parsed.
///
/// **Nothing here throws.** Every invalid path â€” a stray glyph, two decimal
/// points, a missing operand, an unbalanced parenthesis, division by zero, an
/// overflow â€” comes back as an [EvaluationStatus], so the engine can put the
/// display into its error state instead of the app crashing.
///
/// Pure and Flutter-free, so it is unit-tested without pumping a widget.
library;

/// Why an evaluation did not produce a number.
enum EvaluationStatus {
  /// The expression evaluated to a finite number.
  success,

  /// Nothing to evaluate â€” a fresh calculator, or an expression of only
  /// operators. Not an error: it is the state before anything is typed.
  empty,

  /// The expression stops mid-way and would be completed by typing more, e.g.
  /// `5 +` or `(5 + 2`. Harmless while previewing; only reachable as an error if
  /// `=` is pressed without [ExpressionEvaluator.evaluate]'s `autoClose`.
  incomplete,

  /// A parenthesis was opened and never closed (`(5 + 2`) or closed without
  /// being opened (`5 + 2)`).
  unbalanced,

  /// Structurally impossible: two operators in a row, a second decimal point, a
  /// stray `%`, or an empty pair of parentheses.
  invalid,

  /// A mathematically undefined result: division by zero, or a magnitude that
  /// overflows a double.
  undefined,
}

/// The outcome of evaluating one expression.
class ExpressionResult {
  const ExpressionResult(this.status, [this.value]);

  /// A successful evaluation of a finite number.
  const ExpressionResult.success(double this.value)
    : status = EvaluationStatus.success;

  /// The evaluated number, or `null` for any other [status].
  final double? value;

  final EvaluationStatus status;

  bool get isSuccess => status == EvaluationStatus.success;

  @override
  String toString() => isSuccess
      ? 'ExpressionResult.success($value)'
      : 'ExpressionResult($status)';
}

/// The four binary operator glyphs, as **code points** rather than literals.
///
/// Every one of these is written as `\uXXXX` on purpose. They used to be typed
/// as bare characters, which made the file's encoding load-bearing: a single
/// save through a CP1252 toolchain turned `×` into `Ã—`, and since the parser
/// compares glyphs with `==` the calculator then read `5 x 3` as invalid — a
/// silent arithmetic failure from a text-encoding accident. An escape is the
/// same character in every encoding, so this class of bug cannot come back.
const String addGlyph = '+';
const String subtractGlyph = '\u2212';
const String multiplyGlyph = '\u00D7';
const String divideGlyph = '\u00F7';
const String percentGlyph = '%';
const String dotGlyph = '.';
const String openParenthesis = '(';
const String closeParenthesis = ')';

bool isDigitGlyph(String character) {
  final code = character.codeUnitAt(0);
  return code >= 0x30 && code <= 0x39;
}

/// Whether [character] is one of the four binary operator glyphs.
bool isBinaryOperatorGlyph(String character) =>
    character == addGlyph ||
    character == subtractGlyph ||
    character == multiplyGlyph ||
    character == divideGlyph;

/// Evaluates expression strings. Stateless â€” every entry point is a pure
/// function of its argument.
class ExpressionEvaluator {
  const ExpressionEvaluator._();

  /// Evaluates [expression].
  ///
  /// With [autoClose] the evaluator is forgiving in the two ways someone typing
  /// on a phone keypad always is: a dangling binary operator or `(` at the end
  /// is dropped, and unclosed parentheses are closed. That is what lets `=`
  /// answer `(5 + 5` with `10` rather than an error, and it is what makes the
  /// live preview (**D-79**) render something useful for every prefix of an
  /// expression. Without it, only a complete expression evaluates.
  static ExpressionResult evaluate(
    String expression, {
    bool autoClose = false,
  }) {
    final source = autoClose ? repair(expression) : expression;
    if (source.isEmpty) return const ExpressionResult(EvaluationStatus.empty);

    final parser = _Parser(source);
    try {
      final value = parser.parseExpression();
      if (!parser.atEnd) {
        // A `)` with nothing open, or trailing glyphs the grammar cannot use.
        return const ExpressionResult(EvaluationStatus.invalid);
      }
      if (!value.isFinite) {
        return const ExpressionResult(EvaluationStatus.undefined);
      }
      return ExpressionResult.success(value);
    } on _Failure catch (failure) {
      return ExpressionResult(failure.status);
    }
  }

  /// Whether [expression] evaluates to a finite number exactly as it stands,
  /// with no forgiving repair applied.
  static bool isComplete(String expression) =>
      evaluate(expression).status == EvaluationStatus.success;

  /// How many `(` are still unclosed at the end of [expression].
  ///
  /// A `)` beyond what was opened is ignored rather than producing a negative
  /// count: the `()` key never closes a parenthesis it did not open, so such an
  /// expression is not one this keypad can produce, and the paren button needs a
  /// plain "are any groups open?" answer rather than a validity verdict.
  static int openParentheses(String expression) {
    var opens = 0;
    for (var i = 0; i < expression.length; i++) {
      final character = expression[i];
      if (character == openParenthesis) {
        opens++;
      } else if (character == closeParenthesis && opens > 0) {
        opens--;
      }
    }
    return opens;
  }

  /// Makes [expression] evaluable by trimming what is obviously still being
  /// typed and closing what is obviously unfinished.
  ///
  /// Dropped first, repeatedly: a trailing binary operator, then a trailing `(`
  /// that has no operand inside it â€” so `5 +` evaluates as `5` and a bare `(` is
  /// nothing at all. Then every unclosed `(` gets its `)`.
  static String repair(String expression) {
    var source = expression;
    while (source.isNotEmpty && _isDroppable(source[source.length - 1])) {
      source = source.substring(0, source.length - 1);
    }
    for (var i = 0; i < openParentheses(source); i++) {
      source = '$source$closeParenthesis';
    }
    return source;
  }

  static bool _isDroppable(String character) =>
      isBinaryOperatorGlyph(character) || character == openParenthesis;
}

/// Signals a parse failure carrying the status the engine should surface.
class _Failure implements Exception {
  const _Failure(this.status);

  final EvaluationStatus status;
}

/// A parsed factor: its raw value, and whether it carried a trailing `%`.
///
/// The flag is what makes a percentage contextual (**D-86**) â€” the same `10` is
/// an operand under `Ã—` and a share of `200` under `+`, and the difference is
/// only ever knowable by the level that binds the operator.
class _Factor {
  const _Factor(this.value, {this.isPercent = false});

  final double value;
  final bool isPercent;

  /// This factor as a plain operand: a percentage is its hundredth.
  double get asOperand => isPercent ? value / 100 : value;
}

/// A multiplicative term.
///
/// [barePercent] is non-null only when the term is *nothing but* a percentage
/// factor, which is the case `200 + 10 %` needs and `200 + 10 % Ã— 2` is not.
class _Term {
  const _Term(this.value, [this.barePercent]);

  final double value;

  /// The raw `10` of a term that is exactly `10 %`, or `null` for anything else.
  final double? barePercent;
}

class _Parser {
  _Parser(this.source);

  final String source;
  int _position = 0;

  bool get atEnd => _position >= source.length;

  String? get _peek => atEnd ? null : source[_position];

  /// expression := term (('+' | '-') term)*
  double parseExpression() {
    var total = _parseTerm().value;
    while (true) {
      final character = _peek;
      if (character != addGlyph && character != subtractGlyph) return total;
      _position++;
      final term = _parseTerm();
      // The one contextual case (D-86): a percentage under `+`/`-` is a share
      // of everything accumulated so far. `200 + 10 %` is 200 + 20, not 200.1.
      final bare = term.barePercent;
      final operand = bare == null ? term.value : total * bare / 100;
      total = character == addGlyph ? total + operand : total - operand;
    }
  }

  /// term := factor (('Ã—' | 'Ã·') factor)*, with implicit multiplication where a
  /// factor is followed directly by `(`.
  _Term _parseTerm() {
    final first = _parseFactor();
    var value = first.asOperand;
    // Only a term that never enters the loop below is a *bare* percentage, so
    // this is captured up front and cleared by the loop.
    var barePercent = first.isPercent ? first.value : null;

    while (true) {
      final character = _peek;
      if (character != multiplyGlyph &&
          character != divideGlyph &&
          character != openParenthesis &&
          !(character != null && isDigitGlyph(character))) {
        break;
      }
      // A digit can only be reached here straight after a ) or a %, because
      // [_parseNumber] has already swallowed every digit belonging to the number
      // before it. So `(3 + 4)2` is an implicit multiplication and never the
      // start of a second number, which is what stops `2 3` being read as 6.
      // An implicit multiplication consumes no glyph of its own: `2(3 + 4)`
      // leaves the `(` for the factor parser to read, and `(3 + 4)2` leaves
      // the `2`. Only an explicit operator glyph is stepped over.
      if (isBinaryOperatorGlyph(character!)) _position++;

      final operand = _parseFactor().asOperand;
      if (character == divideGlyph) {
        if (operand == 0) throw const _Failure(EvaluationStatus.undefined);
        value /= operand;
      } else {
        value *= operand;
      }
      barePercent = null;
    }

    return _Term(value, barePercent);
  }

  /// factor := number '%'* | '(' expression ')' '%'* | '-' factor
  _Factor _parseFactor() {
    final character = _peek;

    // A leading `-`, so `5 - (-3)` and `5 Ã— -2` are typeable by the expression
    // itself even though the keypad has no sign key (D-85).
    if (character == subtractGlyph) {
      _position++;
      return _Factor(-_parseFactor().asOperand);
    }

    if (character == openParenthesis) {
      _position++;
      if (_peek == closeParenthesis) {
        throw const _Failure(EvaluationStatus.invalid);
      }
      final inner = parseExpression();
      if (_peek != closeParenthesis) {
        throw const _Failure(EvaluationStatus.unbalanced);
      }
      _position++;
      return _withPercent(inner);
    }

    if (character == null ||
        (!isDigitGlyph(character) && character != dotGlyph)) {
      throw _Failure(
        atEnd ? EvaluationStatus.incomplete : EvaluationStatus.invalid,
      );
    }

    return _withPercent(_parseNumber());
  }
  /// Marks the value as carrying one or more trailing `%`.
  ///
  /// The **raw** value is kept and the hundredth is applied once in
  /// [_Factor.asOperand], which is what lets the contextual rule work: `10 %`
  /// has to reach the additive level as the `10` the left operand is taken of,
  /// not as an already-divided `0.1`. A second `%` (`5%%`) is accepted and
  /// treated as the same one, rather than being a syntax error over a glyph
  /// that is right there on the key.
  _Factor _withPercent(double value) {
    var seen = false;
    while (_peek == percentGlyph) {
      _position++;
      seen = true;
    }
    return _Factor(value, isPercent: seen);
  }

  /// A number literal: digits with at most one decimal point.
  double _parseNumber() {
    final start = _position;
    var seenDot = false;
    var digits = 0;

    while (!atEnd) {
      final character = source[_position];
      if (isDigitGlyph(character)) {
        digits++;
      } else if (character == dotGlyph && !seenDot) {
        seenDot = true;
      } else {
        break;
      }
      _position++;
    }

    if (digits == 0) {
      // A trailing `.` is a number the user has not finished, not a malformed
      // one, so it reads as incomplete rather than invalid.
      throw _Failure(
        atEnd ? EvaluationStatus.incomplete : EvaluationStatus.invalid,
      );
    }

    final value = double.tryParse(source.substring(start, _position));
    if (value == null) throw const _Failure(EvaluationStatus.invalid);
    return value;
  }
}