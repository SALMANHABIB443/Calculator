import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';

/// The app's [ThemeData], exposed as a provider so the theme is resolved in
/// one place rather than constructed inline by `MaterialApp`
/// (struction.md §14, "themes").
///
/// Deliberately *not* wired to `AppSettings.theme` (**D-45**). Phase 3 left a
/// comment here saying Phase 6 would do it; Phase 6 declined. Dark is the only
/// theme in v1.0, so the stored value is always `dark` and reading it could
/// only ever produce this same `ThemeData`. Making the provider read the
/// settings would add the second `core → features` import that **D-24** and
/// **D-28** hold down to one, in exchange for a branch with a single arm.
/// Light mode is a Could Have, and when it arrives the seam is this provider —
/// it just has to be resolved in the features layer rather than here.
final appThemeProvider = Provider<ThemeData>((ref) => AppTheme.dark);

/// The [ThemeMode] paired with [appThemeProvider].
///
/// Always [ThemeMode.dark] in v1.0, for the same reason as above. Kept as a
/// separate provider so a later theme can switch mode without introducing a
/// second `ThemeData`.
final appThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.dark);
