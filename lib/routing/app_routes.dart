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

  /// The hidden area's browsing page, parameterised by place (FEAT-SEC-007).
  ///
  /// **One path for the eleven places the Vault screen leads to** rather than
  /// eleven paths and eleven screen classes, because the eleven pages are the
  /// same three parts — a title, the app's back button, an empty list — and
  /// differ only in the three strings the `:place` segment resolves to
  /// (`VaultPlaceScreen`, D-114).
  ///
  /// Held apart from [secretBrowse] below so the prefix is written once: a
  /// `'/secret/browse/:place'` pattern and a `'/secret/browse/$id'` call site that
  /// each spelled their own copy of the middle segment is exactly how the two
  /// drift and every push 404s into the fallback page.
  static const String _secretBrowsePrefix = '/secret/browse';

  /// The route [VaultPlaceScreen] is registered at (FEAT-SEC-007, D-114).
  static const String secretBrowse = '$_secretBrowsePrefix/:place';

  /// [secretBrowse] with [place] filled in — what the rows call `context.push`.
  ///
  /// **A function rather than a template constant** because the segment is
  /// interpolated: `'/secret/browse/$place'` cannot be a `const`, and a
  /// non-const template invites a row to hand-write its own path instead.
  static String secretBrowseTo(String place) => '$_secretBrowsePrefix/$place';

  /// Debug-only component catalogue (phases.md §Phase 3). Registered in
  /// `app_router.dart` behind `kDebugMode`, so this path exists in a debug
  /// build and in no release build.
  static const String catalog = '/catalog';
}