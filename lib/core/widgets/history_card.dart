import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import 'app_icon.dart';

/// One recorded calculation in the History list (desing.md §6.2, introduced in
/// **D-72**, rescaled in **D-73**).
///
/// A rounded surface on the black page holding the expression in the secondary
/// colour above a larger result, with a right chevron signalling that the card
/// can be tapped to load the result back into the calculator
/// (feature.md FEAT-HIST-002).
///
/// D-72 made this a large, generously inset card; D-73 returned the type to
/// desing.md §3's bands and the card to the app's 24 px margin, which is what
/// leaves room on a 360 dp phone for seven entries instead of three.
class HistoryCard extends StatelessWidget {
  const HistoryCard({
    required this.expression,
    required this.result,
    super.key,
    this.onTap,
  });

  /// What the user typed, e.g. `125 × 8`.
  final String expression;

  /// The computed result, already formatted for display, e.g. `1,000`.
  final String result;

  /// Loads this entry into the calculator. Omit for a non-interactive card.
  final VoidCallback? onTap;

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
        label: '$expression, $result',
        child: ExcludeSemantics(
          child: Material(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadius.historyCard),
            clipBehavior: Clip.antiAlias,
            // No border and no elevation: on a black page the card's fill is the
            // only thing separating it from the background, and a hairline edge
            // or a drop shadow would add a second, competing one.
            child: InkWell(
              onTap: onTap,
              // The floor is the *card's* height, so the constraint sits outside
              // the 16 px padding rather than inside it: placed inside, the padding
              // would ride on top and every card would be 120 for no reason the
              // design asked for.
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.historyCardMinHeight,
                ),
                child: Padding(
                  // desing.md §4's "~16 pt" card padding, the token that
                  // already holds it.
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
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
                                Text(
                                  expression,
                                  style: AppTypography.historyExpression,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                // The result is the largest thing on the card,
                                // so it is the one line that must never be
                                // truncated — a half-shown number is worse than a
                                // smaller one. `scaleDown` shrinks it to fit and
                                // leaves it untouched when it already does, which
                                // is the common case at this size.
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    result,
                                    style: AppTypography.historyResult,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          // A row-sized chevron rather than a header-sized one:
                          // at 28 px it was a third of the card's height, and the
                          // affordance is not the content.
                          const AppIcon(
                            Icons.chevron_right,
                            size: AppIconSize.row,
                            color: AppColors.textSecondary,
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
    );

    return card;
  }
}
