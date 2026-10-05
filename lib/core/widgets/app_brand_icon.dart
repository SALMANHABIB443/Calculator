import '../../../core/design/app_palette.dart';
import 'package:flutter/material.dart';

import '../design/app_typography.dart';

/// The app's brand mark (desing.md §5.5): a rounded square holding four
/// circular operator keys in a 2x2 grid.
///
/// The two-orange / two-light split was confirmed by measuring the pixels of
/// mockup `02_30_45`; the glyph-to-quadrant assignment below is carried from
/// the specification.
///
/// ```
///   + (light)   − (orange)
///   × (light)   = (orange)
/// ```
///
/// The left column is the light function-key gray and the right column the
/// orange accent, so the mark reuses the same two tokens as the keypad — the
/// icon is a miniature of the thing it names. Drawn from tokens rather than
/// shipped as an asset so it stays sharp at any size and follows a future
/// palette change.
class AppBrandIcon extends StatelessWidget {
  const AppBrandIcon({super.key, this.size = 88});

  /// Side of the rounded square (desing.md §5.5, larger than a row icon).
  final double size;

  static const List<String> _leftColumn = ['+', '×'];
  static const List<String> _rightColumn = ['−', '='];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.appColors.buttonDigit,
          borderRadius: BorderRadius.circular(size * 0.22),
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.14),
          child: Column(
            children: [
              for (var i = 0; i < _leftColumn.length; i++)
                Expanded(
                  child: Row(
                    children: [
                      _key(_leftColumn[i], context.appColors.buttonFunction, context.appColors),
                      _key(_rightColumn[i], context.appColors.accent, context.appColors),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _key(String label, Color fill, AppPalette palette) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: AppTypography.buttonLabel.copyWith(
                    // The orange quadrant takes the accent label colour (white in
                    // both themes); the light one takes the function-key label.
                    color: fill == palette.accent
                        ? palette.textOnAccent
                        : palette.textOnFunction,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}