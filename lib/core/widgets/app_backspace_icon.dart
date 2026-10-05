import '../../../core/design/app_palette.dart';
import 'package:flutter/material.dart';

import 'app_icon.dart';

/// The `⌫` glyph the calculator and the Secret Mode pad delete with (**D-112**).
///
/// A painted icon for the same reason [AppTrashIcon] is one (**D-73**): the
/// design calls for a specific outlined backspace, and the two alternatives were
/// both worse for this app. `flutter_svg` would add a runtime dependency plus an
/// asset pipeline for one icon, against a project that deliberately takes its
/// audio, haptics, and navigation from the SDK and the plugins it actually needs
/// (**D-01**, **D-16**); flattening the path into Material IconFont codepoints
/// makes the drawing unreadable once it is generated. A painter is ~40 lines,
/// resolves [size] and [color] from the same tokens as [AppIcon], and costs
/// nothing at packaging time.
///
/// It is drawn **stroked rather than filled**, which is what makes it a different
/// glyph from Material's `Icons.backspace_outlined` at the same 24 px: that one
/// is a filled pentagon with the `×` cut out of it, so at 22 px the two arms of
/// the `×` read as slivers rather than as strokes. Outlining the pentagon and
/// the `×` with the same pen keeps both shapes legible at the size these call
/// sites paint them.
///
/// The API mirrors [AppIcon]'s exactly — same defaults, same `semanticLabel`
/// escape hatch — so a call site that swaps one for the other changes nothing
/// but the widget name.
class AppBackspaceIcon extends StatelessWidget {
  const AppBackspaceIcon({
    super.key,
    this.size = AppIconSize.row,
    this.color,
    this.semanticLabel,
  });

  /// Size bucket; use [AppIconSize.row] unless the context says otherwise.
  final AppIconSize size;

  /// Fill colour, defaulting to primary text.
  final Color? color;

  /// Accessible name. Omit for decorative icons, so screen readers do not
  /// announce the row twice.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // A square box of exactly [size], which is what an [AppIcon] of the same
    // bucket occupies too, and what a bare `Icon` of that size occupies. Both
    // call sites here position this glyph inside a box of their own — the
    // calculator's 48 px `AppIconButton`, and the pad key's own circle — so the
    // box has to match what they were getting from `Icon` before, or the touch
    // target and the key's geometry both shift.
    final icon = SizedBox.square(
      dimension: size.value,
      child: CustomPaint(
        painter: AppBackspacePainter(color ?? context.appColors.textPrimary),
      ),
    );
    if (semanticLabel == null) return icon;
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(child: icon),
    );
  }
}

/// Paints the `⌫` — a left-pointing pentagon with an `×` inside it — in a single
/// flat colour.
///
/// Public because the drawing is the component's substance rather than an
/// implementation detail: the two sub-paths, the grid, the pen, and the colour it
/// was asked for are all things a caller or a test has a reason to read, and
/// none of them can be asserted from the outside otherwise.
class AppBackspacePainter extends CustomPainter {
  const AppBackspacePainter(this.color);

  /// The colour the glyph is stroked with.
  final Color color;

  /// The grid [outline] and [cross] are authored on — a 24×24 box, the size
  /// Material's own icon fonts use, so the two kinds of icon in the app share a
  /// coordinate space even though they do not share a renderer.
  static const double grid = 24;

  /// The pen both sub-paths are drawn with.
  ///
  /// 2 units on a 24 grid is the weight Material's own outlined icons use, and it
  /// is the number that decides whether this glyph reads at 22 px: at 1.5 the
  /// pentagon's outline greys out against the black page and the `×` loses an arm
  /// to antialiasing, at 2.5 the two shapes start to crowd each other where the
  /// `×`'s lower-left arm passes close to the pentagon's point.
  static const double strokeWidth = 2;

  /// The pentagon: a rectangle with its left edge drawn in to a point, which is
  /// what makes the shape read as *back*space rather than as a plain delete
  /// square.
  ///
  /// Authored so the path's own bounds run x ∈ [2, 22] and y ∈ [4, 20], whose
  /// centre is the 24 grid's (12, 12) — and because the pen is symmetric, the
  /// *painted* ink is centred there too. That centring is the property both call
  /// sites depend on: the calculator's `AppIconButton` centres this glyph in its
  /// 48 px box, and the pad key centres it in a circle it sized from the smaller
  /// of its two axes, so ink that sat off-centre inside the box would sit
  /// off-centre in the key.
  static final Path outline = Path()
    ..moveTo(9, 4)
    ..lineTo(22, 4)
    ..lineTo(22, 20)
    ..lineTo(9, 20)
    ..lineTo(2, 12)
    ..close();

  /// The `×`, as two crossed strokes.
  ///
  /// Centred on (14.5, 12) rather than on the grid's centre line, because it has
  /// to sit inside the *body* of the pentagon — the body's own centre is at
  /// x ≈ 15.5 once the point is cut in, and centring the `×` on the grid instead
  /// would push it right against the vertical edge and leave the point looking
  /// empty.
  static final Path cross = Path()
    ..moveTo(11.5, 9)
    ..lineTo(17.5, 15)
    ..moveTo(17.5, 9)
    ..lineTo(11.5, 15);

  /// The pen both sub-paths are drawn with, in [color].
  /// Built here rather than inline in [paint] so the weight, cap, and join are
  /// readable from outside the class: they are three of the four numbers that make
  /// this the drawing it is, and `paint` keeps them to itself otherwise. Round
  /// caps and joins mean the `×`'s two arm ends and the pentagon's point carry the
  /// same weight as the rest of the outline, rather than reading as four tiny
  /// blobs against three corners.
  static Paint penOf(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Scaling here rather than baking a size into the path means one drawing
    // serves every bucket, and the source geometry stays readable against the
    // original.
    canvas.scale(size.shortestSide / grid);
    final pen = penOf(color);
    canvas
      ..drawPath(outline, pen)
      ..drawPath(cross, pen);
    canvas.restore();
  }

  @override
  bool shouldRepaint(AppBackspacePainter oldDelegate) =>
      oldDelegate.color != color;
}