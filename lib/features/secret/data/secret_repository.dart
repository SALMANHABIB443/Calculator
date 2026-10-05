import '../domain/secret_code.dart';

/// Persistence boundary for the hidden area's PIN (struction.md §10, D-83).
///
/// Its own interface rather than a field on [AppSettings] because a PIN is a
/// credential and not a preference, and the separate boundary is what makes that
/// visible to whoever opens this file next. The docs make the same argument
/// against folding it into the settings blob.
abstract class SecretRepository {
  /// Reads the stored code, falling back to [SecretCode.defaultCode] for a
  /// missing, unreadable, or malformed value (D-83).
  ///
  /// Never throws. The same contract the settings repository's `load` keeps, and
  /// for the same reason: the screen behind this PIN has no way to recover from
  /// an exception, and a user who cannot get in at all is worse off than a user
  /// who gets in with the documented default.
  Future<SecretCode> load();

  /// Persists [code] so the next unlock requires it, across restarts (AC-021).
  Future<void> save(SecretCode code);

  /// Removes the stored code, so [load] answers [SecretCode.defaultCode] again
  /// (AC-022).
  ///
  /// A **removal** rather than a `save` of the default, because writing `0000`
  /// back would leave a stored credential that a later reader could mistake for
  /// one the user chose. Erasing it restores the state a fresh install is in,
  /// which is the whole point: after a reset the next unlock requires the
  /// documented default and the store carries nothing that looks like a PIN.
  Future<void> clear();
}