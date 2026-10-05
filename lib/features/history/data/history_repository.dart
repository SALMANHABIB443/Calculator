import '../../../core/utils/date_group.dart';
import '../domain/history_entry.dart';

/// Storage boundary for calculation history (struction.md §9).
///
/// The Phase 5 implementation is backed by `shared_preferences` holding a
/// single JSON-encoded list capped at 200 entries with oldest-first eviction
/// (D-02). Keeping this abstract lets tests substitute an in-memory fake.
abstract class HistoryRepository {
  /// Hard ceiling on how many entries are kept, per D-02 and prd.md AC-014.
  ///
  /// On the interface rather than a constructor argument on the concrete class:
  /// it is a product rule, not an implementation detail, so every implementation
  /// owes the same behaviour and a test can assert against a single name.
  static const int maxEntries = 200;

  /// Every stored entry, newest first, grouped into presentation-ready day
  /// sections (`Today`, `Yesterday`, older dates). Grouping happens in this
  /// layer so the UI never has to bucket timestamps itself.
  Future<List<HistoryDayGroup>> getAllGroupedByDay();

  /// Appends [entry] verbatim, honouring the history toggle and the cap.
  ///
  /// The low-level write, for a caller that already holds a fully-formed entry —
  /// which is what lets a test seed a precise timestamp and identifier.
  /// Application code wants [addResult] instead.
  Future<void> add(HistoryEntry entry);

  /// Records a completed calculation and returns the stored entry.
  ///
  /// Takes the finished strings rather than a [HistoryEntry] because the
  /// identifier and the timestamp are the storage layer's to mint — that is the
  /// format's business, and pushing it to the caller would spread the storage
  /// schema into the feature that happens to write to it (D-39). It also means
  /// the in-memory fallback and the real repository cannot drift apart on how an
  /// entry is built.
  Future<HistoryEntry> addResult({
    required String expression,
    required String result,
    required double resultValue,
  });

  /// Removes every entry whose [HistoryEntry.id] is in [ids].
  ///
  /// Takes identifiers rather than entries because the ids are what the
  /// presentation layer holds: a multi-select keeps a set of strings across
  /// rebuilds, and having it resolve them back to entries before calling would
  /// push the join into the screen.
  ///
  /// **Not** a partial [clearAll]. The surviving entries keep their relative
  /// order, so the newest-first storage invariant (D-02) is untouched and the
  /// day grouping below is unaffected — the screen re-groups from the same
  /// source it always did, and no caller has to know which groups lost rows.
  ///
  /// Unknown ids are ignored rather than an error: the list can change between a
  /// selection being made and the delete landing, and a stale id in the set
  /// should cost the user nothing.
  Future<void> deleteByIds(Set<String> ids);

  /// Removes every entry.
  Future<void> clearAll();

  /// Whether new entries should be recorded — mirrors the `historyEnabled`
  /// setting.
  Future<bool> isEnabled();
}

/// A run of entries that share a calendar day.
class HistoryDayGroup {
  const HistoryDayGroup({required this.label, required this.entries});

  /// Section header, e.g. `Today`, `Yesterday`, `Sep 20, 2026`.
  final String label;

  /// Entries in this day, newest first.
  final List<HistoryEntry> entries;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryDayGroup &&
          other.label == label &&
          _entriesEqual(other.entries, entries);

  @override
  int get hashCode => Object.hash(label, Object.hashAll(entries));

  @override
  String toString() => 'HistoryDayGroup($label, ${entries.length} entries)';
}

/// Splits newest-first [entries] into labelled day sections.
///
/// The single implementation of the grouping rule, shared by every repository
/// so they cannot disagree about which section an entry belongs in.
///
/// Consecutive runs sharing a label become one group, which is why [entries]
/// must arrive sorted: a calendar day is one contiguous run, not a set of rows
/// to gather. [dayGroupLabel] decides the label, so `Today` / `Yesterday` / a
/// calendar date are defined in exactly one place and are already unit-tested
/// across midnight, month, year, and leap-day boundaries.
///
/// [now] is read once by the caller and threaded through, so every entry in a
/// single call is judged against the same instant — otherwise a read straddling
/// midnight would split one day across a `Today` and a `Yesterday` group.
List<HistoryDayGroup> groupByDay(
  List<HistoryEntry> entries, {
  required DateTime now,
}) {
  final groups = <HistoryDayGroup>[];

  var label = '';
  var run = <HistoryEntry>[];

  for (final entry in entries) {
    final entryLabel = dayGroupLabel(entry.timestamp, now: now);
    if (entryLabel != label) {
      if (run.isNotEmpty) {
        groups.add(
          HistoryDayGroup(
            label: label,
            entries: List<HistoryEntry>.unmodifiable(run),
          ),
        );
      }
      label = entryLabel;
      run = <HistoryEntry>[];
    }
    run.add(entry);
  }

  if (run.isNotEmpty) {
    groups.add(
      HistoryDayGroup(
        label: label,
        entries: List<HistoryEntry>.unmodifiable(run),
      ),
    );
  }

  return groups;
}

/// Lists do not compare by content, and `listEquals` lives in
/// `package:flutter/foundation.dart` — which the domain layer should not import
/// for this. Same approach as the engine's term comparison.
bool _entriesEqual(List<HistoryEntry> a, List<HistoryEntry> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}