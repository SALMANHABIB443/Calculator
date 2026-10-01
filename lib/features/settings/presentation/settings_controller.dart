/// The settings feature's Riverpod wiring: where the repository comes from, the
/// notifier the Settings screen writes through, and the synchronous read the
/// rest of the app already depends on.
///
/// Two providers, on purpose (D-41). [settingsControllerProvider] is the
/// [AsyncNotifier] that owns the asynchronous load and the writes. The rest of
/// the app cannot use it directly: the calculator controller reads settings
/// *synchronously* on every key press so it can pass the feedback flags and the
/// precision into a call it must not await (**D-34**), and the display needs a
/// value to round with. [settingsProvider] is therefore a plain synchronous
/// [Provider] layered over the notifier, which keeps all four existing read
/// sites — the display's `watch`, the controller's `read`, and the history
/// repository's two closure reads — exactly as they were.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences_provider.dart';
import '../data/settings_repository.dart';
import '../data/shared_preferences_settings_repository.dart';
import '../domain/app_settings.dart';

/// The application's settings storage.
///
/// Resolves to the `shared_preferences` implementation (D-02), falling back to
/// [InMemorySettingsRepository] if the plugin is unavailable. Unlike history,
/// a *hung* plugin does not need special handling here: [settingsProvider] falls
/// back to [AppSettings.defaults] until the load lands, and a pending future
/// schedules no frames, so nothing spins while it waits.
final settingsRepositoryProvider = FutureProvider<SettingsRepository>((
  ref,
) async {
  try {
    final preferences = await ref.watch(preferencesProvider);
    return SharedPreferencesSettingsRepository(preferences);
  } catch (_) {
    return InMemorySettingsRepository();
  }
});

/// The user's preferences as the rest of the app reads them (D-02,
/// struction.md §10).
///
/// Synchronous by design, per **D-41**. A read during the initial load yields
/// [AppSettings.defaults], and a read afterwards yields the stored value. The
/// transition rebuilds every watcher, which is the "load settings on app start"
/// half of the Phase 6 tasks.
final settingsProvider = Provider<AppSettings>(
  (ref) =>
      ref.watch(settingsControllerProvider).valueOrNull ?? AppSettings.defaults,
);

/// Owns the loaded settings and every write to them.
final settingsControllerProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

/// Reads, changes, and persists user preferences.
class SettingsNotifier extends AsyncNotifier<AppSettings> {
  /// A change made while the initial load was still in flight.
  ///
  /// Set by [apply] and cleared by [build]. Without it a user who toggles Sound
  /// in the first few milliseconds after a cold start would watch it snap back:
  /// [apply] publishes optimistically, then the load resolves and its result —
  /// read from disk *before* the toggle — overwrites the visible state. Letting
  /// the write win is both correct and what the user did (**D-43**).
  AppSettings? _writtenWhileLoading;

  @override
  Future<AppSettings> build() async {
    _writtenWhileLoading = null;
    final repository = await ref.watch(settingsRepositoryProvider.future);
    final loaded = await repository.load();
    return _writtenWhileLoading ?? loaded;
  }

  /// The current value, falling back to the defaults before the load lands.
  AppSettings get _current => state.valueOrNull ?? AppSettings.defaults;

  /// Applies [change] to the current settings, publishes the result
  /// immediately, and persists it.
  ///
  /// Named `apply` rather than `update` because `AsyncNotifier` already defines
  /// an `update` with an unrelated signature, and shadowing it would be a trap
  /// for whoever adds the next method to this class.
  ///
  /// Not awaited by the caller: the Settings screen calls this from a toggle
  /// callback that must not await anything, and the user must see the switch
  /// move on the same frame they touched it. The optimistic publish is also what
  /// makes the calculator's feedback flags and the history gate take effect
  /// immediately rather than after a disk write (**AC-004**).
  ///
  /// A [change] that produces no change is dropped, so an idempotent write
  /// costs no I/O.
  Future<void> apply(AppSettings Function(AppSettings) change) async {
    final next = change(_current);
    if (next == _current) return;

    _writtenWhileLoading = next;
    state = AsyncData<AppSettings>(next);

    final repository = await ref.read(settingsRepositoryProvider.future);
    await repository.save(next);
  }
}
