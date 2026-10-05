/// The app's [ThemeData]s, exposed as providers so a theme is resolved in one
/// place rather than constructed inline by `MaterialApp` (struction.md §14,
/// "themes").
///
/// The two themes are `core` design data and are named here, but which one is
/// *in effect* is user state, so the choice is made one layer up, in
/// `theme_controller.dart` (features/settings). Keeping the two apart is what
/// holds **D-24** and **D-28** down: `core` still never imports a feature, and
/// the seam **D-45** predicted — "it just has to be resolved in the features
/// layer rather than here" — is where the preference is now read.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';

/// The dark theme, for callers that name one directly.
///
/// The app itself resolves the *active* theme through
/// `theme_controller.dart` in features/settings, which is where the stored
/// preference is read (**D-45**); these two exist so a test or the
/// store-screenshot run can pin one theme regardless of what is in the store.
final darkThemeProvider = Provider<ThemeData>((ref) => AppTheme.dark);

/// The white theme — the sibling Ethar app's palette (D-90).
final lightThemeProvider = Provider<ThemeData>((ref) => AppTheme.light);