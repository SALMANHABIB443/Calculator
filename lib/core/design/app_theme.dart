import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Shared [ThemeData] for the app.
///
/// v1.0 is dark-only, so a single [dark] ThemeData is used for both `light`
/// and `dark` in [ThemeMode.dark] (desing.md §4, D-09). Every value here is
/// read from a token, so this class composes the design system rather than
/// restating it.
abstract final class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.surface,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.accent,
        onPrimary: AppColors.textPrimary,
        surface: AppColors.background,
        onSurface: AppColors.textPrimary,
        error: AppColors.accent,
        onError: AppColors.textPrimary,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTypography.screenTitle,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textPrimary,
        textColor: AppColors.textPrimary,
        titleTextStyle: AppTypography.rowTitle,
        subtitleTextStyle: AppTypography.rowSubtitle,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        titleTextStyle: AppTypography.rowTitle,
        contentTextStyle: AppTypography.body,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
      ),
      // The R-1 OFF track is fixed here and nowhere else, so Phase 9 can
      // correct the colour by editing AppColors.toggleTrackOff alone. The thumb
      // is white in both states (desing.md §5.2).
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll<Color>(AppColors.toggleThumb),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.toggleTrackOn
              : AppColors.toggleTrackOff,
        ),
        trackOutlineColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 24),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
