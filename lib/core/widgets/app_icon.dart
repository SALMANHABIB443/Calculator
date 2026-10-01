import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_spacing.dart';

/// Standard icon sizes (desing.md §5.4, plus the History redesign's D-72).
enum AppIconSize {
  /// Inside dense content such as a settings row's chevron.
  small(18),

  /// Inside a settings or About row — the mockups use 22–24.
  row(AppSizes.rowIcon),

  /// The History header's back arrow and delete glyphs, and the chevron on the
  /// History card (D-72).
  ///
  /// A bucket rather than a raw `Icon(size: 28)` so the arithmetic that lands a
  /// header glyph on the screen margin has a name to read.
  ///
  /// D-74 moved every header glyph onto [row]: the header actions are now
  /// bordered boxes pinned to [AppSizes.iconTouchTarget], and a 28 px glyph in a
  /// 48 px box left 10 px of air where the design wants 13. The bucket is kept
  /// because the *empty state* still steps up from [row] for its 40 px
  /// illustration, and removing the middle step would leave that jump with no
  /// name.
  large(28),

  /// The empty-state illustration (D-72).
  ///
  /// Distinct from [hero], which is the About brand mark at 44 px: the History
  /// empty state asks for 40, and reusing the brand mark's size would make a
  /// placeholder icon as large as the app's own logo.
  illustration(40),

  /// The About hero brand mark.
  hero(44);

  const AppIconSize(this.value);

  /// Logical pixel side.
  final double value;
}

/// Wraps an [IconData] so every icon in the app resolves its size and colour
/// from tokens instead of hard-coded values (desing.md §5.4).
///
/// Icons default to [AppColors.textPrimary] — white for most, accent for active
/// or feedback icons, which is passed explicitly as [color].
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size = AppIconSize.row,
    this.color = AppColors.textPrimary,
    this.semanticLabel,
  });

  /// The glyph to draw.
  final IconData icon;

  /// Size bucket; use [AppIconSize.row] unless the context says otherwise.
  final AppIconSize size;

  /// Fill colour, defaulting to primary text.
  final Color color;

  /// Accessible name. Omit for decorative icons that sit beside a text label,
  /// so screen readers do not announce the row twice.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: size.value, color: color);
    if (semanticLabel == null) return iconWidget;
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(child: iconWidget),
    );
  }
}
