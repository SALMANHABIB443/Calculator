import 'package:calculator/app.dart';
import 'package:calculator/core/design/app_colors.dart';
import 'package:calculator/core/design/app_spacing.dart';
import 'package:calculator/core/widgets/core_widgets.dart';
import 'package:calculator/features/calculator/presentation/calculator_screen.dart';
import 'package:calculator/features/history/domain/history_entry.dart';
import 'package:calculator/features/secret/data/shared_preferences_secret_repository.dart';
import 'package:calculator/features/secret/domain/secret_code.dart';
import 'package:calculator/features/secret/presentation/change_pin_screen.dart';
import 'package:calculator/features/secret/presentation/secret_controller.dart';
import 'package:calculator/features/secret/presentation/secret_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/pump_app.dart';

/// The whole Secret Mode flow, driven through the real app (D-82 … D-85,
/// AC-017 … AC-021).
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

  Future<SecretCode> storedPin() async {
    final preferences = await SharedPreferences.getInstance();
    return SharedPreferencesSecretRepository(preferences).load();
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

    testWidgets('two short holds do not add up to five seconds', (tester) async {
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

    testWidgets('a tap still opens the Clear History confirmation',
        (tester) async {
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
    testWidgets('shows four dots and still names neither the feature nor the code',
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

      // Guidance is allowed, and is required — this is the complaint D-86 answers.
      expect(find.text('Enter your PIN'), findsOneWidget);
      expect(find.byKey(const Key('secret-forgot-pin')), findsOneWidget);
      expect(filledDots(tester), 0);
      expect(
        tester.takeException(),
        isNull,
        reason: 'the unlock screen must render without error',
      );
    });

    testWidgets('never displays the entered digits as characters',
        (tester) async {
      await pumpApp(tester, history: seeded(), secretPin: SecretCode('1234'));
      await holdForShippedDuration(tester);
      await typeCode(tester, '12');

      // Not as asterisks, not at all — only the dots fill.
      expect(find.text('*'), findsNothing);
      expect(filledDots(tester), 2);
    });

    testWidgets('backspace removes the last digit and checks nothing',
        (tester) async {
      await pumpApp(tester, history: seeded(), secretPin: SecretCode('1234'));
      await holdForShippedDuration(tester);
      await typeCode(tester, '129');
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pumpAndSettle();

      expect(filledDots(tester), 2);
      expect(find.byType(SecretUnlockScreen), findsOneWidget);
    });

    testWidgets('the default 0000 opens the secret screen (AC-018)',
        (tester) async {
      await pumpApp(tester, history: seeded());
      await holdForShippedDuration(tester);
      await typeCode(tester, '0000');
      await tester.pumpAndSettle();

      expect(find.byType(SecretScreen), findsOneWidget);
      // The prompt is *replaced*, not stacked on: a PIN screen underneath would
      // put a back gesture that returns to it in front of the user.
      expect(find.byType(SecretUnlockScreen), findsNothing);
    });

    testWidgets('a wrong code clears the dots and permits an immediate retry',
        (tester) async {
      await pumpApp(tester, history: seeded(), secretPin: SecretCode('1234'));
      await holdForShippedDuration(tester);

      await typeCode(tester, '9999');
      await tester.pumpAndSettle();

      // Cleared (AC-019) — and no attempt counter, no lockout, no error text.
      expect(filledDots(tester), 0);
      expect(find.byType(SecretUnlockScreen), findsOneWidget);
      expect(find.textContaining('wrong'), findsNothing);
      expect(find.textContaining('Incorrect'), findsNothing);

      // Immediately, with nothing having run in between.
      await typeCode(tester, '1234');
      await tester.pumpAndSettle();
      expect(find.byType(SecretScreen), findsOneWidget);
    });

    testWidgets('a rejected code shakes the dots', (tester) async {
      await pumpApp(tester, history: seeded(), secretPin: SecretCode('1234'));
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

    testWidgets('wrong codes never lock out (D-85)', (tester) async {
      await pumpApp(tester, history: seeded(), secretPin: SecretCode('1234'));
      await holdForShippedDuration(tester);

      // More attempts than any lockout threshold would allow — and the correct
      // code still works afterwards. 10⁴ codes are free to try by design; this
      // is a privacy affordance, not a security boundary.
      for (var attempt = 0; attempt < 6; attempt++) {
        await typeCode(tester, '9999');
        await tester.pumpAndSettle();
      }
      await typeCode(tester, '1234');
      await tester.pumpAndSettle();

      expect(find.byType(SecretScreen), findsOneWidget);
    });
  });

group('the secret screen (FEAT-SEC-003, AC-020, D-84)', () {
    testWidgets('is blank apart from two controls, one of them a way out',
        (tester) async {
      await pumpApp(tester, history: seeded());
      await holdForShippedDuration(tester);
      await typeCode(tester, '0000');
      await tester.pumpAndSettle();

      // **Revised by D-86.** Still no title, no logo, no copy, no illustration,
      // and still no back arrow — the screen keeps every part of D-84 that was
      // about *content*. What changed is the control count: the floating home
      // button is now the second thing on the page.
      expect(find.byType(SettingsRow), findsNothing);
      expect(find.byType(SectionHeader), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byType(CalculatorButton), findsNothing);

      // Exactly two controls, asserted as a count so a third has to be argued
      // for rather than arriving with a future change. The home button is
      // counted by its key and the overflow by its type — one is a shared
      // component found through [AppIconButton], the other is a bespoke
      // `Material`/`InkWell` circle, so a single `byType` finder cannot see both.
      expect(find.byKey(const Key('secret-home')), findsOneWidget);
      expect(find.byType(AppIconButton), findsOneWidget);
      expect(find.byKey(const Key('secret-overflow')), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('the overflow button is the shared bordered AppIconButton',
        (tester) async {
      await pumpApp(tester, history: seeded());
      await holdForShippedDuration(tester);
      await typeCode(tester, '0000');
      await tester.pumpAndSettle();

      // D-74: the same 48 px bordered component every other header action
      // wears, so it looks entirely ordinary.
      final button = tester.widget<AppIconButton>(
        find.byKey(const Key('secret-overflow')),
      );
      expect(button.bordered, isTrue);
      expect(button.tooltip, 'Settings');
    });
  });

  group('the way home (D-86)', () {
    /// Unlocks and lands on the blank secret screen.
    Future<void> unlock(WidgetTester tester) async {
      await pumpApp(tester, history: seeded());
      await holdForShippedDuration(tester);
      await typeCode(tester, '0000');
      await tester.pumpAndSettle();
    }

    testWidgets('the PIN screen has a back arrow, not a home button',
        (tester) async {
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

    testWidgets('the back arrow is the shared bordered AppIconButton',
        (tester) async {
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

    testWidgets('it sits in the top-left corner, on the header margin',
        (tester) async {
      await pumpApp(tester, history: seeded());
      await holdForShippedDuration(tester);

      // Measured rather than trusted: the whole point of putting it top-left is
      // that it lands where every other back button in the app lands. If the
      // surrounding [Padding] ever changes, this fails instead of the control
      // quietly drifting into the middle of the prompt.
      final screen = tester.getSize(find.byType(SecretUnlockScreen));
      final box = tester.getRect(
        find.ancestor(
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
        find.ancestor(
          of: find.byKey(const Key('secret-back')),
          matching: find.byType(IconButton),
        ),
      );
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('the unlocked secret screen keeps its floating home button',
        (tester) async {
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
    Future<void> openSecretSettings(WidgetTester tester) async {
      await pumpApp(tester, history: seeded());
      await holdForShippedDuration(tester);
      await typeCode(tester, '0000');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('secret-overflow')));
      await tester.pumpAndSettle();
    }

    testWidgets('holds two rows: "Change PIN" first, "Reset PIN" second',
        (tester) async {
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

group('changing the PIN (FEAT-SEC-005, AC-021)', () {
    /// Opens the Change PIN flow, already past the unlock and the overflow.
    Future<void> openChangePin(WidgetTester tester, SecretCode current) async {
      await pumpApp(tester, history: seeded(), secretPin: current);
      await holdForShippedDuration(tester);
      await typeCode(tester, current.value);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('secret-overflow')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change PIN'));
      await tester.pumpAndSettle();
    }

    /// Walks the whole three-step flow to a successful save.
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
    }

    testWidgets('an incorrect current PIN does not advance', (tester) async {
      await openChangePin(tester, SecretCode('1234'));
      expect(find.byType(ChangePinScreen), findsOneWidget);

      await typeCode(tester, '9999');
      await tester.pumpAndSettle();

      // Still on step one, dots cleared, and no way forward without the real
      // current code. A reset that skipped verification would make the stored
      // code decorative (D-85).
      expect(find.byType(ChangePinScreen), findsOneWidget);
      expect(filledDots(tester), 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the correct current PIN advances to entering a new one',
        (tester) async {
      await openChangePin(tester, SecretCode('1234'));

      await typeCode(tester, '1234');
      await tester.pumpAndSettle();

      // Step two looks exactly like step one — dots cleared and ready, with no
      // text saying which step this is.
      expect(filledDots(tester), 0);
      expect(find.byType(ChangePinScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a mismatched confirmation returns to step two', (tester) async {
      await openChangePin(tester, SecretCode('1234'));

      await typeCode(tester, '1234');
      await tester.pumpAndSettle();
      await typeCode(tester, '5678');
      await tester.pumpAndSettle();
      await typeCode(tester, '9999');
      await tester.pumpAndSettle();

      // Back at step two with the dots cleared — not stuck, and not accepting.
      expect(find.byType(ChangePinScreen), findsOneWidget);
      expect(filledDots(tester), 0);
    });

    testWidgets('a matching confirmation persists the code and ends the flow',
        (tester) async {
      await changeTo(tester, current: '1234', next: '5678');

      // The flow ends where it started: the one-row settings page.
      expect(find.byType(ChangePinScreen), findsNothing);
      expect(find.byType(SecretSettingsScreen), findsOneWidget);

      // And it was written, under the documented key (AC-021, D-83).
      expect(await storedPin(), SecretCode('5678'));
    });
    testWidgets('a PIN with leading zeroes survives as four digits',
        (tester) async {
      // `0001` is a real four-digit code; a store that trimmed leading zeroes
      // would hand the user a code they never chose.
      await changeTo(tester, current: '0000', next: '0001');

      expect((await storedPin()).value, '0001');
    });
  });

  group('the controller (D-83, D-85)', () {
    testWidgets('verify accepts the stored code and rejects any other',
        (tester) async {
      await pumpApp(tester, history: seeded());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      await container.read(secretControllerProvider.future);

      final notifier = container.read(secretControllerProvider.notifier);
      expect(await notifier.verify(SecretCode('0000')), isTrue);
      expect(await notifier.verify(SecretCode('0001')), isFalse);
    });

    testWidgets('change updates the code the notifier publishes',
        (tester) async {
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

    testWidgets('reset returns the published code to the default (AC-022)',
        (tester) async {
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

  group('forgetting the PIN (FEAT-SEC-006, AC-022)', () {
    /// Opens the PIN screen with [current] as the stored code.
    Future<void> openPin(WidgetTester tester, SecretCode current) async {
      await pumpApp(tester, history: seeded(), secretPin: current);
      await holdForShippedDuration(tester);
    }

    /// Taps "Forgot PIN?" and confirms the dialog.
    Future<void> confirmForgotPin(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('secret-forgot-pin')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
    }

    testWidgets('the link opens a confirmation that names the default',
        (tester) async {
      await openPin(tester, SecretCode('1234'));

      await tester.tap(find.byKey(const Key('secret-forgot-pin')));
      await tester.pumpAndSettle();

      // Naming `0000` here is deliberate and is the one place the feature does it:
      // §6.8 withholds the code from a *bystander's* screenshot, but this user has
      // forgotten theirs and cannot act on the withholding.
      expect(find.text('Reset PIN?'), findsOneWidget);
      expect(find.textContaining('0000'), findsOneWidget);
    });

    testWidgets('cancelling changes nothing', (tester) async {
      await openPin(tester, SecretCode('1234'));

      await tester.tap(find.byKey(const Key('secret-forgot-pin')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // The destructive gate doing its job: the old code is still the code.
      expect(await storedPin(), SecretCode('1234'));
      expect(find.text('Reset PIN?'), findsNothing);
    });

    testWidgets('confirming makes 0000 the code that opens the screen',
        (tester) async {
      await openPin(tester, SecretCode('1234'));
      await confirmForgotPin(tester);

      // Still on the PIN screen — the user is standing at the prompt they need to
      // answer next, and `0000` is the answer the dialog just gave them.
      expect(find.byType(SecretUnlockScreen), findsOneWidget);
      expect(find.text('Reset PIN?'), findsNothing);

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
      await openPin(tester, SecretCode('1234'));
      await confirmForgotPin(tester);
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
        ProviderScope(
          key: UniqueKey(),
          child: const CalculatorApp(),
        ),
      );
      await tester.pumpAndSettle();
      await holdForShippedDuration(tester);

      await typeCode(tester, '0000');
      await tester.pumpAndSettle();
      expect(find.byType(SecretScreen), findsOneWidget);
    });

    testWidgets('from the settings page, the reset also lands somewhere useful',
        (tester) async {
      await pumpApp(tester, history: seeded(), secretPin: SecretCode('1234'));
      await holdForShippedDuration(tester);
      await typeCode(tester, '1234');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('secret-overflow')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('secret-reset-pin')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      // Back to the secret screen, not stranded on a Settings page whose only
      // other row needs the PIN they just forgot.
      expect(find.byType(SecretScreen), findsOneWidget);
      expect(await storedPin(), SecretCode.defaultCode);
    });
  });
}
