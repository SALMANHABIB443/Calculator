import 'package:calculator/core/services/feedback_service.dart';
import 'package:calculator/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keypad_session.dart';
import '../support/pump_app.dart';

/// Records what the calculator asked for instead of playing it, so a test can
/// assert the flags without a device.
///
/// `FeedbackService` takes them as parameters precisely so this is possible
/// (**D-34**): a test overrides the provider, not the settings the controller
/// reads. Not `const` because it accumulates — each test builds its own.
class RecordingFeedbackService extends FeedbackService {
  RecordingFeedbackService();

  final List<({bool soundEnabled, bool vibrationEnabled})> presses =
      <({bool soundEnabled, bool vibrationEnabled})>[];

  @override
  Future<void> keyPress({
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) async {
    presses.add((soundEnabled: soundEnabled, vibrationEnabled: vibrationEnabled));
  }
}

/// What the Settings screen does to the rest of the app: **AC-004** (sound and
/// vibration take effect on key presses immediately), **AC-005** (the history
/// toggle stops new entries), and **D-14** (precision is formatting-only).
///
/// Each test drives the real Settings screen, so the whole path is covered —
/// toggle, persist, read back, act — rather than a provider in isolation.
void main() {
  /// Types [session] on the calculator, the way a user would.
  Future<void> typeSession(WidgetTester tester, String session) async {
    for (final key in keysFor(session)) {
      await tester.tap(find.byKey(ValueKey('key-${key.name}')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  String resultText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('calculator-result'))).data!;

  /// Opens Settings, flips [row], and returns to the calculator.
  Future<void> toggleFromSettings(
    WidgetTester tester,
    String row,
  ) async {
    await openSettings(tester);
    await toggleSettingsRow(tester, row);
    await goBack(tester);
  }

  /// Pumps the app with a fresh recorder, and returns it for assertions.
  Future<RecordingFeedbackService> pumpWithRecorder(
    WidgetTester tester, {
    AppSettings? settings,
  }) async {
    final recorder = RecordingFeedbackService();
    await pumpApp(
      tester,
      overrides: [feedbackServiceProvider.overrideWithValue(recorder)],
      settings: settings,
    );
    return recorder;
  }

  group('AC-004 — feedback follows the toggles immediately', () {
    testWidgets('both on by default, so presses ask for both', (tester) async {
      final recorder = await pumpWithRecorder(tester);

      await typeSession(tester, '2+2=');

      expect(recorder.presses, isNotEmpty);
      expect(recorder.presses.last.soundEnabled, isTrue);
      expect(recorder.presses.last.vibrationEnabled, isTrue);
    });

    testWidgets('Sound off stops the click on the very next press', (
      tester,
    ) async {
      final recorder = await pumpWithRecorder(tester);

      await toggleFromSettings(tester, 'Sound');
      final before = recorder.presses.length;
      await typeSession(tester, '7');

      expect(recorder.presses.length, greaterThan(before));
      expect(recorder.presses.last.soundEnabled, isFalse);
      // Vibration was left alone, so the press still asks for it.
      expect(recorder.presses.last.vibrationEnabled, isTrue);
    });

    testWidgets('Vibration off stops the haptic on the very next press', (
      tester,
    ) async {
      final recorder = await pumpWithRecorder(tester);

      await toggleFromSettings(tester, 'Vibration');
      final before = recorder.presses.length;
      await typeSession(tester, '7');

      expect(recorder.presses.length, greaterThan(before));
      expect(recorder.presses.last.vibrationEnabled, isFalse);
      expect(recorder.presses.last.soundEnabled, isTrue);
    });

    testWidgets('both off means neither is requested', (tester) async {
      final recorder = await pumpWithRecorder(tester);

      await toggleFromSettings(tester, 'Sound');
      await openSettings(tester);
      await toggleSettingsRow(tester, 'Vibration');
      await goBack(tester);
      await typeSession(tester, '7');

      expect(recorder.presses.last.soundEnabled, isFalse);
      expect(recorder.presses.last.vibrationEnabled, isFalse);
    });

    testWidgets('a stored preference is honoured on the first press of a run', (
      tester,
    ) async {
      final recorder = await pumpWithRecorder(
        tester,
        settings: AppSettings.defaults.copyWith(
          soundEnabled: false,
          vibrationEnabled: false,
        ),
      );

      await typeSession(tester, '1');

      expect(recorder.presses.single.soundEnabled, isFalse);
      expect(recorder.presses.single.vibrationEnabled, isFalse);
    });
  });

  group('AC-005 — the history toggle gates new entries', () {
    testWidgets('a calculation is recorded while history is on', (
      tester,
    ) async {
      await pumpApp(tester);

      await typeSession(tester, '2+2=');
      await openHistory(tester);

      expect(find.text('2 + 2'), findsOneWidget);
    });

    testWidgets('turning it off stops the next calculation being recorded', (
      tester,
    ) async {
      await pumpApp(tester);

      // One entry while the toggle is on, so the History screen is not merely
      // empty because nothing has been calculated.
      await typeSession(tester, '1+1=');
      await toggleFromSettings(tester, 'History');
      await typeSession(tester, '2+2=');

      await openHistory(tester);

      expect(find.text('1 + 1'), findsOneWidget);
      expect(find.text('2 + 2'), findsNothing);
    });

    testWidgets('turning it back on resumes recording', (tester) async {
      await pumpApp(tester);

      await toggleFromSettings(tester, 'History');
      await typeSession(tester, '2+2=');
      await openHistory(tester);
      expect(find.text('2 + 2'), findsNothing);
      await goBack(tester);

      await openSettings(tester);
      await toggleSettingsRow(tester, 'History');
      await goBack(tester);
      await typeSession(tester, '3+3=');
      await openHistory(tester);

      expect(find.text('3 + 3'), findsOneWidget);
    });

    testWidgets('off on a cold start blocks the very first calculation', (
      tester,
    ) async {
      await pumpApp(
        tester,
        settings: AppSettings.defaults.copyWith(historyEnabled: false),
      );

      await typeSession(tester, '2+2=');
      await openHistory(tester);

      expect(find.text('No calculations yet'), findsOneWidget);
    });

    testWidgets('existing history survives the toggle being turned off', (
      tester,
    ) async {
      await pumpApp(tester);

      await typeSession(tester, '1+1=');
      await toggleFromSettings(tester, 'History');
      await openHistory(tester);

      // FEAT-HIST-004: the toggle stops new entries, it does not delete old
      // ones. Only the explicit Clear path may do that.
      expect(find.text('1 + 1'), findsOneWidget);
    });
  });

  group('D-14 — precision is formatting-only', () {
    testWidgets('a result re-renders at the new precision without recomputing', (
      tester,
    ) async {
      await pumpApp(tester);

      // Left-to-right per D-17, so this is (1/3)*3 = 1 — a case that exposes
      // precision on the *result* rather than cancelling out.
      await typeSession(tester, '1÷7=');
      expect(resultText(tester), '0.14');

      await openSettings(tester);
      await chooseDecimalPlaces(tester, 5);
      await goBack(tester);

      // Same stored value, more places shown. The engine never heard about the
      // setting; only the formatter did.
      expect(resultText(tester), '0.14286');
    });

    testWidgets('the next calculation uses the new precision', (tester) async {
      await pumpApp(tester);

      await openSettings(tester);
      await chooseDecimalPlaces(tester, 4);
      await goBack(tester);

      await typeSession(tester, '1÷3=');

      expect(resultText(tester), '0.3333');
    });

    testWidgets('a computed accumulator re-renders at the new precision', (
      tester,
    ) async {
      await pumpApp(tester);

      // `1 ÷ 3` then `+`: the entry is done, so the result line is the computed
      // accumulator, rounded at the current precision.
      await typeSession(tester, '1÷3+');
      expect(resultText(tester), '0.33');

      await openSettings(tester);
      await chooseDecimalPlaces(tester, 6);
      await goBack(tester);

      // Same stored double, more places shown — the engine never recomputed.
      expect(resultText(tester), '0.333333');
    });

    testWidgets('an expression still being typed is left exactly as entered', (
      tester,
    ) async {
      await pumpApp(tester);

      // A typed entry is grouped but never rounded (D-30), so the setting has
      // no say over it at all.
      await typeSession(tester, '1.50');
      expect(resultText(tester), '1.50');

      await openSettings(tester);
      await chooseDecimalPlaces(tester, 0);
      await goBack(tester);

      // Zero decimal places would render "2" if the entry were rounded. It is
      // not, so the digits the user typed are still what is on screen.
      expect(resultText(tester), '1.50');

      // And the calculation still completes normally afterwards.
      await typeSession(tester, '+1=');
      expect(resultText(tester), '3');
    });

    testWidgets('the expression line is untouched by a precision change', (
      tester,
    ) async {
      await pumpApp(tester);

      await typeSession(tester, '1÷3+');
      final expression = find.text('1 ÷ 3 +');
      expect(expression, findsOneWidget);

      await openSettings(tester);
      await chooseDecimalPlaces(tester, 6);
      await goBack(tester);

      expect(expression, findsOneWidget);
    });

    testWidgets('rounding is applied but zeros are never padded (D-21)', (
      tester,
    ) async {
      await pumpApp(tester);

      await openSettings(tester);
      await chooseDecimalPlaces(tester, 6);
      await goBack(tester);

      await typeSession(tester, '2+2=');

      expect(resultText(tester), '4');
    });

    testWidgets('zero places gives whole-number results', (tester) async {
      await pumpApp(tester);

      await openSettings(tester);
      await chooseDecimalPlaces(tester, 0);
      await goBack(tester);

      await typeSession(tester, '10÷3=');

      expect(resultText(tester), '3');
    });
  });

  group('calculator state is untouched by the round trip', () {
    testWidgets('an unfinished calculation survives visiting Settings', (
      tester,
    ) async {
      await pumpApp(tester);

      await typeSession(tester, '1÷3+');
      expect(resultText(tester), '0.33');

      await openSettings(tester);
      await goBack(tester);

      expect(resultText(tester), '0.33');

      // The keypad still continues from where it left off: left-to-right per
      // D-17, so this is 1/3 + 2, not 1 / (3 + 2).
      await typeSession(tester, '2=');
      expect(resultText(tester), '2.33');
    });

    testWidgets('a half-typed entry survives visiting Settings', (
      tester,
    ) async {
      await pumpApp(tester);

      await typeSession(tester, '12');
      expect(resultText(tester), '12');

      await openSettings(tester);
      await goBack(tester);

      expect(resultText(tester), '12');
      await typeSession(tester, '+1=');
      expect(resultText(tester), '13');
    });
  });
}
