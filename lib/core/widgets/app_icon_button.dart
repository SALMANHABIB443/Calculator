import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_spacing.dart';

/// A header action drawn as a bordered square around its glyph (D-74).
///
/// The QR-Scanner-style header pass replaced the app's bare header glyphs with
/// a visible 48 px button: a [AppColors.surface] fill, a 1 px
/// [AppColors.divider] border, and a [AppRadius.iconButton] corner. Drawing the
/// box is the point of the component — a bare glyph three pixels off the line
/// every card in the app is built on reads as a squashed layout, while a box
/// whose *edge* rides the margin reads as a deliberate object.
///
/// Two things this component is responsible for, both of which a raw
/// `IconButton` gets wrong here:
///
/// * **The box is exactly [AppSizes.iconTouchTarget] square.** The header
///   centres a title between two of these, so the two sides have to be the same
///   width; an `IconButton` that sized itself from its padding would move the
///   title off centre by whatever it decided to add.
/// * **The glyph size is owned here, not at the call site.** Every header icon
///   is [AppSizes.rowIcon] so no call site can quietly ship a 28 px arrow beside
///   a 22 px one.
///
/// It stays a real [IconButton] on purpose. A hand-rolled `InkWell` box would
/// render identically, but `find.byType(IconButton)`, `find.byTooltip`, and the
/// accessibility layer all read an `IconButton` for free — the History header
/// trash is found through exactly those finders.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    this.icon,
    this.iconWidget,
    this.onPressed,
    this.tooltip,
    this.color = AppColors.textPrimary,
    this.disabledColor = AppColors.textSecondary,
  }) : assert(
         icon != null || iconWidget != null,
         'AppIconButton needs either an IconData or a widget to draw',
       );

  /// The Material glyph to draw, e.g. [Icons.arrow_back].
  ///
  /// Mutually exclusive with [iconWidget]; supply one of the two. The glyph is
  /// painted at [AppSizes.rowIcon].
  final IconData? icon;

  /// A painted glyph instead of a [IconData] — the History header's own trash
  /// ([AppTrashIcon]), which is a `CustomPainter` rather than an icon font.
  ///
  /// The widget owns its own colour, so [color] does not reach it.
  final Widget? iconWidget;

  /// What the button does. `null` renders the disabled state, which paints
  /// [disabledColor] and stops responding.
  final VoidCallback? onPressed;

  /// Accessible name, and the handle tests reach the button by.
  final String? tooltip;

  /// Colour of a [icon] glyph, and of that glyph in every state but disabled.
  final Color color;

  /// Colour of a [icon] glyph when [onPressed] is `null`.
  final Color disabledColor;

  /// The bordered square every header action wears.
  ///
  /// The border lives on the *shape* rather than on [ButtonStyle.side] because
  /// the shape is what both the fill and the outline are painted from — a shape
  /// that carries its own side renders the same whichever of the two paths the
  /// framework takes.
  static const OutlinedBorder _box = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.iconButton)),
    side: BorderSide(color: AppColors.divider),
  );

  /// The one size every header action is pinned to.
  static const Size _size = Size.square(AppSizes.iconTouchTarget);

  @override
  Widget build(BuildContext context) {
    final glyph = iconWidget ?? Icon(icon, size: AppSizes.rowIcon);

    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      // Zero padding so the box the style pins is the box the button occupies,
      // and a caller that leaves the default in place cannot widen one side of
      // the header and pull the title off centre.
      padding: EdgeInsets.zero,
      style: ButtonStyle(
        fixedSize: const WidgetStatePropertyAll<Size>(_size),
        minimumSize: const WidgetStatePropertyAll<Size>(_size),
        maximumSize: const WidgetStatePropertyAll<Size>(_size),
        padding: const WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.zero),
        backgroundColor: const WidgetStatePropertyAll<Color>(
          AppColors.surface,
        ),
        // `ButtonStyle` has no `disabledForegroundColor` field: a state's colour
        // is one resolved property, so the disabled state is spelled out in the
        // resolver rather than as a second slot.
        foregroundColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.disabled)
              ? disabledColor
              : color,
        ),
        shape: const WidgetStatePropertyAll<OutlinedBorder>(
          _box,
        ),
      ),
      icon: glyph,
    );
  }
}
