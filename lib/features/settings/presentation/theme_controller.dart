/// Where the stored theme name becomes a live `ThemeData` (D-90).
///
/// **D-45** said the seam for a second theme would be the theme provider and
/// that it "just has to be resolved in the features layer rather than here",
/// because `core` must not import a feature (**D-24**, **D-28**). This file is
/// that layer: `core/design` names the two themes, this file reads the user's
/// choice and picks between them, and `MaterialApp` consumes the result.
///
/// Reading [settingsProvider] rather than [settingsControllerProvider] keeps the
/// synchronous contract the rest of the app already depends on (D-41): the app
/// paints the default theme for the frames before the load lands and repaints
/// when it does, rather than flashing an unstyled screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_theme.dart';
import '../domain/app_settings.dart';
import 'settings_controller.dart';

/// The theme the stored preference names.
final appThemeProvider = Provider<ThemeData>((ref) {
  final name = AppThemeName.from(ref.watch(settingsProvider).theme);
  return switch (name) {
    AppThemeName.dark => AppTheme.dark,
    AppThemeName.light => AppTheme.light,
  };
});

/// The [ThemeMode] paired with [appThemeProvider].
///
/// Always [ThemeMode.light] rather than [ThemeMode.system]: both themes here are
/// explicit choices, so honouring the OS brightness would make the app look
/// light on a phone set to dark while the user's stored preference said black.
/// The name is kept distinct from the theme so a future "follow system" option
/// has somewhere to go without touching `MaterialApp`.
final appThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.light);