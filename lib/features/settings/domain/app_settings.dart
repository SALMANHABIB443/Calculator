/// The themes a user can choose between (D-90).
///
/// Names rather than `ThemeMode` values because `AppSettings` is persisted as a
/// `String` and a stored name must survive a reordering of any enum. Dark comes
/// first so it is the default: the app shipped dark-only, so an install that
/// upgrades must not change appearance on its own.
enum AppThemeName {
  /// The original black theme, measured from the mockup pixels.
  dark('Dark'),

  /// The white theme, matched to the sibling Ethar app.
  light('White');

  const AppThemeName(this.label);

  /// What the Settings row and the theme picker call it.
  final String label;

  /// The stored name, identical to [label] today.
  String get storageValue => name;

  /// Resolves a stored name, falling back to [dark].
  ///
  /// A hand-edited or future-version store can hold a name this build does not
  /// know. `ThemeMode.values.byName` would throw and take the whole settings
  /// load with it; this returns the default so one bad value costs one
  /// preference, which is the same contract the repository follows for a value
  /// of the wrong type (D-42).
  static AppThemeName from(String? stored) {
    for (final theme in AppThemeName.values) {
      if (theme.name == stored) return theme;
    }
    return AppThemeName.dark;
  }
}

/// User-adjustable preferences (struction.md §10, desing.md §6.3).
///
/// Dark is the only supported theme in v1.0, so [theme] exists as a stored
/// value but the Settings screen renders it read-only.
class AppSettings {
  const AppSettings({
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.decimalPlaces,
    required this.historyEnabled,
    required this.theme,
  });

  static const AppSettings defaults = AppSettings(
    soundEnabled: true,
    vibrationEnabled: true,
    decimalPlaces: 2,
    historyEnabled: true,
    theme: 'dark',
  );

  /// Lowest precision the picker offers (D-46).
  ///
  /// The documents never state a range, so this is a chosen bound rather than a
  /// measured one. Zero is included because whole-number arithmetic is a
  /// legitimate setting, not a degenerate one.
  static const int minDecimalPlaces = 0;

  /// Highest precision the picker offers (D-46).
  ///
  /// Seven options is the most that fits the bottom sheet without scrolling on
  /// the narrowest supported phone (desing.md §9, ~442dp logical width), and it
  /// comfortably covers the money and general-science cases a calculator gets.
  static const int maxDecimalPlaces = 6;

  /// Every precision the picker offers, ascending.
  static const List<int> decimalPlacesOptions = <int>[
    minDecimalPlaces,
    1,
    2,
    3,
    4,
    5,
    maxDecimalPlaces,
  ];

  /// Clamps [value] into the offered range.
  ///
  /// Applied to whatever is read from storage, so a hand-edited preference file
  /// or a value written by a future version with a wider range cannot leave the
  /// formatter with a precision the picker cannot show or undo.
  static int clampDecimalPlaces(int value) {
    if (value < minDecimalPlaces) return minDecimalPlaces;
    if (value > maxDecimalPlaces) return maxDecimalPlaces;
    return value;
  }

  /// Play a click on key press (D-16).
  final bool soundEnabled;

  /// Trigger haptic feedback on key press (D-16).
  final bool vibrationEnabled;

  /// Rounding precision for computed results, default 2. Formatting-only:
  /// it never pads with trailing zeros, so `2 + 2` still shows `4` (D-14).
  final int decimalPlaces;

  /// Whether successful calculations are recorded to history.
  final bool historyEnabled;

  /// Which theme the app paints with (D-90).
  ///
  /// One of [AppThemeName]'s values, stored as that name so a future third
  /// theme is a new constant rather than a new storage key, and so a corrupt or
  /// hand-edited value can be resolved to a default instead of crashing
  /// (`ThemeMode.values.byName` would throw on an unknown name; [AppThemeName.from]
  /// falls back).
  final String theme;

  AppSettings copyWith({
    bool? soundEnabled,
    bool? vibrationEnabled,
    int? decimalPlaces,
    bool? historyEnabled,
    String? theme,
  }) {
    return AppSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      decimalPlaces: decimalPlaces ?? this.decimalPlaces,
      historyEnabled: historyEnabled ?? this.historyEnabled,
      theme: theme ?? this.theme,
    );
  }

  /// Value equality, so Riverpod can tell a real preference change from a
  /// rebuild (D-47).
  ///
  /// The calculator display watches this object through
  /// `settingsProvider.select((s) => s.decimalPlaces)`, and `select` compares
  /// with `==`. Without this override two field-by-field identical `AppSettings`
  /// instances compare unequal, so flipping *Sound* would look like a precision
  /// change and rebuild the display line for nothing. With it, the rebuild
  /// happens exactly when `decimalPlaces` itself moves — which is the whole of
  /// D-14.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettings &&
        other.soundEnabled == soundEnabled &&
        other.vibrationEnabled == vibrationEnabled &&
        other.decimalPlaces == decimalPlaces &&
        other.historyEnabled == historyEnabled &&
        other.theme == theme;
  }

  @override
  int get hashCode => Object.hash(
    soundEnabled,
    vibrationEnabled,
    decimalPlaces,
    historyEnabled,
    theme,
  );

  @override
  String toString() =>
      'AppSettings(soundEnabled: $soundEnabled, '
      'vibrationEnabled: $vibrationEnabled, '
      'decimalPlaces: $decimalPlaces, '
      'historyEnabled: $historyEnabled, '
      'theme: $theme)';
}
