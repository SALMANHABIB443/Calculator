import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import 'app_icon.dart';

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
    this.iconColor = AppColors.textPrimary,
    this.showDivider = false,
  });

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
  final Color iconColor;

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
            ExcludeSemantics(child: AppIcon(icon, color: iconColor)),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: AppTypography.rowTitle),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppTypography.rowSubtitle),
                    ],
                  ],
                ),
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null) ...[
              const SizedBox(width: AppSpacing.sm),
              const ExcludeSemantics(
                child: AppIcon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
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
        if (showDivider) const Divider(indent: AppSpacing.cardPadding),
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

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: ColoredBox(
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Divider(indent: AppSpacing.cardPadding),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
