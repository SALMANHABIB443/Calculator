import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/uuid.dart';
import '../domain/history_entry.dart';
import 'history_repository.dart';

/// `HistoryRepository` over `shared_preferences` (D-02).
///
/// One key holds one JSON-encoded list. That is the whole storage design, and
/// D-02 chose it deliberately: history is a small, flat, append-only list, so a
/// database would add a dependency and native setup for no benefit at 200 rows.
///
/// **Newest-first ordering is the storage invariant.** [addResult] inserts at
/// index 0, so the list is always ordered by descending [HistoryEntry.timestamp].
/// The calculator records entries as the user makes them, one at a time, so the
/// insertion order *is* the chronological order. Two things fall out for free:
///
/// - Oldest-first eviction is a [List.sublist], not a search for the minimum
///   timestamp, so a write never has to sort.
/// - Day grouping is a single forward pass, because entries sharing a calendar
///   day are always contiguous.
///
/// **Every read degrades to an empty list.** D-02 requires the repository to
/// work when the platform channel is unavailable so unit tests pass without
/// mocking. A missing plugin, a truncated string, a JSON object where a list
/// was expected, or one corrupt record all yield `[]` rather than throwing: a
/// history list that fails to load should show the empty state, never crash the
/// screen the user opened in order to look at it.
class SharedPreferencesHistoryRepository implements HistoryRepository {
  SharedPreferencesHistoryRepository({
    required this.preferences,
    Future<bool> Function()? isEnabled,
    DateTime Function()? clock,
    String Function()? idGenerator,
  })  : _isEnabled = isEnabled ?? _alwaysEnabled,
        _clock = clock ?? DateTime.now,
        _idGenerator = idGenerator ?? uuidV4;

  /// The single key holding the JSON-encoded list.
  static const String storageKey = 'history_entries';

  final SharedPreferences preferences;
  final Future<bool> Function() _isEnabled;
  final DateTime Function() _clock;
  final String Function() _idGenerator;

  static Future<bool> _alwaysEnabled() async => true;

  @override
  Future<List<HistoryDayGroup>> getAllGroupedByDay() async =>
      groupByDay(await _readAll(), now: _clock());

  @override
  Future<void> add(HistoryEntry entry) async {
    if (!await _isEnabled()) return;

    final entries = await _readAll()..insert(0, entry);
    await _writeAll(entries);
  }

  @override
  Future<HistoryEntry> addResult({
    required String expression,
    required String result,
    required double resultValue,
  }) async {
    final entry = HistoryEntry(
      id: _idGenerator(),
      expression: expression,
      result: result,
      resultValue: resultValue,
      timestamp: _clock(),
    );

    await add(entry);
    return entry;
  }

  @override
  Future<void> deleteByIds(Set<String> ids) async {
    if (ids.isEmpty) return;

    final remaining =
        (await _readAll()).where((entry) => !ids.contains(entry.id)).toList();

    // The same reasoning as [clearAll]: when the delete empties the store, the
    // key is removed outright rather than rewritten as `[]`, so a fully cleared
    // history leaves nothing behind in the platform's file.
    if (remaining.isEmpty) return clearAll();

    await _writeAll(remaining);
  }

  @override
  Future<void> clearAll() async {
    // Remove the key outright rather than storing `[]`, so a cleared history
    // leaves nothing behind in the platform's XML file.
    await preferences.remove(storageKey);
  }

  @override
  Future<bool> isEnabled() => _isEnabled();

  /// The stored entries, newest first.
  ///
  /// Drops any record [HistoryEntry.fromJson] rejects, so one corrupt entry
  /// costs the user that row and not their whole history.
  Future<List<HistoryEntry>> _readAll() async {
    try {
      final stored = preferences.getString(storageKey);
      if (stored == null) return <HistoryEntry>[];

      final decoded = jsonDecode(stored);
      if (decoded is! List) return <HistoryEntry>[];

      final entries = <HistoryEntry>[];
      for (final record in decoded) {
        if (record is! Map<String, dynamic>) continue;
        final entry = HistoryEntry.fromJson(record);
        if (entry != null) entries.add(entry);
      }
      return entries;
    } on FormatException {
      // Not valid JSON at all.
      return <HistoryEntry>[];
    } on TypeError {
      // jsonDecode returned a type the cast above rejected.
      return <HistoryEntry>[];
    }
  }

  /// Writes [entries] newest-first, evicting the oldest beyond the cap (D-02,
  /// prd.md AC-014).
  Future<void> _writeAll(List<HistoryEntry> entries) async {
    final capped = entries.length > HistoryRepository.maxEntries
        ? entries.sublist(0, HistoryRepository.maxEntries)
        : entries;

    await preferences.setString(
      storageKey,
      jsonEncode(<Map<String, dynamic>>[
        for (final entry in capped) entry.toJson(),
      ]),
    );
  }
}