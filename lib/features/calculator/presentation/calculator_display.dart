import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
// Imports the feature's public surface rather than a path into its internals
// (D-57), so the settings providers can move again without touching this file.
import '../../settings/settings.dart';
import 'calculator_controller.dart';
import 'display_resolver.dart';

/// Expression and result lines, right-aligned (desing.md §3, §6.1).
///
/// The lines sit at the bottom of the space the screen gives them, so the
/// display reads as the hero element with the keypad directly beneath it
/// (desing.md §6.1, "display area has large vertical space above the buttons").
///
/// The two strings come from `resolveDisplay` in `display_resolver.dart`, which
/// is pure and Flutter-free; this class is only the layout. The split exists so
/// the history feature can reuse the resolver without importing this widget
/// (D-39) — importing it would create a cycle, since this widget imports
/// [CalculatorController], which writes history.
class CalculatorDisplay extends ConsumerWidget {
  const CalculatorDisplay({super.key});

  /// Result length at which the primary line steps down from
  /// [AppTypography.resultLarge] to [AppTypography.resultMedium]
  /// (desing.md §10, "the result label auto-shrinks when the value is very
  /// long"). Beyond even that, the [FittedBox] scales the line rather than
  /// letting it clip or ellipsize a number the user is trying to read.
  static const int compactResultLength = 10;

  /// Line height used for a style that does not set one.
  static const double _defaultLineHeight = 1.2;

  /// Height reserved for the expression line, at scale 1.0.
  ///
  /// Generous on purpose: the expression style sets no `height`, so its real
  /// line box depends on the font's own metrics — about 1.17× for Roboto, and
  /// taller for some fallbacks. Over-reserving is free, because the display is
  /// bottom-aligned and the slack falls above the expression rather than
  /// between the two lines.
  static final double _expressionLineHeight =
      AppTypography.expression.fontSize! * 1.5;

  /// Height of the result line for [style] at scale 1.0.
  static double _resultLineHeight(TextStyle style) =>
      style.fontSize! * (style.height ?? _defaultLineHeight);

  /// Space the display needs under [scaler], so the screen can reserve it
  /// before sizing the keypad and the two never squeeze each other (D-09).
  ///
  /// Takes the scaler rather than reading it from a `BuildContext` because the
  /// caller is the screen's `LayoutBuilder`, which is sizing the keypad *from*
  /// this number (**D-54**). A fixed point size could not see an enlarged font,
  /// so the two would disagree and the result line would be painted taller than
  /// the space reserved for it. Pass `TextScaler.noScaling` for the 1x value.
  static double minimumHeight(TextScaler scaler) =>
      _expressionLineHeight * scaler.scale(1) +
      AppSpacing.sm +
      _resultLineHeight(AppTypography.resultLarge) * scaler.scale(1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calculatorControllerProvider);

    // D-14: the only dependency on the setting. Watching it here rather than in
    // the controller is what makes a mid-calculation change formatting-only —
    // the engine is never told about it.
    final decimalPlaces = ref.watch(
      settingsProvider.select((settings) => settings.decimalPlaces),
    );

    final display = resolveDisplay(state, decimalPlaces: decimalPlaces);
    final resultStyle =
        display.result.length > compactResultLength
        ? AppTypography.resultMedium
        : AppTypography.resultLarge;

    // D-54: the reserved line box has to grow with the font. `Text` scales its
    // own glyphs through the ambient `MediaQuery`, so a box left at the 1x
    // height would clip the very line the user enlarged the font to read.
    final scale = MediaQuery.textScalerOf(context).scale(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Flexible so the line gives way rather than overflowing if the screen
        // turns out to be shorter than [minimumHeight]. The result line below
        // keeps its exact height, because that is the number being read.
        Flexible(
          child: Text(
            display.expression,
            // Paired with `calculator-result` so a test can read both halves of
            // the display the same way, rather than matching expression copy.
            key: const Key('calculator-expression'),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.expression,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: _resultLineHeight(resultStyle) * scale,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              display.result,
              key: const Key('calculator-result'),
              maxLines: 1,
              softWrap: false,
              style: resultStyle,
            ),
          ),
        ),
      ],
    );
  }
}
