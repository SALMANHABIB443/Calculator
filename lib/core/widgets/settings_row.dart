import '../../../core/design/app_palette.dart';
import 'package:flutter/material.dart';

import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import 'app_icon.dart';
import 'app_icon_tile.dart';

/// A tappable settings / About row (desing.md §5.3, §6.3).
///
/// Icon on the left, title and optional subtitle in the middle, and a control
/// on the right. A row that can be tapped and has no explicit [trailing] draws
/// a chevron, which is what every navigational row in the mockups shows.
///
/// The row is transparent on its own — it takes the surface colour from
/// [SettingsGroup] so that a stack of rows reads as one card with hairlines
/// between them rather than as separate floating tiles.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.icon,
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.showDivider = false,
  });

  /// Widest the trailing slot is ever laid out at (D-92).
  ///
  /// **Ethar's number, copied rather than chosen** —
  /// `Ethar/lib/src/features/settings/settings_components.dart`'s `_SettingsRow`
  /// puts `ConstrainedBox(maxWidth: 105)` around its value for the reason D-91
  /// found independently here: the 44 px tile eats into a narrow row's fixed
  /// budget, and an unbounded value on the right pushes the row past its card.
  ///
  /// A *bound*, not a fixed width — a switch is 60 px and a chevron 22, and
  /// neither should be stretched to fill 105. And it is named rather than
  /// inlined so a test can assert the recipe against the same fact the widget
  /// reads, instead of restating 105 and hoping the two stay equal.
  static const double trailingMaxWidth = 105;

  /// Leading glyph, e.g. the sun, speaker, or shield.
  final IconData icon;

  /// Primary label, e.g. `Sound`.
  final String title;

  /// Supporting label, e.g. `Key press sound`.
  final String? subtitle;

  /// Right-hand control. When omitted on a tappable row, a chevron is drawn.
  final Widget? trailing;

  /// Makes the whole row a tap target. When set, a material ripple is added so
  /// feedback is not limited to the trailing control.
  final VoidCallback? onTap;

  /// Leading icon colour — white for most rows, accent for active/feedback
  /// icons (desing.md §5.4).
  final Color? iconColor;

  /// Draws a hairline under the row. [SettingsGroup] handles this itself, so
  /// standalone rows leave it off.
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    // D-59: the row is one thing to a screen reader, not four. Left alone,
    // TalkBack walked the icon, the title, the subtitle and the chevron as four
    // separate stops, so the row announced as decoration followed by loose
    // text. Only the *visual* parts are excluded — [trailing] stays in the
    // tree, because on a [ToggleRow] that is the `Switch`, and dropping it
    // would delete the on/off state the user came to check.
    final label = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppSizes.rowMinHeight,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.cardPadding,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            // D-91: the leading glyph is a 44 px soft tile rather than a bare
            // icon — Ethar's `_SettingsIconTile`, ported. It stays inside the
            // same `ExcludeSemantics` as before, because a screen reader still
            // gains nothing from the square.
            ExcludeSemantics(
              child: AppIconTile(icon: icon, color: iconColor),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: context.type.rowTitle),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: context.type.rowSubtitle),
                    ],
                  ],
                ),
              ),
            ),
            // D-92: the trailing control is bounded rather than handed its
            // intrinsic width, *and* it is not a flex child. D-91 fixed the
            // overflow with `Flexible`, which solved that problem and created
            // this one: `RenderFlex` divides the width left over between flex
            // children by flex factor, and a loose `Flexible` never hands its
            // unused share back — so the title's `Expanded` and this slot split
            // the row 50/50, and the control rendered at the *start* of its own
            // half-row. At the 442 px reference canvas that parked the Theme
            // chevron 129 px and each switch 91 px short of the card's right
            // edge, while the title column was left with half the width it
            // needed (which is what wrapped "Keep calculation history").
            //
            // Ethar's `_SettingsRow` never had the bug because its value is a
            // plain `ConstrainedBox` — laid out at its own width before the
            // `Expanded` is measured, so the title takes everything that is
            // left. Same bound, same 8 px gap as the chevron below, and the
            // 320 px overflow D-91 was guarding against stays guarded.
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: trailingMaxWidth),
                child: trailing!,
              ),
            ] else if (onTap != null) ...[
              const SizedBox(width: AppSpacing.sm),
              ExcludeSemantics(
                child: AppIcon(
                  Icons.chevron_right,
                  color: context.appColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          button: onTap != null,
          label: subtitle == null ? title : '$title, $subtitle',
          child: onTap == null
              ? label
              : Material(
                  color: Colors.transparent,
                  child: InkWell(onTap: onTap, child: label),
                ),
        ),
        if (showDivider)
          Divider(
            indent: AppSpacing.dividerIndent,
            endIndent: AppSpacing.dividerEndIndent,
            color: context.appColors.divider,
          ),
      ],
    );
  }
}

/// A rounded surface holding a group of rows with hairline separators
/// (desing.md §5.3).
///
/// One card per group is what the mockups show, so the surface, radius, and
/// dividers are handled here rather than per row.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.children, super.key});

  /// Rows in this group, top to bottom. Typically [SettingsRow]s.
  final List<Widget> children;

  /// Builds the card decoration once, in one place, so the fill, the outline,
  /// the corner, and the shadow cannot be told apart by a reader of one
  /// grouped card (D-91).
  ///
  /// The four parts are Ethar's `_settingsCardDecoration`, ported whole: fill
  /// [AppPalette.surface], radius [AppRadius.card], a 1 px
  /// [AppPalette.cardBorder] outline, and — in the white theme only —
  /// [AppPalette.cardShadow] at blur 24 offset (0, 8). The dark theme has a
  /// `null` shadow, which is why the list below is built rather than handed to
  /// `BoxDecoration` directly: `BoxDecoration` takes a list, and an empty one is
  /// not the same as an absent field for a test reading the token.
  static BoxDecoration decoration(BuildContext context) {
    final colors = context.appColors;
    final shadow = colors.cardShadow;
    return BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: colors.cardBorder),
      boxShadow: shadow == null
          ? const []
          : [
              BoxShadow(color: shadow, blurRadius: 24, offset: const Offset(0, 8)),
            ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      // `DecoratedBox` rather than `ColoredBox` + `ClipRRect`: the card now has
      // a border and a shadow, and neither of those can be painted by a
      // `ColoredBox` — the border has to be the same object that clips the
      // rows so the outline sits *on* the corner rather than behind it.
      child: DecoratedBox(
        decoration: decoration(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    indent: AppSpacing.dividerIndent,
                    endIndent: AppSpacing.dividerEndIndent,
                    color: context.appColors.divider,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}