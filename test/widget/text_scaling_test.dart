import 'package:calculator/app.dart';
import 'package:calculator/core/design/app_typography.dart';
import 'package:calculator/features/calculator/presentation/calculator_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

/// NFR-004 / D-54 — Dynamic Type support.
///
/// The app clamps the system font scale to [CalculatorApp.maxTextScaleFactor]
/// rather than honouring it outright. These tests pin both halves of that
/// contract: text really does grow below the ceiling (so the feature is not a
/// no-op dressed up as support), and it stops growing at it (so the two fixed
/// line boxes and the keypad grid on the calculator keep fitting).
///
/// The scale is set through `tester.platformDispatcher` rather than a
/// `MediaQuery` wrapper, because that is the channel the real platform setting
/// arrives on — a wrapper above `MaterialApp` would be ignored, since the app
/// builds its own `MediaQuery` from the view.

void main() {
  /// The scale the app actually resolved for a page below `MaterialApp`.
  double effectiveScale(WidgetTester tester) {
    final context = tester.element(find.byKey(const Key('calculator-display-line')));
    return MediaQuery.textScalerOf(context).scale(1);
  }

  group('the clamp', () {
    testWidgets('a 1x system scale is passed through untouched', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(
        effectiveScale(tester),
        1.0,
        reason: 'the mockup-matched type scale is the baseline, not a reduction',
      );
    });

    testWidgets('growth below the ceiling is honoured', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.15;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpApp(tester);

      expect(
        effectiveScale(tester),
        1.15,
        reason: 'D-54 caps growth, it does not disable it',
      );
    });

    testWidgets('growth past the ceiling is clamped', (tester) async {
      // The largest factor Android offers, to prove the clamp is doing the work
      // rather than the test simply asking for a modest one.
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpApp(tester);

      expect(effectiveScale(tester), CalculatorApp.maxTextScaleFactor);
    });

    testWidgets('a system scale below 1x never shrinks the mockup type', (
      tester,
    ) async {
      // Some launchers and accessibility services report a factor under 1.
      // desing.md §3 measured every size at 1x, so shrinking would drift the app
      // away from the mockup for a setting the user did not ask for.
      tester.platformDispatcher.textScaleFactorTestValue = 0.8;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpApp(tester);

      expect(effectiveScale(tester), 1.0);
    });
  });

  group('CalculatorDisplay.minimumHeight', () {
    test('is two result line boxes when nothing is scaled', () {
      // The display is split into two equal halves (D-78), and each half has to
      // hold the taller of the two lines it can be given, so the reservation is
      // two boxes: the shortest display in which the largest thing either line
      // can paint — the 60 px result — still fits at full size in its own half.
      expect(
        CalculatorDisplay.minimumHeight(TextScaler.noScaling),
        moreOrLessEquals(2 * AppTypography.resultLarge.fontSize! * 1.1),
        reason: 'two halves, so two line boxes are the whole reservation',
      );
    });

    test('grows with the font, which is what the keypad is sized against', () {
      final at2x = CalculatorDisplay.minimumHeight(
        const TextScaler.linear(2.0),
      );

      // Every term is a line box now, so the whole reservation scales with the
      // font — a fixed point size would disagree with what is painted (D-54).
      expect(
        at2x,
        moreOrLessEquals(
          2 * CalculatorDisplay.minimumHeight(TextScaler.noScaling),
        ),
        reason: 'D-54: a fixed reservation would disagree with the painted line',
      );
    });
  });

  group('layout holds at the clamp', () {
    // The narrowest supported phone (desing.md §9, ~442dp wide) is the case
    // that matters: it is where the keypad grid is tightest against the display.
    for (final size in const [Size(320, 568), Size(442, 960), Size(480, 1000)]) {
      testWidgets('the calculator does not overflow at ${size.width.toInt()}x${size.height.toInt()}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await pumpApp(tester);

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('calculator-display-line')), findsOneWidget);
      });
    }

    for (final size in const [Size(320, 568), Size(480, 1000)]) {
      testWidgets('the scrollable screens do not overflow at ${size.width.toInt()}x${size.height.toInt()}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await pumpApp(tester);
        await openSettings(tester);
        expect(tester.takeException(), isNull, reason: 'Settings');

        await goBack(tester);
        await openHistory(tester);
        expect(tester.takeException(), isNull, reason: 'History, empty state');
      });
    }

    testWidgets('the About header title is not clipped at the clamp', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpApp(tester);
      await openSettings(tester);

      // The header is a single centred title now, but D-54's guarantee is
      // unchanged: at the clamp the painted line has to fit the reserved bar.
      // A clip or an overflow exception here would mean the two disagree.
      await tapSettingsRow(tester, 'App Version');
      expect(tester.takeException(), isNull);
      expect(find.text('About'), findsOneWidget);
    });
  });
}
