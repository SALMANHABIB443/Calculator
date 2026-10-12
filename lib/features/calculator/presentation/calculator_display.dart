import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_typography.dart';
// Imports the feature's public surface rather than a path into its internals
// (D-57), so the settings providers can move again without touching this file.
import '../../settings/settings.dart';
import 'calculator_controller.dart';
import 'display_resolver.dart';

/// The calculator's display: **two lines**, the calculation above the output
/// (desing.md §3, **D-78**, **D-79**).
///
/// The block sits against the keypad and stacks the two lines with a tight
/// 4 px gap between them. The **upper** line is the *calculation* — the
/// expression being built, `9 + 9`, in [context.type.expression] — and the
/// **lower** line is the *output* — the result, `18`, in the hero
/// [context.type.resultLarge], stepping down to [context.type.resultMedium]
/// once the value gets long. Bottom-aligning the stack keeps the calculation
/// directly above the live output instead of letting the two drift apart on a
/// tall display.
///
/// The output is a **live preview**: the lower line shows what `=` *would*
/// produce, updated on every keystroke (**D-79**), so `9 + 9` already reads `18`
/// while the second `9` is still being keyed and pressing `=` does not move the
/// number. The preview is derived in `display_resolver.dart` and never touches
/// the engine, so changing `decimalPlaces` re-renders it without the engine ever
/// being told (**D-14**).
///
/// It was a single line for a while (**D-82**), which read the expression while
/// typing and the answer after `=`, so the user could not see the result of
/// their own arithmetic until they committed it — the one thing the large output
/// line exists to show. The two lines are what the layout was drawn for.
///
/// Both lines right-align (**D-69**), which is what keeps their right edges on
/// the `=` column, and both scale down rather than clipping or ellipsising a
/// number the user is trying to read (desing.md §3.2).
///
/// The strings come from `resolveDisplay` in `display_resolver.dart`, which is
/// pure and Flutter-free; this class is only the layout. The split exists so the
/// history feature can reuse the resolver without importing this widget (D-39) —
/// importing it would create a cycle, since this widget imports
/// [CalculatorController], which writes history.
class CalculatorDisplay extends ConsumerWidget {
  const CalculatorDisplay({super.key});

  /// Result length at which the output line steps down from
  /// [context.type.resultLarge] to [context.type.resultMedium]
  /// (desing.md §10, "the result label auto-shrinks when the value is very
  /// long"). Beyond even that, the [FittedBox] scales the line rather than
  /// letting it clip or ellipsize a number the user is trying to read.
  static const int compactResultLength = 10;

  /// Gap between the calculation line and the live output.
  ///
  /// **4, tight on purpose.** The stack sits against the keypad, so the gap
  /// is only what separates the two lines from each other — not a token from
  /// the spacing scale.
  static const double lineGap = 4;

  /// Line height used for a style that does not set one.
  static const double _defaultLineHeight = 1.2;

  /// Height of [style]'s line box at scale 1.0.
  static double _lineHeight(TextStyle style) =>
      style.fontSize! * (style.height ?? _defaultLineHeight);

  /// Height of the result line for [style] at scale 1.0.
  static double _resultLineHeight(TextStyle style) => _lineHeight(style);

  /// Space the display needs under [scaler], so the screen can reserve it
  /// before sizing the keypad and the two never squeeze each other (D-09).
  ///
  /// **One expression box, one result box, and the tight gap between them.**
  /// The stack paints the 20 px expression line above the 60 px result line,
  /// so the reservation is those two line boxes plus [lineGap] — a single
  /// number is shorter still, but the screen budgets for the taller
  /// calculation state so the keypad never shifts when an operator is keyed.
  ///
  /// Takes the scaler rather than reading it from a `BuildContext` because the
  /// caller is the screen's `LayoutBuilder`, which is sizing the keypad *from*
  /// this number (**D-54**). A fixed point size could not see an enlarged font,
  /// so the two would disagree and the number would be painted in a box too
  /// short to hold it. Pass `TextScaler.noScaling` for the 1x value.
  static double minimumHeight(TextScaler scaler) => (_lineHeight(
        AppTypography.expression,
      ) +
      lineGap +
      _resultLineHeight(AppTypography.resultLarge)) *
      scaler.scale(1);

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

    // A short value wears the hero style and steps down when it gets long; the
    // expression stays the small secondary line it has always been
    // (desing.md §3). One line cannot be both, so which of the two bands a value
    // is *in* is what decides its style.
    final resultStyle =
        display.result.length > compactResultLength
        ? context.type.resultMedium
        : context.type.resultLarge;

    return Column(
      // A key so a layout test can measure the block rather than inferring it
      // from its own geometry.
      key: const Key('calculator-display'),
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The calculation, directly above the live output. Blank while a
        // single number is being typed, because there is no calculation to
        // show yet — and the gap goes with it, so a lone number sits flush
        // against the output slot below.
        Align(
          alignment: Alignment.centerRight,
          child: _DisplayLine(
            text: display.expression,
            style: context.type.expression,
            lineKey: const Key('calculator-expression'),
          ),
        ),
        if (display.expression.isNotEmpty) const SizedBox(height: lineGap),
        // The output, previewing what `=` would give (D-79).
        Align(
          alignment: Alignment.centerRight,
          child: _DisplayLine(
            text: display.result,
            style: resultStyle,
            lineKey: const Key('calculator-display-line'),
          ),
        ),
      ],
    );
  }
}

/// One of the display's two lines: right-aligned, and scaled down rather than
/// clipped when it is too long for its half.
///
/// The `FittedBox` measures the line at its natural size and scales it down only
/// when it cannot fit — an enlarged font (D-54), or an expression or value too
/// long for the column. Scaling rather than clipping is what keeps the number the
/// user is reading legible (desing.md §3.2), and right-aligning the scale is what
/// keeps it flush with the `=` column (**D-69**) at every length.
///
/// A shared widget rather than the same eight lines twice, so the two halves
/// cannot drift into styling the same value differently.
class _DisplayLine extends StatelessWidget {
  const _DisplayLine({
    required this.text,
    required this.style,
    required this.lineKey,
  });

  final String text;
  final TextStyle style;
  final Key lineKey;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Text(
        text,
        key: lineKey,
        maxLines: 1,
        softWrap: false,
        style: style,
      ),
    );
  }
}