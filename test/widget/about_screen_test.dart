import 'package:calculator/core/config/app_info.dart';
import 'package:calculator/core/design/app_colors.dart';
import 'package:calculator/core/widgets/core_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

/// The About screen against the documented design (desing.md §6.4, feature.md
/// §D): the hero, the three APP INFORMATION rows, and the three MORE rows.
///
/// As in Phases 2–6, fidelity is asserted against the *documented* structure
/// and copy — not against the mockup pixels, which cannot be opened in this
/// environment. Row icons follow the existing Phase 3 choices; FEAT-ABOUT-002's
/// "Document, Tag, Shield" list is flagged for the Phase 9 pixel pass.
void main() {
  Future<void> openAbout(WidgetTester tester) async {
    await pumpApp(tester);
    await openSettings(tester);
    // A row can be *built* while still below the fold on a short screen
    // (e.g. the 320x568 surface), so ensure it is fully on-screen before
    // tapping — otherwise the tap misses and the test silently stays on
    // Settings.
    await tester.scrollUntilVisible(
      find.text('App Version'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('App Version'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('App Version'));
    await tester.pumpAndSettle();
    expect(find.text('APP INFORMATION'), findsOneWidget, reason: 'did not land on About');
  }

  group('layout (desing.md §6.4)', () {
    testWidgets('shows the two sections in order', (tester) async {
      await openAbout(tester);

      expect(find.text('APP INFORMATION'), findsOneWidget);
      // The MORE header is below the fold on the default test surface, so it
      // is scrolled to before it can be asserted.
      await tester.scrollUntilVisible(
        find.text('MORE'),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('MORE'), findsOneWidget);
      // SectionHeader uppercases its label, so the sentence case is never
      // rendered.
      expect(find.text('App Information'), findsNothing);
      expect(find.text('More'), findsNothing);
    });

    testWidgets('carries the title alone, with no subtitle', (tester) async {
      await openAbout(tester);

      expect(find.text('About'), findsOneWidget);
      // The header is the title and nothing else: the subtitle the mockup had
      // here was dropped along with the `subtitle` parameter itself, so the
      // sentence must not be rendered anywhere on the screen.
      expect(find.text('Simple calculator, powerful features'), findsNothing);
    });

    testWidgets('hero shows the icon, name, version, and description', (
      tester,
    ) async {
      await openAbout(tester);

      expect(find.byType(AppBrandIcon), findsOneWidget);
      expect(find.text('Calculator'), findsWidgets); // hero + App Name row
      expect(find.text('Version 1.0.0'), findsOneWidget);
      expect(
        find.text('A simple, fast and reliable calculator for your everyday needs.'),
        findsOneWidget,
      );
    });

    testWidgets('APP INFORMATION lists name, version, and developer', (
      tester,
    ) async {
      await openAbout(tester);

      expect(find.text('App Name'), findsOneWidget);
      expect(find.text(AppInfo.name), findsWidgets);
      expect(find.text('Version'), findsOneWidget);
      expect(find.text('1.0.0'), findsWidgets);
      expect(find.text('Developer'), findsOneWidget);
      expect(find.text('Hasan Mahadi'), findsOneWidget);
    });

    testWidgets('MORE lists rate, share, and terms with their subtitles', (
      tester,
    ) async {
      await openAbout(tester);

      // The three rows are below the fold on the default test surface; the
      // ListView builds lazily, so each is scrolled to before asserting it.
      for (final text in [
        'Rate App',
        'Support us with your rating',
        'Share App',
        'Tell your friends about this app',
        'Terms of Service',
        'Read our terms and conditions',
      ]) {
        await tester.scrollUntilVisible(
          find.text(text),
          120,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text(text), findsOneWidget, reason: text);
      }
    });

    testWidgets('each MORE row carries a chevron', (tester) async {
      await openAbout(tester);

      for (final title in ['Rate App', 'Share App', 'Terms of Service']) {
        await tester.scrollUntilVisible(
          find.text(title),
          120,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.ensureVisible(find.text(title));
        await tester.pumpAndSettle();
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

    testWidgets('renders on the black app background', (tester) async {
      await openAbout(tester);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
      expect(scaffold.backgroundColor, AppColors.background);
    });

    testWidgets('scrolls on a short screen without overflowing', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await openAbout(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('the whole screen fits a 480x1000 phone without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(480, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await openAbout(tester);

      expect(tester.takeException(), isNull);
    });
  });
}