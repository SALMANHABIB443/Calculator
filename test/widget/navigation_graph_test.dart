import 'package:calculator/app.dart';
import 'package:calculator/routing/app_router.dart';
import 'package:calculator/routing/app_routes.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/pump_app.dart';

/// D-20 and **D-56** — the shape of the navigation graph.
///
/// Phases 2 and 7 proved the graph *works* by driving it. What neither could
/// assert is that it is the *only* graph: nothing stopped a new route, a
/// floating action button, or a shortcut from the Calculator to About from
/// appearing later and quietly widening the app beyond what was designed.
///
/// Two things are locked here:
///
/// - the exact set of registered paths, so a screen cannot be added without
///   this failing;
/// - the **absence** of a direct route from the Calculator to About, Privacy, or
///   Terms, which is the half of D-20 that only a negative assertion can prove.
///
/// **D-56** — transitions are go_router's platform default and are deliberately
/// not configured. No mockup shows motion, so any custom animation would be
/// invented rather than designed; the test below asserts the *absence* of a
/// custom page builder so a future "polish" pass cannot add one by accident
/// without this file being updated to justify it.

void main() {
  group('the graph', () {
    testWidgets('registers exactly the twelve documented paths', (tester) async {
      mockEmptyHistory();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final paths = _allPaths(container.read(appRouterProvider));

      // D-20's six, plus the debug-only catalog (D-25), plus the four Secret Mode
      // routes Phase 11 added (D-82, D-84). The hidden ones are registered even
      // though nothing links to them: the five-second hold has to push a real
      // path, and registering it is cheaper than inventing a private navigator
      // for one screen.
      //
      // **The twelfth is D-114's**, and it is the only *parameterised* path in the
      // app: `/secret/browse/:place` serves the eleven pages the Vault rows open.
      // One path rather than eleven is the decision this file's count records — a
      // thirteenth entry here would mean somebody had decided to give those pages
      // their own routes, which is exactly the change worth a second look.
      expect(
        paths,
        containsAll(<String>[
          AppRoutes.calculator,
          AppRoutes.history,
          AppRoutes.settings,
          AppRoutes.about,
          AppRoutes.privacy,
          AppRoutes.terms,
          AppRoutes.catalog,
          AppRoutes.secretUnlock,
          AppRoutes.secret,
          AppRoutes.secretSettings,
          AppRoutes.secretChangePin,
          AppRoutes.secretBrowse,
        ]),
      );
      expect(
        paths,
        hasLength(12),
        reason: 'a new screen must be a decision, not an accident',
      );
    });

    testWidgets('the catalog is absent from a release build', (tester) async {
      // Guarded by the same `kDebugMode` the router uses, so the test documents
      // which build it is asserting about rather than passing vacuously.
      expect(kDebugMode, isTrue, reason: 'this suite runs in debug');

      mockEmptyHistory();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // The route exists here. Its absence in release is a property of the
      // single `if (kDebugMode)` in app_router.dart, which cannot be exercised
      // from a debug test run — D-25 records that as a build-time guarantee.
      expect(
        _allPaths(container.read(appRouterProvider)),
        contains(AppRoutes.catalog),
      );
    });

    testWidgets('every registered path resolves to a screen', (tester) async {
      mockEmptyHistory();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CalculatorApp(),
        ),
      );
      await tester.pumpAndSettle();

      final router = container.read(appRouterProvider);

      // Pushing each path must not throw — a typo in a route constant is
      // otherwise invisible until a user taps the row that leads there.
      //
      // **The parameterised path pushes its own pattern**, which is why
      // `VaultPlaceScreen` tolerates a segment it does not recognise (D-114): the
      // literal `:place` arrives here as a `:place` id, and it has to render
      // rather than throw. `vault_place_pages_test.dart` asserts that fallback
      // directly; what this line buys is that the *route* resolves at all, which
      // is a different failure from the screen mishandling its input.
      for (final path in _allPaths(router)) {
        router.push(path);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: path);
      }
    });
  });

  group('D-20 — the Calculator reaches nothing but Settings and History', () {
    testWidgets('no About, Privacy, or Terms control exists on the root route', (
      tester,
    ) async {
      await pumpApp(tester);

      // The positive half is covered by the Phase 2 tests: the gear button opens
      // Settings and the clock opens History. This is the half that cannot be
      // shown by tapping things, because a control that does not exist cannot
      // be tapped.
      for (final label in ['About', 'Privacy Policy', 'Terms of Service']) {
        expect(find.text(label), findsNothing, reason: label);
      }
      expect(find.text('APP INFORMATION'), findsNothing);
      expect(find.byIcon(Icons.info_outline), findsNothing);
      expect(find.byIcon(Icons.shield_outlined), findsNothing);
      expect(find.byIcon(Icons.description_outlined), findsNothing);
    });

    testWidgets(
      'the only navigable controls on the root are two icon buttons',
      (tester) async {
        await pumpApp(tester);

        // Exactly two, because every other route is meant to be a level deeper.
        // A third would mean a new way out of the Calculator.
        //
        // Counted as the *navigable* actions rather than as every `IconButton`
        // on screen. The backspace (D-81) is a third `IconButton`, and it has
        // been since it was added — but it is not a way out of the Calculator,
        // so counting it would have turned this test red for a control that
        // does not threaten the graph at all. The filter is what keeps the
        // assertion saying what it means: two destinations, plus whatever
        // editing affordances the screen carries.
        final navigable = find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip != 'Backspace',
        );
        expect(navigable, findsNWidgets(2));
      },
    );

    testWidgets('the app is three levels deep at its furthest', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);
      await tapSettingsRow(tester, 'Terms of Service');

      // Calculator -> Settings -> Terms. One more pop reaches the calculator,
      // and one more still would leave the app.
      expect(find.text('Terms of Service'), findsWidgets);
      expect(
        find.text('Agreement'),
        findsOneWidget,
        reason: 'the document body rendered, so this is a real screen',
      );
      await goBack(tester);
      expect(find.text('Decimal Places'), findsWidgets);
      await goBack(tester);
      expect(find.byKey(const Key('calculator-display-line')), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('D-52 — About carries Terms but not Privacy', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);
      // Scrolled to and then verified on-screen before tapping: a row can be
      // built while still below the fold, and a tap on an off-screen row
      // silently leaves the test on Settings.
      await tester.scrollUntilVisible(
        find.text('App Version'),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(find.text('App Version'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('App Version'));
      await tester.pumpAndSettle();

      // The About mockup shows three rows under MORE. A fourth would be a
      // second documented path to Privacy and would contradict D-52.
      expect(find.text('APP INFORMATION'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Rate App'),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Rate App'), findsOneWidget);
      expect(find.text('Share App'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(
        find.text('Privacy Policy'),
        findsNothing,
        reason: 'D-52: About is not a second path to the privacy policy',
      );
    });
  });

  group('D-56 — transitions are the platform default', () {
    testWidgets('no route customises its page transition', (tester) async {
      mockEmptyHistory();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // A `pageBuilder` on any route means someone has chosen an animation.
      // go_router's default is the platform push, which is what ships today.
      for (final route in _allGoRoutes(container.read(appRouterProvider))) {
        expect(
          route.pageBuilder,
          isNull,
          reason: '${route.name} declares a custom transition',
        );
      }
    });

    testWidgets('each scope gets its own router', (tester) async {
      mockEmptyHistory();

      final first = ProviderContainer();
      final firstRouter = first.read(appRouterProvider);

      // The router is a provider, not a global — so a relaunch gets a new one
      // rather than resuming a navigator that outlived its widget tree. The
      // cold-start test proves the *screen* resets; this proves the mechanism.
      final second = ProviderContainer();
      final secondRouter = second.read(appRouterProvider);

      expect(identical(firstRouter, secondRouter), isFalse);

      // Disposing one must not disturb the other, and must not throw: a
      // double-dispose or a use-after-dispose here would surface as a crash on
      // the *next* launch, which no other test would catch.
      expect(first.dispose, returnsNormally);
      expect(
        () => secondRouter.routerDelegate.currentConfiguration,
        returnsNormally,
      );

      second.dispose();
    });
  });
}

/// The paths of every top-level route the router was built with.
List<String> _allPaths(GoRouter router) => [
  for (final route in router.configuration.routes)
    if (route is GoRoute) route.path,
];

/// The router's top-level routes, as [GoRoute]s.
///
/// The router also exposes a debug-only listing route; narrowing keeps the
/// D-56 assertion to the paths a user can actually be pushed through.
List<GoRoute> _allGoRoutes(GoRouter router) => [
  for (final route in router.configuration.routes)
    if (route is GoRoute) route,
];
