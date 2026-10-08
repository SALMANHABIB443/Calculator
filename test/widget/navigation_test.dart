import 'dart:math' as math;

import 'package:calculator/app.dart';
import 'package:calculator/core/design/app_colors.dart';
import 'package:calculator/routing/app_router.dart';
import 'package:calculator/routing/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

/// Widget harness for the Phase 2 acceptance criteria: the app launches to the
/// Calculator screen and every other screen can be reached and popped back
/// (phases.md §Phase 2, D-20). The helpers live in `test/support/pump_app.dart`
/// so the History tests share the same entry points.

void main() {
  testWidgets('launches to the Calculator screen as the root route', (
    tester,
  ) async {
    await pumpApp(tester);

    // The root screen is identified by its display area; the app title is not
    // painted on the calculator itself (desing.md §6.1).
    expect(find.byKey(const Key('calculator-display-line')), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('0'), findsWidgets);
  });

  testWidgets('the root route has no back arrow', (tester) async {
    await pumpApp(tester);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('calculator top bar exposes Settings and History', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.byIcon(Icons.history), findsOneWidget);
  });

  testWidgets('the gear button opens Settings, and back returns to Calculator', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calculator-display-line')), findsOneWidget);
  });

  testWidgets('the gear spins a full turn before Settings is pushed (D-118)', (
    tester,
  ) async {
    await pumpApp(tester);

    double gearAngle() {
      final transform = tester.widget<Transform>(
        find.byKey(const Key('settings-gear-spin')),
      );
      final m = transform.transform;
      // atan2 wraps into (-π, π], so a turn at or past the half reads as a
      // negative angle; unfolding it back keeps the value in [0, 2π) and
      // leaves the resting 0 untouched.
      final wrapped = math.atan2(m.storage[1], m.storage[0]);
      return wrapped < 0 ? wrapped + 2 * math.pi : wrapped;
    }

    await tester.tap(find.byIcon(Icons.settings));
    // One frame starts the controller; the revolution is under way and the
    // root screen is still the one on top — Settings waits for the turn.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const Key('calculator-display-line')), findsOneWidget);
    expect(find.text('Decimal Places'), findsNothing);
    expect(gearAngle(), greaterThan(0.1));
    expect(gearAngle(), lessThan(2 * math.pi - 0.1));

    // The turn lands, then the push runs.
    await tester.pumpAndSettle();
    expect(find.text('Decimal Places'), findsWidgets);

    // The spin is rewound under the pushed screen, so the gear is back at
    // rest when the user returns.
    await goBack(tester);
    expect(gearAngle(), closeTo(0, 0.001));
  });

  testWidgets('history clock opens History, and back returns to Calculator', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(find.text('No calculations yet'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calculator-display-line')), findsOneWidget);
  });

  testWidgets('Settings reaches About, Privacy, and Terms (D-20)', (
    tester,
  ) async {
    await pumpApp(tester);
    await openSettings(tester);

    // feature.md FEAT-SET-006 calls this the App Version row, and it still
    // opens the About screen.
    await tapSettingsRow(tester, 'App Version');
    expect(find.text('APP INFORMATION'), findsOneWidget);
    await goBack(tester);

    await tapSettingsRow(tester, 'Privacy Policy');
    expect(find.text('What this app does'), findsOneWidget);
    await goBack(tester);

    await tapSettingsRow(tester, 'Terms of Service');
    expect(find.text('Agreement'), findsOneWidget);
    await goBack(tester);

    // Back on Settings after a three-level round trip.
    expect(find.text('Decimal Places'), findsWidgets);

    // And one more pop returns to the root route.
    await goBack(tester);
    expect(find.byKey(const Key('calculator-display-line')), findsOneWidget);
  });

  testWidgets('About shows the version and the developer name (D-11, D-12)', (
    tester,
  ) async {
    await pumpApp(tester);
    await openSettings(tester);
    await tapSettingsRow(tester, 'App Version');

    expect(find.text('1.0.0'), findsWidgets);
    expect(find.text('Hasan Mahadi'), findsOneWidget);
  });

  testWidgets('every screen renders on the black app background (D-03)', (
    tester,
  ) async {
    await pumpApp(tester);

    Scaffold scaffoldOf() => tester.widget<Scaffold>(find.byType(Scaffold));

    for (final icon in [Icons.settings, Icons.history]) {
      await tester.tap(find.byIcon(icon));
      await tester.pumpAndSettle();
      expect(scaffoldOf().backgroundColor, AppColors.background);
      await goBack(tester);
    }
  });

  testWidgets('the component catalog is reachable in a debug build', (
    tester,
  ) async {
    // Registered behind `kDebugMode` (phases.md §Phase 3). It has no entry
    // point in the UI, so it is pushed directly to prove the route resolves.
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

    container.read(appRouterProvider).push(AppRoutes.catalog);
    await tester.pumpAndSettle();

    expect(find.text('Catalog'), findsOneWidget);
    expect(find.text('COLORS'), findsOneWidget);
  });
}
