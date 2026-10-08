import 'package:flutter/material.dart';

import '../design/app_palette.dart';

/// The menu slider's colours, resolved from the active [AppPalette].
///
/// This is the calculator's counterpart to Ethar's `_SettingsColors`
/// (`Ethar/lib/src/features/settings/settings_components.dart:3`) — the small
/// resolver the slide-in panel reads every paint from, so the panel follows the
/// theme rather than spelling hex values per brightness.
///
/// **Why a class over reads at the call site.** The panel paints nine distinct
/// roles and two of them ([softOrange], [accent]) have no single palette token
/// that means "the menu's warm fill" and "the menu's brand ink". Naming them
/// here keeps those two decisions in one file, and the eight that *do* map onto
/// [AppPalette] stay bound to the theme by mapping rather than by a second copy
/// of the same number — which is exactly the drift the palette exists to stop
/// (see `app_palette.dart`'s doc comment).
@immutable
class MenuColors {
  const MenuColors(this.context);

  final BuildContext context;

  AppPalette get _palette => context.appColors;

  /// Panel and page background — the colour behind the whole slide-in.
  Color get background => _palette.background;

  /// Card fill for the tiles' resting surface.
  Color get surface => _palette.surface;

  /// Soft fill for the 44 px icon tiles inside a row.
  Color get surfaceSoft => _palette.surfaceSoft;

  /// Primary ink — row labels and the header title.
  Color get text => _palette.textPrimary;

  /// Muted ink — chevrons and secondary lines.
  Color get secondary => _palette.textSecondary;

  /// Hairline around a resting tile.
  Color get border => _palette.cardBorder;

  /// Hairline between sections and inside the stats row.
  Color get divider => _palette.divider;

  /// The warm fill behind a footer action (Ethar's `_softOrange`).
  ///
  /// Two literals rather than a blend off [accent], because Ethar's own values
  /// (`#392116` dark, `#FFF0E8` light) were picked against its ink and are not
  /// a derivable function of the orange — recomputing them would produce a
  /// different fill than the design source this panel is copied from.
  Color get softOrange =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF392116)
          : const Color(0xFFFFF0E8);

  /// The brand orange for glyphs and labels sitting on [softOrange].
  Color get accent => _palette.accent;
}
