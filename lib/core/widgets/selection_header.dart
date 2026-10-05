import '../../../core/design/app_palette.dart';
import 'package:flutter/material.dart';

import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import 'app_icon.dart';
import 'app_trash_icon.dart';

/// The header a list wears while the user is multi-selecting (D-76).
///
/// Replaces the screen's own title bar rather than sitting above it, which is
/// what makes the mode legible: there is exactly one header, and it says either
/// "History" or "3 selected" and never both. Actions move to the edges the
/// title vacates, so nothing shifts horizontally when the mode is entered.
///
/// The layout is deliberately the same shape as the title header it replaces —
/// a control on the left, a centred label, a control on the right — so the mode
/// reads as the *same* bar in a different state. Anything else would make the
/// transition a jump, and the user would have to re-find the delete button.
///
/// The destructive action is not immediate: [onDelete] is expected to route
/// through a confirmation before anything is removed (D-05).
class AppSelectionHeader extends StatelessWidget {
  const AppSelectionHeader({
    required this.count,
    required this.allVisibleSelected,
    required this.onSelectAll,
    required this.onDelete,
    required this.onCancel,
    super.key,
  });

  /// How many entries are currently selected. Always ≥ 1 — the header is only
  /// mounted while a selection exists.
  final int count;

  /// Whether every entry the list is showing is selected, which is what flips
  /// the select-all action into deselect-all.
  final bool allVisibleSelected;

  /// Selects every visible entry, or clears the selection when
  /// [allVisibleSelected] is already true.
  final VoidCallback onSelectAll;

  /// Deletes the selected entries. The caller confirms first (D-05).
  final VoidCallback onDelete;

  /// Leaves selection mode without deleting anything.
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // The same margin and top gap the title header uses (D-74), so the bar
      // does not move a single pixel vertically when the mode is entered.
      padding: const EdgeInsets.only(
        left: AppSpacing.screenHorizontal,
        right: AppSpacing.screenHorizontal,
        top: AppSpacing.headerTopGap,
      ),
      child: ConstrainedBox(
        // [AppSizes.headerHeight] rather than a fixed box, for the same reason
        // the title header's is a minimum: Dynamic Type (D-54) grows the count
        // line and the bar has to grow with it rather than clip.
        constraints: const BoxConstraints(
          minHeight: AppSizes.headerHeight,
        ),
        child: Row(
          children: <Widget>[
            AppSelectionAction(
              key: const Key('selection-cancel'),
              icon: Icons.close,
              tooltip: 'Cancel selection',
              onPressed: onCancel,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                '$count selected',
                style: context.type.selectionCount,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // Centred for the same geometric reason the title header centres
                // its own: the two edge slots are the same width, so the middle
                // is symmetric about the screen whatever the count says.
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            AppSelectionAction(
              key: const Key('selection-select-all'),
              icon: allVisibleSelected
                  ? Icons.remove_circle_outline
                  : Icons.select_all,
              tooltip: allVisibleSelected ? 'Deselect all' : 'Select all',
              onPressed: onSelectAll,
            ),
            const SizedBox(width: AppSpacing.sm),
            AppSelectionAction(
              key: const Key('selection-delete'),
              // D-73's glyph, not Material's `delete_outline`: this is the same
              // trash the resting header paints and the bottom action paints, so
              // the screen carries **one** delete glyph in every state instead of
              // swapping to a second one the moment the user selects a row. The
              // colour is still this widget's to decide — a painted glyph does
              // not read `foregroundColor` the way a Material one does.
              iconWidget: AppTrashIcon(
                color: count == 0
                    ? context.appColors.textSecondary
                    : context.appColors.selectionAccent,
              ),
              tooltip: 'Delete selected',
              // An inert delete is greyed rather than removed, so the action
              // does not appear and disappear as the selection changes. The
              // header only mounts with a selection, so this is defensive
              // against a caller that renders it at zero.
              onPressed: count == 0 ? () {} : onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// One bordered action box in [AppSelectionHeader].
///
/// The same 48 px bordered square the header actions already wear
/// ([AppIconButton]), so a screen that swaps its title bar for a selection bar
/// does not change the size or the weight of anything on that row.
///
/// A real [IconButton] rather than an `InkWell`, for the reason [AppIconButton]
/// gives: `find.byType(IconButton)`, `find.byTooltip`, and the accessibility
/// layer all read one for free, and the tests reach these actions through them.
class AppSelectionAction extends StatelessWidget {
  const AppSelectionAction({
    required this.onPressed,
    super.key,
    this.icon,
    this.iconWidget,
    this.color,
    this.tooltip,
  }) : assert(
         (icon == null) != (iconWidget == null),
         'AppSelectionAction needs either an IconData or a widget to draw',
       );

  /// The Material glyph to draw, e.g. [Icons.close]. Mutually exclusive with
  /// [iconWidget]; supply one of the two. Painted at [AppIconSize.row].
  final IconData? icon;

  /// A painted glyph instead of an [IconData] — the app's own trash
  /// ([AppTrashIcon]), which is a `CustomPainter` rather than an icon font.
  ///
  /// The mirror of [AppIconButton.iconWidget], and for the same reason: D-73
  /// gave the History screen a delete glyph that Material's set does not
  /// contain, and the selection bar has to be able to paint *that* glyph rather
  /// than a second, different one. The widget owns its own colour, so [color]
  /// does not reach it.
  final Widget? iconWidget;

  /// What the action does.
  final VoidCallback onPressed;

  /// Glyph colour. Defaults to [context.appColors.selectionAccent].
  final Color? color;

  /// Accessible name, and the handle tests reach the action by.
  final String? tooltip;

  /// The one size every header action is pinned to.
  static const Size _size = Size.square(AppSizes.iconTouchTarget);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    // The 48 px bordered box, built per build rather than held as a
    // `static const`: a const shape would bake in the dark theme's divider,
    // which is invisible on a white card. Same box, same 48 px, and the border
    // now follows the theme.
    final box = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.iconButton)),
      side: BorderSide(color: colors.divider),
    );

    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      // Zero padding so the box the style pins is the box the button occupies,
      // which is what keeps this header's geometry matching the title header's.
      padding: EdgeInsets.zero,
      style: ButtonStyle(
        fixedSize: const WidgetStatePropertyAll<Size>(_size),
        minimumSize: const WidgetStatePropertyAll<Size>(_size),
        maximumSize: const WidgetStatePropertyAll<Size>(_size),
        padding: const WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.zero),
        backgroundColor: WidgetStatePropertyAll<Color>(colors.surface),
        shape: WidgetStatePropertyAll<OutlinedBorder>(box),
      ),
      // The label is carried by the [IconButton]'s tooltip rather than by the
      // glyph, so the icon stays decorative and the action is announced once.
      icon:
          iconWidget ??
          AppIcon(
            // The constructor's assert makes the two mutually exclusive, so one
            // of them is always present and the other cannot be read here.
            icon!,
            color: color ?? context.appColors.selectionAccent,
          ),
    );
  }
}