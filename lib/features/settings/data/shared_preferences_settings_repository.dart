import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/preferences_provider.dart';
import '../domain/app_settings.dart';
import 'settings_repository.dart';

/// The `shared_preferences`-backed [SettingsRepository] (D-02).
///
/// One primitive key per preference, named exactly as `struction.md` §10 lists
/// them, rather than a single JSON blob. The platform store already understands
/// booleans, integers, and strings natively, so a blob would add an encode and
/// a decode step and buy nothing in size; the per-key form also means a single
/// corrupt value degrades to one default instead of costing the user every
/// preference (D-42).
///
/// Reads never throw, and the guard is not optional decoration:
/// `SharedPreferences`' typed getters are casts (`getInt` is
/// `_preferenceCache[key] as int?`, `shared_preferences_legacy.dart:122`), so a
/// key holding the wrong type raises a `TypeError` rather than returning null.
/// A corrupt or hand-edited store would therefore take down the whole load and
/// leave the app on defaults forever. [_readOrNull] turns that one bad key into
/// one bad field, which is the same "drop the bad record, keep the rest"
/// contract the history repository follows.
class SharedPreferencesSettingsRepository implements SettingsRepository {
  /// [preferences] is the instance to read and write through; the app supplies
  /// the one from [preferencesProvider].
  const SharedPreferencesSettingsRepository(this._preferences);

  final SharedPreferences _preferences;

  /// The storage keys. Exposed so a test can seed and inspect the real store
  /// rather than a parallel copy of the schema, exactly as
  /// `HistoryRepository.storageKey` is used.
  static const String soundEnabledKey = 'soundEnabled';
  static const String vibrationEnabledKey = 'vibrationEnabled';
  static const String decimalPlacesKey = 'decimalPlaces';
  static const String historyEnabledKey = 'historyEnabled';
  static const String themeKey = 'theme';

  /// [read]'s value, or null if the key is absent *or* holds another type.
  static T? _readOrNull<T>(T? Function() read) {
    try {
      return read();
    } on TypeError {
      return null;
    }
  }

  @override
  Future<AppSettings> load() async {
    return AppSettings(
      soundEnabled:
          _readOrNull(() => _preferences.getBool(soundEnabledKey)) ??
          AppSettings.defaults.soundEnabled,
      vibrationEnabled:
          _readOrNull(() => _preferences.getBool(vibrationEnabledKey)) ??
          AppSettings.defaults.vibrationEnabled,
      decimalPlaces: AppSettings.clampDecimalPlaces(
        _readOrNull(() => _preferences.getInt(decimalPlacesKey)) ??
            AppSettings.defaults.decimalPlaces,
      ),
      historyEnabled:
          _readOrNull(() => _preferences.getBool(historyEnabledKey)) ??
          AppSettings.defaults.historyEnabled,
      theme:
          _readOrNull(() => _preferences.getString(themeKey)) ??
          AppSettings.defaults.theme,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _preferences.setBool(soundEnabledKey, settings.soundEnabled);
    await _preferences.setBool(vibrationEnabledKey, settings.vibrationEnabled);
    await _preferences.setInt(
      decimalPlacesKey,
      AppSettings.clampDecimalPlaces(settings.decimalPlaces),
    );
    await _preferences.setBool(historyEnabledKey, settings.historyEnabled);
    await _preferences.setString(themeKey, settings.theme);
  }
}

/// The fallback for when `shared_preferences` cannot be reached, and the fake
/// unit tests write against.
///
/// Holds one value in memory and forgets it when the process ends. It obeys the
/// same contract as the real repository — [load] never throws and a
/// `SharedPreferences` failure degrades to defaults rather than bricking the
/// app — so a test written against it exercises the behaviour that ships.
class InMemorySettingsRepository implements SettingsRepository {
  InMemorySettingsRepository([AppSettings? initial])
    : _settings = initial ?? AppSettings.defaults;

  AppSettings _settings;

  /// The value currently held, without a round trip through [load]. Lets a test
  /// assert what was written.
  AppSettings get current => _settings;

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> save(AppSettings settings) async {
    _settings = settings;
  }
}