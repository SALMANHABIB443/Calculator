import 'package:calculator/core/design/app_colors.dart';
import 'package:calculator/core/design/app_spacing.dart';
import 'package:calculator/core/design/app_typography.dart';
import 'package:calculator/core/widgets/core_widgets.dart';
import 'package:calculator/features/settings/domain/app_settings.dart';
import 'package:calculator/features/settings/presentation/decimal_places_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

/// The Settings screen against the documented design (desing.md §6.3,
/// feature.md §C) and the persistence behind it (AC-004, AC-005).
///
/// As in Phases 2–5, fidelity is asserted against the *documented* measurements
/// — the D-03 palette, the typography tokens, and the §6.3 row structure — not
/// against the mockup pixels, which cannot be opened in this environment.
void main() {
  group('layout (desing.md §6.3)', () {
    testWidgets('shows the three sections in order', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.text('ABOUT'), findsOneWidget);
      // SectionHeader uppercases, so the label is stored as written in the
      // design doc's Title Case.
      expect(find.text('Appearance'), findsNothing);
      expect(find.text('Preferences'), findsNothing);
    });

    testWidgets('carries the standard header, with no subtitle', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);

      // Every secondary header is the title alone now: no subtitle line, and
      // no per-screen size reduction to make room for one.
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Customize your calculator experience'), findsNothing);

      final title = tester.widget<Text>(
        find.descendant(
          of: find.byType(SecondaryPageHeader),
          matching: find.text('Settings'),
        ),
      );
      expect(title.style?.fontSize, AppTypography.screenTitle.fontSize);
    });

    testWidgets('every specified row is present, with its subtitle', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);

      // The Appearance and Preferences groups are built on open.
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Dark mode'), findsOneWidget);
      expect(find.text('Sound'), findsOneWidget);
      expect(find.text('Key press sound'), findsOneWidget);
      expect(find.text('Vibration'), findsOneWidget);
      expect(find.text('Vibrate on key press'), findsOneWidget);
      expect(find.text('Decimal Places'), findsOneWidget);
      expect(find.text('2 decimal places'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Keep calculation history'), findsOneWidget);

      // The About group is below the fold, so it is scrolled to rather than
      // asserted on sight.
      await tester.scrollUntilVisible(
        find.text('Terms of Service'),
        120,
        scrollable: find.byType(Scrollable).last,
      );

      expect(find.text('App Version'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
    });

    testWidgets('the three preferences are toggles, not static text', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);

      expect(find.widgetWithText(ToggleRow, 'Sound'), findsOneWidget);
      expect(find.widgetWithText(ToggleRow, 'Vibration'), findsOneWidget);
      expect(find.widgetWithText(ToggleRow, 'History'), findsOneWidget);
    });

    testWidgets('every toggle starts on by default (D-16, AC-005)', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);

      for (final title in ['Sound', 'Vibration', 'History']) {
        expect(switchPosition(tester, title), isTrue, reason: title);
      }
    });

    testWidgets('rows sit on the surface colour inside a group card (D-03)', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);

      expect(
        tester.widget<ColoredBox>(
          find.descendant(
            of: find.byType(SettingsGroup).first,
            matching: find.byType(ColoredBox),
          ),
        ).color,
        AppColors.surface,
      );
    });

    testWidgets('sits on the black app background (D-03)', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AppColors.background,
      );
    });

    testWidgets('rows keep the minimum tappable height (desing.md §4)', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);

      final box = tester.widget<ConstrainedBox>(
        find
            .descendant(
              of: find.widgetWithText(ToggleRow, 'Sound'),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(box.constraints.minHeight, AppSizes.rowMinHeight);
    });
  });

  group('Theme row (D-45)', () {
    testWidgets('shows a chevron but is not a tap target', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      expect(
        find.descendant(
          of: find.widgetWithText(SettingsRow, 'Theme'),
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
      );
      // No InkWell means no ripple and no navigation: v1.0 has one theme.
      expect(
        find.descendant(
          of: find.widgetWithText(SettingsRow, 'Theme'),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    });

    testWidgets('tapping it does not navigate anywhere', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();

      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('toggles (AC-004, AC-005)', () {
    testWidgets('Sound starts on and turns off', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      await toggleSettingsRow(tester, 'Sound');

      expect(switchPosition(tester, 'Sound'), isFalse);
      expect(currentSettings(tester).soundEnabled, isFalse);
    });

    testWidgets('Vibration turns off and back on', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      await toggleSettingsRow(tester, 'Vibration');
      expect(switchPosition(tester, 'Vibration'), isFalse);

      await toggleSettingsRow(tester, 'Vibration');
      expect(switchPosition(tester, 'Vibration'), isTrue);
    });

    testWidgets('turning one off leaves the others alone', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      await toggleSettingsRow(tester, 'Vibration');

      final settings = currentSettings(tester);
      expect(settings.vibrationEnabled, isFalse);
      expect(settings.soundEnabled, isTrue);
      expect(settings.historyEnabled, isTrue);
      expect(settings.decimalPlaces, 2);
    });

    testWidgets('reflects a stored preference on open', (tester) async {
      await pumpApp(
        tester,
        settings: AppSettings.defaults.copyWith(
          soundEnabled: false,
          historyEnabled: false,
        ),
      );
      await openSettings(tester);

      expect(switchPosition(tester, 'Sound'), isFalse);
      expect(switchPosition(tester, 'History'), isFalse);
      expect(switchPosition(tester, 'Vibration'), isTrue);
    });

    testWidgets('the switch itself is also a tap target', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ToggleRow, 'History'),
          matching: find.byType(Switch),
        ),
      );
      await tester.pumpAndSettle();

      expect(currentSettings(tester).historyEnabled, isFalse);
    });
  });

  group('Decimal Places (FEAT-SET-004, D-14, D-46)', () {
    testWidgets('opens a picker offering 0 through 6', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      await tapSettingsRow(tester, 'Decimal Places');

      for (var places = 0; places <= 6; places++) {
        expect(
          find.byKey(DecimalPlacesSheet.optionKey(places)),
          findsOneWidget,
        );
      }
    });

    testWidgets('marks the current precision as selected', (tester) async {
      await pumpApp(
        tester,
        settings: AppSettings.defaults.copyWith(decimalPlaces: 4),
      );
      await openSettings(tester);

      await tapSettingsRow(tester, 'Decimal Places');

      expect(
        find.descendant(
          of: find.byKey(DecimalPlacesSheet.optionKey(4)),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('choosing a value updates the row subtitle', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      await chooseDecimalPlaces(tester, 5);

      expect(currentSettings(tester).decimalPlaces, 5);
      expect(find.text('5 decimal places'), findsOneWidget);
      expect(find.text('2 decimal places'), findsNothing);
    });

    testWidgets('one place reads in the singular', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      await chooseDecimalPlaces(tester, 1);

      expect(find.text('1 decimal place'), findsOneWidget);
    });

    testWidgets('zero is selectable, so whole-number arithmetic is possible', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);

      await chooseDecimalPlaces(tester, 0);

      expect(currentSettings(tester).decimalPlaces, 0);
      expect(find.text('0 decimal places'), findsOneWidget);
    });

    testWidgets('dismissing the picker changes nothing', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      await dismissDecimalPlaces(tester);

      expect(currentSettings(tester).decimalPlaces, 2);
      expect(find.text('2 decimal places'), findsOneWidget);
      expect(find.byType(DecimalPlacesSheet), findsNothing);
    });
  });

  group('About links (D-07, D-20)', () {
    testWidgets('App Version, Privacy Policy, and Terms all navigate', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);

      await tapSettingsRow(tester, 'App Version');
      expect(find.text('APP INFORMATION'), findsOneWidget);
      await goBack(tester);

        await tapSettingsRow(tester, 'Privacy Policy');
        expect(find.text('What this app does'), findsOneWidget);
        await goBack(tester);

        await tapSettingsRow(tester, 'Terms of Service');
        expect(find.text('Agreement'), findsOneWidget);
        await goBack(tester);

      // Back on Settings. The header, not a row, is what is guaranteed to be
      // on screen here: the list is still scrolled to the bottom after three
      // round trips, so its top rows are not built.
      expect(find.text('Settings'), findsWidgets);
    });

    testWidgets('each carries a chevron', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      for (final title in [
        'App Version',
        'Privacy Policy',
        'Terms of Service',
      ]) {
        // Rows below the fold are not built until scrolled to, so each is
        // brought into view before its chevron can be asserted.
        await tester.scrollUntilVisible(
          find.widgetWithText(SettingsRow, title),
          120,
          scrollable: find.byType(Scrollable).last,
        );
        expect(
          find.descendant(
            of: find.widgetWithText(SettingsRow, title),
            matching: find.byIcon(Icons.chevron_right),
          ),
          findsOneWidget,
          reason: title,
        );
      }
    });
  });

  group('resilience', () {
    testWidgets('scrolls on a short screen without overflowing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpApp(tester);
      await openSettings(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('APPEARANCE'), findsOneWidget);
    });

    testWidgets('the whole screen fits a 480x1000 phone without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(480, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpApp(tester);
      await openSettings(tester);

      expect(tester.takeException(), isNull);
    });
  });
}
