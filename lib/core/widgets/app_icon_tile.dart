import '../../../core/design/app_palette.dart';
import 'package:flutter/material.dart';

/// The soft rounded square behind a settings row's leading icon (D-91).
///
/// **A direct port of Ethar's `_SettingsIconTile`.** That widget is a 44 px
/// `Container` with `borderRadius: 13` and `color: colors.surfaceSoft`, holding a
/// 21 px icon in the primary text colour, and it is what every row on Ethar's
/// Settings screen wears. This app's settings rows carried a bare glyph until
/// D-91, which made the same row read as two different objects in two sibling
/// apps a user moves between.
///
/// **Why the tile and not the glyph.** A bare 22 px icon on a near-black card is
/// a mark floating in space; the tile gives it a body, an edge, and a size the
/// row's height can be measured against. It is also what makes the row's
/// leading column align: every tile is the same 44 px, so the titles below them
/// share an edge no matter what glyph each row chose.
///
/// The glyph is 21 rather than [AppIconSize]'s row bucket of 22 — Ethar's
/// number, and one pixel is the difference between a glyph that fills its tile
/// evenly and one that looks a shade large inside it.
class AppIconTile extends StatelessWidget {
  const AppIconTile({super.key, this.icon, this.iconWidget, this.color})
    : assert(
        (icon == null) != (iconWidget == null),
        'AppIconTile needs either an IconData or a widget to draw',
      );

  /// The glyph to place in the tile. Mutually exclusive with [iconWidget];
  /// supply one of the two.
  final IconData? icon;

  /// A painted glyph instead of an [IconData] — the app's own trash
  /// ([AppTrashIcon], D-73), which is a `CustomPainter` rather than an icon
  /// font. Scaled to [glyphSize] whatever size the widget draws itself at, so
  /// the tile keeps the 21 px glyph the recipe specifies.
  ///
  /// The mirror of [AppIconButton.iconWidget], and for the same reason: the
  /// delete glyph is not in Material's set, so a tile that has to carry it
  /// needs a way in that is not an [IconData].
  final Widget? iconWidget;

  /// Glyph colour, defaulting to the theme's primary text — the same default
  /// [AppIcon] resolves for itself, restated here because the tile paints the
  /// glyph itself rather than delegating to a bare icon widget. It reaches only
  /// [icon]; a painted [iconWidget] owns its own colour.
  final Color? color;

  /// Side of the square, in logical pixels.
  static const double size = 44;

  /// The square's corner radius.
  static const double radius = 13;

  /// The glyph's size inside the square.
  static const double glyphSize = 21;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: context.appColors.surfaceSoft,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: iconWidget == null
        ? Icon(
            icon,
            color: color ?? context.appColors.textPrimary,
            size: glyphSize,
          )
        // The tile is the component that owns the 21 px glyph, so a painted
        // [iconWidget] is scaled to [glyphSize] rather than trusted to bring
        // its own — the tile and a Material [Icon] then occupy the same box.
        : Center(
            child: SizedBox.square(
              dimension: glyphSize,
              child: FittedBox(fit: BoxFit.contain, child: iconWidget),
            ),
          ),
  );
}