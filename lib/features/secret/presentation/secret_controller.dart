/// The Secret Mode feature's Riverpod wiring: where the PIN comes from and how
/// a code is checked and replaced (D-83, D-85).
///
/// Deliberately smaller than the settings wiring, and the difference is the
/// design. `settingsProvider` exists as a *synchronous* read layered over an
/// `AsyncNotifier` because the calculator needs a preference on every key press
/// and must not await it (**D-41**). Nothing does that with the PIN: exactly one
/// screen verifies it, that screen is behind a gesture a user has to know, and
/// by the time it is asked the store has loaded. So there is one `AsyncNotifier`
/// and no synchronous mirror — a second provider here would be a shape copied
/// from a screen that needed it, not from this one.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences_provider.dart';
import '../data/secret_repository.dart';
import '../data/shared_preferences_secret_repository.dart';
import '../domain/secret_code.dart';

/// The application's PIN storage.
///
/// Resolves to the `shared_preferences` implementation (D-02, D-83), falling
/// back to [InMemorySecretRepository] if the plugin is unavailable — the same
/// degradation the other two repositories do, so a unit test needs no mock and
/// a platform failure still leaves the screen usable.
final secretRepositoryProvider = FutureProvider<SecretRepository>((ref) async {
  try {
    final preferences = await ref.watch(preferencesProvider);
    return SharedPreferencesSecretRepository(preferences);
  } catch (_) {
    return InMemorySecretRepository();
  }
});

/// Owns the stored code and every check and write made against it.
final secretControllerProvider =
    AsyncNotifierProvider<SecretCodeNotifier, SecretCode>(
      SecretCodeNotifier.new,
    );

/// Reads, verifies, and persists the secret code (D-85).
class SecretCodeNotifier extends AsyncNotifier<SecretCode> {
  @override
  Future<SecretCode> build() async {
    final repository = await ref.watch(secretRepositoryProvider.future);
    return repository.load();
  }

  /// Whether [entered] is the stored code (AC-019).
  ///
  /// No attempt counter and no lockout, by design (**D-85**): 10⁴ codes are free
  /// to try, and a lockout would punish the owner for mistyping a four-digit
  /// code with a recovery that means reinstalling and losing the history. The
  /// caller decides what a failure looks like — the unlock screen clears and
  /// shakes, the Change PIN flow refuses to advance.
  Future<bool> verify(SecretCode entered) async {
    final repository = await ref.read(secretRepositoryProvider.future);
    return entered == (await repository.load());
  }

  /// Replaces the stored code and publishes it (AC-021).
  ///
  /// Persisted immediately rather than on leaving the flow, so a PIN that was
  /// successfully confirmed cannot be lost to a process death one frame later.
  Future<void> change(SecretCode next) async {
    state = AsyncData<SecretCode>(next);
    final repository = await ref.read(secretRepositoryProvider.future);
    await repository.save(next);
  }

  /// Erases the stored code, returning the feature to its fresh-install state
  /// (AC-022).
  ///
  /// The published state moves **first**, so anything already watching this
  /// provider — the Change PIN flow's own guard, a screen holding the code it
  /// last verified against — sees the reset the moment the user confirms rather
  /// than after a store write that a process death could swallow. Same ordering
  /// as [change], and for the same reason: the user's confirmation must not be
  /// undoable by a crash.
  ///
  /// **What this costs.** D-85 declined a lockout because 10⁴ codes are free to
  /// try and the documented recovery was a reinstall. This is that recovery,
  /// made reachable — so it is also a one-tap route *past* the code for anyone
  /// who reaches this screen. That is accepted rather than overlooked: the
  /// alternative is a user who forgets their PIN having to reinstall and lose the
  /// history with it, and a feature holding no user data is a weaker prize than a
  /// usable recovery path. D-86 records the trade.
  Future<void> reset() async {
    state = AsyncData<SecretCode>(SecretCode.defaultCode);
    final repository = await ref.read(secretRepositoryProvider.future);
    await repository.clear();
  }
}