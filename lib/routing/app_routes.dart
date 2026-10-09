/// Route paths and names for the app (D-01, struction.md §7).
///
/// Referenced by name rather than by raw string so a path change is a
/// single-file edit.
abstract final class AppRoutes {
  /// Root route — the calculator itself (D-20: no back arrow here).
  static const String calculator = '/';

  static const String history = '/history';
  static const String settings = '/settings';
  static const String about = '/about';
  static const String privacy = '/privacy';
  static const String terms = '/terms';

  /// Debug-only component catalogue (phases.md §Phase 3). Registered in
  /// `app_router.dart` behind `kDebugMode`, so this path exists in a debug
  /// build and in no release build.
  static const String catalog = '/catalog';
}