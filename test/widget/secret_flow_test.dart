import 'package:calculator/app.dart';
import 'package:calculator/core/design/app_colors.dart';
import 'package:calculator/core/design/app_palette.dart';
import 'package:calculator/core/design/app_spacing.dart';
import 'package:calculator/core/widgets/core_widgets.dart';
import 'package:calculator/features/calculator/presentation/calculator_screen.dart';
import 'package:calculator/features/history/domain/history_entry.dart';
import 'package:calculator/features/secret/data/shared_preferences_secret_repository.dart';
import 'package:calculator/features/secret/domain/secret_code.dart';
import 'package:calculator/features/secret/presentation/change_pin_screen.dart';
import 'package:calculator/features/secret/presentation/secret_controller.dart';
import 'package:calculator/features/secret/presentation/secret_lockout_controller.dart';
import 'package:calculator/features/secret/presentation/secret_menu.dart';
import 'package:calculator/features/secret/presentation/secret_screens.dart';
import 'package:calculator/features/secret/presentation/secret_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/pump_app.dart';

/// The whole Secret Mode flow, driven through the real app (D-82 — D-85,
/// AC-017 — AC-021).
///
/// Two things about these tests are unusual, and both are forced by the design:
///
/// * **The five-second hold has no widget to find** (D-82). The hold gives no
///   feedback of any kind, so a test cannot look for a progress ring and wait
///   for it — it has to *pump the gesture* for the shipped duration. Every
///   other interaction in this suite is driven by a finder.
/// * **The unlock screen is entered only by the hold.** There is no link to it,
///   so the first step of each test is the gesture itself rather than a
///   shortcut — which keeps the gesture under test instead of bypassed by one.
void main() {
  /// One seeded entry, so the bottom Clear History button renders at all — D-38
  /// hides it when there is nothing to clear.
  List<HistoryEntry> seeded() => <HistoryEntry>[
    seededEntry(
      expression: '2 + 2',
      result: '4',
      resultValue: 4,
      timestamp: DateTime(2026, 10, 3, 9),
    ),
  ];

  /// Opens History and holds its bottom action for [hold].
  ///
  /// The pointer goes down, [hold] passes, then it comes back up — the real
  /// gesture. The tree is settled *before* the release, because the timer fires
  /// inside `pump` and the route push it triggers needs a frame of its own to
  /// mount; releasing first would interleave the push with the button's own tap
  /// handling.
  Future<void> holdClearHistory(WidgetTester tester, Duration hold) async {
    await openHistory(tester);
    final button = find.byKey(const Key('history-clear-button'));
    expect(button, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(hold);
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  /// The full hold, at the shipped duration.
  Future<void> holdForShippedDuration(WidgetTester tester) =>
      holdClearHistory(tester, secretHoldDuration);

  /// Taps the digits of [code] on the PIN keypad, settling between them.
  Future<void> typeCode(WidgetTester tester, String code) async {
    for (final digit in code.split('')) {
      await tester.tap(
        find.widgetWithText(CalculatorButton, digit),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
    }
  }

  /// How many dots are currently filled.
  ///
  /// Counted from the painted [Container]s rather than from the entered digits:
  /// the digits are the thing under test not to be visible, so a helper reading
  /// them would assume the answer it is meant to be checking.
  int filledDots(WidgetTester tester) => tester
      .widgetList<Container>(
        find.descendant(
          of: find.byKey(const Key('secret-pin-dots')),
          matching: find.byType(Container),
        ),
      )
      .where(
        (dot) => (dot.decoration! as BoxDecoration).color != Colors.transparent,
      )
      .length;

  /// The outline colour of each PIN dot, in order.
  ///
  /// Read off the painted `Container`s for the same reason [filledDots] reads
  /// those: the dot's colour is the thing under test, so a helper that inferred it
  /// from the state that produced it would be asserting the implementation back at
  /// itself.
  List<Color> dotBorders(WidgetTester tester) => tester
      .widgetList<Container>(
        find.descendant(
          of: find.byKey(const Key('secret-pin-dots')),
          matching: find.byType(Container),
        ),
      )
      .map((dot) => (dot.decoration! as BoxDecoration).border)
      .whereType<Border>()
      // `Border.top`, not `BorderSide.colors` — the dots paint a single
      // `Border.all`, so the outline is one colour per side and the assertion
      // wants that colour, not the list `Border.all` would hand back.
      .map((border) => border.top.color)
      .toList();

  /// The code the app actually has on disk, read through the real repository.
  ///
  /// Not read from a provider: the claim under test is that the *store* changed,
  /// and a provider would only report what the running app already believes.
  Future<SecretCode> storedPin() async {
    final preferences = await SharedPreferences.getInstance();
    return SharedPreferencesSecretRepository(preferences).load();
  }

  /// The one "this is wrong" colour, read from the dark palette the tests run in.
  ///
  /// Resolved through the palette rather than hard-coded so a future retune of
  /// [AppColors.danger] does not turn these four assertions into failures about a
  /// colour they were never pinning.
  final Color danger = AppPalette.dark.danger;

  /// Whether any digit key on the pad currently accepts a tap (D-88).
  ///
  /// Read from a digit key's `onPressed` rather than from the lockout provider,
  /// for the same reason [filledDots] reads the painted dots: "is the pad live"
  /// is the claim under test, so deriving it from the controller that decided it
  /// would assert the implementation back at itself. The screen hands a **null**
  /// callback when locked, and a null is the shared [CalculatorButton]'s own
  /// existing signal for "disabled", so this is the real thing being checked.
  bool keypadEnabled(WidgetTester tester) =>
      tester
          .widget<CalculatorButton>(find.widgetWithText(CalculatorButton, '5'))
          .onPressed !=
      null;

  /// The instant [secretClockProvider] reports while a test runs.
  ///
  /// Movable rather than real, because the lockout's remaining time is read from
  /// a wall clock and `tester.pump` advances timers but not the clock. Reset by
  /// [pumpSecretApp], so no test inherits another's time.
  DateTime clockNow = DateTime(2026, 10, 5, 12);

  /// Opens the app with the lockout reading [clockNow] instead of the real one.
  Future<void> pumpSecretApp(
    WidgetTester tester, {
    SecretCode? secretPin,
  }) async {
    clockNow = DateTime(2026, 10, 5, 12);
    await pumpApp(
      tester,
      history: seeded(),
      secretPin: secretPin ?? SecretCode('1234'),
      overrides: <Override>[
        secretClockProvider.overrideWithValue(() => clockNow),
      ],
    );
  }

  /// Moves the injected clock **and** the timer queue forward by [seconds].
  ///
  /// Both, deliberately: the deadline is compared against [clockNow] and the
  /// repaint is scheduled by the ticker, so advancing only one of the two leaves
  /// a state the app can never actually be in — a clock that has moved with no
  /// tick yet, or a tick with no time passed.
  Future<void> elapse(WidgetTester tester, int seconds) async {
    clockNow = clockNow.add(Duration(seconds: seconds));
    await tester.pump(Duration(seconds: seconds));
  }

  /// Whether the `⌫` key currently accepts a tap (D-88).
  ///
  /// Found through the **glyph** and walked up to its `InkWell`, rather than by
  /// taking the last `InkWell` on the screen: the digit keys are
  /// `CalculatorButton`s, which build `InkWell`s of their own, so "the last one"
  /// is whichever key happened to be built last and says nothing about the
  /// backspace.
  bool backspaceEnabled(WidgetTester tester) =>
      tester
          .widget<InkWell>(
            find
                .ancestor(
                  of: find.byType(AppBackspaceIcon),
                  matching: find.byType(InkWell),
                )
                .first,
          )
          .onTap !=
      null;

  /// The lockout controller's state as the running app holds it (D-88).
  ///
  /// Read through the widget tree's own [ProviderScope] rather than through a
  /// freshly-built container, so what is asserted is the state the **screen** is
  /// working from — the thing a second container would only be a guess at.
  ///
  /// Anchored to the **secret screen or the unlock screen**, whichever is on top.
  /// One of the assertions using this runs *after* a correct code has navigated
  /// away from the prompt — and "the counter was cleared" is exactly the claim
  /// being checked there, so anchoring on the unlock screen alone would fail to
  /// find it having already navigated, and report a missing element for a counter
  /// that had in fact reset correctly.
  SecretLockoutState lockoutState(WidgetTester tester) {
    final unlocked = find.byType(SecretScreen);
    final context = tester.element(
      unlocked.evaluate().isNotEmpty
          ? unlocked.first
          : find.byType(SecretUnlockScreen),
    );
    return ProviderScope.containerOf(
      context,
      listen: false,
    ).read(secretLockoutProvider);
  }

  group('the hidden gesture (FEAT-SEC-001, AC-017)', () {
    testWidgets('a five-second hold opens the PIN screen', (tester) async {
      await pumpApp(tester, history: seeded());
      await holdForShippedDuration(tester);

      expect(find.byType(SecretUnlockScreen), findsOneWidget);
    });

    testWidgets('releasing early does nothing at all', (tester) async {
      await pumpApp(tester, history: seeded());

      // One second short of the threshold: the case AC-017 names. A four-second
      // press is a long press to the user, and the feature says it produces no
      // dialog either — which is not what a plain release would do.
      await holdClearHistory(
        tester,
        secretHoldDuration - const Duration(seconds: 1),
      );

      expect(find.byType(SecretUnlockScreen), findsNothing);
      expect(find.byKey(const Key('history-list')), findsOneWidget);
      expect(find.text('Clear history?'), findsNothing);
    });

    testWidgets('two short holds do not add up to five seconds', (
      tester,
    ) async {
      await pumpApp(tester, history: seeded());
      await openHistory(tester);
      final button = find.byKey(const Key('history-clear-button'));

      // Each falls short, and the timer restarts rather than accumulating —
      // otherwise a user fidgeting on the button would open the secret screen.
      for (var i = 0; i < 2; i++) {
        final gesture = await tester.startGesture(tester.getCenter(button));
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        await gesture.up();
        await tester.pumpAndSettle();
      }

      expect(find.byType(SecretUnlockScreen), findsNothing);
    });

    testWidgets('a tap still opens the Clear History confirmation', (
      tester,
    ) async {
      await pumpApp(tester, history: seeded());
      await openHistory(tester);

      await tester.tap(find.byKey(const Key('history-clear-button')));
      await tester.pumpAndSettle();

      // D-05, unchanged: the gesture is additive, and the tap path is the one
      // the users who will never find the secret rely on.
      expect(find.text('Clear history?'), findsOneWidget);
      expect(find.byType(SecretUnlockScreen), findsNothing);
    });

    testWidgets('the hold is invisible (D-82)', (tester) async {
      await pumpApp(tester, history: seeded());
      await openHistory(tester);
      final button = find.byKey(const Key('history-clear-button'));

      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(seconds: 2));

      // Nothing was added, nothing changed. A ring, a spinner, or a colour
      // change would let the gesture be found by resting a thumb on the
      // button, which is the one thing a hidden feature must not allow.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        tester.takeException(),
        isNull,
        reason: 'holding must not disturb the button',
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('the unlock screen (FEAT-SEC-002, AC-018, AC-019)', () {
    testWidgets(
      'shows four dots and still names neither the feature nor the code',
      (tester) async {
        await pumpApp(tester, history: seeded());
        await holdForShippedDuration(tester);

        // **Revised by D-86.** This used to assert *no text of any kind*, which was
        // §6.8's rule and D-84's protection: a screen that names itself confirms it
        // is real. D-86 keeps the half of that rule that matters — the screen never
        // names the feature and never names the code — and drops the blanket ban,
        // because a user who reaches this screen with no idea what the dots are for
        // gets nothing from the privacy.
        expect(find.textContaining('Secret'), findsNothing);

        // The code itself, in any wording. This is the assertion the old test was
        // really making, and the only one that must never be relaxed: a prompt
        // reading "Enter your PIN" is fine, one reading "Default 0000" is the
        // feature over.
        expect(find.textContaining('0000'), findsNothing);
        expect(find.textContaining('default'), findsNothing);

        // Guidance is allowed, and is required — this is the complaint D-86
        // answers.
        expect(find.text('Enter your PIN'), findsOneWidget);
        expect(filledDots(tester), 0);
        expect(
          tester.takeException(),
          isNull,
          reason: 'the unlock screen must render without error',
        );
      },
    );

    testWidgets('has no "Forgot PIN?" link (D-88)', (tester) async {
      await pumpApp(tester, history: seeded());
      await holdForShippedDuration(tester);

      // **Removed in D-88.** The link was the only in-app route out of a
      // forgotten PIN from this screen, and with the lockout in place it is also
      // an unlimited bypass of it — one tap, no waiting, three fresh attempts.
      // The reset still exists on the Secret Settings page, where reaching it
      // means being past the lockout and the code anyway.
      expect(find.textContaining('Forgot'), findsNothing);
      expect(find.byKey(const Key('secret-forgot-pin')), findsNothing);
    });

    testWidgets('never displays the entered digits as characters', (
      tester,
    ) async {
      await pumpSecretApp(tester);
      await holdForShippedDuration(tester);
      await typeCode(tester, '12');

      // Not as asterisks, not at all — only the dots fill.
      expect(find.text('*'), findsNothing);
      expect(filledDots(tester), 2);
    });

    testWidgets('backspace removes the last digit and checks nothing', (
      tester,
    ) async {
      await pumpSecretApp(tester);
      await holdForShippedDuration(tester);
      await typeCode(tester, '129');
      await tester.tap(find.byType(AppBackspaceIcon));
      await tester.pumpAndSettle();

      expect(filledDots(tester), 2);
      expect(find.byType(SecretUnlockScreen), findsOneWidget);
    });

    testWidgets('the default 0000 opens the secret screen (AC-018)', (
      tester,
    ) async {
      await pumpApp(tester, history: seeded());
      await holdForShippedDuration(tester);
      await typeCode(tester, '0000');
      await tester.pumpAndSettle();

      expect(find.byType(SecretScreen), findsOneWidget);
      // The prompt is *replaced*, not stacked on: a PIN screen underneath would
      // put a back gesture that returns to it in front of the user.
      expect(find.byType(SecretUnlockScreen), findsNothing);
    });

    testWidgets('a wrong code clears the dots and permits an immediate retry', (
      tester,
    ) async {
      await pumpSecretApp(tester);
      await holdForShippedDuration(tester);

      await typeCode(tester, '9999');
      await tester.pumpAndSettle();

      // Still cleared, still on this screen, still retryable straight away.
      // **Revised by D-88**, which added the message and the red indicator this
      // test previously forbade: a silent rejection cannot support a lockout,
      // because a screen that stops accepting input without saying why is
      // indistinguishable from a broken one.
      expect(filledDots(tester), 0);
      expect(find.byType(SecretUnlockScreen), findsOneWidget);
      expect(find.text('Wrong PIN'), findsOneWidget);

      // Immediately, with nothing having run in between.
      await typeCode(tester, '1234');
      await tester.pumpAndSettle();
      expect(find.byType(SecretScreen), findsOneWidget);
    });

    testWidgets(
      'the indicator and the message turn red on a wrong code (D-88)',
      (tester) async {
        await pumpSecretApp(tester);
        await holdForShippedDuration(tester);

        // Nothing is red before the first attempt — the error describes a *judged*
        // code, so a screen the user has not yet answered is not in an error state.
        expect(find.text('Wrong PIN'), findsNothing);
        expect(dotBorders(tester).toSet(), isNot(contains(danger)));

        await typeCode(tester, '9999');
        await tester.pumpAndSettle();

        // Every outline red, not just the filled ones — the entry clears on the
        // same frame, so a fill-only treatment would have nothing left to paint.
        expect(dotBorders(tester), everyElement(danger));
        expect(
          tester
              .widget<Text>(find.byKey(const Key('secret-pin-status')))
              .style
              ?.color,
          danger,
        );

        // And the page itself does not turn: only the PIN and the message do.
        expect(
          tester
              .widget<Scaffold>(
                find.descendant(
                  of: find.byType(SecretUnlockScreen),
                  matching: find.byType(Scaffold),
                ),
              )
              .backgroundColor,
          AppColors.background,
        );
      },
    );

    testWidgets('typing again clears the error before the code is complete', (
      tester,
    ) async {
      await pumpSecretApp(tester);
      await holdForShippedDuration(tester);
      await typeCode(tester, '9999');
      await tester.pumpAndSettle();
      expect(find.text('Wrong PIN'), findsOneWidget);

      // One digit, not four: the message describes the code that was rejected
      // and is stale the moment a new one is started. Leaving it up for four
      // more taps would mean the screen accused the user mid-retry.
      await typeCode(tester, '1');
      await tester.pumpAndSettle();

      expect(find.text('Wrong PIN'), findsNothing);
      expect(dotBorders(tester).toSet(), isNot(contains(danger)));
      expect(filledDots(tester), 1);
    });

    testWidgets('a rejected code shakes the dots', (tester) async {
      await pumpSecretApp(tester);
      await holdForShippedDuration(tester);
      await typeCode(tester, '9999');
      await tester.pumpAndSettle();

      // The indicator is driven by an animation, and that is what AC-019's
      // "shakes" is implemented as. Asserted on the mechanism rather than on a
      // sampled offset: a transform's exact value at any frame is not a fact a
      // test should pin, but "there is an animation on the dots" is.
      // Material builds `AnimatedBuilder`s of its own, so the finder is scoped
      // to the dots' own ancestor rather than searching the whole tree.
      // The shake is an `AnimationController` driving a `Transform.translate`
      // over the dot row. Asserted on the structure rather than on a sampled
      // offset: a transform's exact value at any frame is not a fact a test
      // should pin, but that an animation is driving the indicator is exactly
      // what AC-019 asks for.
      final shakers = find.ancestor(
        of: find.byKey(const Key('secret-pin-dots')),
        matching: find.byType(AnimatedBuilder),
      );
      expect(shakers, findsWidgets);
      // The `Transform` is what the AnimatedBuilder's child is painted through,
      // so its presence proves this is the shake and not an incidental
      // framework animation Material happened to build nearby.
      expect(
        find.descendant(of: shakers.first, matching: find.byType(Transform)),
        findsOneWidget,
      );
    });

    // ===========================================================================
    // The 3-strike lockout (D-88). This group *reverses* the single test that
    // stood here before it, which asserted that wrong codes never lock out — a
    // direct statement of D-85. D-88 supersedes it: 10^4 unguarded guesses were
    // free, and three attempts against a 30-second wall costs an owner who
    // mistypes their own code half a minute.
    // ===========================================================================

    group('the 30-second lockout (D-88)', () {
      /// Fails the PIN `times` times over, settling after each.
      Future<void> failTimes(WidgetTester tester, int times) async {
        for (var attempt = 0; attempt < times; attempt++) {
          await typeCode(tester, '9999');
          await tester.pumpAndSettle();
        }
      }

      testWidgets('the first two wrong codes only say "Wrong PIN"', (
        tester,
      ) async {
        await pumpSecretApp(tester);
        await holdForShippedDuration(tester);

        for (var attempt = 1; attempt <= 2; attempt++) {
          await failTimes(tester, 1);
          // Still the short message, still no countdown — one and two are a
          // warning, not a penalty.
          expect(find.text('Wrong PIN'), findsOneWidget);
          expect(find.textContaining('Too many attempts'), findsNothing);
        }

        // And the pad is still live, which is the whole point of counting to
        // three rather than locking on the first.
        expect(keypadEnabled(tester), isTrue);
      });

      testWidgets('the third wrong code locks the screen for 30 seconds', (
        tester,
      ) async {
        await pumpSecretApp(tester);
        await holdForShippedDuration(tester);
        await failTimes(tester, 3);

        // The lock message, not "Wrong PIN" — a locked screen is not told it
        // answered wrong, because the question is no longer being asked.
        expect(find.text('Wrong PIN'), findsNothing);
        expect(
          find.text('Too many attempts. Try again in 30s'),
          findsOneWidget,
        );

        // Every input path inert: the digits carry the shared button's own null
        // callback, which is the disabled signal.
        expect(keypadEnabled(tester), isFalse);
        expect(
          tester
              .widget<CalculatorButton>(
                find.widgetWithText(CalculatorButton, '5'),
              )
              .onPressed,
          isNull,
        );
        expect(backspaceEnabled(tester), isFalse);
      });

      testWidgets('a locked pad cannot be driven by typing', (tester) async {
        await pumpSecretApp(tester);
        await holdForShippedDuration(tester);
        await failTimes(tester, 3);

        // Tapping through the lock must do nothing at all. `typeCode` uses
        // `warnIfMissed: false` so the taps still land on the pad's position;
        // the assertion is that no dot ever fills.
        await typeCode(tester, '1234');
        await tester.pumpAndSettle();

        expect(filledDots(tester), 0);
        expect(find.byType(SecretScreen), findsNothing);
        expect(find.textContaining('Too many attempts'), findsOneWidget);
      });

      testWidgets('the countdown falls one second at a time', (tester) async {
        await pumpSecretApp(tester);
        await holdForShippedDuration(tester);
        await failTimes(tester, 3);

        expect(
          find.text('Too many attempts. Try again in 30s'),
          findsOneWidget,
        );

        // Each second is one step down. [elapse] moves the injected clock and the
        // ticker together, so the message is read in a state the app can
        // actually be in — a repaint without time passing, or time passing
        // without a repaint, would each be a fiction. Driven with `pump` rather
        // than `pumpAndSettle` because the ticker is a periodic timer: settling
        // would run it to exhaustion, which is the opposite of the assertion.
        for (final seconds in const [29, 28, 27]) {
          await elapse(tester, 1);
          expect(
            find.text('Too many attempts. Try again in ${seconds}s'),
            findsOneWidget,
          );
        }
        expect(keypadEnabled(tester), isFalse);
      });

      testWidgets('the screen unlocks when the countdown reaches zero', (
        tester,
      ) async {
        await pumpSecretApp(tester);
        await holdForShippedDuration(tester);
        await failTimes(tester, 3);

        await elapse(tester, 31);
        await tester.pumpAndSettle();

        // Message gone, pad live again, and — the part that is easy to forget —
        // the counter is back to zero, so the user is not locked straight into
        // another lock for another wrong guess.
        expect(find.textContaining('Too many attempts'), findsNothing);
        expect(keypadEnabled(tester), isTrue);
        expect(lockoutState(tester).failedAttempts, 0);

        // And the correct code works straight away.
        await typeCode(tester, '1234');
        await tester.pumpAndSettle();
        expect(find.byType(SecretScreen), findsOneWidget);
      });

      testWidgets('leaving the screen does not end the lockout', (
        tester,
      ) async {
        await pumpSecretApp(tester);
        await holdForShippedDuration(tester);
        await failTimes(tester, 3);
        expect(find.textContaining('Too many attempts'), findsOneWidget);

        // Go home and come straight back — the bypass the wall-clock deadline
        // exists to close. A counter living in widget state would start at zero
        // here.
        await tester.tap(find.byKey(const Key('secret-back')));
        await tester.pumpAndSettle();
        // No `openHistory` before the hold: [holdClearHistory] opens History
        // itself, so opening it here would leave the hold trying to tap a
        // History icon that is not on the screen it is already on.
        await holdForShippedDuration(tester);
        await tester.pump();

        expect(find.textContaining('Too many attempts'), findsOneWidget);
        expect(keypadEnabled(tester), isFalse);
      });

      testWidgets('a partial entry is not counted as an attempt', (
        tester,
      ) async {
        await pumpSecretApp(tester);
        await holdForShippedDuration(tester);

        // Two digits, then backspace, three times over. Never a fourth digit
        // anywhere, so nothing is ever submitted and therefore nothing is ever
        // judged and nothing may be counted — this is the distinction between
        // "typed the wrong code" and "typed a prefix".
        //
        // **The backspace is load-bearing, and so is its absence of counting.**
        // Two digits typed three times over without clearing would accumulate to
        // four on the second pass, which *is* a complete code and is judged as
        // one — correctly. So the clearing is what makes each round a genuine
        // prefix rather than half of a submission, and the assertion below then
        // says the three prefixes together cost nothing.
        for (var round = 0; round < 3; round++) {
          await typeCode(tester, '99');
          await tester.pumpAndSettle();
          for (var digit = 0; digit < 2; digit++) {
            await tester.tap(find.byType(AppBackspaceIcon));
            await tester.pumpAndSettle();
          }
        }

        expect(lockoutState(tester).failedAttempts, 0);
        expect(find.textContaining('Too many attempts'), findsNothing);
      });

      testWidgets('a correct code clears the counter', (tester) async {
        await pumpSecretApp(tester);
        await holdForShippedDuration(tester);

        await failTimes(tester, 2);
        expect(lockoutState(tester).failedAttempts, 2);

        await typeCode(tester, '1234');
        await tester.pumpAndSettle();

        expect(find.byType(SecretScreen), findsOneWidget);
        expect(lockoutState(tester).failedAttempts, 0);
      });

      testWidgets('rapid taps cannot spend more than one attempt', (
        tester,
      ) async {
        await pumpSecretApp(tester);
        await holdForShippedDuration(tester);

        // A real finger lands twice on the last digit. `_checking` is set before
        // the await and re-checked at the top of `_submit`, so the pair of taps
        // yields one judgement — and one failure, not two.
        for (var i = 0; i < 3; i++) {
          for (var digit = 0; digit < 3; digit++) {
            await tester.tap(
              find.widgetWithText(CalculatorButton, '9'),
              warnIfMissed: false,
            );
            await tester.pump();
          }
          // The fourth tap lands twice in a row, with nothing settled between.
          await tester.tap(find.widgetWithText(CalculatorButton, '9'));
          await tester.pump();
          await tester.tap(find.widgetWithText(CalculatorButton, '9'));
          await tester.pumpAndSettle();
        }

        // Three entries, three failures — and it locked, which proves the count
        // reached exactly three and not six.
        expect(lockoutState(tester).failedAttempts, 3);
        expect(find.textContaining('Too many attempts'), findsOneWidget);
      });
    });
  });

  group('the secret screen (FEAT-SEC-003, D-84)', () {
    /// Unlocks and lands on the secret screen itself.
    Future<void> unlock(WidgetTester tester) async {
      await pumpApp(tester, history: seeded());
      await holdForShippedDuration(tester);
      await typeCode(tester, '0000');
      await tester.pumpAndSettle();
    }

    /// The list the dashboard scrolls in, so a finder does not have to know that
    /// the FAB is a `Stack` sibling of it rather than a child.
    Finder homeList() => find.byKey(const Key('secret-home-list'));

    /// Grows the test surface so the whole dashboard is inside the viewport.
    ///
    /// The default 800 × 600 canvas is *shorter* than the screen it is testing,
    /// so a [ListView] never builds a tail it cannot show and every assertion
    /// about the bottom card would fail for a viewport reason rather than for
    /// the thing it was written about. The one test that cares about the short
    /// case sets its own size instead, and the one that cares about scrolling
    /// deliberately leaves the canvas short.
    ///
    /// Called before [unlock], because the app lays out at `pumpApp`.
    void useTallView(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('leads with Recent files and then a 3x2 grid of Categories', (
      tester,
    ) async {
      useTallView(tester);
      await unlock(tester);

      // **Revised by the file-manager pass**, which reversed D-84's "blank". The
      // screen is now the first draft of the hidden area's file manager: Recent
      // files first, then a card per group. Every part of D-84 that was about
      // *content* — no title, no logo, no illustration, no back arrow — still
      // holds, and the "no back arrow" assertion below is the one that catches a
      // later change that quietly reintroduces one.
      expect(find.byKey(const Key('secret-recent-files')), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byType(CalculatorButton), findsNothing);

      // Two group labels, and only two. "Recent files" is the page's own first
      // action rather than a group, so a heading over it would be a label
      // announcing a list of one.
      expect(find.byType(SectionHeader), findsNWidgets(2));
      expect(find.text('CATEGORIES'), findsOneWidget);
      expect(find.text('STORAGE'), findsOneWidget);

      // The grid: six cells, each its own keyed target rather than a `Text` a
      // test has to match on wording. `3 * 2` is the shape the pass asked for, so
      // it is asserted rather than left to whoever edits the data next.
      for (final category in const <String>[
        'images',
        'videos',
        'audio',
        'documents',
        'downloads',
        'installation',
      ]) {
        expect(
          find.byKey(Key('secret-category-$category')),
          findsOneWidget,
          reason: 'the grid must keep a cell for "$category"',
        );
      }
      expect(find.byType(AppIconTile), findsWidgets);

      // One cell per column on one row, three across: read back from the layout
      // rather than from the source data, so a data edit that changed the order
      // or the count of columns cannot pass.
      final first = tester.getCenter(
        find.byKey(const Key('secret-category-images')),
      );
      final second = tester.getCenter(
        find.byKey(const Key('secret-category-videos')),
      );
      final fourth = tester.getCenter(
        find.byKey(const Key('secret-category-documents')),
      );
      expect(second.dx, greaterThan(first.dx));
      expect(fourth.dy, greaterThan(first.dy));
      expect(fourth.dx, closeTo(first.dx, 1));
    });

    testWidgets(
      'shows both storages with their figures, and two bottom actions',
      (tester) async {
        useTallView(tester);
        await unlock(tester);

        expect(
          find.byKey(const Key('secret-storage-internal')),
          findsOneWidget,
        );
        expect(find.text('Internal storage'), findsOneWidget);
        expect(
          find.text('28.35 GB / 32.00 GB · 3.65 GB free'),
          findsOneWidget,
        );

        expect(find.byKey(const Key('secret-storage-sd')), findsOneWidget);
        expect(find.text('SD card'), findsOneWidget);
        expect(find.text('Not inserted'), findsOneWidget);

        expect(find.byType(AppTrashIcon), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsNothing);
        expect(find.byKey(const Key('secret-recycle-bin')), findsOneWidget);
        expect(find.text('Recycle bin'), findsOneWidget);
        expect(find.byKey(const Key('secret-analyse-storage')), findsOneWidget);
        expect(find.text('Analyse storage'), findsOneWidget);

        // All five rows, in the order the screen stacks them — the count and the
        // order in one assertion, so recycling and analysing cannot drift above
        // Storage, and a sixth row cannot arrive unnoticed. Read off the widget
        // list rather than off the rows' centres: a positional assertion can
        // fail for a viewport reason, and this one is about the sequence.
        expect(
          tester
              .widgetList<SettingsRow>(find.byType(SettingsRow))
              .map((row) => row.title),
          <String>[
            'Recent files',
            'Internal storage',
            'SD card',
            'Recycle bin',
            'Analyse storage',
          ],
        );
      },
    );

    testWidgets('puts Search and the overflow together on the top-right', (
      tester,
    ) async {
      await unlock(tester);

      final screen = tester.getSize(find.byType(SecretScreen));
      Rect box(Key key) => tester.getRect(
        find.descendant(of: find.byKey(key), matching: find.byType(IconButton)),
      );
      final search = box(const Key('secret-search'));
      final overflow = box(const Key('secret-overflow'));

      // **The move the pass asked for.** The overflow used to sit alone in the
      // top-*left*, which was defensible on a page with one control on it and is
      // not now that the header carries a second action. Both sit against the
      // app's own 24 px margin — the same line the cards below them end on, which
      // is why the numbers are read off the token rather than retyped.
      expect(
        overflow.right,
        closeTo(screen.width - AppSpacing.screenHorizontal, 1),
      );
      expect(search.right, closeTo(overflow.left - AppSpacing.md, 1));

      // "Top-right", as a corner rather than as two measurements: the exact
      // insets are the app's business.
      expect(overflow.center.dx, greaterThan(screen.width / 2));
      expect(search.center.dy, lessThan(screen.height / 2));
      expect(overflow.center.dy, closeTo(search.center.dy, 1));
    });

    testWidgets('titles the bar "Vault", on the top-left', (tester) async {
      useTallView(tester);
      await unlock(tester);

      final screen = tester.getSize(find.byType(SecretScreen));
      final title = tester.getRect(find.text('Vault'));
      final search = tester.getRect(
        find.descendant(
          of: find.byKey(const Key('secret-search')),
          matching: find.byType(IconButton),
        ),
      );

      // A first line that says what you are looking at, before the grid. The
      // header was titleless while the bar carried nothing but two actions; the
      // left half has a word in it now, and this is the assertion that it stays
      // there.
      expect(find.text('Vault'), findsOneWidget);

      // On the header's own margin, on the same 24 px the cards below end on, so
      // the word does not start where the cards start by accident.
      expect(title.left, closeTo(AppSpacing.screenHorizontal, 1));

      // "Top-left", as a corner rather than as a measurement.
      expect(title.center.dx, lessThan(screen.width / 2));
      expect(title.center.dy, lessThan(screen.height / 2));

      // And it stays *left* of the actions, so the two do not collide.
      //
      // Equality, not `lessThan`: [AppPageHeader] gives the title an `Expanded`,
      // and an `Expanded` takes all the slack, so the title's box ends exactly
      // where the first action begins. The word "Vault" is far narrower than
      // that box — measuring the *glyphs* would need a `RenderParagraph`, and
      // what the layout guarantees is the box. The bar is the thing that is
      // measured, and the assertion is that the bar did not have to reflow to fit
      // both.
      expect(title.right, lessThanOrEqualTo(search.left));

      // One line, not two, so the bar is still the height every screen's top
      // spacing is measured from. Read off the token rather than typed as a
      // magic number: a wrapped title would add a second line's height to this.
      expect(
        tester.getSize(find.byType(AppPageHeader)).height,
        closeTo(AppSpacing.headerTopGap + AppSizes.headerHeight, 1),
        reason:
            'a second title line would make this bar taller than every '
            'other screen in the app',
      );
    });

    testWidgets('the title stays one line beside the actions when narrow', (
      tester,
    ) async {
      // The width where a longer title *would* want a second line, and where a
      // title wide enough to press against the actions would show it.
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await unlock(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Vault'), findsOneWidget);

      final search = tester.getRect(
        find.descendant(
          of: find.byKey(const Key('secret-search')),
          matching: find.byType(IconButton),
        ),
      );

      // Ellipsised rather than wrapped, and the bar is still one line tall at the
      // width where a second would have wanted to happen. Measured off the bar
      // rather than off the text: [AppPageHeader] caps the title at one line, so
      // the guarantee is that the bar did not grow, not that the glyphs shrank.
      expect(
        tester.getSize(find.byType(AppPageHeader)).height,
        closeTo(AppSpacing.headerTopGap + AppSizes.headerHeight, 1),
      );
      expect(
        tester.getRect(find.text('Vault')).right,
        lessThanOrEqualTo(search.left),
        reason: 'the title must yield to the actions, not overlap them',
      );
    });

    testWidgets('names no part of the feature and no code (§6.8)', (
      tester,
    ) async {
      useTallView(tester);
      await unlock(tester);

      // **The part of §6.8 that survived the reversal.** The pass added eleven
      // strings to a page whose whole privacy argument was that it had none, so
      // the burden sits on this one assertion. The words are phone vocabulary —
      // Images, Downloads, Internal storage — and none of them is the *code*.
      //
      // **The naming rule is withdrawn here, not relaxed.** "Vault" in the header
      // is now a name for the feature, which desing.md §6.8 and D-84 forbade, so
      // the line that asserted it is gone rather than weakened. What this test
      // still protects is the thing §6.8 was ultimately about: a screenshot of
      // this screen must never carry the four digits that open it. Someone who
      // wants the area deniable by name does not have it any more; that cost is
      // accepted in `SecretScreen`'s doc comment, where it belongs.
      expect(find.textContaining('Secret'), findsNothing);
      expect(find.textContaining('0000'), findsNothing);
      expect(find.textContaining('default'), findsNothing);
      expect(find.textContaining('PIN'), findsNothing);

      // And the title that replaced that rule is asserted by name, so a later
      // rename cannot quietly re-break the doc comment above.
      expect(find.text('Vault'), findsOneWidget);
    });

    testWidgets('every control is enabled-looking, and only Search is inert', (
      tester,
    ) async {
      useTallView(tester);
      await unlock(tester);

      // **Reversed by D-114**, which wired the eleven rows to the eleven browsing
      // pages. The old version of this test tapped `secret-search`,
      // `secret-recent-files`, and `secret-category-images` and asserted the screen
      // was still on `SecretScreen` afterwards — the *correct* assertion at the
      // time, and the thing that would have caught the wiring going in if it had
      // not been replaced first.
      //
      // So this test now asserts the half of the old decision that survived and
      // hands the other half to `vault_place_pages_test.dart`, which drives all
      // eleven rows rather than three.
      //
      // Enabled-looking **on purpose**: a disabled or absent control renders the
      // page as grey text on dark cards, which reads as a layout bug rather than
      // as a first draft. So every control is enabled — and now, unlike before,
      // eleven of the twelve open something.
      expect(
        tester
            .widget<AppIconButton>(find.byKey(const Key('secret-search')))
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<SettingsRow>(find.byKey(const Key('secret-recent-files')))
            .onTap,
        isNotNull,
      );

      // The one control still wired to a no-op, and it stays here: search has no
      // destination and no honest empty page to open. A row that opens a page
      // saying "No images yet" states a fact; a search page over a set of files
      // that does not exist would not.
      await tester.tap(find.byKey(const Key('secret-search')));
      await tester.pumpAndSettle();

      // Still here, and still intact: nothing pushed, nothing popped, and no
      // rebuild threw on the way.
      expect(find.byType(SecretScreen), findsOneWidget);
      expect(find.text('CATEGORIES'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the overflow button is the shared bordered AppIconButton', (
      tester,
    ) async {
      useTallView(tester);
      await unlock(tester);

      // D-74: the same 48 px bordered component every other header action wears,
      // so it looks entirely ordinary. Search shares it too, which is the other
      // half of "reads as furniture".
      final button = tester.widget<AppIconButton>(
        find.byKey(const Key('secret-overflow')),
      );
      expect(button.bordered, isTrue);
      expect(button.tooltip, 'Menu');

      final search = tester.widget<AppIconButton>(
        find.byKey(const Key('secret-search')),
      );
      expect(search.bordered, isTrue);
      expect(search.icon, Icons.search);
    });

    testWidgets('the last card clears the floating home button', (
      tester,
    ) async {
      await unlock(tester);

      // The FAB became a `Stack` sibling of the scrolling column, so it now
      // floats *over* content that used to be a page with nothing on it. Without
      // the list's bottom padding the last action would be unreachable behind it.
      final list = tester.widget<ListView>(homeList());
      expect(
        list.padding!.resolve(TextDirection.ltr).bottom,
        closeTo(
          AppSizes.secretHomeButton +
              AppSecretSpacing.homeButtonInset +
              AppSpacing.md,
          0.01,
        ),
        reason: 'the list must reserve the FAB plus the inset it is padded by',
      );

      // And proved on screen rather than only in the padding: scrolled to the
      // end, nothing overlaps the button.
      await tester.drag(homeList(), const Offset(0, -400));
      await tester.pumpAndSettle();

      final fab = tester.getRect(find.byKey(const Key('secret-home')));
      final last = tester.getRect(
        find.byKey(const Key('secret-analyse-storage')),
      );
      expect(
        last.bottom,
        lessThanOrEqualTo(fab.top),
        reason: 'the last row must not sit underneath the home button',
      );
    });

    testWidgets('scrolls, so nothing is unreachable on a short screen', (
      tester,
    ) async {
      // A 360 x 640 phone: the narrowest and shortest this pass has to survive,
      // and the case where a non-scrolling column would have overflowed outright.
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await unlock(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(SecretScreen), findsOneWidget);

      // The categories card holds its three columns at this width rather than
      // overflowing: the labels are the thing at risk, and the long one wraps
      // instead of being ellipsised away.
      final install = tester.getSize(
        find.byKey(const Key('secret-category-installation')),
      );
      final images = tester.getSize(
        find.byKey(const Key('secret-category-images')),
      );
      expect(install.width, closeTo(images.width, 0.5));
      expect(tester.takeException(), isNull);
    });
  });

  group('the way home (D-86)', () {
    /// Unlocks and lands on the secret screen.
    Future<void> unlock(WidgetTester tester) async {
      await pumpApp(tester, history: seeded());
      await holdForShippedDuration(tester);
      await typeCode(tester, '0000');
      await tester.pumpAndSettle();
    }

    testWidgets('the PIN screen has a back arrow, not a home button', (
      tester,
    ) async {
      await pumpApp(tester, history: seeded());
      await holdForShippedDuration(tester);

      // The case D-86 exists for: a user who held the button by accident and
      // cannot guess the code had, before this, only the system back gesture.
      // D-87 keeps the exit and changes its shape.
      expect(find.byKey(const Key('secret-back')), findsOneWidget);

      // And the FAB is gone from this screen — asserted negatively so a later
      // change that puts both on one page has to be argued for. The two keys
      // differ precisely so this assertion cannot pass by matching the other
      // button.
      expect(find.byKey(const Key('secret-home')), findsNothing);
      expect(find.byIcon(Icons.home_outlined), findsNothing);
    });

    testWidgets('the back arrow is the shared bordered AppIconButton', (
      tester,
    ) async {
      await pumpApp(tester, history: seeded());
      await holdForShippedDuration(tester);

      // D-74: the same 48 px bordered component every other header action
      // wears, and the same `arrow_back` glyph History and Settings leave by —
      // so on the one screen with no header it still reads as ordinary
      // furniture rather than as something Secret Mode invented.
      final button = tester.widget<AppIconButton>(
        find.byKey(const Key('secret-back')),
      );
      expect(button.icon, Icons.arrow_back);
      expect(button.bordered, isTrue);
      expect(button.tooltip, 'Back to calculator');
    });

    testWidgets('it sits in the top-left corner, on the header margin', (
      tester,
    ) async {
      await pumpApp(tester, history: seeded());
      await holdForShippedDuration(tester);

      // Measured rather than trusted: the whole point of putting it top-left is
      // that it lands where every other back button in the app lands. If the
      // surrounding [Padding] ever changes, this fails instead of the control
      // quietly drifting into the middle of the prompt.
      final screen = tester.getSize(find.byType(SecretUnlockScreen));
      final box = tester.getRect(
        find.descendant(
          of: find.byKey(const Key('secret-back')),
          matching: find.byType(IconButton),
        ),
      );

      // `screenHorizontal` is 24 and the header rides `headerTopGap`, both read
      // off the tokens rather than retyped, so a change to the app's margin
      // moves this assertion with it.
      expect(box.left, closeTo(AppSpacing.screenHorizontal, 1));
      expect(box.top, closeTo(AppSpacing.headerTopGap, 1));

      // The left half of the screen, and the top — asserted separately from the
      // numbers above because these are what "top-left" *means*; the exact insets
      // are the app's business, the corner is this decision's.
      expect(box.center.dx, lessThan(screen.width / 2));
      expect(box.center.dy, lessThan(screen.height / 2));
    });

    testWidgets('it clears the touch floor', (tester) async {
      await pumpApp(tester, history: seeded());
      await holdForShippedDuration(tester);

      final size = tester.getSize(
        find.descendant(
          of: find.byKey(const Key('secret-back')),
          matching: find.byType(IconButton),
        ),
      );
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('the unlocked secret screen keeps its floating home button', (
      tester,
    ) async {
      await unlock(tester);

      // D-87 narrowed D-86 rather than reversing it: the blank screen has no
      // primary action, so a bottom-right circle is *the* control there and
      // reads as an exit. Only the PIN screen — which has a keypad and one job —
      // outgrew the FAB.
      expect(find.byKey(const Key('secret-home')), findsOneWidget);
      expect(find.byKey(const Key('secret-back')), findsNothing);
    });

    testWidgets('it is white on black, from the app palette (D-86)', (
      tester,
    ) async {
      await unlock(tester);

      // The inversion the decision calls for: `textPrimary` (white) behind
      // `textOnFunction` (black). Both pre-existing tokens — D-84's "a blank page
      // needing a new token would be the signal it had stopped being blank" is
      // satisfied in letter and in spirit.
      // Read straight off the keyed widget rather than through an ancestor
      // finder: the key is *on* this `Material`, so searching its ancestors
      // would climb past it to whatever Material the `Scaffold` supplied.
      final button = tester.widget<Material>(
        find.byKey(const Key('secret-home')),
      );
      expect(button.color, AppColors.textPrimary);

      final glyph = tester.widget<Icon>(find.byIcon(Icons.home_outlined));
      expect(glyph.color, AppColors.textOnFunction);
    });

    testWidgets('it sits in the bottom-right corner', (tester) async {
      await unlock(tester);

      // Position is the reason a user recognises it without reading it, so it is
      // asserted rather than left to the `Align` being right.
      final screen = tester.getSize(find.byType(SecretScreen));
      final button = tester.getRect(find.byKey(const Key('secret-home')));

      // The screen's own box, not the window's: `SafeArea` insets differ by
      // platform and a test comparing against the raw window size would pass on
      // a device with a home indicator and fail on one without.
      expect(button.right, closeTo(screen.width - 24, 1));
      expect(button.bottom, closeTo(screen.height - 24, 1));
      expect(
        button.center.dx,
        greaterThan(screen.width / 2),
        reason: 'the home affordance belongs in the right half',
      );
    });

    testWidgets('it clears the system inset and the touch floor', (
      tester,
    ) async {
      await unlock(tester);

      final button = tester.getSize(find.byKey(const Key('secret-home')));
      expect(button.width, closeTo(56, 0.5));
      expect(button.width, greaterThanOrEqualTo(44));
    });

    testWidgets('from the secret screen it lands on the calculator', (
      tester,
    ) async {
      await unlock(tester);

      await tester.tap(find.byKey(const Key('secret-home')));
      await tester.pumpAndSettle();

      // `go`, so nothing of the secret area is left on the stack to swipe back
      // into — the same reasoning the unlock screen's own `go` records.
      expect(find.byType(SecretScreen), findsNothing);
      expect(find.byType(SecretUnlockScreen), findsNothing);
      expect(find.byType(CalculatorScreen), findsOneWidget);
    });

    testWidgets('from the PIN screen it lands on the calculator too', (
      tester,
    ) async {
      await pumpApp(tester, history: seeded());
      await holdForShippedDuration(tester);

      await tester.tap(find.byKey(const Key('secret-back')));
      await tester.pumpAndSettle();

      // The whole point: someone who never knew the code still ends up back in
      // the calculator, with no trace of the hidden area left behind them.
      expect(find.byType(SecretUnlockScreen), findsNothing);
      expect(find.byType(CalculatorScreen), findsOneWidget);
    });
  });

  group('the secret settings page (FEAT-SEC-004, AC-020, D-84)', () {
    /// Unlocks and opens the one-row page.
    ///
    /// Two taps rather than one as of D-115: the overflow opens [SecretMenu],
    /// and the panel's single row is what opens the page.
    Future<void> openSecretSettings(WidgetTester tester) async {
      await pumpApp(tester, history: seeded());
      await holdForShippedDuration(tester);
      await typeCode(tester, '0000');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('secret-overflow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SecretMenu.settingsRowKey));
      await tester.pumpAndSettle();
    }

    testWidgets('holds two rows: "Change PIN" first, "Reset PIN" second', (
      tester,
    ) async {
      await openSecretSettings(tester);

      expect(find.byType(SecretSettingsScreen), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Change PIN'), findsOneWidget);
      expect(find.text('Reset PIN'), findsOneWidget);

      // D-86 added the second row. Two, not more: the recovery route is one
      // action, and a third row here would be scope the hidden area does not need.
      expect(find.byType(SettingsRow), findsNWidgets(2));

      // The full Settings page is **not** duplicated here — no Sound, no
      // Vibration, no Decimal Places. Four settings in a hidden area would be a
      // second place to maintain a page nobody reaches.
      expect(find.text('Sound'), findsNothing);
      expect(find.text('Vibration'), findsNothing);
      expect(find.text('Decimal Places'), findsNothing);
      expect(find.text('Privacy Policy'), findsNothing);
    });

    testWidgets('back returns to the blank secret screen', (tester) async {
      await openSecretSettings(tester);

      await goBack(tester);

      expect(find.byType(SecretScreen), findsOneWidget);
    });
  });

  group('changing the PIN (FEAT-SEC-005, AC-021, D-113)', () {
    /// Opens the Change PIN flow, already past the unlock, the overflow and the
    /// panel that sits between them (D-115).
    Future<void> openChangePin(WidgetTester tester, SecretCode current) async {
      await pumpApp(tester, history: seeded(), secretPin: current);
      await holdForShippedDuration(tester);
      await typeCode(tester, current.value);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('secret-overflow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SecretMenu.settingsRowKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change PIN'));
      await tester.pumpAndSettle();
    }

    /// Taps the back arrow in the flow's own header.
    ///
    /// Found by glyph rather than by a bespoke key because the shared `goBack`
    /// helper would do exactly this — and because the arrow is the app's ordinary
    /// way out, so a key of its own would be a second name for a control that
    /// every other screen finds the same way.
    Future<void> pressBack(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
    }

    /// Lets the confirmation line finish its pause and the flow end.
    ///
    /// **An explicit [WidgetTester.pump], not `pumpAndSettle`.** The pause is a
    /// timer, not a scheduled frame, so `pumpAndSettle` returns the moment the
    /// success `setState` has been painted — with the flow still open and the
    /// line still up. Pumping the *shipped* duration (published on the widget
    /// precisely so this cannot drift from the app) is what lets the `pop` after
    /// it actually run.
    Future<void> settleSuccess(WidgetTester tester) async {
      await tester.pump(ChangePinScreen.successPause);
      await tester.pumpAndSettle();
    }

    /// Walks the whole three-step flow to a successful save, then lets the
    /// success line expire.
    Future<void> changeTo(
      WidgetTester tester, {
      required String current,
      required String next,
    }) async {
      await openChangePin(tester, SecretCode(current));
      await typeCode(tester, current);
      await tester.pumpAndSettle();
      await typeCode(tester, next);
      await tester.pumpAndSettle();
      await typeCode(tester, next);
      await tester.pumpAndSettle();
      await settleSuccess(tester);
    }

    testWidgets('the three steps each name their own question', (tester) async {
      await openChangePin(tester, SecretCode('1234'));

      // Step one. The line above the dots is the only thing telling three
      // identical dot rows apart, so each is named rather than implied (D-113).
      expect(find.text('Enter current PIN'), findsOneWidget);
      expect(find.text('Enter new PIN'), findsNothing);
      expect(find.text('Confirm new PIN'), findsNothing);

      await typeCode(tester, '1234');
      await tester.pumpAndSettle();
      expect(find.text('Enter new PIN'), findsOneWidget);
      expect(find.text('Enter current PIN'), findsNothing);

      await typeCode(tester, '5678');
      await tester.pumpAndSettle();
      expect(find.text('Confirm new PIN'), findsOneWidget);
      expect(find.text('Enter new PIN'), findsNothing);
    });

    testWidgets('no step ever renders the digits as characters', (
      tester,
    ) async {
      await openChangePin(tester, SecretCode('1234'));

      // Every step, including the two the user is typing a *new* code into: a
      // fresh four-digit code is the one value a bystander most needs not to see.
      // Read on a **partial** entry, which is the only moment the digits are
      // definitely on screen — and never as a matched confirmation, which would
      // start the success pause this test has no reason to sit through.
      for (final step in <(String, String)>[
        ('Enter current PIN', '12'),
        ('Enter new PIN', '56'),
      ]) {
        await typeCode(tester, step.$2);
        await tester.pumpAndSettle();

        expect(find.text(step.$1), findsOneWidget, reason: step.$1);
        expect(find.text('*'), findsNothing);
        expect(find.text(step.$2), findsNothing);
        // The digits are in the field — they are just not on it.
        expect(filledDots(tester), 2);

        // Completing the step. The first is the real current PIN; the second is
        // the new one, which is deliberately *not* a match for anything.
        await typeCode(tester, step.$1 == 'Enter current PIN' ? '34' : '78');
        await tester.pumpAndSettle();
      }

      expect(find.text('Confirm new PIN'), findsOneWidget);
      await typeCode(tester, '99');
      await tester.pumpAndSettle();
      // A mismatch rather than a match: the assertion is about what is *not*
      // rendered, and a confirmation that fails leaves the screen up to ask.
      expect(find.text('5678'), findsNothing);
      expect(find.text('1234'), findsNothing);
      expect(find.text('*'), findsNothing);
    });

    testWidgets('an incorrect current PIN does not advance', (tester) async {
      await openChangePin(tester, SecretCode('1234'));
      expect(find.byType(ChangePinScreen), findsOneWidget);

      await typeCode(tester, '9999');
      await tester.pumpAndSettle();

      // Still on step one, dots cleared, and no way forward without the real
      // current code. A reset that skipped verification would make the stored
      // code decorative (D-85).
      expect(find.byType(ChangePinScreen), findsOneWidget);
      expect(find.text('Enter current PIN'), findsOneWidget);
      expect(filledDots(tester), 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an incorrect current PIN says so, in red, under the dots', (
      tester,
    ) async {
      await openChangePin(tester, SecretCode('1234'));

      // Nothing is red before the first attempt: the error describes a *judged*
      // code, so a screen nobody has answered yet is not in an error state.
      expect(find.text('Incorrect PIN'), findsNothing);
      expect(dotBorders(tester).toSet(), isNot(contains(danger)));

      await typeCode(tester, '9999');
      await tester.pumpAndSettle();

      // **Reverses D-88's opt-in for this screen.** Step 1 used to refuse a
      // genuinely wrong code in silence, which is indistinguishable from a
      // keypad that has stopped responding — the one thing D-88's own reasoning
      // (a screen that stops accepting input without saying why) argues against.
      // Every outline red, not just the filled ones: the entry clears on the same
      // frame, so a fill-only treatment would have nothing left to paint.
      expect(dotBorders(tester), everyElement(danger));
      expect(
        tester
            .widget<Text>(find.byKey(const Key('secret-pin-status')))
            .style
            ?.color,
        danger,
      );
      expect(find.text('Incorrect PIN'), findsOneWidget);

      // And it is a caption, right below the indicator, not a banner: the message
      // slot is 18 px and reserved whether or not it has anything in it, so the
      // keypad cannot move when it appears (D-88).
      final dots = tester.getRect(find.byKey(const Key('secret-pin-dots')));
      final message = tester.getRect(
        find.byKey(const Key('secret-pin-status')),
      );
      expect(message.top, greaterThan(dots.bottom));
      expect(
        message.height,
        lessThan(AppSpacing.xl),
        reason: 'a caption line, not a block of error text',
      );
    });

    testWidgets(
      'typing again clears "Incorrect PIN" before the code is complete',
      (tester) async {
        await openChangePin(tester, SecretCode('1234'));
        await typeCode(tester, '9999');
        await tester.pumpAndSettle();
        expect(find.text('Incorrect PIN'), findsOneWidget);

        // One digit, not four: the message describes the code just rejected and is
        // stale the moment a new one is started.
        await typeCode(tester, '1');
        await tester.pumpAndSettle();

        expect(find.text('Incorrect PIN'), findsNothing);
        expect(dotBorders(tester).toSet(), isNot(contains(danger)));
        expect(filledDots(tester), 1);
      },
    );

    testWidgets('the correct current PIN advances to entering a new one', (
      tester,
    ) async {
      await openChangePin(tester, SecretCode('1234'));

      await typeCode(tester, '1234');
      await tester.pumpAndSettle();

      expect(filledDots(tester), 0);
      expect(find.text('Enter new PIN'), findsOneWidget);
      expect(find.byType(ChangePinScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an incomplete PIN never advances', (tester) async {
      await openChangePin(tester, SecretCode('1234'));

      // One digit short, on each step that has one: the code is only a code at
      // four digits, and `SecretPinField` submits on the fourth and not before.
      await typeCode(tester, '123');
      await tester.pumpAndSettle();

      expect(find.text('Enter current PIN'), findsOneWidget);
      expect(filledDots(tester), 3);

      // Only the *fourth* digit — the three already typed are still in the field,
      // so typing the whole code again would make a different four digits.
      await typeCode(tester, '4');
      await tester.pumpAndSettle();
      expect(find.text('Enter new PIN'), findsOneWidget);

      await typeCode(tester, '567');
      await tester.pumpAndSettle();

      expect(find.text('Enter new PIN'), findsOneWidget);
      expect(find.text('Confirm new PIN'), findsNothing);
      expect(filledDots(tester), 3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a fifth digit is refused', (tester) async {
      await openChangePin(tester, SecretCode('1234'));

      // The cap is [SecretCode.length], so the extra key changes nothing — and,
      // more to the point, does not *submit twice*.
      await typeCode(tester, '12349');
      await tester.pumpAndSettle();

      expect(find.text('Enter new PIN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the new PIN is not written before it is confirmed', (
      tester,
    ) async {
      await openChangePin(tester, SecretCode('1234'));

      await typeCode(tester, '1234');
      await tester.pumpAndSettle();
      await typeCode(tester, '5678');
      await tester.pumpAndSettle();

      // Read through the real repository, so a code that had been cached
      // somewhere but never persisted would still show as the old one.
      expect(await storedPin(), SecretCode('1234'));

      // And still not written three quarters of the way through confirming it:
      // the write is behind the *match*, so a code that only looks finished
      // changes nothing.
      await typeCode(tester, '567');
      await tester.pumpAndSettle();
      expect(await storedPin(), SecretCode('1234'));

      // The fourth digit is where the answer is decided.
      await typeCode(tester, '8');
      await tester.pumpAndSettle();
      expect(await storedPin(), SecretCode('5678'));

      // And the flow is over, so no timer is left hanging past the test.
      await settleSuccess(tester);
      expect(find.byType(SecretSettingsScreen), findsOneWidget);
    });

    testWidgets(
      'a mismatched confirmation stays on step three and keeps the code',
      (tester) async {
        await openChangePin(tester, SecretCode('1234'));
        await typeCode(tester, '1234');
        await tester.pumpAndSettle();
        await typeCode(tester, '5678');
        await tester.pumpAndSettle();

        await typeCode(tester, '9999');
        await tester.pumpAndSettle();

        // **Reverses the old "a mismatch returns to step two"** (D-113). Still
        // step three, asking the same question: the user mistyped the confirmation,
        // not their choice of PIN, and being sent back to re-choose it makes a
        // third attempt of a code they already settled on.
        expect(find.text('Confirm new PIN'), findsOneWidget);
        expect(find.text('PINs do not match'), findsOneWidget);
        expect(dotBorders(tester), everyElement(danger));
        // Only the confirmation is cleared; the new code is still held in memory
        // and is proven held by the next test step.
        expect(filledDots(tester), 0);
        expect(await storedPin(), SecretCode('1234'));

        // Retrying the confirmation with the code they chose the first time saves
        // it — which is only possible if the mismatch did not discard it.
        await typeCode(tester, '5678');
        await tester.pumpAndSettle();
        expect(await storedPin(), SecretCode('5678'));

        // Left here rather than at the end of the first half: the save starts the
        // success pause, and a test that ends with a pending timer is a test that
        // failed for a reason nobody wrote.
        await settleSuccess(tester);
        expect(find.byType(SecretSettingsScreen), findsOneWidget);
      },
    );

    testWidgets('a mismatched confirmation does not turn step two red', (
      tester,
    ) async {
      await openChangePin(tester, SecretCode('1234'));
      await typeCode(tester, '1234');
      await tester.pumpAndSettle();
      await typeCode(tester, '5678');
      await tester.pumpAndSettle();
      await typeCode(tester, '9999');
      await tester.pumpAndSettle();

      // The complaint belongs to the step that produced it, and re-asking step 2
      // must not inherit it.
      await pressBack(tester);

      expect(find.text('Enter new PIN'), findsOneWidget);
      expect(find.text('PINs do not match'), findsNothing);
      expect(dotBorders(tester).toSet(), isNot(contains(danger)));
    });

    testWidgets('a matching confirmation persists the code and ends the flow', (
      tester,
    ) async {
      await openChangePin(tester, SecretCode('1234'));
      await typeCode(tester, '1234');
      await tester.pumpAndSettle();
      await typeCode(tester, '5678');
      await tester.pumpAndSettle();
      await typeCode(tester, '5678');
      await tester.pumpAndSettle();

      // Saved *the instant it is confirmed* — the store is already changed while
      // the success line is still up, because AC-021's claim is that a process
      // death one frame later cannot lose a code the user was told had changed.
      expect(await storedPin(), SecretCode('5678'));
      expect(find.text('PIN changed successfully'), findsOneWidget);
      // In the app's own neutral label colour: the palette has no success token
      // (D-84) and red under an accepted code would be a false claim.
      expect(
        tester
            .widget<Text>(find.byKey(const Key('secret-pin-status')))
            .style
            ?.color,
        isNot(danger),
      );

      await settleSuccess(tester);

      // The flow ends where it started: the one-row settings page.
      expect(find.byType(ChangePinScreen), findsNothing);
      expect(find.byType(SecretSettingsScreen), findsOneWidget);
      expect(await storedPin(), SecretCode('5678'));
    });

    testWidgets(
      'nothing can be entered or navigated while the success line is up',
      (tester) async {
        await openChangePin(tester, SecretCode('1234'));
        await typeCode(tester, '1234');
        await tester.pumpAndSettle();
        await typeCode(tester, '5678');
        await tester.pumpAndSettle();
        await typeCode(tester, '5678');
        await tester.pumpAndSettle();

        expect(find.text('PIN changed successfully'), findsOneWidget);
        expect(keypadEnabled(tester), isFalse);
        expect(backspaceEnabled(tester), isFalse);
        // The arrow is disabled rather than removed: a control that vanished
        // mid-flow would move the layout the user was looking at.
        final back = tester.widget<AppIconButton>(find.byType(AppIconButton));
        expect(back.onPressed, isNull);

        // Taps that land anyway change nothing. **`pump`, not `pumpAndSettle`**, and the
        // reason is the whole point of the assertion: `pumpAndSettle` advances the
        // test clock 100 ms a frame until nothing is scheduled, which walks the
        // confirmation pause straight past its end and pops the screen the test is
        // trying to inspect. A bare `pump` advances nothing, so the pause cannot
        // expire underneath it.
        await tester.tap(find.widgetWithText(CalculatorButton, '1'));
        await tester.pump();
        expect(find.text('PIN changed successfully'), findsOneWidget);
        expect(filledDots(tester), 4);

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pump();
        expect(find.text('PIN changed successfully'), findsOneWidget);

        // Only when the pause is deliberately pumped out does the flow end.
        await settleSuccess(tester);
        expect(find.byType(ChangePinScreen), findsNothing);
        expect(await storedPin(), SecretCode('5678'));
      },
    );

    testWidgets(
      'the changed PIN is the one that opens the screen, and the old is not',
      (tester) async {
        await changeTo(tester, current: '1234', next: '5678');

        // Out of the settings page to the blank screen, then out of the hidden
        // area entirely — so the claim below is about the *store* answering a fresh
        // unlock prompt rather than about a provider's opinion of it.
        await goBack(tester);
        expect(find.byType(SecretScreen), findsOneWidget);

        await tester.tap(find.byKey(const Key('secret-home')));
        await tester.pumpAndSettle();
        await holdForShippedDuration(tester);

        // The old code is refused and opens nothing.
        await typeCode(tester, '1234');
        await tester.pumpAndSettle();
        expect(find.byType(SecretScreen), findsNothing);
        expect(find.text('Wrong PIN'), findsOneWidget);

        // The new one is accepted, which is what "changed" means. Typed straight
        // after the rejection, so this is also the immediate-retry path.
        await typeCode(tester, '5678');
        await tester.pumpAndSettle();
        expect(find.byType(SecretScreen), findsOneWidget);
      },
    );

    testWidgets('a PIN with leading zeroes survives as four digits', (
      tester,
    ) async {
      // `0001` is a real four-digit code; a store that trimmed leading zeroes
      // would hand the user a code they never chose.
      await changeTo(tester, current: '0000', next: '0001');

      expect((await storedPin()).value, '0001');
    });

    testWidgets('back on step one leaves the flow, changing nothing', (
      tester,
    ) async {
      await openChangePin(tester, SecretCode('1234'));

      // Step one is where the arrow does the ordinary thing: the flow has nowhere
      // earlier to go, so it pops.
      await pressBack(tester);

      expect(find.byType(ChangePinScreen), findsNothing);
      expect(find.byType(SecretSettingsScreen), findsOneWidget);
      expect(await storedPin(), SecretCode('1234'));
    });

    testWidgets('back on step two returns to step one and drops the new PIN', (
      tester,
    ) async {
      await openChangePin(tester, SecretCode('1234'));
      await typeCode(tester, '1234');
      await tester.pumpAndSettle();

      await pressBack(tester);

      // Back to the verification step with a clean field, not to step 3 with the
      // candidate already filled.
      expect(find.text('Enter current PIN'), findsOneWidget);
      expect(filledDots(tester), 0);
      expect(await storedPin(), SecretCode('1234'));

      // And the candidate is really gone: re-verifying and stepping forward again
      // asks step 2 from empty rather than confirming what was dropped.
      await typeCode(tester, '1234');
      await tester.pumpAndSettle();
      expect(find.text('Enter new PIN'), findsOneWidget);
      expect(filledDots(tester), 0);
    });

    testWidgets(
      'back on step three returns to step two and keeps the new PIN',
      (tester) async {
        await openChangePin(tester, SecretCode('1234'));
        await typeCode(tester, '1234');
        await tester.pumpAndSettle();
        await typeCode(tester, '5678');
        await tester.pumpAndSettle();

        await pressBack(tester);

        // Step two again, asking for the new code — which the user is about to type
        // a second time. Throwing it away would be the same mistake the
        // confirmation mismatch used to make.
        expect(find.text('Enter new PIN'), findsOneWidget);
        expect(filledDots(tester), 0);
        // Unconfirmed means unwritten: going back must never save anything.
        expect(await storedPin(), SecretCode('1234'));

        // And the whole flow still completes afterwards.
        await typeCode(tester, '5678');
        await tester.pumpAndSettle();
        await typeCode(tester, '5678');
        await tester.pumpAndSettle();
        expect(await storedPin(), SecretCode('5678'));

        await settleSuccess(tester);
        expect(find.byType(SecretSettingsScreen), findsOneWidget);
      },
    );

    testWidgets('backspace works on all three steps', (tester) async {
      await openChangePin(tester, SecretCode('1234'));

      // Step one: removes a digit and submits nothing.
      await typeCode(tester, '129');
      await tester.tap(find.byType(AppBackspaceIcon));
      await tester.pumpAndSettle();
      expect(filledDots(tester), 2);
      expect(find.text('Enter current PIN'), findsOneWidget);

      await typeCode(tester, '34');
      await tester.pumpAndSettle();
      expect(find.text('Enter new PIN'), findsOneWidget);

      // Step two. Three digits, one deleted, and the *two* remaining plus the one that
      // completes them — the deletion left `56` in the field, so the code is
      // finished by `78`, not by `8`.
      await typeCode(tester, '567');
      await tester.tap(find.byType(AppBackspaceIcon));
      await tester.pumpAndSettle();
      expect(filledDots(tester), 2);

      await typeCode(tester, '78');
      await tester.pumpAndSettle();
      expect(find.text('Confirm new PIN'), findsOneWidget);

      // Step three, the same two taps — and the same two digits to finish.
      await typeCode(tester, '567');
      await tester.tap(find.byType(AppBackspaceIcon));
      await tester.pumpAndSettle();
      expect(filledDots(tester), 2);

      await typeCode(tester, '78');
      await tester.pumpAndSettle();
      expect(await storedPin(), SecretCode('5678'));
      expect(find.text('PIN changed successfully'), findsOneWidget);

      await settleSuccess(tester);
      expect(find.byType(SecretSettingsScreen), findsOneWidget);
    });

    testWidgets('backspace on an empty entry does nothing', (tester) async {
      await openChangePin(tester, SecretCode('1234'));

      // Twice, because one is a claim about the guard and two is a claim that the
      // key survives being pressed when there is nothing to delete.
      await tester.tap(find.byType(AppBackspaceIcon));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppBackspaceIcon));
      await tester.pumpAndSettle();

      expect(filledDots(tester), 0);
      expect(find.text('Enter current PIN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the controller (D-83, D-85)', () {
    testWidgets('verify accepts the stored code and rejects any other', (
      tester,
    ) async {
      await pumpApp(tester, history: seeded());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      await container.read(secretControllerProvider.future);

      final notifier = container.read(secretControllerProvider.notifier);
      expect(await notifier.verify(SecretCode('0000')), isTrue);
      expect(await notifier.verify(SecretCode('0001')), isFalse);
    });

    testWidgets('change updates the code the notifier publishes', (
      tester,
    ) async {
      await pumpApp(tester, history: seeded());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      await container.read(secretControllerProvider.future);

      await container
          .read(secretControllerProvider.notifier)
          .change(SecretCode('4321'));

      expect(
        container.read(secretControllerProvider).valueOrNull,
        SecretCode('4321'),
      );
      // And verify now accepts it, from the repository rather than from the
      // published state - so a write that failed to persist would show up here.
      expect(
        await container
            .read(secretControllerProvider.notifier)
            .verify(SecretCode('4321')),
        isTrue,
      );
    });

    testWidgets('reset returns the published code to the default (AC-022)', (
      tester,
    ) async {
      await pumpApp(tester, history: seeded());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      await container.read(secretControllerProvider.future);
      await container
          .read(secretControllerProvider.notifier)
          .change(SecretCode('4321'));

      await container.read(secretControllerProvider.notifier).reset();

      expect(
        container.read(secretControllerProvider).valueOrNull,
        SecretCode.defaultCode,
      );
      // Read back through the repository, so a reset that only updated the
      // published state — and left the store holding `4321` — fails here.
      expect(
        await container
            .read(secretControllerProvider.notifier)
            .verify(SecretCode('4321')),
        isFalse,
      );
      // And it is gone from the store, not merely overwritten: `snapshotStore`
      // is the real store's keys, so a key left behind holding `0000` would show
      // up here as a present entry.
      final keys = (await snapshotStore()).keys;
      expect(keys, isNot(contains(SharedPreferencesSecretRepository.pinKey)));
    });
  });

  // ===========================================================================
  // The forgotten-PIN reset (FEAT-SEC-006, AC-022).
  //
  // **Reached from the Settings page, not from a "Forgot PIN?" link.** D-88
  // removed that link from the PIN screen, so the dialog it opened is now
  // reachable only from "Reset PIN" in the Secret settings page — which is the
  // same dialog with the same wording, because it is the same problem and the
  // same person. The behaviour these tests cover is unchanged by that removal:
  // the reset still has to erase the code, still has to survive a restart, and
  // still has not to strand the user on a page that needs the code they just
  // destroyed. Only the route to it moved.
  // ===========================================================================

  group('forgetting the PIN (FEAT-SEC-006, AC-022)', () {
    /// Unlocks, then opens the Secret settings page through the panel.
    Future<void> openSecretSettings(WidgetTester tester) async {
      await pumpSecretApp(tester);
      await holdForShippedDuration(tester);
      await typeCode(tester, '1234');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('secret-overflow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SecretMenu.settingsRowKey));
      await tester.pumpAndSettle();
    }

    /// Taps "Reset PIN" on the settings page and confirms the dialog.
    Future<void> confirmReset(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('secret-reset-pin')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
    }

    testWidgets('the PIN screen offers no way to reset', (tester) async {
      // The counterpart to the removal itself: nothing on the PIN screen opens
      // the reset dialog any more, so a user who cannot get in is not also shown
      // a link that destroys their credential in one tap.
      await pumpSecretApp(tester);
      await holdForShippedDuration(tester);

      expect(find.textContaining('Forgot'), findsNothing);
      expect(find.byKey(const Key('secret-forgot-pin')), findsNothing);
      // The prompt and the dots are untouched by any of that.
      expect(find.text('Enter your PIN'), findsOneWidget);
    });

    testWidgets('the row opens a confirmation that names the default', (
      tester,
    ) async {
      await openSecretSettings(tester);

      await tester.tap(find.byKey(const Key('secret-reset-pin')));
      await tester.pumpAndSettle();

      // Naming `0000` here is deliberate and is the one place the feature does it:
      // §6.8 withholds the code from a *bystander's* screenshot, but this user has
      // forgotten theirs and cannot act on the withholding.
      expect(find.text('Reset PIN?'), findsOneWidget);
      expect(find.textContaining('0000'), findsOneWidget);
    });

    testWidgets('cancelling changes nothing', (tester) async {
      await openSecretSettings(tester);

      await tester.tap(find.byKey(const Key('secret-reset-pin')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // The destructive gate doing its job: the old code is still the code.
      expect(await storedPin(), SecretCode('1234'));
      expect(find.text('Reset PIN?'), findsNothing);
    });

    testWidgets('confirming makes 0000 the code that opens the screen', (
      tester,
    ) async {
      await openSecretSettings(tester);
      await confirmReset(tester);

      // Back on the blank secret screen, not stranded on a Settings page whose
      // only other row needs the PIN they have just forgotten.
      expect(find.byType(SecretScreen), findsOneWidget);
      expect(find.text('Reset PIN?'), findsNothing);
      expect(await storedPin(), SecretCode.defaultCode);

      // And the default the dialog named is what opens it, with the old code now
      // refused. Re-entered through the PIN screen rather than asserted on the
      // store alone, because "the store says 0000" is not the same claim as
      // "the screen admits 0000 and nothing else".
      // The **home** button, not `secret-back`: the unlocked screen has no
      // back arrow by design (D-84) — its way out is the floating home control.
      await tester.tap(find.byKey(const Key('secret-home')));
      await tester.pumpAndSettle();
      await holdForShippedDuration(tester);

      await typeCode(tester, '1234');
      await tester.pumpAndSettle();
      expect(find.byType(SecretScreen), findsNothing);

      await typeCode(tester, '0000');
      await tester.pumpAndSettle();
      expect(find.byType(SecretScreen), findsOneWidget);
    });

    testWidgets('the reset survives a restart', (tester) async {
      // The half a `clear()` bug would hide: an in-memory-looking reset that still
      // answers the old code after the app is rebuilt from disk. `seedStore` with
      // the snapshot is what makes this a genuine restart — see its note on
      // nulling the plugin's cached completer.
      await openSecretSettings(tester);
      await confirmReset(tester);
      expect(await storedPin(), SecretCode.defaultCode);

      // Re-pump from disk rather than trusting the in-memory provider. Ordering
      // matters: `pumpApp` *re-seeds* the store through `mockHistoryStore`, which
      // would replace the snapshot with a fresh history and quietly undo the
      // reset being tested. So the snapshot is installed first and the widget is
      // built directly on top of it.
      final snapshot = await snapshotStore();
      seedStore(snapshot);

      await tester.pumpWidget(
        // **UniqueKey, and it is load-bearing.** Pumping a second widget of the
        // same type reuses the existing element, so the first app's `GoRouter`
        // and its `ProviderScope` survive — the tree comes back up still sitting
        // on the PIN screen, with no History icon to tap. A distinct key forces a
        // genuinely new router, which is what "restart" has to mean for this
        // assertion to be about the disk rather than about the first app.
        ProviderScope(key: UniqueKey(), child: const CalculatorApp()),
      );
      await tester.pumpAndSettle();
      await holdForShippedDuration(tester);

      await typeCode(tester, '0000');
      await tester.pumpAndSettle();
      expect(find.byType(SecretScreen), findsOneWidget);
    });
  });
}
