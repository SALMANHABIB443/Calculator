import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_typography.dart';

/// The key styles on the calculator keypad (desing.md §5.1).
///
/// Each variant owns its own fill and label colour, so a screen never pairs a
/// fill with the wrong foreground — the classic trap being the function keys,
/// which are a light mid-gray carrying **near-black** labels.
enum CalculatorButtonVariant {
  /// `0`–`9` and the decimal point: dark fill, white label.
  digit(background: AppColors.buttonDigit, foreground: AppColors.textPrimary),

  /// `+ − × ÷` and `=`: the orange primary action.
  operator(
    background: AppColors.accent,
    foreground: AppColors.textPrimary,
  ),

  /// `AC`, `+/−`, `%`: light fill, **dark** label.
  function(
    background: AppColors.buttonFunction,
    foreground: AppColors.textOnFunction,
  );

  const CalculatorButtonVariant({
    required this.background,
    required this.foreground,
  });

  /// Key fill.
  final Color background;

  /// Label colour, chosen for contrast against [background].
  final Color foreground;
}

/// A single circular calculator key (desing.md §5.1).
///
/// **Sizing.** The key is sized from the space its parent gives it — the
/// smaller of the available width and height — so a grid can hand it a square
/// cell and it stays a circle at any phone size without clipping (D-09). No
/// fixed diameter is baked in, because Phase 1 could only measure a *range*
/// of 85–95 logical px and the exact value is residual unknown **R-2**,
/// settled in Phase 9 against the rendered grid. The fallback below is the
/// midpoint of that range and applies only when the parent gives an unbounded
/// box, e.g. in the component catalog.
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
  /// desing.md §5.1 describes the keys as circles *and* the `0` as spanning two
  /// columns, which cannot both hold. A stadium is the only shape that is both
  /// two columns wide and fully round at the ends, so that is what this renders;
  /// Phase 9 confirms it against the mockup.
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
        final keySize = math.min(maxWidth, maxHeight);

        // Round keys take the smaller axis so they stay circular; a wide key
        // keeps its full cell width and matches the row height beside it.
        final height = keySize;
        final width = widget.isWide ? maxWidth : keySize;
        final radius = BorderRadius.all(Radius.circular(height / 2));

        return Semantics(
          button: true,
          enabled: enabled,
          label: widget.semanticLabel ?? widget.label,
          child: ExcludeSemantics(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 100),
              opacity: enabled
                  ? (_pressed ? AppColors.pressedOpacity : 1)
                  : AppColors.pressedOpacity,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 100),
                scale: _pressed ? 0.94 : 1,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: Material(
                    color: widget.variant.background,
                    shape: RoundedRectangleBorder(borderRadius: radius),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: widget.onPressed,
                      onTapDown: (_) => _setPressed(true),
                      onTapUp: (_) => _setPressed(false),
                      onTapCancel: () => _setPressed(false),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            style: AppTypography.buttonLabel.copyWith(
                              color: widget.variant.foreground,
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
