import 'package:flutter/material.dart';

/// The single definition site for spacing, radii, and fixed layout sizes
/// (desing.md §4, §5).
abstract final class AppSpacing {
  /// Horizontal screen margin.
  ///
  /// **Measured at 24–25 px in Phase 9 (D-60).** desing.md §4 originally allowed
  /// 16–20, but the card edges in the History, Settings, and About mockups all
  /// sit at logical x≈24 — consistently, across three independently rendered
  /// images. Phase 9 read the mockup pixels directly, which Phases 2–8 could not
  /// do, and corrected this from 20.
  ///
  /// This one token also sets the calculator key size, because the keypad sizes
  /// its cells from the width left over after the margins (D-27). At the
  /// 442×890 mockup canvas the grid maths is:
  ///
  /// ```
  /// margin 20 -> cell (442 - 40 - 3*14) / 4 = 90.0   too large
  /// margin 24 -> cell (442 - 48 - 3*14) / 4 = 88.0   matches the pixels
  /// ```
  ///
  /// 88 px is inside the 86.5–87.5 px the key rows actually measure, which is
  /// how correcting the margin closed R-2 (**D-60**).
  static const double screenHorizontal = 24;

  /// Inner padding of a card or list row (desing.md §4, ~16).
  static const double cardPadding = 16;

  /// Vertical gap between major page sections (desing.md §4, "generous").
  static const double sectionGap = 32;

  /// Gap between stacked elements inside one section.
  static const double md = 12;

  static const double sm = 8;
  static const double lg = 16;
  static const double xl = 24;

  /// Gap between the top safe area and the page header.
  ///
  /// Applied *inside* both header widgets rather than by each screen that uses
  /// them, so a new screen cannot forget it: seven screens (the calculator, plus
  /// History, Settings, About, both legal documents, and the debug catalogue)
  /// share two components, and the gap is therefore one edit rather than seven.
  ///
  /// 24 px is one `xl` step — the same value the QR Scanner app puts above every
  /// one of its own headers, and the same step the screen margin uses
  /// ([screenHorizontal]). A header that sits flush against the status bar reads
  /// as trapped, while a gap on the screen's own rhythm reads as chosen.
  ///
  /// It stacks with the `SafeArea` inset rather than replacing it: that is how
  /// the other app does it too, and the two are not alternatives — one clears
  /// the system, one is the design's breathing room above the bar.
  static const double headerTopGap = 24;

  /// Breathing room below the last element so content clears the system
  /// navigation bar / home indicator (desing.md §4).
  static const double bottomSafe = 24;

  /// Gap between the calculator's display block and the top row of keys.
  ///
  /// The number is the visual focus, so it reads as belonging to the keypad
  /// rather than floating: one `xl` step, matching the rhythm of the rest of
  /// the app rather than the tighter `lg` the two lines inside the display use
  /// between themselves.
  static const double calculatorDisplayGap = 24;

  /// Gap between two History cards inside one day group (D-72, D-73).
  ///
  /// Applied as half above and half below each card, so the value the design
  /// states is the distance a user actually sees between two card edges.
  static const double historyCardGap = 8;

  /// Space above a History day label — the gap that separates two groups.
  ///
  /// Deliberately larger than [historyCardGap]: the day boundary is a change of
  /// subject, and a list where every row is equally spaced reads as one
  /// undifferentiated run however the labels are styled. D-73 took it from 44 to
  /// one [sectionGap] step, which still separates the groups but no longer opens
  /// a hole in the top of the list.
  static const double historyGroupGap = 24;
}

/// Corner radii (desing.md §5).
abstract final class AppRadius {
  /// History cards, settings groups, and About cards. desing.md §5.3 gives a
  /// 12–16 range; the midpoint keeps the two from drifting apart.
  static const double card = 14;

  /// The History card's radius (D-72, D-73).
  ///
  /// Separate from [card] because the History card is one large surface rather
  /// than a stack of rows inside a group, and a single object reads better with
  /// a softer corner than the container its rows are set in. D-72's 30 was
  /// sized for a 150 pt card; at the 88 pt card D-73 settles on, 30 would be
  /// close to a stadium, so it comes down to 20 — still visibly rounder than
  /// the 14 the grouped cards use, still inside the spirit of desing.md §5.3.
  static const double historyCard = 20;

  /// A row inside a grouped card.
  static const double tile = 12;

  /// The header icon button's rounded square (D-74).
  ///
  /// The header actions are drawn as a bordered box around the glyph rather
  /// than as a bare glyph, so the box needs a corner radius of its own. [tile]
  /// happens to carry the same number, but it names a *row*; one shared value
  /// standing for two different objects is exactly the drift this file exists
  /// to prevent, so the button gets its own name.
  static const double iconButton = 12;

  /// The About hero card and the confirmation dialog.
  static const double dialog = 20;

  /// Calculator keys are full circles.
  static const BorderRadius button = BorderRadius.all(Radius.circular(999));
}

/// Fixed sizes the layout depends on.
abstract final class AppSizes {
  /// Minimum height of the calculator top bar and of every secondary screen
  /// header (D-74).
  ///
  /// A **minimum** rather than a fixed height: the header is a `Row` that grows
  /// when its title wraps or when the About subtitle is enlarged by Dynamic
  /// Type, so the bar can never clip its own text (D-54). At 1x a single-line
  /// header holds a 48 px icon box with 4 px of air above and below it.
  static const double headerHeight = 56;

  /// Minimum height of a tappable settings row (desing.md §4, ~50–56).
  static const double rowMinHeight = 56;

  /// Icon size inside a list row (desing.md §5.4, ~22–24).
  static const double rowIcon = 22;

  /// Side of the touch target an icon-only action occupies (prd.md §12, ~44–48).
  static const double iconTouchTarget = 48;

  /// Side of the About hero brand mark.
  static const double brandIcon = 88;

  /// Minimum height of a History card (D-72, D-73).
  ///
  /// A **minimum**, not a fixed height, and that distinction is the whole
  /// responsiveness story for the card. At 1× its content — 32 of padding plus a
  /// 21 px expression line, an 8 px gap, and a 24 px result line — comes to
  /// 85 px, so the card settles at 88. At the 1.3× text-scale ceiling (D-54) the
  /// same content grows past it and the card grows with it, instead of clipping
  /// its own result or throwing a render overflow. A hard `SizedBox(height: 88)`
  /// would be the one value that is wrong on every screen except a 1× one.
  static const double historyCardMinHeight = 88;

  /// Widest the calculator's header, display, and keypad are ever laid out at.
  ///
  /// The three share one column so their left and right edges line up, and that
  /// column is capped here. Without a cap the grid's cell is derived from the
  /// width it is given, so a desktop or resizable window would stretch the
  /// calculator to the full window width and the keys with it — a 1280×1600
  /// window would render 268 px keys. Capping keeps the calculator a
  /// calculator-sized object at any window size and centres the surplus,
  /// which is the whole of the "resizable window" story under D-09's
  /// portrait-phone scope.
  ///
  /// 480 is a little wider than the 442-wide reference canvas, so a large phone
  /// is never letterboxed and the measured 88 px cell is untouched.
  static const double calculatorPanelMaxWidth = 480;

}
