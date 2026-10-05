import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/feedback_service.dart';
import '../../history/presentation/history_controller.dart';
// Imports the feature's public surface rather than a path into its internals
// (D-57), so the settings providers can move again without touching this file.
import '../../settings/settings.dart';
import '../domain/calculator_engine.dart';
import 'display_resolver.dart';

/// The calculator's single source of truth for the UI
/// (struction.md §16: *UI Button Press → Controller → engine*).
///
/// The [CalculatorEngine] is held as a field rather than rebuilt from
/// [build], so the engine's internal bookkeeping — notably whether the last
/// `=` has just been evaluated, which decides if the next digit starts a fresh
/// calculation — survives for the lifetime of the provider.
final calculatorControllerProvider =
    NotifierProvider<CalculatorController, CalculatorState>(
      CalculatorController.new,
    );

class CalculatorController extends Notifier<CalculatorState> {
  final CalculatorEngine _engine = CalculatorEngine();

  @override
  CalculatorState build() => _engine.state;

  /// Handles a keypad press: delegates to the engine, fires the feedback the
  /// Settings toggles ask for (D-16), and records the result in history when the
  /// press completed a calculation.
  ///
  /// None of the side effects are awaited, so a slow or missing platform channel
  /// — sound, vibration, or a disk write — can never delay the display. The user
  /// sees their result immediately and history catches up.
  ///
  /// A press the engine declined — an operator with nothing to act on (D-80), a
  /// second decimal point, a digit past the 15-digit cap — leaves the state
  /// untouched, and [CalculatorState] compares by value, so the press is
  /// recognised here and returns without feedback or a history write. A key that
  /// did nothing must not look or sound like one that did.
  void press(CalculatorKey key) {
    final previous = state;
    final next = _engine.apply(key);
    if (next == previous) return;
    state = next;

    final settings = ref.read(settingsProvider);
    unawaited(
      ref
          .read(feedbackServiceProvider)
          .keyPress(
            soundEnabled: settings.soundEnabled,
            vibrationEnabled: settings.vibrationEnabled,
          ),
    );

    if (_justCompletedACalculation(state)) _record(state, settings.decimalPlaces);
  }

  /// AC, for callers outside the keypad.
  void clear() {
    _engine.reset();
    state = _engine.state;
  }

  /// One digit back, for the backspace control above the rule (**D-81**).
  ///
  /// [press] without the key: the same "no change means nothing happened"
  /// contract, so a press with nothing left to delete costs no sound and no
  /// vibration, and the same settings decide what that sound is.
  ///
  /// What it takes back, in the order the states are reachable: the last
  /// character of the entry being typed, then the operator the user changed
  /// their mind about, then the **last committed number** — reopened as a typed
  /// entry so a calculation stays editable after `=` — then a `±` sign staged
  /// for a number not yet typed, and finally a result with no expression behind
  /// it (`1234` → `123` → `12`, for a value loaded from history). The engine
  /// decides which applies; this method only decides whether the press
  /// *counted*.
  ///
  /// Nothing is ever recorded here. A backspace is an edit of what the user is
  /// in the middle of, not a calculation — and [CalculatorState.justEvaluated]
  /// is cleared by every key the backspace can act on, including the one that
  /// reopens a committed term, so there is nothing to record even if the press
  /// follows a completed one.
  void backspace() {
    final previous = state;
    final next = _engine.backspace();
    if (next == previous) return;
    state = next;

    final settings = ref.read(settingsProvider);
    unawaited(
      ref
          .read(feedbackServiceProvider)
          .keyPress(
            soundEnabled: settings.soundEnabled,
            vibrationEnabled: settings.vibrationEnabled,
          ),
    );
  }

  /// Puts a stored result on screen, replacing whatever was there (D-37,
  /// feature.md FEAT-HIST-002).
  ///
  /// Called when the user taps a history card. The engine treats the value as a
  /// freshly evaluated result, so the primary line shows just the number and the
  /// next operator continues from it as `1,000 +`.
  void loadResult(double value) {
    _engine.loadValue(value);
    state = _engine.state;
  }

  /// Whether [state] is a calculation the user just finished.
  ///
  /// [CalculatorState.justEvaluated] (D-35) is the engine's own signal and is
  /// the real test; the other three conditions are the guard rails that keep a
  /// broken or non-finite result out of the history no matter what. The engine
  /// already clears the flag on `%`, `±`, and an error, so `2 + 2 = %` cannot
  /// save a second entry for the same calculation.
  static bool _justCompletedACalculation(CalculatorState state) =>
      state.justEvaluated &&
      !state.isError &&
      state.expression.isNotEmpty &&
      state.value != null;

  /// Saves the completed calculation (AC-002).
  ///
  /// The two strings come from [resolveDisplay], the same function the display
  /// itself uses, so a card can never disagree with what the user was looking at
  /// — the expression is grouped the same way and the result carries the same
  /// `decimalPlaces` rounding. The raw [CalculatorState.value] goes in as
  /// `resultValue` so the entry can be loaded back without re-parsing.
  ///
  /// The repository decides whether the history toggle permits this (AC-005), and
  /// an entry with an empty expression is skipped: a bare `=` on a fresh
  /// calculator produces a value with nothing behind it, and a card reading
  /// `''` → `0` is noise rather than history.
  void _record(CalculatorState state, int decimalPlaces) {
    final value = state.value;
    if (value == null) return;

    final display = resolveDisplay(state, decimalPlaces: decimalPlaces);
    if (display.expression.isEmpty) return;

    unawaited(
      ref
          .read(historyControllerProvider.notifier)
          .record(
            expression: display.expression,
            result: display.result,
            resultValue: value,
          ),
    );
  }
}