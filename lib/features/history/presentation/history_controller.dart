/// The history feature's Riverpod wiring: where the repository comes from, and
/// the notifier the History screen reads (D-39).
///
/// This file deliberately imports **nothing** from the calculator feature. The
/// dependency runs the other way — `CalculatorController` calls
/// [HistoryNotifier.record] — so history stays unaware of the calculator and the
/// two features cannot form a cycle. For the same reason [record] takes the
/// finished strings rather than a `CalculatorState`: the identifier and the
/// timestamp belong to the storage layer, and the formatting to the calculator.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences_provider.dart';
// Imports the feature's public surface rather than a path into its internals
// (D-57), so the settings providers can move again without touching this file.
import '../../settings/settings.dart';
import '../data/history_repository.dart';
import '../data/shared_preferences_history_repository.dart';
import '../domain/history_entry.dart';

/// The application's history storage.
///
/// Resolves to the `shared_preferences` implementation (D-02), falling back to
/// [InMemoryHistoryRepository] if the plugin is unavailable.
///
/// One caveat worth knowing before writing a test: this catches *throws*, and a
/// missing plugin in a widget test does not throw — the pending platform call
/// simply never completes, so the screen waits on its progress indicator and
/// `pumpAndSettle` times out. The fallback therefore does not rescue unmocked
/// widget tests. Mock the store instead; see `test/support/pump_app.dart`.
final historyRepositoryProvider = FutureProvider<HistoryRepository>((
  ref,
) async {
  try {
    final preferences = await ref.watch(preferencesProvider);
    return SharedPreferencesHistoryRepository(
      preferences: preferences,
      // D-40: the toggle is read through the settings provider, so Phase 6
      // swapping in the real settings repository changes nothing here.
      isEnabled: () async => ref.read(settingsProvider).historyEnabled,
    );
  } catch (_) {
    // The fallback gets the same toggle as the real repository, so a user who
    // turned history off keeps it off even while storage is unavailable.
    return InMemoryHistoryRepository(
      isEnabled: () async => ref.read(settingsProvider).historyEnabled,
    );
  }
});

/// The day-grouped history the screen renders, newest day first.
///
/// An [AsyncNotifier] because the repository is asynchronous: on a cold start the
/// History screen can mount before the disk has been read, and the screen handles
/// those three states explicitly rather than flashing an empty list and then
/// popping entries in.
final historyControllerProvider =
    AsyncNotifierProvider<HistoryNotifier, List<HistoryDayGroup>>(
      HistoryNotifier.new,
    );

/// Reads, appends to, and clears the history list.
class HistoryNotifier extends AsyncNotifier<List<HistoryDayGroup>> {
  @override
  Future<List<HistoryDayGroup>> build() async {
    final repository = await ref.watch(historyRepositoryProvider.future);
    return repository.getAllGroupedByDay();
  }

  /// The repository.
  ///
  /// Awaited on every use rather than read once into a field: on a cold start
  /// the first calculation is usually evaluated before `shared_preferences` has
  /// finished handing back its instance, and a record call that found no
  /// repository yet would drop the user's very first result. Every caller here
  /// is already async, so waiting costs nothing that matters.
  Future<HistoryRepository> get _repository =>
      ref.read(historyRepositoryProvider.future);

  /// Records a completed calculation (feature.md FEAT-HIST-004, AC-002).
  ///
  /// The repository enforces the history toggle, so a caller cannot forget to
  /// check it (AC-005).
  ///
  /// Not awaited by the caller: the calculator invokes this after a key press,
  /// and the user must never wait on a disk write to see their result. The list
  /// is rebuilt from storage afterwards rather than appended optimistically, so
  /// what the screen shows is always what the repository actually holds — and
  /// two rapid `=` presses cannot race into a duplicate or a lost entry.
  Future<void> record({
    required String expression,
    required String result,
    required double resultValue,
  }) async {
    final repository = await _repository;

    await repository.addResult(
      expression: expression,
      result: result,
      resultValue: resultValue,
    );

    ref.invalidateSelf();
    await future;
  }

  /// Deletes the entries in [ids] and no others. The caller is responsible for
  /// the confirmation dialog, exactly as for [clearAll] (D-05, AC-008).
  ///
  /// Kept beside [clearAll] rather than folded into it so the destructive
  /// actions stay two named operations at the notifier: a bulk delete of a
  /// known set and a wipe are different intents, and a caller reaching for the
  /// wrong one is a bug this separation makes visible in review.
  Future<void> deleteSelected(Set<String> ids) async {
    if (ids.isEmpty) return;

    final repository = await _repository;

    await repository.deleteByIds(ids);
    ref.invalidateSelf();
    await future;
  }

  /// Empties the history. The caller is responsible for the confirmation dialog
  /// (D-05, AC-008).
  Future<void> clearAll() async {
    final repository = await _repository;

    await repository.clearAll();
    ref.invalidateSelf();
    await future;
  }
}

/// A [HistoryRepository] that keeps everything in memory and forgets it all when
/// the process ends.
///
/// The fallback for when `shared_preferences` cannot be reached, and the fake
/// tests can use directly. It honours the same cap as the real one, so a test
/// written against it exercises the behaviour the app ships rather than a looser
/// approximation of it. [isEnabled] defaults to enabled so a test that does not
/// care about the toggle does not have to supply it.
class InMemoryHistoryRepository implements HistoryRepository {
  InMemoryHistoryRepository({
    DateTime Function()? clock,
    this.idGenerator,
    Future<bool> Function()? isEnabled,
  }) : _clock = clock ?? DateTime.now,
       _isEnabled = isEnabled ?? (() async => true);

  int _counter = 0;

  /// An instance counter rather than a static one, so ids never depend on test
  /// execution order.
  String _nextId() => idGenerator?.call() ?? 'memory-${_counter++}';

  final DateTime Function() _clock;
  final String Function()? idGenerator;
  final Future<bool> Function() _isEnabled;
  final List<HistoryEntry> _entries = <HistoryEntry>[];

  @override
  Future<List<HistoryDayGroup>> getAllGroupedByDay() async =>
      groupByDay(List<HistoryEntry>.unmodifiable(_entries), now: _clock());

  @override
  Future<void> add(HistoryEntry entry) async {
    if (!await isEnabled()) return;
    _entries.insert(0, entry);
    if (_entries.length > HistoryRepository.maxEntries) {
      _entries.removeRange(HistoryRepository.maxEntries, _entries.length);
    }
  }

  @override
  Future<HistoryEntry> addResult({
    required String expression,
    required String result,
    required double resultValue,
  }) async {
    final entry = HistoryEntry(
      id: _nextId(),
      expression: expression,
      result: result,
      resultValue: resultValue,
      timestamp: _clock(),
    );

    await add(entry);
    return entry;
  }

  @override
  Future<void> deleteByIds(Set<String> ids) async =>
      _entries.removeWhere((entry) => ids.contains(entry.id));

  @override
  Future<void> clearAll() async => _entries.clear();

  @override
  Future<bool> isEnabled() => _isEnabled();
}