import 'package:calculator/core/widgets/core_widgets.dart';
import 'package:calculator/features/settings/presentation/settings_controller.dart';
import 'package:calculator/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keypad_session.dart';
import '../support/pump_app.dart';

/// Presses the keys of [session] in order, settling so the display and the
/// unawaited history write both flush before the next assertion.
///
/// [session] is written the way a user would key it, so [keysFor] maps the
/// glyphs to enum values and this file never has to know the key naming.
Future<void> tapKeys(WidgetTester tester, String session) async {
  for (final key in keysFor(session)) {
    await tester.tap(find.byKey(ValueKey('key-${key.name}')));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// The primary display line as rendered.
String resultText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('calculator-display-line'))).data!;

void main() {
  testWidgets('a completed calculation shows up in History (AC-002)', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapKeys(tester, '2+2=');

    await openHistory(tester);

    expect(find.text('2 + 2'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('repeating the pending operator with = is recorded (D-36)', (
    tester,
  ) async {
    await pumpApp(tester);
    // Without D-36 the engine returns the value already on screen and the
    // result would never be recorded, so the card is the only proof.
    await tapKeys(tester, '2+=');

    await openHistory(tester);

    expect(find.byType(HistoryCard), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('pressing = twice records one card, not two', (tester) async {
    await pumpApp(tester);
    // The second `=` re-runs `_equals` and the flag is still set, so the press
    // used to look like a freshly completed calculation and write a duplicate
    // of a result that never changed.
    await tapKeys(tester, '2+2==');

    await openHistory(tester);

    expect(find.byType(HistoryCard), findsOneWidget);
  });

  testWidgets('a failed calculation is not recorded', (tester) async {
    await pumpApp(tester);
    // Division by zero sets the error state, which clears justEvaluated.
    await tapKeys(tester, '5÷0=');

    await openHistory(tester);

    expect(find.text('No calculations yet'), findsOneWidget);
  });

  testWidgets('tapping a card loads the result and returns to Calculator (AC-003)', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapKeys(tester, '5×5=');
    await openHistory(tester);

    await tester.tap(find.text('5 × 5'));
    await tester.pumpAndSettle();

    expect(find.text('History'), findsNothing);
    expect(resultText(tester), '25');
  });

  testWidgets('a loaded result is a fresh value the next key can use (D-37)', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapKeys(tester, '5×5=');
    await openHistory(tester);
    await tester.tap(find.text('5 × 5'));
    await tester.pumpAndSettle();

    // The key proof: the loaded 25 is an input, not a finished display. If
    // loading left the calculator showing a result, `× 2` would do nothing.
    await tapKeys(tester, '×2=');

    expect(resultText(tester), '50');
  });

  testWidgets('loading a result does not record a second copy of it', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapKeys(tester, '5×5=');
    await openHistory(tester);
    await tester.tap(find.text('5 × 5'));
    await tester.pumpAndSettle();

    await openHistory(tester);

    expect(find.byType(HistoryCard), findsOneWidget);
  });

  testWidgets('history survives a restart (AC-001)', (tester) async {
    await pumpApp(tester);
    await tapKeys(tester, '7×6=');

    // A second app instance over the same store stands in for a cold start.
    await pumpApp(tester);
    await openHistory(tester);

    expect(find.text('7 × 6'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('nothing is recorded while the history toggle is off (AC-005)', (
    tester,
  ) async {
    await pumpApp(
      tester,
      overrides: [
        settingsProvider.overrideWithValue(
          AppSettings.defaults.copyWith(historyEnabled: false),
        ),
      ],
    );
    await tapKeys(tester, '2+2=');

    await openHistory(tester);

    expect(find.text('No calculations yet'), findsOneWidget);
  });

  group('clearing requires confirmation (AC-008, D-05)', () {
    testWidgets('cancelling keeps every entry', (tester) async {
      await pumpApp(tester);
      await tapKeys(tester, '2+2=');
      await tapKeys(tester, '3+3=');
      await openHistory(tester);
      expect(find.byType(HistoryCard), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('history-clear-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryCard), findsNWidgets(2));
    });

    testWidgets('confirming empties the history', (tester) async {
      await pumpApp(tester);
      await tapKeys(tester, '2+2=');
      await openHistory(tester);

      await tester.tap(find.byKey(const Key('history-clear-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Clear'));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryCard), findsNothing);
      expect(find.text('No calculations yet'), findsOneWidget);
    });

    testWidgets('the header trash clears too, and warns first', (tester) async {
      await pumpApp(tester);
      await tapKeys(tester, '2+2=');
      await openHistory(tester);

      await tester.tap(find.byTooltip('Clear History'));
      await tester.pumpAndSettle();

      // D-05: one dialog for both entry points, and nothing deleted yet.
      expect(find.text('Clear history?'), findsOneWidget);
      expect(find.byType(HistoryCard), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Clear'));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryCard), findsNothing);
    });
  });

  testWidgets('the calculator shows the loaded result', (tester) async {
    await pumpApp(tester);
    await tapKeys(tester, '8+8=');
    await openHistory(tester);
    await tester.tap(find.text('8 + 8'));
    await tester.pumpAndSettle();

    expect(resultText(tester), '16');
  });
}
