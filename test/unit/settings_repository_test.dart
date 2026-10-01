import 'package:calculator/features/settings/data/shared_preferences_settings_repository.dart';
import 'package:calculator/features/settings/domain/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The `shared_preferences` settings store, at the storage boundary (D-02,
/// D-42).
///
/// Every test drives the real store through the real key names, so a schema
/// change shows up here rather than only on a device.
void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();
  });

  SharedPreferencesSettingsRepository repository() =>
      SharedPreferencesSettingsRepository(preferences);

  group('load', () {
    test('returns the documented defaults when the store is empty', () async {
      expect(await repository().load(), AppSettings.defaults);
    });

    test('returns defaults for a partially written store, field by field', () async {
      await preferences.setBool(
        SharedPreferencesSettingsRepository.soundEnabledKey,
        false,
      );

      final loaded = await repository().load();

      expect(loaded.soundEnabled, isFalse);
      expect(loaded.vibrationEnabled, AppSettings.defaults.vibrationEnabled);
      expect(loaded.decimalPlaces, AppSettings.defaults.decimalPlaces);
      expect(loaded.historyEnabled, AppSettings.defaults.historyEnabled);
      expect(loaded.theme, AppSettings.defaults.theme);
    });

    test('a key holding the wrong type degrades to its default', () async {
      // The realistic corruption: a value written as a string where the app
      // reads an int. `getInt` returns null, so the field falls back rather
      // than the whole read failing.
      await preferences.setString(
        SharedPreferencesSettingsRepository.decimalPlacesKey,
        '4',
      );

      final loaded = await repository().load();

      expect(loaded.decimalPlaces, AppSettings.defaults.decimalPlaces);
    });

    test('one corrupt key does not take the other preferences with it', () async {
      await preferences.setString(
        SharedPreferencesSettingsRepository.decimalPlacesKey,
        'not an int',
      );
      await preferences.setBool(
        SharedPreferencesSettingsRepository.historyEnabledKey,
        false,
      );

      final loaded = await repository().load();

      expect(loaded.decimalPlaces, AppSettings.defaults.decimalPlaces);
      expect(loaded.historyEnabled, isFalse);
    });

    test('clamps a stored precision outside the offered range (D-46)', () async {
      await preferences.setInt(
        SharedPreferencesSettingsRepository.decimalPlacesKey,
        99,
      );
      expect((await repository().load()).decimalPlaces, 6);

      await preferences.setInt(
        SharedPreferencesSettingsRepository.decimalPlacesKey,
        -4,
      );
      expect((await repository().load()).decimalPlaces, 0);
    });
  });

  group('save', () {
    test('round-trips every field', () async {
      const settings = AppSettings(
        soundEnabled: false,
        vibrationEnabled: false,
        decimalPlaces: 5,
        historyEnabled: false,
        theme: 'dark',
      );

      await repository().save(settings);

      expect(await repository().load(), settings);
    });

    test('writes one primitive key per preference, not a blob', () async {
      await repository().save(
        AppSettings.defaults.copyWith(decimalPlaces: 3, historyEnabled: false),
      );

      expect(preferences.getBool('soundEnabled'), isTrue);
      expect(preferences.getBool('vibrationEnabled'), isTrue);
      expect(preferences.getInt('decimalPlaces'), 3);
      expect(preferences.getBool('historyEnabled'), isFalse);
      expect(preferences.getString('theme'), 'dark');
    });

    test('a second save overwrites rather than accumulating', () async {
      final store = repository();

      await store.save(AppSettings.defaults.copyWith(decimalPlaces: 6));
      await store.save(AppSettings.defaults.copyWith(decimalPlaces: 1));

      expect((await store.load()).decimalPlaces, 1);
    });

    test('clamps on write as well as on read', () async {
      await repository().save(AppSettings.defaults.copyWith(decimalPlaces: 50));

      expect(preferences.getInt('decimalPlaces'), AppSettings.maxDecimalPlaces);
    });
  });

  group('InMemorySettingsRepository', () {
    test('obeys the same defaults contract as the real one', () async {
      expect(await InMemorySettingsRepository().load(), AppSettings.defaults);
    });

    test('holds what it was given and forgets on construction', () async {
      final store = InMemorySettingsRepository();
      const settings = AppSettings.defaults;

      await store.save(settings);
      expect(await store.load(), settings);
      expect(store.current, settings);
      expect(await InMemorySettingsRepository().load(), AppSettings.defaults);
    });

    test('can be seeded', () async {
      final seeded = AppSettings.defaults.copyWith(decimalPlaces: 4);
      expect(await InMemorySettingsRepository(seeded).load(), seeded);
    });
  });

  group('AppSettings', () {
    test('compares by value, not identity (D-47)', () {
      expect(
        AppSettings.defaults.copyWith(),
        AppSettings.defaults,
      );
      expect(
        AppSettings.defaults.copyWith(decimalPlaces: 3).hashCode,
        isNot(AppSettings.defaults.hashCode),
      );
    });

    test('is identical to itself', () {
      const settings = AppSettings.defaults;
      expect(settings == settings, isTrue);
    });

    test('is not equal to a different type', () {
      expect(AppSettings.defaults == Object(), isFalse);
    });

    test('the picker offers 0 through 6, ascending, with no gaps', () {
      expect(AppSettings.decimalPlacesOptions, <int>[0, 1, 2, 3, 4, 5, 6]);
    });

    test('clampDecimalPlaces leaves a value in range alone', () {
      expect(AppSettings.clampDecimalPlaces(0), 0);
      expect(AppSettings.clampDecimalPlaces(3), 3);
      expect(AppSettings.clampDecimalPlaces(6), 6);
    });
  });
}
