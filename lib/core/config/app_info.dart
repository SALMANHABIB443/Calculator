/// Build/app metadata surfaced by the About screen (prd.md §10, D-11, D-12).
///
/// The version must match `pubspec.yaml` and is updated at release time.
abstract final class AppInfo {
  static const String name = 'Calculator';

  /// Matches `version:` in `pubspec.yaml` (D-12). The About screen shows
  /// only the `1.0.0` part.
  static const String version = '1.0.0+1';

  /// Displayed verbatim by the About screen (D-11).
  static const String developer = 'Hasan Mahadi';

  static const String description =
      'A simple, fast and reliable calculator for your everyday needs.';

  /// Android package name, also the Rate App store fallback target (D-08).
  static const String androidPackageName = 'com.hasanmahadi.calculator';

  /// Web Play Store listing, composed from [androidPackageName] so the two
  /// cannot drift. Used by Share App (D-53). The Rate App fallback does not
  /// need it: the plugin builds the URL from the package name on Android
  /// (D-49). **Placeholder domain until the store listing is confirmed in
  /// Phase 10**, which is a hard release gate.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=$androidPackageName';

  /// Text the system share sheet sends when the user shares the app
  /// (feature.md FEAT-ABOUT-003).
  static String get shareMessage =>
      '${AppInfo.name} — ${AppInfo.description} $playStoreUrl';
}
