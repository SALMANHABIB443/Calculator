import 'package:calculator/features/secret/data/shared_preferences_secret_repository.dart';
import 'package:calculator/features/secret/domain/secret_code.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The `secretPin` key in `shared_preferences`, at the storage boundary (D-83,
/// AC-018, AC-021).
///
/// Modelled on `settings_repository_test.dart`: every case drives the real store
/// through the real key, so a schema change surfaces here rather than only on a
/// device. The two guards the repository carries are each given a case — the
/// wrong-type key and the malformed value — because a guard with no test is a
/// guard that gets deleted.
void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();
  });

  SharedPreferencesSecretRepository repository() =>
      SharedPreferencesSecretRepository(preferences);

  group('load', () {
    test('returns 0000 on a fresh install', () async {
      expect(await repository().load(), SecretCode.defaultCode);
      expect((await repository().load()).value, '0000');
    });

    test('returns the stored code once one exists', () async {
      await preferences.setString(
        SharedPreferencesSecretRepository.pinKey,
        '2580',
      );

      expect(await repository().load(), SecretCode('2580'));
    });

    test('a key holding the wrong type degrades to the default', () async {
      // The plugin's typed getters are casts, so `getString` on an int raises a
      // `TypeError`. Without the guard this would be an exception on the unlock
      // screen rather than a code the user can still get in with.
      await preferences.setInt(SharedPreferencesSecretRepository.pinKey, 1234);

      expect(await repository().load(), SecretCode.defaultCode);
    });

    test('a malformed value degrades to the default rather than throwing',
        () async {
      // `SecretCode`'s constructor throws, so the choice is between degrading
      // and refusing to open at all. The documents choose degrading.
      for (final corrupt in <Object>['123', '12345', 'abcd', '', ' 123', '12 4']) {
        SharedPreferences.setMockInitialValues(<String, Object>{
          SharedPreferencesSecretRepository.pinKey: corrupt,
        });
        final store = await SharedPreferences.getInstance();

        expect(
          await SharedPreferencesSecretRepository(store).load(),
          SecretCode.defaultCode,
          reason: 'a stored "$corrupt" must degrade, not throw',
        );
      }
    });

    test('never throws, whatever the store holds', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPreferencesSecretRepository.pinKey: <String>['not', 'a', 'code'],
      });
      final store = await SharedPreferences.getInstance();

      // The whole contract in one line: the screen behind the PIN has no way to
      // recover from an exception.
      expect(
        () => SharedPreferencesSecretRepository(store).load(),
        returnsNormally,
      );
    });
  });

  group('save', () {
    test('round-trips a code', () async {
      await repository().save(SecretCode('1357'));

      expect(await repository().load(), SecretCode('1357'));
    });

    test('writes under the documented key, as a plain string', () async {
      await repository().save(SecretCode('1357'));

      // Named in `struction.md` §10 and cited by D-83; a rename would silently
      // hand every existing user the default again.
      expect(preferences.getString('secretPin'), '1357');
    });

    test('a second save overwrites rather than accumulating', () async {
      final store = repository();

      await store.save(SecretCode('1111'));
      await store.save(SecretCode('2222'));

      expect(await store.load(), SecretCode('2222'));
    });

    test('survives a restart', () async {
      // The real AC-021 claim. Re-seeding from the snapshot is what makes this a
      // restart rather than a second read of a cached instance — the same
      // technique `pump_app.dart`'s `snapshotStore` exists for.
      await repository().save(SecretCode('8642'));
      final snapshot = <String, Object>{
        for (final key in preferences.getKeys()) key: preferences.get(key)!,
      };

      SharedPreferences.setMockInitialValues(snapshot);
      final reopened = await SharedPreferences.getInstance();

      expect(
        await SharedPreferencesSecretRepository(reopened).load(),
        SecretCode('8642'),
      );
    });

    test('round-trips a code with leading zeroes', () async {
      await repository().save(SecretCode('0001'));

      expect((await repository().load()).value, '0001');
    });
  });

  group('InMemorySecretRepository', () {
    test('obeys the same defaults contract as the real one', () async {
      expect(await InMemorySecretRepository().load(), SecretCode.defaultCode);
    });

    test('holds what it was given', () async {
      final store = InMemorySecretRepository();

      await store.save(SecretCode('4567'));

      expect(await store.load(), SecretCode('4567'));
      expect(store.current, SecretCode('4567'));
    });

    test('can be seeded', () async {
      expect(
        await InMemorySecretRepository(SecretCode('4567')).load(),
        SecretCode('4567'),
      );
    });
  });
}
