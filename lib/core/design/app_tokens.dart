/// Barrel for the design tokens, so a widget imports one file to reach the
/// whole visual language (struction.md §14, "tokens barrel").
///
/// The token values themselves live in [AppColors], [AppTypography], and the
/// spacing/size classes; they are single-definition-site and must not be
/// duplicated at call sites (desing.md §2).
library;

export 'app_colors.dart';
export 'app_spacing.dart';
export 'app_typography.dart';