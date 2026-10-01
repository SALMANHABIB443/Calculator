import 'dart:async';

import 'package:calculator/core/storage/preferences_provider.dart';
import 'package:calculator/features/settings/data/settings_repository.dart';
import 'package:calculator/features/settings/data/shared_preferences_settings_repository.dart';
import 'package:calculator/features/settings/domain/app_settings.dart';
import 'package:calculator/features/settings/presentation/settings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A repository whose [load] the test resolves by hand, so a write can be made
/// to land *while* the read is still outstanding.
class ControllableRepository implements SettingsRepository {
  Completer<AppSettings>? _load;

  final List<AppSettings> saved = <AppSettings>[];

  void holdLoad() => _load = Completer<AppSettings>();

  void releaseLoad(AppSettings settings) {
    _load!.complete(settings);
    _load = null;
  }

  @override
  Future<AppSettings> load() async {
    final pending = _load;
    if (pending != null) return pending.future;
    return AppSettings.defaults;
  }

  @override
  Future<void> save(AppSettings settings) async => saved.add(settings);
}

/// The settings notifier: load, write, persist, and the degradation path
/// (AC-004, AC-006, D-41, D-43).
void main() {
  ProviderContainer containerWith(SettingsRepository repository) {
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('load', () {
    test('publishes what the repository returns', () async {
      final stored = AppSettings.defaults.copyWith(
        decimalPlaces: 5,
        historyEnabled: false,
      );
      final container = containerWith(InMemorySettingsRepository(stored));

      final loaded = await container.read(settingsControllerProvider.future);

      expect(loaded, stored);
    });

    test('the synchronous view mirrors the loaded value (D-41)', () async {
      final stored = AppSettings.defaults.copyWith(decimalPlaces: 3);
      final container = containerWith(InMemorySettingsRepository(stored));

      expect(container.read(settingsProvider), AppSettings.defaults);
      await container.read(settingsControllerProvider.future);
      expect(container.read(settingsProvider), stored);
    });

    test('the synchronous view falls back to defaults while loading', () async {
      final repository = ControllableRepository()..holdLoad();
      final container = containerWith(repository);

      // Reading the notifier starts the build, which is now parked.
      unawaited(container.read(settingsControllerProvider.future));
      expect(container.read(settingsControllerProvider).isLoading, isTrue);

      // A key pressed in that window must still round with a usable precision.
      expect(container.read(settingsProvider), AppSettings.defaults);
      expect(container.read(settingsProvider).decimalPlaces, 2);
    });
  });

  group('apply', () {
    test('publishes the new value and persists it', () async {
      final repository = InMemorySettingsRepository();
      final container = containerWith(repository);
      await container.read(settingsControllerProvider.future);

      await container
          .read(settingsControllerProvider.notifier)
          .apply((s) => s.copyWith(decimalPlaces: 6, historyEnabled: false));

      final expected = AppSettings.defaults.copyWith(
        decimalPlaces: 6,
        historyEnabled: false,
      );
      expect(container.read(settingsProvider), expected);
      expect(repository.current, expected);
    });

    test('persists exactly once, with the whole object', () async {
      final repository = InMemorySettingsRepository();
      final container = containerWith(repository);
      await container.read(settingsControllerProvider.future);

      await container
          .read(settingsControllerProvider.notifier)
          .apply((s) => s.copyWith(soundEnabled: false));

      expect(repository.current.soundEnabled, isFalse);
      // The rest of the object is carried through, not reset to defaults.
      expect(repository.current.decimalPlaces, 2);
    });

    test('a change that changes nothing writes nothing', () async {
      final repository = ControllableRepository();
      final container = containerWith(repository);
      await container.read(settingsControllerProvider.future);

      await container
          .read(settingsControllerProvider.notifier)
          .apply((s) => s.copyWith(soundEnabled: s.soundEnabled));

      expect(repository.saved, isEmpty);
    });

    test('leaves the other preferences untouched', () async {
      final container = containerWith(
        InMemorySettingsRepository(
          AppSettings.defaults.copyWith(decimalPlaces: 4),
        ),
      );
      await container.read(settingsControllerProvider.future);

      await container
          .read(settingsControllerProvider.notifier)
          .apply((s) => s.copyWith(vibrationEnabled: false));

      final settings = container.read(settingsProvider);
      expect(settings.vibrationEnabled, isFalse);
      expect(settings.soundEnabled, isTrue);
      expect(settings.decimalPlaces, 4);
      expect(settings.historyEnabled, isTrue);
    });
  });

  group('a write that beats the initial load (D-43)', () {
    test('the user change survives the load resolving', () async {
      final repository = ControllableRepository()..holdLoad();
      final container = containerWith(repository);

      // Start the load and leave it outstanding.
      final loading = container.read(settingsControllerProvider.future);

      // The user toggles Sound off before the read comes back.
      unawaited(
        container
            .read(settingsControllerProvider.notifier)
            .apply((s) => s.copyWith(soundEnabled: false)),
      );

      // Only now does the store answer, holding the value from *before* the
      // toggle. Without the guard in build(), this would snap the switch back on.
      repository.releaseLoad(AppSettings.defaults);

      await loading;

      expect(container.read(settingsProvider).soundEnabled, isFalse);
    });

    test('the guarded value is also what gets persisted', () async {
      final repository = ControllableRepository()..holdLoad();
      final container = containerWith(repository);

      final loading = container.read(settingsControllerProvider.future);
      unawaited(
        container
            .read(settingsControllerProvider.notifier)
            .apply((s) => s.copyWith(decimalPlaces: 6)),
      );
      repository.releaseLoad(AppSettings.defaults);
      await loading;
      // Let the write's own `await read(...future)` and save settle.
      await Future<void>.delayed(Duration.zero);

      expect(repository.saved.single.decimalPlaces, 6);
    });
  });

  group('degradation', () {
    test('an unavailable plugin yields in-memory settings, not an error', () async {
      // The real production path: the plugin throws, the repository provider
      // catches it and substitutes the in-memory store, and the app still has
      // usable preferences. AC-006 degrades rather than failing.
      final container = ProviderContainer(
        overrides: [
          preferencesProvider.overrideWith((ref) async {
            throw StateError('no plugin');
          }),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(settingsRepositoryProvider.future),
        isA<InMemorySettingsRepository>(),
      );
      expect(
        await container.read(settingsControllerProvider.future),
        AppSettings.defaults,
      );
    });

    test('a write still works against the fallback', () async {
      final container = ProviderContainer(
        overrides: [
          preferencesProvider.overrideWith((ref) async {
            throw StateError('no plugin');
          }),
        ],
      );
      addTearDown(container.dispose);
      await container.read(settingsControllerProvider.future);

      await container
          .read(settingsControllerProvider.notifier)
          .apply((s) => s.copyWith(decimalPlaces: 1));

      expect(container.read(settingsProvider).decimalPlaces, 1);
    });
  });
}
