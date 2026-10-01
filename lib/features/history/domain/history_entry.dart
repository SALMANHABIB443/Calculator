/// One recorded calculation, as stored by the history repository
/// (struction.md §9).
///
/// Serialised into a single JSON-encoded list under one
/// `shared_preferences` key, capped at 200 entries (D-02).
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.expression,
    required this.result,
    required this.resultValue,
    required this.timestamp,
  });

  /// Stable identifier (UUID v4) assigned when the calculation succeeds.
  final String id;

  /// Human-readable expression, e.g. `100 + 7 + 49 + 450 + 10`.
  final String expression;

  /// Formatted result exactly as it was displayed, e.g. `1,234.57`.
  final String result;

  /// Raw numeric result, kept so a history item can be loaded back into the
  /// calculator without re-parsing the formatted string.
  final double resultValue;

  /// When the calculation completed. Drives the Today / Yesterday grouping
  /// in the presentation layer (the day is not stored separately).
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'id': id,
        'expression': expression,
        'result': result,
        'resultValue': resultValue,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Restores an entry written by [toJson].
  ///
  /// Returns `null` for malformed records instead of throwing, so a single
  /// corrupt entry cannot take down the whole history list.
  static HistoryEntry? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final expression = json['expression'];
    final result = json['result'];
    final resultValue = json['resultValue'];
    final timestamp = json['timestamp'];

    if (id is! String ||
        expression is! String ||
        result is! String ||
        resultValue is! num ||
        timestamp is! String) {
      return null;
    }

    final parsedDate = DateTime.tryParse(timestamp);
    if (parsedDate == null) return null;

    return HistoryEntry(
      id: id,
      expression: expression,
      result: result,
      resultValue: resultValue.toDouble(),
      timestamp: parsedDate,
    );
  }

  /// Compares by content, so a re-read from storage is equal to the entry that
  /// was written and a test can assert a whole object instead of five fields.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryEntry &&
          other.id == id &&
          other.expression == expression &&
          other.result == result &&
          other.resultValue == resultValue &&
          other.timestamp == timestamp;

  @override
  int get hashCode =>
      Object.hash(id, expression, result, resultValue, timestamp);

  @override
  String toString() =>
      'HistoryEntry($expression = $result, id: $id, at: $timestamp)';
}
