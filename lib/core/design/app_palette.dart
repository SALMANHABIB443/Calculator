import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The app's colours as a *resolvable* set, one instance per theme (D-90).
///
/// ## Why this exists
///
/// [AppColors] holds the palette measured from the mockup pixels and it is the
/// single definition site for the dark theme. It is a set of `static const`
/// fields, which is exactly right for a theme that never changes and exactly
/// wrong for two: a `const` cannot be swapped at runtime, so every widget that
/// read `AppColors.background` painted black no matter what theme the app was
/// in. Adding a white theme therefore cannot be done by editing hex values —
/// it has to be done by moving the reads behind something the widget tree can
/// resolve, and this is that something.
///
/// A [ThemeExtension] rather than a bare global or an inherited widget:
/// * the theme owns it, so it travels with `Theme.of(context)` and is rebuilt
///   with the theme, with nothing global to keep in sync;
/// * it reaches `core` widgets with no `core -> features` import (D-24),
///   because the palette is pure design data, not user state;
/// * light and dark then differ only in the instance they install.
///
/// ## The two palettes
///
/// [dark] **is** [AppColors]: every field resolves to the existing token, so the
/// dark theme is unchanged and the design-system tests that assert those
/// literals still hold.
///
/// [light] is the white theme, taken from the sibling **Ethar** app so the two
/// apps read as one family: page `#FEFEFE`, cards `#FFFFFF`, soft fills
/// `#FAFAFB`, ink `#0C0F16`, muted `#656A78`, hairlines `#ECEDEF`, and the
/// orange `#FE651B` Ethar uses for its primary action. The two accents differ
/// between the themes on purpose — `#F89508` is what the calculator's mockup
/// pixels measured, and `#FE651B` is Ethar's brand orange — so neither theme's
/// accent had to be re-measured to give the other up.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  /// Creates a palette. Use [dark] or [light] rather than spelling this out; a
  /// bespoke instance is how the two themes would drift apart.
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSoft,
    required this.cardBorder,
    required this.cardShadow,
    required this.surfaceSelected,
    required this.accent,
    required this.buttonDigit,
    required this.buttonFunction,
    required this.textPrimary,
    required this.textOnFunction,
    required this.textOnAccent,
    required this.textSecondary,
    required this.divider,
    required this.ruleOnPage,
    required this.toggleTrackOn,
    required this.toggleTrackOff,
    required this.toggleThumb,
    required this.selectionAccent,
    required this.selectionCheck,
    required this.pressedOpacity,
    required this.keyShadow,
    required this.keyBorder,
  });

  /// Full screen background. The page colour behind every card and row.
  final Color background;

  /// The app's standard card fill, sitting just above [background].
  ///
  /// Read by the Settings groups, the History cards, the About hero card, the
  /// dialogs and the sheets. The History card used to read [surfaceRaised] so it
  /// would not restyle those screens; it now reads this one, because a card
  /// that is a different colour on one screen and the same colour on another
  /// reads as a mistake rather than as a distinction.
  final Color surface;

  /// A surface one step above [surface] that is **not** a card — see
  /// [AppColors.surfaceRaised]. The History card, which used to read this, now
  /// reads [surface] like every other card in the app.
  final Color surfaceRaised;

  /// Fill of a selected History card.
  final Color surfaceSelected;

  /// Soft fill behind a row's leading icon — the **settings row icon tile**
  /// (D-91).
  ///
  /// One step *below* [surface] in the light theme and one step *above* it in the
  /// dark theme, because a tile has to separate from its card in both: a
  /// lighter tile on white, a lighter tile on near-black. Ethar's
  /// `_SettingsIconTile` calls the same colour `surfaceSoft`
  /// (`#FAFAFB` light / `#20232A` dark) and this is that value, so the row
  /// reads as the same object in both apps.
  final Color surfaceSoft;

  /// The 1 px outline around a grouped card (D-91).
  ///
  /// **Taken from the sibling app, not chosen.** Ethar's
  /// `_settingsCardDecoration` draws `Border.all(color: colors.border)` on every
  /// settings card, `#ECEDEF` in its white theme and `#292D35` in its dark one.
  /// A card on a black page has no edge without it — [surface] is one step above
  /// [background] and a fill alone cannot say "this ends here".
  final Color cardBorder;

  /// The card's drop shadow, or `null` where there is none (D-91).
  ///
  /// A `BoxShadow` cannot express "no shadow" as a colour, so absence is spelled
  /// `null` rather than a transparent black: the dark theme has `null` and the
  /// white theme carries Ethar's `Color(0x0D0F172A)` at blur 24, offset (0, 8).
  /// Ethar drops its shadow in dark for the same reason it does everywhere else
  /// on a black page — there is nothing for it to lift.
  final Color? cardShadow;

  /// Primary accent. Reserved for primary actions only: operator keys, `=`,
  /// toggles when ON, Clear History, and active icons.
  final Color accent;

  /// Fill for the digit keys and the decimal point.
  final Color buttonDigit;

  /// Fill for the function keys (`AC`, `+/−`, `%`).
  final Color buttonFunction;

  /// Main result, headings, active labels, and keys on dark fills.
  final Color textPrimary;

  /// Label colour for keys filled with [buttonFunction].
  final Color textOnFunction;

  /// Label colour for anything filled with [accent].
  ///
  /// A separate token from [textPrimary] because in the dark theme the digit
  /// keys and the accent keys both want white, so [textPrimary] answered for
  /// both — they agreed there by accident, not by design. In the light theme
  /// they disagree: digits are near-white and want ink, `=` is orange and
  /// still wants white. Reading [textPrimary] for the orange key would have
  /// printed ink on orange.
  final Color textOnAccent;

  /// Expression line, descriptions, subtitles, and section headers.
  final Color textSecondary;

  /// Separator between rows inside a grouped card.
  final Color divider;

  /// The 1 px rule between the calculator's display and its keypad.
  ///
  /// Separate from [divider] because the two are different objects that must not
  /// be allowed to drift: [divider] is a hairline *inside* a grouped card, this
  /// is a rule *across* an open page, and one shared value standing for both is
  /// the failure this class exists to prevent.
  final Color ruleOnPage;

  /// Track fill of a toggle in the ON state.
  final Color toggleTrackOn;

  /// Track fill of a toggle in the OFF state.
  final Color toggleTrackOff;

  /// Toggle thumb, ON and OFF alike.
  final Color toggleThumb;

  /// Selection accent: the checkbox fill, the selected card's border, and the
  /// "N selected" count.
  final Color selectionAccent;

  /// Tick inside a selected History card's checkbox.
  final Color selectionCheck;

  /// Opacity applied to a pressed key or button.
  final double pressedOpacity;

  /// The glow a calculator key casts, or `null` where there is none (D-111).
  ///
  /// A dark *glow* on the black page and a dark *shadow* on the white one,
  /// because the two themes need opposite colours to separate a key from what is
  /// behind it — see [AppColors.keyShadow] for why elevation could not do this.
  final Color? keyShadow;

  /// The 1 px outline drawn around every calculator key (D-111).
  final Color keyBorder;

  /// The dark palette — every field is the token [AppColors] already holds.
  static const AppPalette dark = AppPalette(
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceRaised: AppColors.surfaceRaised,
    surfaceSelected: AppColors.surfaceSelected,
    // D-91: the three card-edge tokens, taken from Ethar's
    // `_SettingsColors`. `#20232A` sits a step above the near-black card and
    // `#292D35` draws the edge a fill alone cannot.
    surfaceSoft: AppColors.surfaceSoft,
    cardBorder: AppColors.cardBorder,
    // No shadow on a black page — Ethar drops it in dark for the same reason.
    cardShadow: null,
    accent: AppColors.accent,
    buttonDigit: AppColors.buttonDigit,
    buttonFunction: AppColors.buttonFunction,
    textPrimary: AppColors.textPrimary,
    textOnFunction: AppColors.textOnFunction,
    // No such token existed before the white theme: in the dark theme the
    // accent keys and the digit keys both wanted white, so `textPrimary`
    // answered for both. The token is named rather than reused so the light
    // theme is free to disagree with it.
    textOnAccent: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    divider: AppColors.divider,
    ruleOnPage: AppColors.ruleOnPage,
    toggleTrackOn: AppColors.toggleTrackOn,
    toggleTrackOff: AppColors.toggleTrackOff,
    toggleThumb: AppColors.toggleThumb,
    selectionAccent: AppColors.selectionAccent,
    selectionCheck: AppColors.selectionCheck,
    pressedOpacity: AppColors.pressedOpacity,
    // D-111: elevation could not survive the black page — a framework-drawn
    // shadow there is black on black. The key casts a faint white halo instead,
    // plus a hard 1 px edge, which is what actually makes it an object.
    keyShadow: AppColors.keyShadow,
    keyBorder: AppColors.keyBorder,
  );
  /// The white palette, matching the sibling Ethar app's white theme.
  ///
  /// Every value is Ethar's own token block except the keypad fills, which Ethar
  /// has no equivalent of. Those follow the *same relationship the dark theme
  /// uses* rather than being re-invented: digits sit a step below the card so
  /// they read as keys on the page, and the function keys sit a step further
  /// still, so `AC` and `=` are told apart at a glance exactly as they are on
  /// black.
  static const AppPalette light = AppPalette(
    background: Color(0xFFFEFEFE),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFAFAFB),
    surfaceSelected: Color(0xFFF0F1F3),
    surfaceSoft: Color(0xFFFAFAFB),
    cardBorder: Color(0xFFECEDEF),
    cardShadow: Color(0x0D0F172A),
    accent: Color(0xFFFE651B),
    buttonDigit: Color(0xFFF4F5F7),
    buttonFunction: Color(0xFFD9DADD),
    textPrimary: Color(0xFF0C0F16),
    textOnFunction: Color(0xFF0C0F16),
    textOnAccent: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF656A78),
    divider: Color(0xFFECEDEF),
    // The light half of the display-to-keypad rule. A dark-theme hairline on a
    // white page is invisible, so the light theme states its own rather than
    // inheriting a value that only reads on black.
    ruleOnPage: Color(0xFFDCDEE2),
    toggleTrackOn: Color(0xFFFE651B),
    toggleTrackOff: Color(0xFFDFE1E5),
    toggleThumb: Color(0xFFFFFFFF),
    // Ink rather than the dark theme's white: selection is painted as a filled
    // disc with a tick cut out of it, and a white disc on a white card would be
    // invisible. The pairing is the dark theme's, inverted.
    selectionAccent: Color(0xFF0C0F16),
    selectionCheck: Color(0xFFFFFFFF),
    pressedOpacity: AppColors.pressedOpacity,
    // The white half of the pair. Here a dark shadow is the conventional and
    // correct answer, so the light theme casts one and skips the halo entirely —
    // the two themes differ because the page differs, not for variety.
    keyShadow: Color(0x1F0F172A),
    keyBorder: Color(0xFFE4E6EA),
  );

  /// The palette the [context] is currently painting with.
  ///
  /// Falls back to [dark] when no extension is installed, so a widget pumped
  /// on its own — a component-catalog entry in a test, say — still gets a
  /// complete palette instead of a null crash.
  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? dark;

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSelected,
    Color? surfaceSoft,
    Color? cardBorder,
    Color? cardShadow,
    Color? accent,
    Color? buttonDigit,
    Color? buttonFunction,
    Color? textPrimary,
    Color? textOnFunction,
    Color? textOnAccent,
    Color? textSecondary,
    Color? divider,
    Color? ruleOnPage,
    Color? toggleTrackOn,
    Color? toggleTrackOff,
    Color? toggleThumb,
    Color? selectionAccent,
    Color? selectionCheck,
    double? pressedOpacity,
    Color? keyShadow,
    Color? keyBorder,
  }) => AppPalette(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    surfaceSelected: surfaceSelected ?? this.surfaceSelected,
    surfaceSoft: surfaceSoft ?? this.surfaceSoft,
    cardBorder: cardBorder ?? this.cardBorder,
    // The one nullable field, so `null` here means "leave the shadow alone"
    // rather than "remove it" — there is no other way to ask for absence here,
    // and `CardDecoration` is the only place that wants to.
    cardShadow: cardShadow ?? this.cardShadow,
    accent: accent ?? this.accent,
    buttonDigit: buttonDigit ?? this.buttonDigit,
    buttonFunction: buttonFunction ?? this.buttonFunction,
    textPrimary: textPrimary ?? this.textPrimary,
    textOnFunction: textOnFunction ?? this.textOnFunction,
    textOnAccent: textOnAccent ?? this.textOnAccent,
    textSecondary: textSecondary ?? this.textSecondary,
    divider: divider ?? this.divider,
    ruleOnPage: ruleOnPage ?? this.ruleOnPage,
    toggleTrackOn: toggleTrackOn ?? this.toggleTrackOn,
    toggleTrackOff: toggleTrackOff ?? this.toggleTrackOff,
    toggleThumb: toggleThumb ?? this.toggleThumb,
    selectionAccent: selectionAccent ?? this.selectionAccent,
    selectionCheck: selectionCheck ?? this.selectionCheck,
    pressedOpacity: pressedOpacity ?? this.pressedOpacity,
    // Nullable for the same reason [cardShadow] is: `null` means "leave the
    // shadow alone", and that is the only way to ask for it here.
    keyShadow: keyShadow ?? this.keyShadow,
    keyBorder: keyBorder ?? this.keyBorder,
  );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    // Read into locals because a final field on `this` is not promoted by the
    // null checks below — Dart does not promote instance fields, so the ternary
    // would still see `Color?` on the third arm.
    final shadow = cardShadow;
    final otherShadow = other.cardShadow;
    // The same local-read for the key's glow, for the same promotion reason.
    final keyGlow = keyShadow;
    final otherKeyGlow = other.keyShadow;
    return AppPalette(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      surfaceSelected: mix(surfaceSelected, other.surfaceSelected),
      surfaceSoft: mix(surfaceSoft, other.surfaceSoft),
      cardBorder: mix(cardBorder, other.cardBorder),
      // A theme change crosses from no shadow to a shadow. Fading in from the
      // side that has one is enough: the intermediate frame is still a card,
      // and an alpha ramp reads as the page settling rather than as a shadow
      // popping on halfway through.
      cardShadow: shadow == null
          ? otherShadow
          : otherShadow == null
          ? shadow
          : mix(shadow, otherShadow),
      accent: mix(accent, other.accent),
      buttonDigit: mix(buttonDigit, other.buttonDigit),
      buttonFunction: mix(buttonFunction, other.buttonFunction),
      textPrimary: mix(textPrimary, other.textPrimary),
      textOnFunction: mix(textOnFunction, other.textOnFunction),
      textOnAccent: mix(textOnAccent, other.textOnAccent),
      textSecondary: mix(textSecondary, other.textSecondary),
      divider: mix(divider, other.divider),
      ruleOnPage: mix(ruleOnPage, other.ruleOnPage),
      toggleTrackOn: mix(toggleTrackOn, other.toggleTrackOn),
      toggleTrackOff: mix(toggleTrackOff, other.toggleTrackOff),
      toggleThumb: mix(toggleThumb, other.toggleThumb),
      selectionAccent: mix(selectionAccent, other.selectionAccent),
      selectionCheck: mix(selectionCheck, other.selectionCheck),
      pressedOpacity:
          pressedOpacity + (other.pressedOpacity - pressedOpacity) * t,
      // Both palettes state a glow, so this normally mixes; the null arms are
      // there only so a bespoke palette cannot make the lerp throw.
      keyShadow: keyGlow == null
          ? otherKeyGlow
          : otherKeyGlow == null
          ? keyGlow
          : mix(keyGlow, otherKeyGlow),
      keyBorder: mix(keyBorder, other.keyBorder),
    );
  }
}

/// Reads the active palette off a [BuildContext].
///
/// `context.appColors.background` rather than `AppColors.background`: the first
/// follows the theme, the second is the dark palette frozen at compile time.
extension AppPaletteContext on BuildContext {
  /// The palette this subtree is painting with.
  AppPalette get appColors => AppPalette.of(this);
}