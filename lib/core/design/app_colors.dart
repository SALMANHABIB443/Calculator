import 'package:flutter/material.dart';

/// The single definition site for every colour in the app (desing.md §2).
///
/// These values were **measured directly from the mockup pixels** in Phase 1
/// and are authoritative under D-03; the earlier visual estimates are
/// superseded. Nothing outside this class may hard-code a hex value — screens
/// and components read them from here so a token change propagates in one edit.
abstract final class AppColors {
  /// Full screen background. The page colour behind every card and row.
  static const Color background = Color(0xFF000000);

  /// Card and row surface, sitting just above [background] so the two read as
  /// distinct layers on a black page.
  static const Color surface = Color(0xFF101011);

  /// Fill of the History cards.
  ///
  /// **Chosen, not measured (D-72).** The History redesign specifies `#151517`,
  /// one step lighter than [surface]. It is a separate token rather than an edit
  /// to [surface] because [surface] is the shared fill of the Settings groups,
  /// the About hero card, the confirmation dialog, and the decimal-places sheet:
  /// moving it would restyle three other screens. Naming the lighter fill keeps
  /// the redesign inside History while the rest of the app stays where D-60
  /// measured it.
  static const Color surfaceRaised = Color(0xFF151517);

  /// Primary accent. Reserved for primary actions only: operator keys, `=`,
  /// toggles when ON, Clear History, and active icons.
  static const Color accent = Color(0xFFF89508);

  /// Fill for the digit keys and the decimal point.
  static const Color buttonDigit = Color(0xFF1E1E1E);

  /// Fill for the function keys (`AC`, `+/−`, `%`).
  ///
  /// Note the inverted contrast this implies: these keys are a light mid-gray
  /// carrying [textOnFunction] labels, not a medium gray with white labels.
  /// This was the largest correction in the Phase 1 measurement.
  static const Color buttonFunction = Color(0xFF949494);

  /// Main result, headings, active labels, and keys on dark fills.
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Label colour for keys filled with [buttonFunction].
  static const Color textOnFunction = Color(0xFF000000);

  /// Expression line, descriptions, subtitles, and section headers.
  static const Color textSecondary = Color(0xFF949AA4);

  /// Separator between rows inside a grouped card.
  ///
  /// **Unmeasured.** desing.md §2 specifies only a "subtle dark line" with no
  /// value, so this is a chosen stand-in sized to sit just above [surface].
  /// Tuned during the Phase 9 pixel comparison.
  static const Color divider = Color(0xFF1A1A1B);

  /// Track fill of a toggle in the ON state (desing.md §5.2).
  static const Color toggleTrackOn = Color(0xFFF89508);

  /// Track fill of a toggle in the OFF state.
  ///
  /// **Chosen, not measured — residual unknown R-1, closed in Phase 9.** Phase
  /// 9 read the mockup pixels for the first time (Phases 2–8 could not open
  /// them) and confirmed what Phase 1 had suspected: all three toggles in the
  /// Settings mockup are ON. The tracks measure 44 × 25.5 px and are orange
  /// `#F89508`, so **no mockup contains the OFF state** and no value for it
  /// can be derived from the source material. This is a decision, not a
  /// measurement.
  ///
  /// The platform default was rejected because it renders a light gray track
  /// that breaks the black/gray palette. This value is a dark gray in the same
  /// family as [buttonDigit], so it sits in the palette rather than on top of
  /// it. Accepted as final for v1.0 (**D-61**); a designer hand-off would
  /// supersede it, and this is the single edit needed if one arrives.
  static const Color toggleTrackOff = Color(0xFF2A2A2A);

  /// Toggle thumb, ON and OFF alike.
  static const Color toggleThumb = Color(0xFFFFFFFF);

  /// Opacity applied to a pressed key or button (desing.md §8).
  ///
  /// Pressed states are absent from the mockups, so this is the standard
  /// platform feedback the specification calls for.
  static const double pressedOpacity = 0.85;
}
