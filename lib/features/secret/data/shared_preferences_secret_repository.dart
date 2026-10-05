import 'package:shared_preferences/shared_preferences.dart';

import '../domain/secret_code.dart';
import 'secret_repository.dart';

/// The `shared_preferences`-backed [SecretRepository] (D-83).
///
/// Plaintext, and deliberately so. `flutter_secure_storage` was rejected because
/// it would be the first package added since Phase 1, breaking the dependency
/// lockdown that held for ten phases; hashing was rejected because the threat is
/// *reading* the store rather than brute-forcing it, and with no rate limit
/// (D-85) a hash of four digits is no stronger than the plaintext it replaces.
/// The exposure is real and smaller than the history sitting in the same store,
/// so `phases.md` records it as a limitation rather than a security guarantee.
///
/// Two guards, both doing real work:
///
/// * `_readOrNull` turns a key holding the wrong type into `null`. The
///   plugin's typed getters are casts, so `getString` on an `int` raises a
///   `TypeError` rather than returning null — one hand-edited key would
///   otherwise take down the whole load and lock the screen out.
/// * [SecretCode.isWellFormed] degrades a well-typed but malformed value — `"12"`,
///   `"abcd"`, `"00000"` — to [SecretCode.defaultCode]. `SecretCode`'s
///   constructor throws, so the choice is between degrading and refusing to
///   open; the documents choose degrading (D-42's contract).
class SharedPreferencesSecretRepository implements SecretRepository {
  /// [preferences] is the instance to read and write through; the app supplies
  /// the one from `preferencesProvider`.
  const SharedPreferencesSecretRepository(this._preferences);

  final SharedPreferences _preferences;

  /// The storage key. Exposed so a test seeds and inspects the real store
  /// rather than a parallel copy of the schema, exactly as the settings
  /// repository's keys are used.
  static const String pinKey = 'secretPin';

  /// [read]'s value, or null if the key is absent *or* holds another type.
  static T? _readOrNull<T>(T? Function() read) {
    try {
      return read();
    } on TypeError {
      return null;
    }
  }

  @override
  Future<SecretCode> load() async {
    final stored = _readOrNull(() => _preferences.getString(pinKey));
    return SecretCode.isWellFormed(stored)
        ? SecretCode(stored!)
        : SecretCode.defaultCode;
  }

  @override
  Future<void> save(SecretCode code) async {
    await _preferences.setString(pinKey, code.value);
  }

  @override
  Future<void> clear() async {
    // `remove`, not `setString(pinKey, defaultCode.value)` — see the interface's
    // note on why the key is erased rather than overwritten. [load] already
    // answers the default for an absent key, so nothing has to be written for the
    // reset to take effect.
    await _preferences.remove(pinKey);
  }
}

/// The fallback for when `shared_preferences` cannot be reached, and the fake
/// unit tests write against.
///
/// Holds one value in memory and forgets it when the process ends — which is
/// exactly the guarantee [SharedPreferencesSecretRepository] gives, minus the
/// restart. It obeys the same contract, so a test written against it exercises
/// the behaviour that ships.
class InMemorySecretRepository implements SecretRepository {
  InMemorySecretRepository([SecretCode? initial])
    : _code = initial ?? SecretCode.defaultCode;

  SecretCode _code;

  /// The value currently held, without a round trip through [load].
  SecretCode get current => _code;

  @override
  Future<SecretCode> load() async => _code;

  @override
  Future<void> save(SecretCode code) async {
    _code = code;
  }

  @override
  Future<void> clear() async {
    // Back to the same value a fresh construction takes, so this fake is not a
    // parallel copy of the schema that could drift from the real repository's
    // "absent key means the default" rule — it assigns the same named fact.
    _code = SecretCode.defaultCode;
  }
}