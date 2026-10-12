import '../../../core/design/app_palette.dart';

import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';

/// The key styles on the calculator keypad (desing.md §5.1).
///
/// Each variant owns its own fill and label colour, so a screen never pairs a
/// fill with the wrong foreground — the classic trap being the function keys,
/// which are a light mid-gray carrying **near-black** labels.
///
/// The pair is resolved from the palette by [colors] rather than stored on the
/// enum. A `const` enum field is fixed at compile time, and a key's fill is one
/// of the tokens that differs between the two themes — the dark theme's
/// `#1E1E1E` digit key would be a black disc on a white page. Naming the *role*
/// here and letting the palette supply the colours is what keeps the pairing
/// rule (which foreground goes with which fill) in one readable place while the
/// values themselves follow the theme.
enum CalculatorButtonVariant {
  /// `0`–`9` and the decimal point: the page's key fill, primary label.
  digit,

  /// `+ − × ÷` and `=`: the orange primary action, white label.
  ///
  /// [AppPalette.textOnAccent] rather than `textPrimary`: on white, `textPrimary`
  /// is ink, and ink on the orange `=` would be the one unreadable key on the pad.
  operator,

  /// `AC`, `+/−`, `%`: the lightest fill, **dark** label.
  function;

  /// The label size this variant paints its glyph at (D-111).
  ///
  /// One getter rather than a `fontSize` on the palette: the three sizes are the
  /// *same* in both themes, so a colour field would imply they differ when they
  /// do not. Reading it here means a key's size is chosen by its variant — the
  /// same way its fill and foreground already are — so no call site can pair the
  /// orange fill with the digit size.
  TextStyle labelStyle(AppType type) => switch (this) {
    CalculatorButtonVariant.digit => type.buttonLabel,
    CalculatorButtonVariant.operator => type.buttonOperatorLabel,
    CalculatorButtonVariant.function => type.buttonFunctionLabel,
  };

  /// The fill and label colour pair this variant paints in [palette].
  CalculatorButtonColors colors(AppPalette palette) => switch (this) {
    CalculatorButtonVariant.digit => CalculatorButtonColors(
      background: palette.buttonDigit,
      foreground: palette.textPrimary,
    ),
    CalculatorButtonVariant.operator => CalculatorButtonColors(
      background: palette.accent,
      foreground: palette.textOnAccent,
    ),
    CalculatorButtonVariant.function => CalculatorButtonColors(
      background: palette.buttonFunction,
      foreground: palette.textOnFunction,
    ),
  };

  /// The tactile surface this variant paints: gradient stops, top highlight,
  /// edge, and shadow (D-114).
  ///
  /// Naming the *role* here and letting the palette supply the colours keeps
  /// the same rule as [colors]: no call site can pair a digit gradient with
  /// an operator edge, while the values themselves follow the theme.
  CalculatorButtonSurface surface(AppPalette palette) => switch (this) {
    CalculatorButtonVariant.digit => CalculatorButtonSurface(
      gradientTop: palette.keyDigitTop,
      gradientBottom: palette.keyDigitBottom,
      highlight: palette.keyDigitHighlight,
      border: palette.keyBorder,
      shadow: palette.keyShadow,
      shadowBlur: AppColors.keyShadowBlur,
      shadowOffsetY: AppColors.keyShadowOffsetY,
    ),
    CalculatorButtonVariant.operator => CalculatorButtonSurface(
      gradientTop: palette.keyOperatorTop,
      gradientBottom: palette.keyOperatorBottom,
      highlight: palette.keyOperatorHighlight,
      border: palette.keyOperatorBorder,
      shadow: palette.keyOperatorShadow,
      shadowBlur: palette.keyOperatorShadowBlur,
      shadowOffsetY: palette.keyOperatorShadowOffsetY,
    ),
    CalculatorButtonVariant.function => CalculatorButtonSurface(
      gradientTop: palette.keyFunctionTop,
      gradientBottom: palette.keyFunctionBottom,
      highlight: palette.keyFunctionHighlight,
      border: palette.keyFunctionBorder,
      shadow: palette.keyShadow,
      shadowBlur: AppColors.keyShadowBlur,
      shadowOffsetY: AppColors.keyShadowOffsetY,
    ),
  };
}

/// One key's fill and the label colour chosen to read on it (desing.md §5.1).
///
/// A named pair rather than two loose `Color`s so the fill and its foreground
/// are always passed together — the whole point of the enum above is that no
/// call site can pair a fill with the wrong foreground.
class CalculatorButtonColors {
  /// Paints [foreground] on [background].
  const CalculatorButtonColors({
    required this.background,
    required this.foreground,
  });

  /// Key fill.
  final Color background;

  /// Label colour, chosen for contrast against [background].
  final Color foreground;
}

/// One key's tactile surface recipe: gradient, highlight, edge, shadow.
///
/// A named bundle rather than loose values at the call site so a variant's
/// treatment cannot be mixed with another's — the same pairing rule
/// [CalculatorButtonColors] applies to fills.
class CalculatorButtonSurface {
  /// Paints the gradient from [gradientTop] to [gradientBottom] with
  /// [highlight] along the top edge, [border] around it, and [shadow].
  const CalculatorButtonSurface({
    required this.gradientTop,
    required this.gradientBottom,
    required this.highlight,
    required this.border,
    required this.shadow,
    required this.shadowBlur,
    required this.shadowOffsetY,
  });

  /// Upper stop of the key's vertical gradient.
  final Color gradientTop;

  /// Lower stop of the key's vertical gradient.
  final Color gradientBottom;

  /// 1 px inner highlight drawn along the key's top edge.
  final Color highlight;

  /// 1 px outline around the key.
  final Color border;

  /// Soft shadow (or halo) cast under the key.
  ///
  /// Nullable because the palette's glow is: `null` means "cast nothing", which
  /// the widget spells as no `BoxShadow` rather than as a transparent one.
  final Color? shadow;

  /// Blur radius of [shadow].
  final double shadowBlur;

  /// Vertical offset of [shadow].
  final double shadowOffsetY;
}

/// A single rounded-square calculator key (desing.md §5.1, D-120).
///
/// **Sizing.** The key fills the cell its parent gives it — the full cell
/// width and the row height — so the grid's geometry still owns the layout
/// (D-27, D-69) and the key stays aligned at any phone size without clipping
/// (D-09). No fixed diameter is baked in, because Phase 1 could only measure
/// a *range* of 85–95 logical px and the exact value is residual unknown
/// **R-2**, settled in Phase 9 against the rendered grid. The fallback below
/// is the midpoint of that range and applies only when the parent gives an
/// unbounded box, e.g. in the component catalog.
class CalculatorButton extends StatefulWidget {
  const CalculatorButton({
    required this.label,
    required this.variant,
    super.key,
    this.onPressed,
    this.semanticLabel,
    this.isWide = false,
  });

  /// Glyph shown on the key, e.g. `7`, `÷`, `AC`.
  final String label;

  /// Fill and label colour pair.
  final CalculatorButtonVariant variant;

  /// Press handler. A `null` callback renders the key dimmed and inert.
  final VoidCallback? onPressed;

  /// Accessible name. Falls back to [label], which is right for digits and
  /// operators but wrong for `AC`, so pass a real name for that key.
  final String? semanticLabel;

  /// Whether this key spans two grid columns — the `0` key.
  ///
  /// desing.md §5.1 draws the keys as rounded squares *and* the `0` as spanning
  /// two columns. A double-width rounded square with the same corner radius is
  /// what this renders; Phase 9 confirms the span against the mockup.
  final bool isWide;

  /// Fallback key side when the parent supplies an unbounded box.
  static const double fallbackSize = 88;

  @override
  State<CalculatorButton> createState() => _CalculatorButtonState();
}

class _CalculatorButtonState extends State<CalculatorButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = _resolve(constraints.maxWidth);
        final maxHeight = _resolve(constraints.maxHeight);

        // Rounded-square keys fill their cell: the full width the grid hands
        // down (two columns for the wide `0`) and the full row height (D-120,
        // D-27). Sizing from the smaller axis used to keep them circular; the
        // reference shape is a compact rounded square, so the cell itself is
        // the size now.
        final height = maxHeight;
        final width = maxWidth;
        final radius = BorderRadius.all(
          Radius.circular(AppRadius.calculatorKey),
        );
        // The key's own fill and label pair, resolved once per build from the
        // theme so a switch repaints the key in the new palette.
        final key = widget.variant.colors(context.appColors);
        // D-120: the tactile surface — gradient, highlight, edge, shadow —
        // resolved once here so the decorations below are the only place that
        // knows how it is drawn.
        final surface = widget.variant.surface(context.appColors);

        return Semantics(
          button: true,
          enabled: enabled,
          label: widget.semanticLabel ?? widget.label,
          child: ExcludeSemantics(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 100),
              opacity: enabled
                  ? (_pressed ? context.appColors.pressedOpacity : 1)
                  : context.appColors.pressedOpacity,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 100),
                scale: _pressed ? 0.94 : 1,
                child: SizedBox(
                  width: width,
                  height: height,
                  // D-120: the palette's glow/shadow, cast from the key's own
                  // rounded-square shape — so it follows the corners exactly.
                  // It wraps the `Material` rather than sitting inside it,
                  // because a `Material`'s own shadow is the framework's to
                  // colour.
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(borderRadius: radius),
                      // A dark theme's digit key casts the D-111 halo, an
                      // operator its own accent-tinted glow; `null` paints no
                      // shadow at all rather than a transparent one.
                      shadows: surface.shadow == null
                          ? null
                          : <BoxShadow>[
                              BoxShadow(
                                color: surface.shadow!,
                                blurRadius: surface.shadowBlur,
                                offset: Offset(0, surface.shadowOffsetY),
                              ),
                            ],
                    ),
                    child: Material(
                      // D-114: elevation 0 with the depth drawn explicitly. A
                      // `Material` shadow is painted in a colour the framework
                      // picks — black in the dark theme — and the page is
                      // `#000000`, so the elevation this used to ask for was
                      // black-on-black and could not be seen at any value. The
                      // palette now states a colour instead: a faint white halo
                      // on digit and function keys, an accent-tinted glow on
                      // the orange column.
                      color: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: radius,
                        // The hard edge, and the one that does most of the work:
                        // the halo is soft and a fill step is implied, but only an
                        // outline actually says where the key stops. Per-variant
                        // in D-114 so the orange and light keys keep an edge
                        // tuned to their own fill.
                        side: BorderSide(color: surface.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Ink(
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          // The soft-touch surface: a very subtle vertical
                          // gradient inside the existing hue family, so the key
                          // catches light without going glossy.
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              surface.gradientTop,
                              surface.gradientBottom,
                            ],
                          ),
                        ),
                        child: DecoratedBox(
                          // The 1 px inner highlight along the top edge: a
                          // restrained light line that gives the softly raised
                          // feel without an outline or 3D effect.
                          decoration: BoxDecoration(
                            borderRadius: radius,
                            border: Border(
                              top: BorderSide(
                                color: surface.highlight,
                              ),
                            ),
                          ),
                          child: InkWell(
                            onTap: widget.onPressed,
                            onTapDown: (_) => _setPressed(true),
                            onTapUp: (_) => _setPressed(false),
                            onTapCancel: () => _setPressed(false),
                            borderRadius: radius,
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  widget.label,
                                  maxLines: 1,
                                  // The variant picks the size as well as the
                                  // colour (D-111), so the operator column cannot be
                                  // painted at the digit size by accident.
                                  style: widget.variant
                                      .labelStyle(context.type)
                                      .copyWith(color: key.foreground),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Falls back to [CalculatorButton.fallbackSize] for an unbounded axis, which
  /// only happens outside a real grid.
  double _resolve(double constraint) =>
      constraint.isFinite && constraint > 0
      ? constraint
      : CalculatorButton.fallbackSize;
}