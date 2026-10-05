import '../../../core/design/app_palette.dart';

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The type scale with its **colours resolved against a palette** (D-90).
///
/// ## Why this is a second layer rather than an edit to [AppTypography]
///
/// Every token in [AppTypography] is a `const TextStyle` with its colour baked
/// in, and that is what makes them cheap to use and safe to assert on. It is
/// also exactly why they could not follow a theme: `AppTypography.rowTitle.color`
/// is white, permanently, on a white page.
///
/// So the sizes and weights stay where they are — one definition, still
/// assertable, still the thing the design doc pins — and only the colour is
/// re-applied here. Every getter is the matching [AppTypography] token with its
/// colour swapped for the palette's, so a font-size change lands in one place
/// and a palette change lands in the other, and neither can drift.
///
/// Widgets read `context.type.rowTitle` rather than `AppTypography.rowTitle`.
class AppType {
  /// Binds the scale to [palette].
  const AppType(this.palette);

  /// The colours this scale paints with.
  final AppPalette palette;

  Color get _primary => palette.textPrimary;
  Color get _secondary => palette.textSecondary;
  Color get _accent => palette.accent;

  /// Hero result on the calculator display.
  TextStyle get resultLarge =>
      AppTypography.resultLarge.copyWith(color: _primary);

  /// Result style used where the value can get long.
  TextStyle get resultMedium =>
      AppTypography.resultMedium.copyWith(color: _primary);

  /// Expression line above the result.
  TextStyle get expression =>
      AppTypography.expression.copyWith(color: _secondary);

  /// Screen title in a page header.
  TextStyle get screenTitle =>
      AppTypography.screenTitle.copyWith(color: _primary);

  /// Compact screen title, one step down from [screenTitle].
  TextStyle get screenTitleCompact =>
      AppTypography.screenTitleCompact.copyWith(color: _primary);

  /// Subtitle under a screen title.
  TextStyle get subtitle => AppTypography.subtitle.copyWith(color: _secondary);

  /// Uppercase group label.
  TextStyle get sectionHeader =>
      AppTypography.sectionHeader.copyWith(color: _secondary);

  /// Primary label in a settings row.
  TextStyle get rowTitle => AppTypography.rowTitle.copyWith(color: _primary);

  /// Supporting label in a settings row.
  TextStyle get rowSubtitle =>
      AppTypography.rowSubtitle.copyWith(color: _secondary);

  /// Expression in a history card's meta row (D-93).
  TextStyle get historyExpression =>
      AppTypography.historyExpression.copyWith(color: _secondary);

  /// Result, the title line of a history card (D-93).
  TextStyle get historyResult =>
      AppTypography.historyResult.copyWith(color: _primary);

  /// Day label above a group of history cards.
  TextStyle get historyDayLabel =>
      AppTypography.historyDayLabel.copyWith(color: _secondary);

  /// "Clear History" at the foot of the history screen.
  TextStyle get bottomAction =>
      AppTypography.bottomAction.copyWith(color: _accent);

  /// Small print: the version footer and legal metadata.
  TextStyle get caption => AppTypography.caption.copyWith(color: _secondary);

  /// Body copy on the legal screens.
  TextStyle get body => AppTypography.body.copyWith(color: _secondary);

  /// Section heading on the legal screens.
  TextStyle get legalHeading =>
      AppTypography.legalHeading.copyWith(color: _primary);

  /// Value shown on the trailing side of a settings row.
  TextStyle get rowValue => AppTypography.rowValue.copyWith(color: _secondary);

  /// The selection count in the History header.
  TextStyle get selectionCount =>
      AppTypography.selectionCount.copyWith(color: palette.selectionAccent);

  /// Label on a calculator key.
  ///
  /// The one token with no colour of its own: a key's label takes the colour of
  /// whatever fill it is printed on, so the variant decides it per key rather
  /// than the scale deciding it once. Delegating keeps the size and weight in
  /// one place all the same.
  TextStyle get buttonLabel => AppTypography.buttonLabel;
}

/// Reads the palette-bound type scale off a [BuildContext].
///
/// `context.type.rowTitle` rather than `AppTypography.rowTitle`: the first
/// follows the theme, the second carries the dark theme's white forever.
extension AppTypeContext on BuildContext {
  /// The type scale this subtree is painting with.
  AppType get type => AppType(AppPalette.of(this));
}

/// The single definition site for text styles (desing.md §3).
///
/// Every size below is the exact value desing.md §3.1 now states. That document
/// used to give a **range** per style, and each size here was the midpoint of it;
/// the midpoints are now the values Phase 9 compared against the mockups at 1x, so
/// what follows is a record of how a number was arrived at rather than a live
/// instruction.
///
/// The system font is used throughout (SF Pro on iOS, Roboto on Android) so no
/// custom asset ships; only weight and size are specified.
abstract final class AppTypography {
  static const List<FontFeature> _tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  /// Hero result on the calculator display (desing.md §3.1).
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

  /// Expression line above the result (desing.md §3.1).
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
  /// (desing.md §3.1).
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

  /// Primary label in a settings row — “Sound”, “Vibration” (desing.md §3.1).
  static const TextStyle rowTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 17,
    fontWeight: FontWeight.w500,
  );

  /// Supporting label in a settings row — “Key press sound” (desing.md §3.1).
  static const TextStyle rowSubtitle = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  /// Expression at the *bottom* of a history card — “125 × 8” (D-93: 13).
  ///
  /// **Re-specced from 16/w500 to 13/w400.** D-73 had this leading the card above
  /// the result; D-93 adopts Ethar's `_TaskCard` hierarchy whole, where the
  /// *title* is the thing the row is about and the expression is its meta line
  /// (13 muted, one line, `task_list.dart:519`). For a task the title is what it
  /// is; for a calculation the **result** is — `125 × 8` is how the row got made,
  /// `1,000` is why the user came back. So the two styles swap ranks here, and
  /// this one takes the meta band.
  static const TextStyle historyExpression = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  /// Result at the *top* of a history card — “1,000” (D-93: 17/w700).
  ///
  /// **Re-specced from 22/w600 to 17/w700** — Ethar's task title exactly
  /// (`task_list.dart:496`). It was the largest thing on the card for three
  /// decisions (D-72 at 44, D-73 at 22); it is now the card's *rank* rather than
  /// its scale that makes it the line you read first, which is the same thing
  /// Ethar's row does with a 17 px title against a 13 px meta line.
  ///
  /// The tabular figures stay: this is a number that has to line up with the
  /// numbers in the rows above and below it, and that is a property of the
  /// glyphs rather than of its size.
  static const TextStyle historyResult = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.25,
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

  /// Label on a calculator key (desing.md §3.1).
  static const TextStyle buttonLabel = TextStyle(
    fontSize: 25,
    fontWeight: FontWeight.w500,
  );

  /// “Clear History” at the foot of the history screen (desing.md §3.1).
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

  /// The selection count in the History header — “3 selected” (D-76).
  ///
  /// A named token rather than a `copyWith` of [screenTitle] at the call site for
  /// the reason [historyDayLabel] exists: this is the one place the header stops
  /// being a screen title, and an in-place size edit would shrink the real title
  /// beside it. The colour is [selectionAccent] rather than [textPrimary] so the
  /// count reads as belonging to the selection controls on the same row.
  static const TextStyle selectionCount = TextStyle(
    color: AppColors.selectionAccent,
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );
}
