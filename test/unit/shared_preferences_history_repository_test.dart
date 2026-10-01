import 'dart:convert';

import 'package:calculator/features/history/data/history_repository.dart';
import 'package:calculator/features/history/data/shared_preferences_history_repository.dart';
import 'package:calculator/features/history/domain/history_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fixed "now" for every test, so `Today` / `Yesterday` are deterministic
/// without waiting for a day to pass.
final DateTime now = DateTime(2026, 9, 28, 14, 30);

HistoryEntry entry({
  String id = 'id',
  String expression = '2 + 2',
  String result = '4',
  double resultValue = 4,
  DateTime? timestamp,
}) {
  return HistoryEntry(
    id: id,
    expression: expression,
    result: result,
    resultValue: resultValue,
    timestamp: timestamp ?? now,
  );
}

/// A repository over freshly mocked preferences.
Future<SharedPreferencesHistoryRepository> makeRepository({
  Map<String, Object> initial = const <String, Object>{},
  bool enabled = true,
}) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferencesHistoryRepository(
    preferences: await SharedPreferences.getInstance(),
    isEnabled: () async => enabled,
    clock: () => now,
    idGenerator: () => 'generated-id',
  );
}

/// A repository over a fresh preferences instance seeded only with [stored] —
/// the "app relaunched" half of a restart test.
Future<SharedPreferencesHistoryRepository> makeRelaunchedRepository(
  String stored,
) =>
    makeRepository(
      initial: <String, Object>{
        SharedPreferencesHistoryRepository.storageKey: stored,
      },
    );

/// The raw persisted string, which is what would survive a process restart.
Future<String?> storedJson() async =>
    (await SharedPreferences.getInstance()).getString(
      SharedPreferencesHistoryRepository.storageKey,
    );

/// [storedJson] as a non-nullable value, failing loudly if nothing was written.
Future<String> requireStoredJson() async {
  final stored = await storedJson();
  expect(stored, isNotNull, reason: 'nothing was persisted');
  return stored!;
}

Future<List<HistoryEntry>> readAll(
  SharedPreferencesHistoryRepository repository,
) async {
  final groups = await repository.getAllGroupedByDay();
  return [for (final group in groups) ...group.entries];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('storage format (D-02)', () {
    test('writes a single key holding a JSON list', () async {
      final repository = await makeRepository();
      await repository.add(entry());

      final stored = await storedJson();
      expect(stored, isNotNull);
      final decoded = jsonDecode(stored!);
      expect(decoded, isA<List<dynamic>>());
      expect(decoded, hasLength(1));
      expect(
        (decoded as List).single,
        containsPair('expression', '2 + 2'),
      );
    });

    test('round-trips an entry through JSON unchanged', () async {
      final repository = await makeRepository();
      final original = entry(
        expression: '100 + 7 + 49 + 450 + 10',
        result: '616',
        resultValue: 616,
        timestamp: DateTime(2026, 9, 28, 9, 5, 30, 250),
      );
      await repository.add(original);

      // Read through a second repository, so nothing is reused in memory.
      final reloaded = await makeRelaunchedRepository(await requireStoredJson());
      expect(await readAll(reloaded), <HistoryEntry>[original]);
    });

    test('keeps the most recently added entry first', () async {
      // The storage invariant: the list is always ordered by descending
      // timestamp, which holds because the calculator records entries as the
      // user makes them — one at a time, in order.
      final repository = await makeRepository();
      await repository.add(entry(id: 'first-made', timestamp: now));
      await repository.add(
        entry(id: 'made-later', timestamp: now.add(const Duration(minutes: 1))),
      );

      final ids = (await readAll(repository)).map((e) => e.id).toList();
      expect(ids, <String>['made-later', 'first-made']);
    });
  });

  group('persistence across a restart (AC-006)', () {
    test('data written before a restart is readable after it', () async {
      // The strongest form of this test: nothing crosses the boundary except
      // the persisted string, so a field the JSON does not carry would fail
      // here rather than passing on an object still in memory.
      final before = await makeRepository();
      await before.add(entry(id: 'a', expression: '2 + 2', result: '4'));
      await before.add(
        entry(id: 'b', expression: '125 × 8', result: '1,000', resultValue: 1000),
      );

      final onDisk = await requireStoredJson();

      // Simulate the process restart: a brand new preferences instance seeded
      // only with what was actually written.
      final after = await makeRelaunchedRepository(onDisk);

      final restored = await readAll(after);
      expect(restored, hasLength(2));
      expect(restored.first.expression, '125 × 8');
      expect(restored.first.result, '1,000');
      expect(restored.first.resultValue, 1000);
      expect(restored.last.expression, '2 + 2');
    });

    test('starts empty when the key was never written', () async {
      final repository = await makeRepository();
      expect(await repository.getAllGroupedByDay(), isEmpty);
    });
  });

  group('the 200-entry cap (AC-014, D-02)', () {
    test('keeps the newest 200 and evicts the oldest first', () async {
      final repository = await makeRepository();

      // Added one at a time in order, so `entry-249` is the most recent and the
      // tail is what a cap has to discard.
      for (var i = 0; i < 250; i++) {
        await repository.add(entry(id: 'entry-$i'));
      }

      final stored = await readAll(repository);
      expect(stored, hasLength(HistoryRepository.maxEntries));
      expect(stored.first.id, 'entry-249');
      expect(stored.last.id, 'entry-50');
      expect(
        stored.any((e) => e.id == 'entry-49'),
        isFalse,
        reason: 'the oldest entry must have been evicted',
      );
    });

    test('exactly at the cap keeps everything', () async {
      final repository = await makeRepository();
      for (var i = 0; i < HistoryRepository.maxEntries; i++) {
        await repository.add(entry(id: 'entry-$i'));
      }
      expect(await readAll(repository), hasLength(HistoryRepository.maxEntries));
    });

    test('enforces the cap on the persisted JSON, not just the read', () async {
      final repository = await makeRepository();
      for (var i = 0; i < HistoryRepository.maxEntries + 5; i++) {
        await repository.add(entry(id: 'entry-$i'));
      }
      final decoded = jsonDecode((await storedJson())!) as List<dynamic>;
      expect(decoded, hasLength(HistoryRepository.maxEntries));
    });
  });

  group('the history toggle (AC-005)', () {
    test('add is a no-op while disabled', () async {
      final repository = await makeRepository(enabled: false);
      await repository.add(entry());

      expect(await storedJson(), isNull);
      expect(await repository.getAllGroupedByDay(), isEmpty);
    });

    test('isEnabled reflects the setting', () async {
      expect(await (await makeRepository()).isEnabled(), isTrue);
      expect(await (await makeRepository(enabled: false)).isEnabled(), isFalse);
    });

    test('disabling stops new entries but keeps existing ones (FEAT-HIST-004)',
        () async {
      final repository = await makeRepository();
      await repository.add(entry(id: 'kept'));

      final off = SharedPreferencesHistoryRepository(
        preferences: await SharedPreferences.getInstance(),
        isEnabled: () async => false,
        clock: () => now,
        idGenerator: () => 'unused',
      );
      await off.add(entry(id: 'dropped'));

      final ids = (await readAll(off)).map((e) => e.id).toList();
      expect(ids, <String>['kept']);
    });
  });

  group('addResult', () {
    test('assigns an id and a timestamp from the repository', () async {
      final repository = await makeRepository();
      await repository.addResult(
        expression: '2 + 2',
        result: '4',
        resultValue: 4,
      );

      final stored = await readAll(repository);
      expect(stored, hasLength(1));
      expect(stored.single.id, 'generated-id');
      expect(stored.single.timestamp, now);
    });

    test('respects the toggle', () async {
      final repository = await makeRepository(enabled: false);
      await repository.addResult(
        expression: '2 + 2',
        result: '4',
        resultValue: 4,
      );
      expect(await readAll(repository), isEmpty);
    });
  });

  group('clearAll (AC-008)', () {
    test('empties the list and removes the key', () async {
      final repository = await makeRepository();
      await repository.add(entry());
      expect(await storedJson(), isNotNull);

      await repository.clearAll();

      expect(await storedJson(), isNull);
      expect(await repository.getAllGroupedByDay(), isEmpty);
    });

    test('is safe on an already-empty history', () async {
      final repository = await makeRepository();
      await repository.clearAll();
      expect(await repository.getAllGroupedByDay(), isEmpty);
    });
  });

  group('corrupt data degrades instead of throwing', () {
    Future<SharedPreferencesHistoryRepository> withRaw(Object value) =>
        makeRepository(
          initial: <String, Object>{
            SharedPreferencesHistoryRepository.storageKey: value,
          },
        );

    test('ignores a value that is not JSON', () async {
      final repository = await withRaw('not json at all {{{');
      expect(await repository.getAllGroupedByDay(), isEmpty);
    });

    test('ignores JSON that is not a list', () async {
      final repository = await withRaw('{"id":"a"}');
      expect(await repository.getAllGroupedByDay(), isEmpty);
    });

    test('ignores a list of non-objects', () async {
      final repository = await withRaw('[1, 2, 3]');
      expect(await repository.getAllGroupedByDay(), isEmpty);
    });

    test('drops only the malformed record, keeping the rest', () async {
      final repository = await withRaw(
        jsonEncode(<Object>[
          entry(id: 'good').toJson(),
          <String, Object>{'id': 'missing-everything-else'},
          entry(id: 'also-good').toJson(),
        ]),
      );

      final ids = (await readAll(repository)).map((e) => e.id).toList();
      expect(ids, <String>['good', 'also-good']);
    });

    test('an entry with an unparseable timestamp is dropped', () async {
      final repository = await withRaw(
        jsonEncode(<Object>[
          <String, Object>{
            'id': 'bad',
            'expression': '1 + 1',
            'result': '2',
            'resultValue': 2,
            'timestamp': 'not-a-date',
          },
        ]),
      );
      expect(await repository.getAllGroupedByDay(), isEmpty);
    });
  });

  group('day grouping (AC-002)', () {
    // `add` inserts at index 0, so entries arrive in the order the user made
    // them — chronologically. The tests below insert oldest-first to match what
    // actually happens; `stores entries in the order they were added` covers the
    // invariant itself.
    test('an empty history produces no groups', () async {
      final repository = await makeRepository();
      expect(await repository.getAllGroupedByDay(), isEmpty);
    });

    test('splits Today from Yesterday, newest day first', () async {
      final repository = await makeRepository();
      await repository.add(entry(id: 'y1', timestamp: DateTime(2026, 9, 27, 22)));
      await repository.add(entry(id: 't1', timestamp: now));

      final groups = await repository.getAllGroupedByDay();
      expect(
        groups.map((g) => g.label),
        <String>['Today', 'Yesterday'],
      );
      expect(groups.first.entries.map((e) => e.id), <String>['t1']);
      expect(groups.last.entries.map((e) => e.id), <String>['y1']);
    });

    test('collapses a same-day run into one group, newest entry first',
        () async {
      final repository = await makeRepository();
      await repository.add(entry(id: 'a', timestamp: DateTime(2026, 9, 28, 8)));
      await repository.add(entry(id: 'b', timestamp: DateTime(2026, 9, 28, 9)));
      await repository.add(entry(id: 'c', timestamp: DateTime(2026, 9, 28, 10)));

      final groups = await repository.getAllGroupedByDay();
      expect(groups, hasLength(1));
      expect(groups.single.label, 'Today');
      expect(groups.single.entries.map((e) => e.id), <String>['c', 'b', 'a']);
    });

    test('labels an older day with its calendar date', () async {
      final repository = await makeRepository();
      await repository.add(entry(timestamp: DateTime(2026, 9, 20, 12)));

      final groups = await repository.getAllGroupedByDay();
      expect(groups.single.label, 'Sep 20, 2026');
    });

    test('keeps days in descending order', () async {
      final repository = await makeRepository();
      await repository.add(entry(timestamp: DateTime(2026, 9, 10)));
      await repository.add(entry(timestamp: DateTime(2026, 9, 27)));
      await repository.add(entry(timestamp: DateTime(2026, 9, 28)));

      final groups = await repository.getAllGroupedByDay();
      expect(
        groups.map((g) => g.label),
        <String>['Today', 'Yesterday', 'Sep 10, 2026'],
      );
    });

    test('exposes each group as an unmodifiable list', () async {
      final repository = await makeRepository();
      await repository.add(entry());

      final groups = await repository.getAllGroupedByDay();
      expect(
        () => groups.single.entries.add(entry()),
        throwsUnsupportedError,
      );
    });
  });
}
