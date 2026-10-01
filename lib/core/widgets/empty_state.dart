import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import 'app_icon.dart';

/// Centred placeholder for a screen with nothing to show
/// (desing.md §9, feature.md FEAT-HIST-001).
///
/// Used by the empty History list (“No calculations yet”) and by the legal
/// screens when a document has no content yet (feature.md FEAT-LEGAL-001) —
/// the specification asks for a short message in both cases rather than a
/// blank area.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    super.key,
    this.message,
    this.iconSize = AppIconSize.hero,
    this.action,
  });

  /// Illustration glyph, drawn large and in the secondary colour so it reads
  /// as decoration rather than as an actionable control.
  final IconData icon;

  /// The headline, e.g. `No calculations yet`.
  final String title;

  /// Optional one-line guidance on what to do next.
  final String? message;

  /// Size bucket for the illustration.
  final AppIconSize iconSize;

  /// Optional control below the message.
  ///
  /// An empty list needs no remedy — there is nothing to do but go and
  /// calculate. A *failed* read does: the difference is that the user can fix
  /// it by trying again, so only that case supplies a button (D-58). Declaring
  /// the slot here rather than bolting a column onto the History screen keeps
  /// the same component serving "nothing yet" and "something went wrong".
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    // Scrollable rather than a bare Center: an empty state is the one place a
    // screen is guaranteed to have no other content to scroll, so it is also
    // the place a large Dynamic Type factor is most likely to overflow a short
    // phone. Scrolling degrades to a no-op at 1x, where the column is shorter
    // than the viewport anyway (D-54).
    //
    // D-70: the scroll view is the whole trick. A `Center` handed an *unbounded*
    // main axis — which is exactly what a vertical `SingleChildScrollView` gives
    // its child — collapses to its child's own height, so the block sticks to the
    // top of the page instead of sitting in the middle of it. The viewport is
    // therefore stated to the `Center` as a *minimum* height: content shorter than
    // the page centres, content taller than it still overflows the box and scrolls.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(
                    icon,
                    size: iconSize,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTypography.subtitle.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: AppTypography.rowSubtitle,
                    ),
                  ],
                  if (action != null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
