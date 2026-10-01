import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import 'app_icon.dart';

/// The trash glyph the History screen deletes with (**D-73**).
///
/// A painted icon rather than an [Icon] because the design calls for a specific
/// glyph that Material's set does not contain, and the two alternatives were both
/// worse for this app. `flutter_svg` would add a runtime dependency plus an asset
/// pipeline for one icon, against a project that deliberately takes its audio,
/// haptics, and navigation from the SDK and the plugins it actually needs
/// (**D-01**, **D-16**); flattening the path into Material IconFont codepoints
/// makes the drawing unreadable once it is generated. A painter is ~40 lines,
/// resolves [size] and [color] from the same tokens as [AppIcon], and costs
/// nothing at packaging time — the only thing it gives up is accepting arbitrary
/// SVG, which nothing else in the app asks for.
///
/// The API mirrors [AppIcon]'s exactly — same defaults, same `semanticLabel`
/// escape hatch — so a call site that swaps one for the other changes nothing
/// but the widget name.
class AppTrashIcon extends StatelessWidget {
  const AppTrashIcon({
    super.key,
    this.size = AppIconSize.row,
    this.color = AppColors.textPrimary,
    this.semanticLabel,
  });

  /// Size bucket; use [AppIconSize.row] unless the context says otherwise.
  final AppIconSize size;

  /// Fill colour, defaulting to primary text.
  final Color color;

  /// Accessible name. Omit for decorative icons, so screen readers do not
  /// announce the row twice.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // A square box of exactly [size], which is what an [AppIcon] of the same
    // bucket occupies too. That is the contract the header's arithmetic depends
    // on: D-70 places this glyph by *measuring* its box so the ink lands 24 px
    // from the screen edge, so the box has to match a Material icon's whatever
    // the glyph inside it happens to look like.
    final icon = SizedBox.square(
      dimension: size.value,
      child: CustomPaint(painter: AppTrashPainter(color)),
    );
    if (semanticLabel == null) return icon;
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(child: icon),
    );
  }
}

/// Paints [path] — a solid trash can — in a single flat colour.
///
/// Public because the drawing is the component's substance rather than an
/// implementation detail: the path, its grid, and the colour it was asked for are
/// all things a caller or a test has a reason to read, and none of them can be
/// asserted from the outside otherwise.
class AppTrashPainter extends CustomPainter {
  const AppTrashPainter(this.color);

  /// The colour the glyph is filled with.
  final Color color;

  /// The grid [path] is authored on — a 24×24 box, the size Material's own icon
  /// fonts use, so the two kinds of icon in the app share a coordinate space
  /// even though they do not share a renderer.
  static const double grid = 24;

  /// A trash can: lid and handle, body, and two vertical slots.
  ///
  /// Ported op-for-op from the source SVG's `d` attribute, which carries the
  /// geometry in this 24-unit space behind a `transform="scale(10.66667,…)"`
  /// on the way to its `0 0 256 256` viewBox — 256 / 24 is not 10.66667, so the
  /// path and the viewBox disagree with each other and the path is the one the
  /// drawing was actually made on.
  ///
  /// The ink runs x ∈ [4, 20] and y ∈ [2, 22], which centres it on the grid's
  /// own (12, 12) and so on whatever square it is painted into. That matters
  /// here: the header places the glyph by measuring its box, and a drawing that
  /// sat off-centre inside that box would land its ink somewhere other than the
  /// 24 px margin the arithmetic promises.
  ///
  /// The four sub-paths are one [Path] on purpose. The two slots wind *opposite*
  /// to the body, so the default [PathFillType.nonZero] rule — which is what the
  /// SVG's own `fill-rule="nonzero"` asks for — cancels them out and they render
  /// as holes rather than adding two solid bars. Splitting them into separate
  /// paths or switching the fill type would fill them in and change the design.
  static final Path path = Path()
    // Lid and handle: the handle's two shoulders, the full-width bar beneath
    // them, and the two ends of that bar.
    ..moveTo(10, 2)
    ..lineTo(9, 3)
    ..lineTo(5, 3)
    ..relativeCubicTo(-0.6, 0, -1, 0.4, -1, 1)
    ..relativeCubicTo(0, 0.6, 0.4, 1, 1, 1)
    ..lineTo(7, 5)
    ..lineTo(17, 5)
    ..lineTo(19, 5)
    ..relativeCubicTo(0.6, 0, 1, -0.4, 1, -1)
    ..relativeCubicTo(0, -0.6, -0.4, -1, -1, -1)
    ..lineTo(15, 3)
    ..lineTo(14, 2)
    ..close()
    // Body: straight sides down to y≈20, then a slight taper across the bottom.
    ..moveTo(5, 7)
    ..lineTo(5, 20)
    ..relativeCubicTo(0, 1.1, 0.9, 2, 2, 2)
    ..lineTo(17, 22)
    ..relativeCubicTo(1.1, 0, 2, -0.9, 2, -2)
    ..lineTo(19, 7)
    ..close()
    // The two slots, the same shape mirrored about the body's centre line.
    ..moveTo(9, 9)
    ..relativeCubicTo(0.6, 0, 1, 0.4, 1, 1)
    ..lineTo(10, 19)
    ..relativeCubicTo(0, 0.6, -0.4, 1, -1, 1)
    ..relativeCubicTo(-0.6, 0, -1, -0.4, -1, -1)
    ..lineTo(8, 10)
    ..relativeCubicTo(0, -0.6, 0.4, -1, 1, -1)
    ..close()
    ..moveTo(15, 9)
    ..relativeCubicTo(0.6, 0, 1, 0.4, 1, 1)
    ..lineTo(16, 19)
    ..relativeCubicTo(0, 0.6, -0.4, 1, -1, 1)
    ..relativeCubicTo(-0.6, 0, -1, -0.4, -1, -1)
    ..lineTo(14, 10)
    ..relativeCubicTo(0, -0.6, 0.4, -1, 1, -1)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Scaling here rather than baking a size into the path means one drawing
    // serves every bucket, and the source geometry stays readable against the
    // original.
    canvas.scale(size.shortestSide / grid);
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(AppTrashPainter oldDelegate) => oldDelegate.color != color;
}
