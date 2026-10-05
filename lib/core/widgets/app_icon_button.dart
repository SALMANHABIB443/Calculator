import '../../../core/design/app_palette.dart';
import 'package:flutter/material.dart';

import '../design/app_spacing.dart';

/// A header action drawn as a bordered square around its glyph (D-74).
///
/// The QR-Scanner-style header pass replaced the app's bare header glyphs with
/// a visible 48 px button: a [context.appColors.surface] fill, a 1 px
/// [context.appColors.divider] border, and a [AppRadius.iconButton] corner. Drawing the
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
    this.color,
    this.disabledColor,
    this.bordered = true,
    this.size,
    this.iconSize,
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
  final Color? color;

  /// Colour of a [icon] glyph when [onPressed] is `null`.
  final Color? disabledColor;

  /// Whether the glyph sits in the bordered 48 px square (D-74).
  ///
  /// **The box is this component's point**, so it is on by default and every
  /// header action keeps it. [false] drops the fill and the outline and leaves a
  /// bare glyph in the same 48 px touch target — for a control that reads as
  /// editing the number beside it rather than as a screen-level action, which is
  /// what the calculator's `⌫` is: a bordered box there competed with the
  /// result it sits above and read as a fifth destination.
  ///
  /// The *target* never changes either way. Both renderings occupy
  /// [AppSizes.iconTouchTarget] and are a real [IconButton], so the touch floor
  /// (prd.md §12) and the accessibility layer are identical — only the ink is
  /// gone.
  final bool bordered;

  /// Overrides [AppSizes.iconTouchTarget] as this button's square side, or
  /// `null` for the app-wide 48 (**D-110**).
  ///
  /// The calculator's two header actions are the only ones that take it: D-110
  /// made every key on that screen noticeably larger, and a 48 px box above a
  /// 90 px key reads as a header that belongs to a *smaller* calculator than the
  /// one underneath it. 56 puts the box on the app's own 56 px rhythm
  /// ([AppSizes.headerHeight]) and still clears the 44 pt floor with room to
  /// spare.
  ///
  /// The target and the ink scale together — [iconSize] follows [size] unless a
  /// caller says otherwise — so a caller cannot ship a 56 px box with a 22 px
  /// glyph floating in it.
  final double? size;

  /// Overrides [AppSizes.rowIcon] as the glyph's size, or `null` to follow
  /// [size] ([AppSizes.calculatorHeaderAction] is 56 / 26).
  ///
  /// Separate only so an [iconWidget] owner — which draws its own glyph at
  /// whatever size it likes — is not forced to accept a scale it does not apply.
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // One derived pair rather than two optional numbers the caller has to keep
    // in step: an omitted [size] falls back to the app-wide 48, and the glyph
    // follows whatever the box resolved to unless it was asked for explicitly.
    final boxSize = Size.square(size ?? AppSizes.iconTouchTarget);
    final glyphSize =
        iconSize ??
        (size == null
            ? AppSizes.rowIcon
            : size! * AppSizes.calculatorHeaderGlyphRatio);
    final glyph = iconWidget ?? Icon(icon, size: glyphSize);

    // The bordered square, built here rather than held as a `static const`.
    //
    // The border lives on the *shape* rather than on [ButtonStyle.side] because
    // the shape is what both the fill and the outline are painted from — a shape
    // that carries its own side renders the same whichever of the two paths the
    // framework takes. A `const` shape would have to bake in one divider colour,
    // and a divider is exactly the token that differs between the two themes: a
    // dark-theme outline on a white card would be invisible. Rebuilding it costs
    // one allocation and is what lets the box follow the theme.
    final box = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.iconButton)),
      side: BorderSide(color: colors.divider),
    );

    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      // Zero padding so the box the style pins is the box the button occupies,
      // and a caller that leaves the default in place cannot widen one side of
      // the header and pull the title off centre.
      padding: EdgeInsets.zero,
      style: ButtonStyle(
        fixedSize: WidgetStatePropertyAll<Size>(boxSize),
        minimumSize: WidgetStatePropertyAll<Size>(boxSize),
        maximumSize: WidgetStatePropertyAll<Size>(boxSize),
        padding: const WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.zero),
        // Transparent rather than absent, so the *button* still occupies the
        // same 48 px box it does with a border: dropping the background property
        // would leave the shape to supply the paint and change nothing else,
        // but an explicit transparent fill states the intent — the target is
        // unchanged, only its ink is gone.
        backgroundColor: WidgetStatePropertyAll<Color>(
          bordered ? colors.surface : Colors.transparent,
        ),
        // `ButtonStyle` has no `disabledForegroundColor` field: a state's colour
        // is one resolved property, so the disabled state is spelled out in the
        // resolver rather than as a second slot.
        foregroundColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.disabled)
              ? disabledColor ?? colors.textSecondary
              : color ?? colors.textPrimary,
        ),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          bordered
              ? box
              // A borderless variant still has to hand the style an
              // [OutlinedBorder] — `WidgetStatePropertyAll<OutlinedBorder>` will
              // not take a `BorderlessBorder` — so it is the same shape with no
              // side, which paints the fill and nothing else.
              : const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppRadius.iconButton),
                  ),
                ),
        ),
      ),
      icon: glyph,
    );
  }
}