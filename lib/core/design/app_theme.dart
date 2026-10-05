import '../../../core/design/app_palette.dart';
import 'package:flutter/material.dart';

import 'app_spacing.dart';
import 'app_typography.dart';

/// The app's two [ThemeData]s, one per palette (D-90).
///
/// [dark] is unchanged from what shipped: every value still resolves to the
/// token in `AppColors`, so the dark theme renders exactly as the mockup
/// measured and the design-system tests that assert those literals still hold.
///
/// [light] is the white theme, built from [AppPalette.light] — the sibling
/// Ethar app's palette, so the two apps read as one family.
///
/// Both are produced by [_build], so a widget-level difference between the two
/// themes cannot creep in on one side only: there is no second copy of the
/// dialog, divider, or switch wiring to forget to update.
abstract final class AppTheme {
  /// The dark theme, as it shipped before the white theme existed.
  static ThemeData get dark => _build(AppPalette.dark, Brightness.dark);

  /// The white theme.
  static ThemeData get light => _build(AppPalette.light, Brightness.light);

  /// The theme for [palette] at [brightness].
  ///
  /// Public because the Settings screen resolves the stored preference through
  /// it: `AppSettings.theme` is a name, and this is the one place a name becomes
  /// a `ThemeData`.
  static ThemeData of(AppPalette palette, Brightness brightness) =>
      _build(palette, brightness);

  /// Composes one theme from [palette].
  ///
  /// `ThemeData.dark`/`ThemeData.light` rather than a seeded `ColorScheme`: the
  /// palette is the authority on colour here, and a seed scheme would derive a
  /// second, competing set of colours that nothing in the app reads.
  static ThemeData _build(AppPalette palette, Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    final type = AppType(palette);

    return base.copyWith(
      // The palette is what every widget reads for its own fills, and this is
      // what the framework reads for the ones it paints itself (a Scaffold, a
      // `ListTile` default, a scrollbar). Both come from the same instance, so
      // the page behind a card and the card cannot disagree.
      extensions: <ThemeExtension<dynamic>>[palette],
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.surface,
      colorScheme: base.colorScheme.copyWith(
        primary: palette.accent,
        onPrimary: palette.textOnAccent,
        surface: palette.background,
        onSurface: palette.textPrimary,
        // The accent doubles as the error colour, as it did before the white
        // theme: this app has one alarm colour, and a second red would be the
        // only hue in the palette that appears on exactly one screen.
        error: palette.accent,
        onError: palette.textOnAccent,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: palette.textPrimary,
        displayColor: palette.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        surfaceTintColor: palette.background,
        foregroundColor: palette.textPrimary,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: type.screenTitle,
      ),
      dividerTheme: DividerThemeData(
        color: palette.divider,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.textPrimary,
        textColor: palette.textPrimary,
        titleTextStyle: type.rowTitle,
        subtitleTextStyle: type.rowSubtitle,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: palette.surface,
        titleTextStyle: type.rowTitle,
        contentTextStyle: type.body,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
          side: BorderSide(color: palette.divider),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: palette.surface,
        elevation: 10,
        // The sheet's drag handle is drawn by the framework in a default colour
        // chosen for the other theme — invisible on black, and Ethar draws it
        // `#D9DADD` on white. Taking it from the palette is what stops the two
        // themes disagreeing about the one control the app does not draw.
        dragHandleColor: palette.buttonFunction,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        // The dark theme's snackbar was the ink colour carrying white text; in
        // the white theme that would be a black bar, which is not a snackbar
        // anyone expects on a white page. Ink and white swap roles, so the bar
        // is always the *contrast* of the page it sits on.
        backgroundColor: palette.textPrimary,
        contentTextStyle: TextStyle(
          color: palette.background,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        elevation: 8,
        insetPadding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
      ),
      // The R-1 OFF track is fixed here and nowhere else, so a designer hand-off
      // can correct the colour by editing the palette alone. The thumb is the
      // opposite of the track in both themes (desing.md §5.2).
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll<Color>(palette.toggleThumb),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.toggleTrackOn
              : palette.toggleTrackOff,
        ),
        trackOutlineColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
      ),
      iconTheme: IconThemeData(color: palette.textPrimary, size: 24),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}