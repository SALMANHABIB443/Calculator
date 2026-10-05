import 'package:calculator/core/storage/preferences_provider.dart';
import 'package:calculator/features/secret/data/shared_preferences_secret_repository.dart';
import 'package:calculator/features/secret/domain/secret_code.dart';
import 'package:calculator/features/secret/presentation/secret_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/pump_app.dart';
/// **AC-021** — "A changed PIN is persisted, survives a restart, and is the code
/// the next unlock requires."
///
/// These are here rather than in `secret_flow_test.dart` for one reason: a
/// restart cannot be performed inside a single widget-test app session, because
/// `SharedPreferences` caches its instance for the life of the process and
/// `pumpApp` seeds a store of its own. The restart technique is the same one
/// `settings_persistence_test.dart` uses — snapshot the store, re-seed from it,
/// and read through a **fresh** `ProviderContainer` — and the widget test proves
/// the change is *written*, while these prove it survives and is read back.
void main() {
  /// Reads the PIN a *fresh* container sees, as a cold start would.
  Future<SecretCode> reload() async {
    final snapshot = await snapshotStore();
    SharedPreferences.setMockInitialValues(snapshot);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container.read(secretControllerProvider.future);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('a fresh install reads the documented default', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(secretControllerProvider.future), SecretCode.defaultCode);
  });

  test('a changed PIN survives a relaunch', () async {
    // The first run changes it, exactly as the Change PIN flow does: through the
    // notifier, not by writing the key behind its back.
    final first = ProviderContainer();
    await first.read(secretControllerProvider.future);
    await first
        .read(secretControllerProvider.notifier)
        .change(SecretCode('5678'));

    expect(await reload(), SecretCode('5678'));
  });

  test('a changed PIN is the code the next unlock requires', () async {
    final first = ProviderContainer();
    await first.read(secretControllerProvider.future);
    await first
        .read(secretControllerProvider.notifier)
        .change(SecretCode('5678'));

    // A fresh container, as a relaunched app would build: the old code no longer
    // verifies and the new one does.
    final second = ProviderContainer();
    addTearDown(second.dispose);
    await second.read(secretControllerProvider.future);

    final notifier = second.read(secretControllerProvider.notifier);
    expect(await notifier.verify(SecretCode('5678')), isTrue);
    expect(await notifier.verify(SecretCode('0000')), isFalse);
    expect(await notifier.verify(SecretCode('1234')), isFalse);
  });

  test('the last of several changes is the one that survives', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(secretControllerProvider.future);

    await container
        .read(secretControllerProvider.notifier)
        .change(SecretCode('1111'));
    await container
        .read(secretControllerProvider.notifier)
        .change(SecretCode('2222'));

    expect(await reload(), SecretCode('2222'));
  });

  test('a PIN with leading zeroes survives a relaunch', () async {
    // `0001` must not be trimmed into `1` on the way through storage.
    final first = ProviderContainer();
    await first.read(secretControllerProvider.future);
    await first
        .read(secretControllerProvider.notifier)
        .change(SecretCode('0001'));

    expect((await reload()).value, '0001');
  });

  test('a store that cannot be reached degrades to the default', () async {
    // D-44's contract, applied to the third repository: acquisition failure must
    // leave the hidden area usable rather than bricking the one screen that
    // reads it. The whole shared store is broken rather than just the PIN key,
    // because `shared_preferences` is one plugin — a test cannot fail one
    // repository's acquisition and leave another's working.
    final container = ProviderContainer(
      overrides: <Override>[
        preferencesProvider.overrideWithValue(
          Future<SharedPreferences>.error(Exception('no store')),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(secretRepositoryProvider.future),
      isA<InMemorySecretRepository>(),
    );
    expect(
      await container.read(secretControllerProvider.future),
      SecretCode.defaultCode,
    );
  });

  test('an unreachable store still accepts and persists a change', () async {
    // The stronger half of the degradation contract: the in-memory fallback is
    // not read-only. A user who changes their PIN on a device where the plugin
    // failed gets a session that honours the new code, and the docs say exactly
    // that rather than promising a write that cannot happen.
    final container = ProviderContainer(
      overrides: <Override>[
        preferencesProvider.overrideWithValue(
          Future<SharedPreferences>.error(Exception('no store')),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(secretControllerProvider.future);

    final notifier = container.read(secretControllerProvider.notifier);
    expect(await notifier.verify(SecretCode('0000')), isTrue);

    await notifier.change(SecretCode('4321'));
    expect(await notifier.verify(SecretCode('4321')), isTrue);
  });
}
