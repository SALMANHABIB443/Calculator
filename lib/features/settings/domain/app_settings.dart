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

  /// Theme name. Only `dark` in v1.0.
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

