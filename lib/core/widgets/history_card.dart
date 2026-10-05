import '../../../core/design/app_palette.dart';

import 'package:flutter/material.dart';

import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import 'app_icon.dart';

/// Gap between a History card's title line and its meta row (D-93).
///
/// **7 — Ethar's number** (`task_list.dart:502`). Not [AppSpacing.sm]'s 8: this
/// gap belongs to the title's 17 px line rather than to the card's own 8 px
/// rhythm, and Ethar measures the two independently. Naming it here keeps the
/// pairing with [AppSizes.historyMetaGlyph] readable — the title is 4 px larger
/// than the glyph beside the meta text, and its 4 px of extra leading is what
/// this 7 accounts for.
const double historyTitleGap = 7;

/// One recorded calculation in the History list (desing.md §6.2, introduced in
/// **D-72**, rescaled in **D-73**, re-based on the sibling app in **D-93**).
///
/// **This card is Ethar's `_TaskCard`.** D-93 ports that recipe whole rather
/// than converging on it by degrees: `_appCard(radius: 12)` with its 1 px
/// outline and its `cardShadow`, `padding: EdgeInsets.symmetric(horizontal: 18,
/// vertical: 17)`, and — the part that is a real change rather than a number —
/// **Ethar's line hierarchy, with the result as the title and the expression as
/// the meta row**.
///
/// The hierarchy flip is the substance of it. Ethar prints a task's title at
/// 17/w700 over a 13 muted meta line. Here the title is the **result** and the
/// meta line is the **expression** with a leading clock glyph, because the
/// result is what the user came back to read: `125 × 8` is how the row was
/// made, `1,000` is what it is worth. D-73 led with the expression at 16 over a
/// 22 result, which put the setup above the answer.
///
/// Three of D-72/D-73/D-77's values are superseded by this port, and the tokens
/// carrying them say so:
///
/// * **Borderless → outlined.** D-72 reasoned that on a black page the fill is
///   the only edge. Ethar outlines *every* card in both themes and it is the
///   outline, not the fill, that makes a `#151517` card an object on black, so
///   the card takes [AppPalette.cardBorder] at rest.
/// * **No shadow → [AppPalette.cardShadow].** Whichever theme has a shadow
///   paints it, exactly as `SettingsGroup` does; the dark theme has none and so
///   draws an empty list rather than a zero-alpha one.
/// * **Radius 14 → [AppRadius.historyCard] 12**, the *task card's* corner. D-77
///   had matched the Create Task *option* rows instead.
/// * **`surfaceRaised` → [AppPalette.surface].** The card is now the same
///   colour as the Settings groups' cards. Two screens whose cards are the same
///   shape and the same object should not be told apart by a one-step fill
///   difference; the radius stays History's own, because a 12 px corner on this
///   card is a shape decision, not a colour one.
///
/// Height is unchanged: 17·1.25 + 7 + 13·1.3 is ~45 of content inside 34 of
/// padding, so [AppSizes.historyCardMinHeight]'s floor of 88 still governs and a
/// 360 dp phone still fits four entries.
class HistoryCard extends StatelessWidget {
  const HistoryCard({
    required this.expression,
    required this.result,
    super.key,
    this.onTap,
    this.onLongPress,
    this.selecting = false,
    this.selected = false,
  });

  /// What the user typed, e.g. `125 × 8`.
  final String expression;

  /// The computed result, already formatted for display, e.g. `1,000`.
  final String result;

  /// Loads this entry into the calculator. Omit for a non-interactive card.
  final VoidCallback? onTap;

  /// Enters selection mode with this entry selected (D-76).
  ///
  /// Long-press rather than an edit-mode button: on a list of up to 200 rows a
  /// persistent "select" affordance would cost a row's worth of height, and the
  /// gesture is already how the sibling app enters the same mode, so it is the
  /// one users arrive expecting.
  final VoidCallback? onLongPress;

  /// Whether the list is multi-selecting at all.
  ///
  /// Distinct from [selected] because the two change different things: this one
  /// swaps the chevron for a checkbox on *every* card, while [selected] paints
  /// one card. A card that had only a `selected` flag could not know whether to
  /// show a circle for an entry the user has not chosen yet.
  final bool selecting;

  /// Whether this entry is one of the chosen ones.
  final bool selected;

  /// Side of the selection circle drawn in the trailing slot (D-76).
  ///
  /// The app's key diameter rather than an invented number, so the circle and a
  /// calculator key read as the same object at a glance — the user is choosing
  /// rows here with the same gesture language they use to enter numbers.
  ///
  /// Left at 28 rather than Ethar's 32: the trailing slot sits on a card that is
  /// now 76 px of text and padding tall, and a 32 px disc would be nearly half
  /// of it. D-93 aligned this card to Ethar's *chrome*, which is measured in
  /// units of the card's own edges — the outline, the shadow, the corner, the
  /// padding — not in units of a control Ethar hangs on a wider row.
  static const double selectionCircle = 28;

  /// Width of the selected card's border (D-76, **D-93**).
  ///
  /// **1.5 — Ethar's selected-card border** (`task_list.dart:411`), down from
  /// this card's 2.
  ///
  /// The card now carries a 1 px resting outline, and the selected row's
  /// outline is that same outline *thickened* — which is what makes a selection
  /// of twenty rows scannable without a second, competing edge appearing out of
  /// nowhere. At 2 the jump from 1 to 2 is a doubling and reads as a different
  /// object; at 1 to 1.5 it reads as the row you are holding.
  static const double selectionBorderWidth = 1.5;

  /// How long the card takes to cross between its resting and selected paints
  /// (D-93).
  ///
  /// **150 ms — Ethar's `AnimatedContainer` duration** (`task_list.dart:403`).
  ///
  /// Ethar animates the card because selection there also *moves* things: the
  /// leading completion circle and the trailing control trade places. Here the
  /// trailing slot is already shared between the chevron and the checkbox (D-76)
  /// and nothing moves, so this is pure feedback on the fill, outline, and
  /// shadow — a card that changes state without saying so reads as a glitch.
  static const Duration stateDuration = Duration(milliseconds: 150);

  /// The card's outline and shadow (D-93) — Ethar's `_appCard`, adapted.
  ///
  /// Published as a function rather than inlined at the call site so the resting
  /// and selected decorations are built by the same code path, and because
  /// [HistoryCard.selectionBorderWidth] and the palette's shadow are the only
  /// things that decide what this returns — three facts a test can read off the
  /// rendered card instead of restating.
  ///
  /// The shadow follows [AppPalette.cardShadow] rather than being stated here,
  /// which means the **dark theme draws none** and the white theme draws the
  /// `0x0D0F172A` blur-22 (0, 6) Ethar uses. `BoxDecoration` takes a list and an
  /// empty list is not the same as an absent field, so the ternary below exists
  /// to hand a test a readable "no shadow" — the same reason
  /// `SettingsGroup.decoration()` is built rather than passed inline.
  static BoxDecoration decoration(
    BuildContext context, {
    required bool selected,
  }) {
    final colors = context.appColors;
    final radius = BorderRadius.circular(AppRadius.historyCard);
    final shadow = selected
        ? colors.selectionAccent.withValues(alpha: selectionShadowAlpha)
        : colors.cardShadow;
    return BoxDecoration(
      color: selected ? colors.surfaceSelected : colors.surface,
      borderRadius: radius,
      border: Border.all(
        color: selected ? colors.selectionAccent : colors.cardBorder,
        width: selected ? selectionBorderWidth : restingBorderWidth,
      ),
      boxShadow: shadow == null
          ? const []
          : [
              BoxShadow(
                color: shadow,
                blurRadius: selected ? selectionShadowBlur : restingShadowBlur,
                offset: selected ? const Offset(0, 3) : const Offset(0, 6),
              ),
            ],
    );
  }

  /// Opacity of a selected card's shadow (D-93).
  ///
  /// **0.15 — Ethar's `_orange.withValues(alpha: .15)`** (`task_list.dart:416`),
  /// re-expressed against this app's [AppPalette.selectionAccent], which is
  /// white rather than orange (D-76) and would be a wall of glare at full
  /// strength.
  static const double selectionShadowAlpha = 0.15;

  /// Blur of a selected card's shadow (D-93) — Ethar's 12.
  static const double selectionShadowBlur = 12;

  /// Blur of a resting card's shadow (D-93) — Ethar's `_appCard` blur 22.
  static const double restingShadowBlur = 22;

  /// Width of a resting card's outline (D-93) — Ethar's `_appCard` 1 px border.
  static const double restingBorderWidth = 1;

  @override
  Widget build(BuildContext context) {
    // D-59: the card is a single action — "load this result back into the
    // calculator" (feature.md FEAT-HIST-002) — so it announces as one button.
    // Left alone it was four stops: the expression, the result, the chevron,
    // and the tap target, with nothing tying them to each other or saying what
    // activating one would do.
    final card = Padding(
      padding: const EdgeInsets.symmetric(
        // D-73: the app's own 24 px margin, which is what D-72's dedicated
        // `historyHorizontal` used to double. Every other screen in the app is
        // built on this line and the header's own back arrow sits on it, so
        // pulling the cards inboard of both read as a mistake rather than as a
        // distinction.
        horizontal: AppSpacing.screenHorizontal,
        // Half above, half below: two adjacent cards then sit exactly
        // `historyCardGap` apart, which is the distance the design states.
        vertical: AppSpacing.historyCardGap / 2,
      ),
      child: Semantics(
        container: true,
        button: onTap != null,
        // D-76: announced so a screen reader says which rows are chosen while
        // the user arrows through the list, instead of leaving the state to be
        // inferred from a tick nobody hears.
        selected: selected,
        label: selecting
            // In selection mode the row is a *choice*, and "5 × 5, 25, selected"
            // says what tapping it will now do in a way the resting label does
            // not — the resting card loads the result, this one toggles.
            ? '$expression, $result, ${selected ? 'selected' : 'not selected'}'
            : '$expression, $result',
        child: ExcludeSemantics(
          // D-93: the fill, the outline, and the shadow all live on one
          // `AnimatedContainer`, which is Ethar's `_TaskCard` shape exactly —
          // an implicit animation over 150 ms rather than a bare box.
          //
          // The outline cannot go on the [Material]'s own `shape`: `Material`
          // asserts that `shape` and `borderRadius` are never both given, and
          // `borderRadius` is the one the geometry tests already assert on.
          // (D-76 reached the same conclusion for the selection border alone;
          // D-93 widens it to the resting one, so the reasoning still holds —
          // it is now simply the whole decoration rather than a special case.)
          //
          // The wrapper's radius matches the card's own, so the outline traces
          // the same curve rather than sitting proud of it — a mismatch would
          // show as two parallel edges on the row.
          child: AnimatedContainer(
            duration: stateDuration,
            decoration: decoration(context, selected: selected),
            child: Material(
              // `Colors.transparent`, not the card fill: the decoration above now
              // paints the fill too, and a second opaque layer on top of it
              // would hide the shadow's inner half and the border's inward half.
              //
              // The geometry tests read this `Material`'s `borderRadius`, which
              // is unchanged — what moved is who owns the *colour*.
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.historyCard),
              clipBehavior: Clip.antiAlias,
              // No elevation: the shadow is painted by the decoration above as
              // Ethar specifies it, and [Material] elevation would add a second
              // one on top of it.
              child: InkWell(
                onTap: onTap,
                // D-76: the same gesture the sibling app uses to enter selection.
                // Long-press rather than double-tap or a leading checkbox, because
                // the trailing slot already changes shape in selection mode and a
                // control there would mean the resting card carries a target that
                // does nothing until you know to use it.
                onLongPress: onLongPress,
                // The floor is the *card's* height, so the constraint sits outside
                // the 16 px padding rather than inside it: placed inside, the padding
                // would ride on top and every card would be 120 for no reason the
                // design asked for.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppSizes.historyCardMinHeight,
                  ),
                  child: Padding(
                    // Ethar's `padding: EdgeInsets.symmetric(horizontal: 18,
                    // vertical: 17)` — D-93, not desing.md §4's "~16 pt", which is
                    // the settings row's band and not this card's.
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.historyCardHorizontal,
                      vertical: AppSpacing.historyCardVertical,
                    ),
                    // `Center` rather than a bare min-height box on the row,
                    // because a sliver hands its children an unbounded height:
                    // `Center` is what turns the floor above into a box to centre
                    // *within* rather than slack dumped under the text.
                    // `double.infinity` is what keeps the row full width so the
                    // chevron stays on the right.
                    child: Center(
                      child: SizedBox(
                        width: double.infinity,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // D-93: the result is the *title* now — Ethar's
                                  // 17/w700 line — and it is the one line that must
                                  // never be truncated, so the `FittedBox` that
                                  // D-72 wrapped it in moves up with it. At 17 px
                                  // rather than 22 a long answer scales down far
                                  // less often, but a twenty-digit result is still
                                  // one tap from happening.
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      result,
                                      style: context.type.historyResult,
                                      maxLines: 1,
                                    ),
                                  ),
                                  // Ethar's 7 px gap between title and meta row
                                  // (`task_list.dart:502`), not [AppSpacing.sm]'s
                                  // 8 — the pair are measured together and a
                                  // half-rounding of one and not the other is the
                                  // drift a shared number prevents.
                                  const SizedBox(height: historyTitleGap),
                                  // The meta row: a clock glyph, a 5 px gap, and
                                  // the expression at 13 muted — Ethar's
                                  // `schedule_rounded` + time row verbatim
                                  // (`task_list.dart:503-523`).
                                  //
                                  // The glyph stands for "this happened", which is
                                  // the one thing the expression alone does not say
                                  // and the reason this row has a leading slot at
                                  // all. The expression gets the ellipsis rather
                                  // than the result because it is a composition the
                                  // user can reconstruct from the result alone,
                                  // where a truncated result is a wrong number.
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.schedule_rounded,
                                        size: AppSizes.historyMetaGlyph,
                                        color: context.appColors.textSecondary,
                                      ),
                                      const SizedBox(
                                        width: AppSizes.historyMetaGap,
                                      ),
                                      Expanded(
                                        child: Text(
                                          expression,
                                          style: context.type.historyExpression,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            // A row-sized chevron rather than a header-sized one:
                            // at 28 px it was a third of the card's height, and the
                            // affordance is not the content.
                            //
                            // D-76: in selection mode this slot becomes the choice
                            // control, so the two states share one trailing column
                            // and a card's width does not change the moment the
                            // user enters the mode — the row they long-pressed
                            // stays exactly where it was under their finger.
                            selecting
                                ? HistorySelectionCircle(selected: selected)
                                : AppIcon(
                                    Icons.chevron_right,
                                    size: AppIconSize.row,
                                    color: context.appColors.textSecondary,
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return card;
  }
}

/// The checkbox a History card shows while the list is selecting (D-76).
///
/// White, matching [context.appColors.selectionAccent], and paired with a **black** tick
/// ([context.appColors.selectionCheck]) — a white tick on a white circle is invisible,
/// which is the whole reason this is not a copy of the sibling app's orange
/// version. The unchecked state keeps a visible ring so an unselected row in
/// selection mode still reads as *offering a choice* rather than as a row that
/// has lost its affordance.
///
/// Public rather than private because [HistoryCard.selectionCircle] and
/// [HistoryCard.selectionBorderWidth] name its two measurements, and a private
/// class cannot be referenced from a sibling library even in a doc link —
/// naming them here is what keeps the circle from drifting away from the card.
class HistorySelectionCircle extends StatelessWidget {
  const HistorySelectionCircle({required this.selected, super.key});

  /// Whether this row is one of the chosen ones.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: HistoryCard.selectionCircle,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? context.appColors.selectionAccent
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? context.appColors.selectionAccent
                : context.appColors.textSecondary,
            // Matching [HistoryCard.selectionBorderWidth]: the card gains a 2 px
            // outline when selected, and a thinner ring beside it would make
            // the same event look like two different weights.
            width: HistoryCard.selectionBorderWidth,
          ),
        ),
        child: selected
            ? Icon(
                Icons.check,
                // Held to the circle's own 28 px minus a hair of air, rather
                // than the app's 22 px row glyph: the tick is filling a shape,
                // not sitting beside text, and at 22 it reads as undersized
                // inside a 28 px disc.
                size: 18,
                color: context.appColors.selectionCheck,
              )
            : null,
      ),
    );
  }
}
