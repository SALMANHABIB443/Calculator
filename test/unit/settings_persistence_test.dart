import 'package:calculator/core/storage/preferences_provider.dart';
import 'package:calculator/features/settings/domain/app_settings.dart';
import 'package:calculator/features/settings/presentation/settings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/pump_app.dart';

/// **AC-006** — "Settings and History persist after force-quit and relaunch."
///
/// The point of these tests is the *relaunch*, so none of them is satisfied by
/// one container reading its own writes. Each re-seeds the backing store from a
/// snapshot and reads through a fresh container, which is what forces
/// `SharedPreferences` to drop its cached instance and go back to the store —
/// see `snapshotStore` in `pump_app.dart`.
void main() {
  /// Reads the settings a *fresh* container sees, as a cold start would.
  Future<AppSettings> reload() async {
    final snapshot = await snapshotStore();
    SharedPreferences.setMockInitialValues(snapshot);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container.read(settingsControllerProvider.future);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('a fresh install reads the documented defaults', () async {
    expect(await reload(), AppSettings.defaults);
  });

  test('every preference survives a relaunch', () async {
    const changed = AppSettings(
      soundEnabled: false,
      vibrationEnabled: false,
      decimalPlaces: 5,
      historyEnabled: false,
      theme: 'dark',
    );

    final first = ProviderContainer();
    addTearDown(first.dispose);
    await first.read(settingsControllerProvider.future);
    await first
        .read(settingsControllerProvider.notifier)
        .apply((_) => changed);

    expect(await reload(), changed);
  });

  test('a single preference survives, the rest fall back to defaults', () async {
    final first = ProviderContainer();
    addTearDown(first.dispose);
    await first.read(settingsControllerProvider.future);
    await first
        .read(settingsControllerProvider.notifier)
        .apply((s) => s.copyWith(decimalPlaces: 6));

    final reloaded = await reload();

    expect(reloaded.decimalPlaces, 6);
    expect(reloaded.soundEnabled, AppSettings.defaults.soundEnabled);
    expect(reloaded.historyEnabled, AppSettings.defaults.historyEnabled);
  });

  test('the last of several writes is the one that survives', () async {
    final first = ProviderContainer();
    addTearDown(first.dispose);
    final notifier = first.read(settingsControllerProvider.notifier);
    await first.read(settingsControllerProvider.future);

    await notifier.apply((s) => s.copyWith(decimalPlaces: 4));
    await notifier.apply((s) => s.copyWith(decimalPlaces: 1));
    await notifier.apply((s) => s.copyWith(decimalPlaces: 3));

    expect((await reload()).decimalPlaces, 3);
  });

  test('a seeded store is read as stored, not as defaults', () async {
    // The other direction: a preference written by a previous run is honoured on
    // the next one. This is what stops the app resetting a user's choices.
    final seed = AppSettings.defaults.copyWith(
      decimalPlaces: 0,
      vibrationEnabled: false,
    );
    SharedPreferences.setMockInitialValues(settingsStoreValues(seed));

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(settingsControllerProvider.future), seed);
  });

  test('an out-of-range stored precision is clamped, not rejected', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'decimalPlaces': 42,
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect((await container.read(settingsControllerProvider.future)).decimalPlaces, 6);
  });

  test('the synchronous view is usable before the load resolves', () async {
    // A key press in the first frames of a cold start must still round with a
    // valid precision rather than throwing or reading null.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(settingsProvider).decimalPlaces, 2);
    expect(container.read(settingsProvider).historyEnabled, isTrue);

    await container.read(settingsControllerProvider.future);

    expect(container.read(settingsProvider).decimalPlaces, 2);
  });

  test('an unavailable plugin leaves the app on usable defaults', () async {
    final container = ProviderContainer(
      overrides: [
        preferencesProvider.overrideWith((ref) async {
          throw StateError('no plugin');
        }),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(settingsProvider), AppSettings.defaults);
    expect(await container.read(settingsControllerProvider.future),
        AppSettings.defaults);
  });
}
