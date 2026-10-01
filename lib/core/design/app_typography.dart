import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The single definition site for text styles (desing.md §3).
///
/// desing.md gives a **size range** per style rather than a measured value, so
/// each size here is the midpoint of its range — the same reasoning that left
/// the key diameter as a range (R-2). Rounding consistently to the midpoint
/// gives Phase 9 a single number to move when it compares against the mockups
/// at 1x.
///
/// The system font is used throughout (SF Pro on iOS, Roboto on Android) so no
/// custom asset ships; only weight and size are specified.
abstract final class AppTypography {
  static const List<FontFeature> _tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  /// Hero result on the calculator display (desing.md range 56–64).
  static const TextStyle resultLarge = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 60,
    fontWeight: FontWeight.w600,
    height: 1.1,
  );

  /// Result style used where the value can get long and the display needs to
  /// shrink it. One step down from [resultLarge].
  static const TextStyle resultMedium = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 44,
    fontWeight: FontWeight.w600,
    height: 1.1,
  );

  /// Expression line above the result (desing.md range 18–22).
  static const TextStyle expression = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 20,
    fontWeight: FontWeight.w400,
  );

  /// Screen title in a page header — “Settings”, “History”, “About”
  /// (range 28–34).
  static const TextStyle screenTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 32,
    fontWeight: FontWeight.w700,
  );

  /// Compact screen title, one step down from [screenTitle] — the Settings
  /// header, which carries no subtitle to balance it against (range 28–34).
  ///
  /// A token rather than a `copyWith` at the call site so the size has one
  /// definition, and so the About hero card — which also prints a screen-title
  /// — cannot be dragged along with it (D-71).
  static const TextStyle screenTitleCompact = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 28,
    fontWeight: FontWeight.w700,
  );

  /// Subtitle under a screen title, e.g. “Simple calculator, powerful features”
  /// (desing.md range 15–17).
  static const TextStyle subtitle = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );

  /// Uppercase group label — “APPEARANCE”, “PREFERENCES”, “Today” (range 13–14).
  static const TextStyle sectionHeader = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.1,
  );

  /// Primary label in a settings row — “Sound”, “Vibration” (desing.md 17).
  static const TextStyle rowTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 17,
    fontWeight: FontWeight.w500,
  );

  /// Supporting label in a settings row — “Key press sound” (desing.md 13–15).
  static const TextStyle rowSubtitle = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  /// Expression at the top of a history card — “125 × 8” (desing.md §3: 15–16).
  ///
  /// D-72 pushed this to 28 on a claim of spaciousness; D-73 puts it back on the
  /// documented band, because at 28 the expression was competing with the result
  /// it is supposed to introduce rather than leading it.
  static const TextStyle historyExpression = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Result at the bottom of a history card — “1,000” (desing.md §3: 20–22).
  ///
  /// D-72's 44 made the result outrank even the page title (32); D-73 returns it
  /// to the design doc's band, where it is still the largest thing on the card
  /// and the number the user came back to read.
  static const TextStyle historyResult = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.1,
    fontFeatures: _tabularFigures,
  );

  /// Day label above a group of history cards — “Today”, “Yesterday” (D-73: 17).
  ///
  /// A separate token from [sectionHeader] rather than a `copyWith` at the call
  /// site, for the same reason [screenTitleCompact] exists: History speaks in
  /// sentence case at reading size while Settings and About keep their 14 px
  /// uppercase ones, and one shared style cannot be both. 17 is [rowTitle]'s
  /// size, so a day heading and a row label are the same kind of thing at the
  /// same rank.
  static const TextStyle historyDayLabel = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Label on a calculator key (desing.md range 22–28).
  static const TextStyle buttonLabel = TextStyle(
    fontSize: 25,
    fontWeight: FontWeight.w500,
  );

  /// “Clear History” at the foot of the history screen (desing.md 16–17).
  static const TextStyle bottomAction = TextStyle(
    color: AppColors.accent,
    fontSize: 17,
    fontWeight: FontWeight.w500,
  );

  /// Small print: the version footer and legal metadata.
  static const TextStyle caption = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  /// Body copy on the legal screens.
  static const TextStyle body = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Section heading on the legal screens.
  static const TextStyle legalHeading = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  /// Value shown on the trailing side of a settings row, e.g. `2` or `On`.
  static const TextStyle rowValue = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );
}
