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

  /// Soft fill behind a settings row's leading icon — the **icon tile** (D-91).
  ///
  /// **Taken from the sibling app.** Ethar's `_SettingsColors.surfaceSoft` is
  /// `#20232A` in its dark theme and `#FAFAFB` in its white one, and its
  /// `_SettingsIconTile` is a 44 px square filled with exactly that. This is the
  /// dark half of that pair; [AppPalette.light] carries the other.
  ///
  /// A separate token from [surfaceRaised] rather than a reuse of it: the two
  /// fills happen to be near each other here, but the tile belongs to a row and
  /// `surfaceRaised` is the History card's, and one value serving both is the
  /// drift the token file exists to prevent.
  static const Color surfaceSoft = Color(0xFF20232A);

  /// The 1 px outline around a grouped card (D-91).
  ///
  /// **Taken from the sibling app.** Ethar draws
  /// `Border.all(color: colors.border)` on every settings card, `#292D35` in its
  /// dark theme. On a black page a card's fill alone gives it no edge —
  /// `#101011` on `#000000` is a difference you can see but not point at — and
  /// the outline is what makes it an object.
  static const Color cardBorder = Color(0xFF292D35);

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
  /// **Retuned in D-91 from `#1A1A1B` to `#292D35`.** The old value was
  /// "a chosen stand-in sized to sit just above [surface]" and it still does —
  /// but it was chosen before the card had an edge, and a hairline that is
  /// darker than the outline around the card reads as a crease in the card
  /// rather than as a boundary between two rows. Ethar's settings cards use one
  /// value for both (`_SettingsColors.divider` *is* `border`, `#292D35` in dark
  /// and `#ECEDEF` in white), and this is that value; [cardBorder] is the same
  /// number under the name that says where it is drawn.
  static const Color divider = Color(0xFF292D35);

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

  // --- Multi-select (D-76) ------------------------------------------------
  //
  // The History list's selection mode borrows the sibling app's pattern but
  // restates its accent in **white** rather than orange. Three tokens, because
  // the three roles are genuinely different and collapsing them is what makes a
  // selected card unreadable.

  /// Selection accent: the checkbox fill, the selected card's border, and the
  /// "N selected" count.
  ///
  /// White rather than [accent]. Orange is the app's *primary action* colour —
  /// `=`, the toggles, Clear History — and selection is a mode, not an action:
  /// painting three rows orange would claim three button presses. It is the same
  /// value as [textPrimary], stated separately so the intent survives the next
  /// reader: if the palette ever gains a second neutral, selection moves with
  /// the text, not with the accent.
  static const Color selectionAccent = Color(0xFFFFFFFF);

  /// Fill of a selected History card.
  ///
  /// **Not** [selectionAccent]. A pure-white card carrying this app's white
  /// result text would be unreadable, and inverting the type to fix that would
  /// turn a list of selected rows into a block of slabs that outshouts the
  /// numbers they exist to act on. This is white carried at low opacity over the
  /// black page — the same relationship [surfaceRaised] has to [background], one
  /// step further along — so the card reads as *lifted* rather than *filled*, and
  /// the accent on top of it stays the brightest thing in the row.
  static const Color surfaceSelected = Color(0xFF2E2E31);

  /// Tick inside a selected History card's checkbox.
  ///
  /// Black on white. [textPrimary] is the obvious thing to reach for and it is
  /// what the sibling app uses on its orange fill, but there the fill is a
  /// mid-tone and white still contrasts; on a *white* circle a white tick is
  /// invisible, so this is [textOnFunction] — the same black the app already
  /// prints on light fills.
  static const Color selectionCheck = Color(0xFF000000);
}