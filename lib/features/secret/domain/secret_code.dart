/// A four-digit secret PIN (D-83, struction.md §10).
///
/// A **type** rather than a `String`, on purpose. The stored value can be
/// hand-edited, restored from a backup, or typed in by the Change PIN flow, so
/// "four decimal digits" is a claim that has to be enforced somewhere. Putting
/// the check in the constructor means a malformed code cannot *exist* as a
/// value — not at a call site, not in the repository, not in a widget's field —
/// and every later reader (the verifier, the storage key, the comparison) gets
/// the guarantee for free instead of re-deriving it.
///
/// The app never renders the code, so there is deliberately no `toString()`
/// override that would make a stray interpolation leak it into a log line. The
/// [value] getter is the only way out, and it is there because storage needs it.
class SecretCode {
  /// Wraps [value], rejecting anything that is not exactly four decimal digits.
  ///
  /// Throws [FormatException] rather than accepting a malformed code: the
  /// failure modes the docs care about are a corrupt store and a user typing
  /// three digits, and both are handled by *never getting here* — the repository
  /// degrades before constructing, and the UI only constructs once four digits
  /// are in. A code that quietly coerced `"12"` to `"0012"` would turn a typo
  /// into a code the user never chose.
  SecretCode(this.value) {
    if (!isWellFormed(value)) {
      throw FormatException(
        'A secret code is exactly four decimal digits',
        value,
      );
    }
  }

  /// The code a fresh install opens with (D-83).
  ///
  /// Named rather than spelled at call sites so the default is one fact in the
  /// codebase: the repository's fallback, the docs, and the tests all read this.
  static final SecretCode defaultCode = SecretCode('0000');

  /// Exactly the digits of the code, as a `String`.
  final String value;

  /// Whether [candidate] is a well-formed code, without throwing.
  ///
  /// This is what callers use to *decide* whether to construct; the constructor
  /// is what guarantees it. Exposing both is the whole design: the check is not
  /// hidden behind a `tryParse`, so a caller cannot forget that it exists.
  static bool isWellFormed(String? candidate) {
    if (candidate == null || candidate.length != length) return false;
    for (final unit in candidate.codeUnits) {
      if (unit < 0x30 || unit > 0x39) return false;
    }
    return true;
  }

  /// How many digits a code has — four, everywhere (AC-018).
  static const int length = 4;

  /// The code as it is written to storage.
  String get digits => value;

  @override
  bool operator ==(Object other) =>
      other is SecretCode && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'SecretCode(****)';
}