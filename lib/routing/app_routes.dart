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

  /// The hidden PIN prompt (D-82, struction.md §7).
  ///
  /// Reached **only** by the five-second hold on History's Clear History
  /// button. It is registered as an ordinary route rather than kept out of the
  /// router because the hold has to push *something*, and `history_screen.dart`
  /// knows route names but nothing about `features/secret/` — that one-way
  /// dependency is what lets the gesture live in the History feature.
  static const String secretUnlock = '/secret/unlock';

  /// The blank page behind the PIN (D-84).
  ///
  /// Reached by **replacing** [secretUnlock], never by pushing on top of it: a
  /// PIN prompt left on the stack underneath would put a back gesture that
  /// returns to it in front of the user.
  static const String secret = '/secret';

  /// The one-row page holding Change PIN (D-84).
  static const String secretSettings = '/secret/settings';

  /// The three-step Change PIN flow (FEAT-SEC-005).
  static const String secretChangePin = '/secret/change-pin';

  /// Debug-only component catalogue (phases.md §Phase 3). Registered in
  /// `app_router.dart` behind `kDebugMode`, so this path exists in a debug
  /// build and in no release build.
  static const String catalog = '/catalog';
}