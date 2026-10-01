import 'dart:async';

import 'package:calculator/app.dart';
import 'package:calculator/core/storage/preferences_provider.dart';
import 'package:calculator/core/widgets/core_widgets.dart';
import 'package:calculator/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/pump_app.dart';

/// AC-006 and `prd.md` §11 — what survives a cold start.
///
/// Phase 8's task list called for "app lifecycle (restore state on cold start)".
/// There is no lifecycle observer in the app and **D-55** records why one would
/// be wrong: every persisted read is a provider's `build()`, so it happens
/// exactly once per `ProviderScope` — which *is* the cold start. The only
/// honest way to close the task is therefore to prove the restore rather than
/// to add a listener that would have nothing to listen for.
///
/// A genuine restart needs three things this file is careful about:
///
/// - A **new** `ProviderScope`, because providers are the app's memory. A second
///   `pumpApp` over the same scope would re-read nothing and prove nothing.
/// - The store **re-seeded** from a snapshot. `setMockInitialValues` nulls the
///   plugin's cached completer, so without it both scopes would share one
///   in-memory `SharedPreferences` and the second would be reading the first's
///   live object rather than the bytes on disk.
/// - The old scope **disposed**, so nothing from run one can answer a read in
///   run two.

void main() {
  /// Tears the app down the way a force-quit would, then brings it back up
  /// against the same store.
  ///
  /// The `pumpWidget(SizedBox.shrink())` is what actually detaches the old
  /// `ProviderScope`; without it the router, the notifiers, and the
  /// `SharedPreferences` handle from run one would still be alive.
  Future<void> restart(
    WidgetTester tester, {
    required Map<String, Object> store,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    seedStore(store);
    await tester.pumpWidget(
      const ProviderScope(child: CalculatorApp()),
    );
    await tester.pumpAndSettle();
  }

  group('AC-006 — settings and history survive a relaunch', () {
    testWidgets('a precision chosen in run one is in force in run two', (
      tester,
    ) async {
      await pumpApp(tester);

      // Flip two of the five preferences and set a third, so the restore is
      // demonstrably per-key rather than "some settings came back".
      await openSettings(tester);
      await toggleSettingsRow(tester, 'Sound');
      await toggleSettingsRow(tester, 'History');
      await chooseDecimalPlaces(tester, 4);

      expect(currentSettings(tester).decimalPlaces, 4);
      expect(currentSettings(tester).soundEnabled, isFalse);
      expect(currentSettings(tester).historyEnabled, isFalse);

      final store = await snapshotStore();
      await restart(tester, store: store);

      // Read the synchronous view production reads, not a rendered string.
      expect(currentSettings(tester).decimalPlaces, 4);
      expect(currentSettings(tester).soundEnabled, isFalse);
      expect(currentSettings(tester).historyEnabled, isFalse);
      // The two that were not touched are still at their defaults — the run
      // restored the store rather than inventing a blob of settings.
      expect(
        currentSettings(tester).vibrationEnabled,
        AppSettings.defaults.vibrationEnabled,
      );
    });

    testWidgets('the precision is still the one the row advertises', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);
      await chooseDecimalPlaces(tester, 6);

      await restart(tester, store: await snapshotStore());
      await openSettings(tester);

      // Proves the restore reached the UI, not just the provider.
      expect(find.text('6 decimal places'), findsWidgets);
      expect(switchPosition(tester, 'Sound'), isTrue);
    });

    testWidgets('a recorded calculation is still in the list afterwards', (
      tester,
    ) async {
      await pumpApp(tester);

      // A real calculation through the keypad, so the entry is written by the
      // same path a user would exercise rather than seeded directly.
      for (final key in ['1', '2', '5', '×', '8', '=']) {
        await tester.tap(find.byKey(ValueKey('key-${_keyName(key)}')));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      await openHistory(tester);
      expect(historyExpressions(tester), isNotEmpty);

      await restart(tester, store: await snapshotStore());
      await openHistory(tester);

      expect(historyExpressions(tester), ['125 × 8']);
      expect(find.text('1,000'), findsOneWidget);
    });
  });

  group('prd.md §11 — the calculator itself opens cleared', () {
    testWidgets('a half-typed expression does not survive the relaunch', (
      tester,
    ) async {
      await pumpApp(tester);

      for (final key in ['9', '+', '4']) {
        await tester.tap(find.byKey(ValueKey('key-${_keyName(key)}')));
        await tester.pump();
      }
      expect(find.text('9 +'), findsOneWidget);

      await restart(tester, store: await snapshotStore());

      // The in-flight expression is deliberately not persisted, so the display
      // comes back at the initial value rather than the interrupted one.
      expect(find.text('9 +'), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('calculator-result'))).data,
        '0',
      );
    });

    testWidgets('the app opens on the root route, not where it was left', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);
      expect(find.text('Settings'), findsWidgets);

      await restart(tester, store: await snapshotStore());

      expect(find.byKey(const Key('calculator-result')), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
    });
  });

  group('D-55 — no lifecycle observer is needed', () {
    testWidgets('a toggle flipped before the store answers is not snapped back', (
      tester,
    ) async {
      // The cold-start race D-43 exists for. On a real launch the store answers
      // after the first frame, and a user can reach Settings and flip a switch
      // before it does. The value on disk is older than the choice the user
      // just made, so the write has to win or the switch springs back — which
      // is exactly the kind of bug only a genuine async load can produce, and
      // therefore the one thing a lifecycle observer would not have fixed.
      final gate = Completer<SharedPreferences>();
      mockEmptyHistory();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [preferencesProvider.overrideWith((ref) => gate.future)],
          child: const CalculatorApp(),
        ),
      );
      // One frame only: the load is still in flight, so the app is showing the
      // defaults and the settings screen is reachable.
      await tester.pump();

      await openSettings(tester);
      await tester.tap(find.widgetWithText(ToggleRow, 'Sound'));
      await tester.pump();

      expect(
        currentSettings(tester).soundEnabled,
        isFalse,
        reason: 'the toggle moves on the frame it is touched (AC-004)',
      );

      // The store finally answers, and it says Sound is ON — the value it held
      // before the user touched the switch.
      SharedPreferences.setMockInitialValues(
        settingsStoreValues(AppSettings.defaults),
      );
      gate.complete(await SharedPreferences.getInstance());
      await tester.pumpAndSettle();

      expect(
        currentSettings(tester).soundEnabled,
        isFalse,
        reason: 'D-43: a write made during the initial load wins',
      );
      expect(
        switchPosition(tester, 'Sound'),
        isFalse,
        reason: 'and the switch itself did not spring back',
      );
    });
  });
}

/// The `CalculatorKey` enum name behind a keypad glyph the user types.
String _keyName(String glyph) => switch (glyph) {
  '×' => 'multiply',
  '÷' => 'divide',
  '−' => 'subtract',
  '+' => 'add',
  '=' => 'equals',
  _ => 'digit$glyph',
};
