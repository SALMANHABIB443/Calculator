import 'dart:async';

import 'package:calculator/core/storage/preferences_provider.dart';
import 'package:calculator/features/history/data/history_repository.dart';
import 'package:calculator/features/history/presentation/history_controller.dart';
import 'package:calculator/features/settings/presentation/settings_controller.dart';
import 'package:calculator/features/settings/domain/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wires a container to [repository], bypassing `shared_preferences` entirely.
ProviderContainer containerWith(HistoryRepository repository) {
  final container = ProviderContainer(
    overrides: [
      historyRepositoryProvider.overrideWith((ref) async => repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('records a completed calculation', () async {
    final repository = InMemoryHistoryRepository();
    final container = containerWith(repository);

    await container
        .read(historyControllerProvider.notifier)
        .record(expression: '2 + 2', result: '4', resultValue: 4);

    final groups = await container.read(historyControllerProvider.future);
    expect(groups.single.entries.single.expression, '2 + 2');
  });

  test('records before the repository has finished loading', () async {
    // The regression this guards: the very first calculation of a session is
    // usually made before `shared_preferences` has handed back its instance, and
    // a `record` that found no repository yet would drop it silently.
    final gate = Completer<HistoryRepository>();
    final container = ProviderContainer(
      overrides: [historyRepositoryProvider.overrideWith((ref) => gate.future)],
    );
    addTearDown(container.dispose);

    final pending = container
        .read(historyControllerProvider.notifier)
        .record(expression: '2 + 2', result: '4', resultValue: 4);

    final repository = InMemoryHistoryRepository();
    gate.complete(repository);
    await pending;

    final groups = await container.read(historyControllerProvider.future);
    expect(groups.single.entries.single.resultValue, 4);
  });

  test('clears every entry', () async {
    final repository = InMemoryHistoryRepository();
    final container = containerWith(repository);
    final notifier = container.read(historyControllerProvider.notifier);

    await notifier.record(expression: '1 + 1', result: '2', resultValue: 2);
    await notifier.clearAll();

    expect(await container.read(historyControllerProvider.future), isEmpty);
    expect(await repository.getAllGroupedByDay(), isEmpty);
  });

  test('clears even when called before the repository has loaded', () async {
    final gate = Completer<HistoryRepository>();
    final container = ProviderContainer(
      overrides: [historyRepositoryProvider.overrideWith((ref) => gate.future)],
    );
    addTearDown(container.dispose);

    final pending = container.read(historyControllerProvider.notifier).clearAll();
    final repository = InMemoryHistoryRepository();
    gate.complete(repository);
    await pending;

    expect(await repository.getAllGroupedByDay(), isEmpty);
  });

  test('the toggle is read on every write, not cached at construction', () async {
    var enabled = true;
    final repository = InMemoryHistoryRepository(
      isEnabled: () async => enabled,
    );
    final container = containerWith(repository);
    final notifier = container.read(historyControllerProvider.notifier);

    await notifier.record(expression: '1 + 1', result: '2', resultValue: 2);
    enabled = false;
    await notifier.record(expression: '2 + 2', result: '4', resultValue: 4);

    final entries = await repository.getAllGroupedByDay();
    expect(entries.single.entries.map((entry) => entry.expression), ['1 + 1']);
  });

  test('the in-memory fallback honours the history setting (D-40, AC-005)', () async {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWithValue(
          AppSettings.defaults.copyWith(historyEnabled: false),
        ),
        // Force the fallback by making acquisition fail.
        preferencesProvider.overrideWith((ref) async => throw StateError('no')),
      ],
    );
    addTearDown(container.dispose);

    final repository = await container.read(historyRepositoryProvider.future);
    expect(repository, isA<InMemoryHistoryRepository>());

    await repository.addResult(
      expression: '2 + 2',
      result: '4',
      resultValue: 4,
    );

    expect(await repository.getAllGroupedByDay(), isEmpty);
  });

  test('the in-memory fallback keeps the same cap as the real one', () async {
    final repository = InMemoryHistoryRepository();

    for (var i = 0; i < HistoryRepository.maxEntries + 5; i++) {
      await repository.addResult(
        expression: '$i',
        result: '$i',
        resultValue: i.toDouble(),
      );
    }

    final groups = await repository.getAllGroupedByDay();
    expect(groups.expand((group) => group.entries), hasLength(200));
  });

  test('an unreadable store degrades to in-memory rather than failing', () async {
    final container = ProviderContainer(
      overrides: [
        preferencesProvider.overrideWith((ref) async => throw StateError('no')),
      ],
    );
    addTearDown(container.dispose);

    // D-02: the screen must render something, not an error.
    expect(await container.read(historyControllerProvider.future), isEmpty);
  });
}
