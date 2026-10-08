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

  /// Side margin of the **calculator's own column** — its header, display, and
  /// keypad (**D-110**).
  ///
  /// **16, not [screenHorizontal]'s 24.** Every card edge in History, Settings,
  /// and About is measured at logical x≈24, so that token cannot move — but the
  /// calculator is not a column of cards. It is a 4-column grid whose keys are
  /// derived from whatever width the screen hands it, so its margin is not
  /// decoration: it is subtracted before the division. On the 442×890 reference
  /// canvas the grid maths reads:
  ///
  /// ```
  /// margin 24, gap 14 -> (442 - 48 - 42) / 4 = 88.0
  /// margin 16, gap 16 -> (442 - 32 - 48) / 4 = 90.5
  /// ```
  ///
  /// So the tighter margin is bought together with the wider gap and the cell
  /// comes out both **larger** *and* more generously spaced — which is the whole
  /// of the spaciousness this redesign is after. Widening the gap alone would
  /// have shrunk the keys; tightening the margin alone would have left them
  /// touching.
  ///
  /// The column is **centred** rather than pinned to a margin
  /// ([CalculatorScreen]), so on a window wider than
  /// [calculatorPanelMaxWidth] the surplus falls equally on both sides and the
  /// key at x≈16 on a phone is at x≈176 on a desktop — the same relationship the
  /// 24 px margin describes, at a different number.
  static const double calculatorSideMargin = 16;

  /// Inner padding of a card or list row (desing.md §4, ~16).
  static const double cardPadding = 16;

  /// Where a hairline inside a grouped card starts, measured from the card's
  /// left edge (D-91).
  ///
  /// **72, and it is not a rounding of [cardPadding].** The old value was 16,
  /// which drew the line under the leading icon as well as under the text — the
  /// icon looked like it belonged to the row above it. The line now starts where
  /// the titles start: `cardPadding` (16) + the 44 px tile + [lg] (16) + a
  /// half-pixel of the glyph's own bearing. Ethar draws the same 72 in
  /// `_SettingsGroup`'s `Divider(indent: 72)`.
  ///
  /// Kept as its own token rather than recomputed at the call site because the
  /// standalone [SettingsRow] divider and the group's internal one have to agree
  /// exactly, and two literals drifting apart is the failure this file exists
  /// to prevent.
  static const double dividerIndent = 72;

  /// Where a hairline inside a grouped card ends, from the card's right edge
  /// (D-91).
  ///
  /// Ethar's `_SettingsGroup` passes `endIndent: 16`, so the line stops short of
  /// the corner by the same [cardPadding] the rows pad their content by, and the
  /// two read as one inset rather than as a line that happens to stop.
  static const double dividerEndIndent = 16;

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

  /// Horizontal padding inside a History card (D-93).
  ///
  /// **18 — Ethar's number.** `_TaskCard` in `task_list.dart:429` pads
  /// `EdgeInsets.symmetric(horizontal: 18, vertical: 17)`, and this card is
  /// that card. The previous value was [cardPadding]'s 16, which is right for a
  /// settings row and two pixels narrow for a card that leads with a number:
  /// the glyph column Ethar puts on the left needs the air or the text column
  /// starts visibly off-centre.
  ///
  /// Named rather than reusing [cardPadding] because a History card and a
  /// settings row are different objects at different widths — the reason
  /// `AppRadius.historyCard` is a separate token for the same reason.
  static const double historyCardHorizontal = 18;

  /// Vertical padding inside a History card (D-93).
  ///
  /// **17 — Ethar's number**, and half of what it is beside: [cardPadding] is 16,
  /// so the old card was 32 of vertical padding to Ethar's 34. At the app's
  /// 88 px floor this is invisible per card and decisive across a list of
  /// thirty — the extra pixel is what lets four entries fit where D-73 fitted
  /// four and D-72 fitted three.
  static const double historyCardVertical = 17;

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

  /// The History card's radius (D-72, D-73, **D-77**, **D-93**).
  ///
  /// **12 — the corner Ethar's `_TaskCard` gives the task card itself**
  /// (`task_list.dart:405`, `_appCard(radius: 12)`).
  ///
  /// D-77 took this to 14 so the History entry would match Ethar's *Create Task
  /// option* cards (`task_editor.dart`'s `_TaskOption`, which is also 14). D-93
  /// corrects which Ethar card it was tracking: the option rows and the task card
  /// are two different components that happen to share a number, and the object
  /// a History entry is the same kind of thing as — a single row in a list of
  /// peers, long-pressable and multi-selectable — is the **task card**, not an
  /// editor field row. Twelve is also where desing.md §5.3's 12–16 band starts,
  /// which is the value a card this size should sit at.
  ///
  /// The token *name* is kept even though [card] carries a different number.
  /// The two are different objects that must not be allowed to drift — a
  /// History card leads with a number and a settings group leads with a glyph —
  /// and one shared value standing for both is precisely the drift this file
  /// exists to prevent. If a future change moves one, it moves here by name.
  static const double historyCard = 12;

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

  /// Minimum height of a tappable settings row (D-91).
  ///
  /// **Raised from 56 to 64.** Ethar's `_SettingsRow` and `_ToggleRow` both
  /// carry `BoxConstraints(minHeight: 64)`, and a row cannot be shorter than the
  /// thing it holds: D-91 put a 44 px icon tile in the leading column, and 44
  /// plus the row's 20 px of vertical padding is already 64. At 56 the tile was
  /// either clipped or the padding was squeezed, and the two apps' settings
  /// screens stopped being the same object.
  ///
  /// Still a **minimum**, so a two-line row at large text scale grows past it
  /// rather than clipping (D-54).
  static const double rowMinHeight = 64;

  /// Icon size inside a list row (desing.md §5.4, ~22–24).
  static const double rowIcon = 22;

  /// Side of the touch target an icon-only action occupies (prd.md §12, ~44–48).
  static const double iconTouchTarget = 48;

  /// Side of the calculator's two header actions — the Settings gear button and
  /// the History clock (**D-110**).
  ///
  /// **56, not [iconTouchTarget]'s 48.** Every key on that screen grew when the
  /// grid's margin tightened and its gap widened, and a 48 px box sitting above
  /// a 90 px `AC` key reads as a header drawn for a different, smaller app.
  /// 56 is [headerHeight] — the bar's own height, which is the rhythm this
  /// screen already sits on — so the boxes fill the bar's height rather than
  /// floating in it, and it stays well clear of the prd.md §12 44 pt floor.
  ///
  /// A *size*, not a variant: the buttons keep the same fill, border, radius,
  /// and glyph colour (`AppIconButton`'s [bordered] path) and only get larger.
  /// The other five headers keep 48 — this is the calculator's own scale, not
  /// the app's.
  static const double calculatorHeaderAction = 56;

  /// Glyph size that goes with [calculatorHeaderAction], as a ratio of it.
  ///
  /// **26 / 56 ≈ 0.464**, which is [rowIcon]'s own 22 / 48 to within a pixel.
  /// Expressed as a ratio rather than a literal so `AppIconButton` can derive
  /// the glyph from whatever box it was given instead of the caller having to
  /// pass two numbers that could disagree.
  static const double calculatorHeaderGlyphRatio = 26 / 56;

  /// Side of the About hero brand mark.
  static const double brandIcon = 88;

  /// Side of the glyph leading a History card's meta row (D-93).
  ///
  /// **17 — Ethar's number** (`task_list.dart:508`, the `schedule_rounded` beside
  /// a task's time). A *size* token rather than a new `AppIconSize` bucket
  /// because that enum's steps are the app's own — 18, 22, 28, 40, 44 — and 17
  /// belongs to none of them; adding a bucket that sits 1 px below [small] would
  /// put a step into an enum that deliberately has none.
  static const double historyMetaGlyph = 17;

  /// Gap between a History card's meta glyph and its meta text (D-93).
  ///
  /// **5 — Ethar's number** (`task_list.dart:511`). Not [sm]'s 8: the glyph is
  /// 17, not 22, and a 22 px glyph wants 8 of air where a 17 px one wants 5. The
  /// gap belongs to the glyph rather than to the row, which is why it lives here
  /// beside the glyph's size instead of in `AppSpacing`'s own scale.
  static const double historyMetaGap = 5;

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

  /// Height of the calculator's backspace row, between the display and the rule
  /// (**D-81**).
  ///
  /// The row is exactly one shared header box ([iconTouchTarget]) tall, and the
  /// screen reserves this height *before* it sizes the keypad — so a name for the
  /// reservation, rather than a caller measuring the button's own widget, which
  /// would be reading a layout result back as if it were the budget.
  static const double calculatorBackspaceRow = iconTouchTarget;

  /// Side of the floating home button on the Secret Mode screens (D-86).
  ///
  /// **56** rather than the header action's [iconTouchTarget] 48: this button is
  /// not a header action and does not sit in a header, and at 48 a bottom-right
  /// circle reads as a stray header box that fell to the wrong end of the screen.
  /// 56 is the Material FAB's small size, which is the same silhouette this is
  /// borrowing, and it stays comfortably above the prd.md §12 touch floor.
  ///
  /// A *size*, not a new colour or radius — the button is painted from
  /// [context.appColors.textPrimary] and [context.appColors.textOnFunction], both of which
  /// already exist. D-84 warned that a blank page needing a token would be the
  /// signal it had stopped being blank; it has stopped being blank, and this is
  /// the record of how it did so without opening the palette.
  static const double secretHomeButton = 56;
}

/// Inset the floating home button keeps from the screen's edges (D-86).
///
/// Named here rather than spelled at the call site so the button's clearance is
/// one fact: it has to clear the system gesture inset on every screen it appears
/// on, and a number retyped at two call sites is a number that drifts.
abstract final class AppSecretSpacing {
  /// From the right and bottom edges, under the [SafeArea] the screens use.
  static const double homeButtonInset = 24;
}
