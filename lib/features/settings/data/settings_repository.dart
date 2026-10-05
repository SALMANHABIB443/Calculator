import '../domain/app_settings.dart';

/// Persistence boundary for user preferences (struction.md §10).
///
/// The Phase 6 implementation is backed by `shared_preferences` (D-02) and
/// follows the Riverpod `AsyncNotifier` pattern with graceful degradation to
/// [AppSettings.defaults] when the platform channel is unavailable, so unit
/// tests run without mocking.
abstract class SettingsRepository {
  /// Reads the stored settings, falling back to [AppSettings.defaults] for
  /// any missing or unreadable key.
  Future<AppSettings> load();

  /// Persists [settings] and notifies observers so the feedback service and
  /// the history toggle take effect immediately.
  Future<void> save(AppSettings settings);
}