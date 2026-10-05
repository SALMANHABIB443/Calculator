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
/// The space the display is given is divided into two equal halves. The **upper
/// half** is the *calculation* — the expression being built, `9 + 9`, in
/// [context.type.expression] — and the **lower half** is the *output* — the
/// result, `18`, in the hero [context.type.resultLarge], stepping down to
/// [context.type.resultMedium] once the value gets long. Each line centres in
/// its own half, so the boundary between them is the display's own midline
/// rather than a gap someone has to choose and then defend.
///
/// The output is a **live preview**: the lower half shows what `=` *would*
/// produce, updated on every keystroke (**D-79**), so `9 + 9` already reads `18`
/// while the second `9` is still being keyed and pressing `=` does not move the
/// number. The preview is derived in `display_resolver.dart` and never touches
/// the engine, so changing `decimalPlaces` re-renders it without the engine ever
/// being told (**D-14**).
///
/// It was a single line for a while (**D-82**), which read the expression while
/// typing and the answer after `=`, so the user could not see the result of
/// their own arithmetic until they committed it — the one thing the large lower
/// half exists to show. The two lines are what the layout was drawn for.
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

  /// Line height used for a style that does not set one.
  static const double _defaultLineHeight = 1.2;

  /// Height of the result line for [style] at scale 1.0.
  static double _resultLineHeight(TextStyle style) =>
      style.fontSize! * (style.height ?? _defaultLineHeight);

  /// Space the display needs under [scaler], so the screen can reserve it
  /// before sizing the keypad and the two never squeeze each other (D-09).
  ///
  /// **Two result line boxes** (**D-78**). The space is split into two equal
  /// halves, and each half must hold the taller of the two lines it can be given,
  /// so the reservation is two boxes rather than one — a single box would let the
  /// display be laid out too short for its own lower half the moment a long
  /// expression pushed its line past the midpoint.
  ///
  /// Taken against the *large* result style because that is the tallest thing
  /// either line can paint: the expression style is smaller, so it can never be
  /// the one that overflows its half.
  ///
  /// Takes the scaler rather than reading it from a `BuildContext` because the
  /// caller is the screen's `LayoutBuilder`, which is sizing the keypad *from*
  /// this number (**D-54**). A fixed point size could not see an enlarged font,
  /// so the two would disagree and the number would be painted in a box too
  /// short to hold it. Pass `TextScaler.noScaling` for the 1x value.
  static double minimumHeight(TextScaler scaler) =>
      2 * _resultLineHeight(AppTypography.resultLarge) * scaler.scale(1);

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
      children: [
        // The upper half — the calculation. Blank while a single number is
        // being typed, because there is no calculation to show yet.
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: _DisplayLine(
              text: display.expression,
              style: context.type.expression,
              lineKey: const Key('calculator-expression'),
            ),
          ),
        ),
        // The lower half — the output, previewing what `=` would give (D-79).
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: _DisplayLine(
              text: display.result,
              style: resultStyle,
              lineKey: const Key('calculator-display-line'),
            ),
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