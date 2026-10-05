import '../../../../core/design/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/core_widgets.dart';
import '../../../routing/app_routes.dart';
import 'secret_controller.dart';
import 'secret_pin_field.dart';

/// The way out of the PIN screen: one back arrow in the **top-left** corner,
/// going home (D-87).
///
/// **Reverses where D-86 put it on this screen**, not whether it exists. D-86
/// argued — correctly — that a user who held the button by accident and cannot
/// guess the code had no way out, and that argument still holds. What it got
/// wrong for *this* screen is the shape of the answer: a 56 px white circle in
/// the bottom-right corner is a Material FAB, and a FAB reads as "the primary
/// action of this screen". On the PIN screen it was not primary and never could
/// be — the only actions there are four dots and a keypad, and the way out is
/// neither. So the same affordance that looked like an exit on the blank secret
/// screen (which has no primary action at all) looked like a competing
/// destination on a screen whose one real task is typing four digits.
///
/// **Top-left and a back arrow** because that is where every other screen in
/// this app puts "leave", and where a user's thumb already goes to leave. It is
/// the shared [AppIconButton] on the app's own 24 px margin — the same component
/// and the same inset as the overflow button on the unlocked secret screen and
/// the trash on History — so it looks like an ordinary control rather than
/// something the Secret Mode screens invented.
///
/// **D-84's "no back arrow" clause is now amended for this screen only.** It
/// still holds on `SecretScreen`, which is not this screen; and it still holds
/// for *content* everywhere here — no title, no logo, no copy, no illustration.
/// What is withdrawn is the argument that a second exit "tells the user this
/// page is somewhere they arrived at". A corner arrow is the cheapest exit in
/// the app and the most forgettable, and reachability for a trapped user is
/// worth more than deniability about a page that shows nothing.
class _SecretBackButton extends StatelessWidget {
  const _SecretBackButton();

  /// The handle tests reach this button by, and the name every finder's key
  /// matches.
  ///
  /// Distinct from [_SecretHomeButton.buttonKey] on purpose: the two buttons now
  /// live on different screens, and a shared key would let a test asserting
  /// "the PIN screen has no home button" pass for the wrong reason.
  static const Key buttonKey = Key('secret-back');

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: AppIconButton(
        key: buttonKey,
        icon: Icons.arrow_back,
        tooltip: 'Back to calculator',
        // `go`, not `pop`: the system gesture on this screen pops to History,
        // which is the trap D-86 was written about — a user holding down on the
        // 0 result would slide back onto the calculator but a user mid-secret
        // would slide back into the app with the hidden area still under them.
        // `go` leaves nothing of Secret Mode on the stack either way.
        onPressed: () => context.go(AppRoutes.calculator),
      ),
    );
  }
}

/// The floating way home from the unlocked secret screen (D-86, narrowed by
/// D-87).
///
/// **Reverses D-84**, which held that the system back gesture was the *only*
/// exit and that a second exit "would be an affordance telling the user this page
/// is somewhere they arrived at". The reason it is being reversed is that the
/// user who actually arrived there could not get out at all. A screen nobody can
/// leave teaches the wrong lesson — that the app has trapped them — which is a
/// worse way to reveal a hidden feature than an extra button is.
///
/// Bottom-right and white, in the position and at the contrast a Material FAB
/// occupies, because that is a shape every phone user already reads as "go back
/// to the main thing". The glyph is black on the white fill
/// ([context.appColors.textOnFunction] on [context.appColors.textPrimary]) — the app's own
/// inverted pair, not a new colour.
///
/// **Why this button stayed a FAB while the PIN screen's became an arrow**
/// (D-87): this screen has no primary action at all, so a bottom-right circle
/// reads as *the* control rather than as a rival to one. The PIN screen is a
/// keypad with one job; there the arrow belongs instead.
///
/// **What this costs, on the record.** The blankness in D-84 was a real
/// property, argued well: a screenshot of this page spoils nothing when the page
/// shows nothing. This button does not spoil the *feature* — the five-second hold
/// still has to be known to reach either screen — but it does mean the page is
/// now visible in a screenshot as somewhere a user has been. That is accepted:
/// reachability beats deniability when the unreachable user cannot leave.
class _SecretHomeButton extends StatelessWidget {
  const _SecretHomeButton();

  /// The handle tests and `find.byKey` reach this button by.
  ///
  /// Applied to the **[Material]** rather than to this widget, which sounds like
  /// a detail and is not: a `Key` on this widget resolves to the `Align` that
  /// fills the screen, so `tester.getRect` would measure the whole page and every
  /// assertion about the button's size and position would be measuring the
  /// layout instead of the control. On the `Material`, the key resolves to the
  /// 56 px circle the tests mean to measure.
  ///
  /// Published as a constant rather than written at the two call sites, for the
  /// same reason the app does this elsewhere (D-82's hold duration, the settings
  /// repository's keys): the value a test asserts against must be the one that
  /// ships.
  static const Key buttonKey = Key('secret-home');

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(AppSecretSpacing.homeButtonInset),
        child: Semantics(
          container: true,
          button: true,
          label: 'Back to calculator',
          child: Material(
            key: buttonKey,
            color: context.appColors.textPrimary,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () => context.go(AppRoutes.calculator),
              customBorder: const CircleBorder(),
              child: SizedBox.square(
                dimension: AppSizes.secretHomeButton,
                child: Icon(
                  Icons.home_outlined,
                  // The inverted half of the app's own pair, so the glyph keeps
                  // its contrast against whatever it is drawn on.
                  color: context.appColors.textOnFunction,
                  size: AppSizes.rowIcon + 4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Runs the reset from the PIN screen's "Forgot PIN?" link.
///
/// **Shares [SecretSettingsScreen]'s copy and behaviour on purpose** rather than
/// having its own: a user who forgets their PIN is one person with one problem,
/// and two dialogs that reset to the same place with different wording is exactly
/// the drift the shared-token files exist to prevent. The confirm text names the
/// default because this is the screen where that is the useful thing to say.
///
/// On success it stays on this screen and clears the entered digits, rather than
/// navigating: the user is already looking at the prompt they need to answer
/// next, and `0000` is the answer. Navigating away would make them find their
/// way back here before typing the code the dialog just told them.
Future<void> _resetFromPrompt(BuildContext context, WidgetRef ref) async {
  final confirmed = await AppConfirmationDialog.show(
    context,
    title: SecretSettingsScreen.resetTitle,
    message: SecretSettingsScreen.resetMessage,
    confirmLabel: 'Reset',
  );
  if (!confirmed || !context.mounted) return;

  await ref.read(secretControllerProvider.notifier).reset();
}

/// The black PIN prompt (FEAT-SEC-002, AC-018/AC-019).
///
/// **No header, no title, no hint, and no error text** — all four are
/// deliberate. A screen that names itself confirms it is real, and this is a
/// hidden feature; the dots are the entire interface. The single exception is
/// the one exit in the **top-left**: a back arrow, sharing the app's margin and
/// its back-button component, and nothing more (D-87). It was a floating
/// bottom-right home button until D-87 moved it, because a user who held the
/// 0 key by accident could not otherwise reach the calculator.
class SecretUnlockScreen extends ConsumerWidget {
  const SecretUnlockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      body: SafeArea(
        child: Padding(
          // Horizontal room for the dots and the keypad's own padding. The
          // vertical gap keeps the dot row off the top edge without centring the
          // whole assembly, which would drift between phone heights.
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.headerTopGap,
            AppSpacing.screenHorizontal,
            AppSpacing.bottomSafe,
          ),
          child: Stack(
            children: <Widget>[
              SecretPinField(
                // **Neither string names the code** (§6.8). The prompt says only
                // that a PIN is wanted, and the recovery route is the link — which
                // leads to a dialog that does name the default, to a user who has
                // already tapped their way to asking for it (D-86).
                prompt: 'Enter your PIN',
                onForgotPin: () => _resetFromPrompt(context, ref),
                // The one place a correct code acts: replace this screen with
                // the secret screen rather than pushing on top of it. Leaving a
                // PIN prompt beneath the secret screen would put a back gesture
                // that returns here in front of the user (struction.md §7,
                // D-84).
                onSubmit: (entered) async {
                  final accepted = await ref
                      .read(secretControllerProvider.notifier)
                      .verify(entered);
                  if (!accepted || !context.mounted) return false;
                  // `go`, not `push`: this **replaces** the unlock screen rather
                  // than stacking on it. A PIN prompt left underneath would put
                  // a back gesture that returns to it in front of the user
                  // (struction.md §7, D-84).
                  context.go(AppRoutes.secret);
                  return true;
                },
              ),
              // The one exit on this screen, and the reason it is a top-left back
              // arrow rather than the bottom-right FAB D-86 chose: a user who
              // held the button by accident and cannot guess the code has to be
              // able to leave, and an arrow is the app's ordinary way out — so it
              // reads as furniture and never competes with the keypad, which is
              // the one thing this screen exists for (D-87).
              //
              // No padding of its own: the [Padding] around this [Stack] already
              // puts the button on the app's 24 px header margin, the same inset
              // every other screen's back button rides (D-74).
              const _SecretBackButton(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The unlocked secret screen: **blank** (FEAT-SEC-003, AC-020, D-84).
///
/// One button and nothing else. No title, no logo, no empty-state illustration,
/// and no back arrow of its own — the system back gesture is the only exit, and
/// a second exit would be an affordance telling the user this page is somewhere
/// they arrived at.
class SecretScreen extends StatelessWidget {
  const SecretScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            // The same header inset every other screen's header rides, so the
            // button sits on the app's 24 px margin and reads as an ordinary
            // header action rather than as something placed by hand (D-74).
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.screenHorizontal,
                right: AppSpacing.screenHorizontal,
                top: AppSpacing.headerTopGap,
              ),
              child: Align(
                alignment: Alignment.topLeft,
                child: AppIconButton(
                  key: const Key('secret-overflow'),
                  icon: Icons.more_vert,
                  tooltip: 'Settings',
                  onPressed: () => context.push(AppRoutes.secretSettings),
                ),
              ),
            ),
            // The second control D-84 ruled out, kept for the same reason as on
            // the PIN screen: a user in a hidden area needs one obvious way to
            // return to the app they came from (D-86).
            const _SecretHomeButton(),
          ],
        ),
      ),
    );
  }
}

/// The settings page inside the hidden area (FEAT-SEC-004, D-84, D-86).
///
/// **Two rows as of D-86**, where D-84 specified exactly one. "Change PIN" is
/// unchanged and keeps its place first; "Reset PIN" is added after it because
/// the two are not peers — one sets a code, the other destroys one, and the
/// destructive action reading last is what keeps it off the row a thumb lands on
/// while browsing.
///
/// The full Settings page is **not** duplicated here: it would be a second place
/// to maintain four settings that no user who found this screen would come back
/// to, and the screen's only job is the PIN.
class SecretSettingsScreen extends ConsumerWidget {
  const SecretSettingsScreen({super.key});

  /// Confirmation copy for the reset.
  ///
  /// **Public** because the PIN screen's "Forgot PIN?" link opens the same
  /// dialog with the same wording — see `_resetFromPrompt`.
  ///
  /// The message **names the default** on purpose, unlike everywhere else in
  /// this feature. §6.8 withholds the code so a screenshot cannot spoil it, but a
  /// user who has *forgotten* their PIN has no way to act on the withholding —
  /// the information is what they need, and by this point they are already
  /// standing inside the area holding a code they set. Naming it turns a dead end
  /// into a two-tap recovery.
  static const String resetTitle = 'Reset PIN?';
  static const String resetMessage =
      'Your PIN will return to the default, 0000. '
      'You will need 0000 to get back in.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SecondaryPageScaffold(
      header: const SecondaryPageHeader(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        children: <Widget>[
          SettingsGroup(
            children: <Widget>[
              SettingsRow(
                icon: Icons.lock_outline,
                title: 'Change PIN',
                onTap: () => context.push(AppRoutes.secretChangePin),
              ),
              SettingsRow(
                key: const Key('secret-reset-pin'),
                icon: Icons.restart_alt,
                title: 'Reset PIN',
                // Red rather than the default white: this row destroys a
                // credential, and the app already reserves orange for
                // destructive confirms in the Clear History dialog. The glyph is
                // the only red ink here — the label stays [textPrimary], so the
                // row still reads as a row in the app's own type.
                iconColor: context.appColors.accent,
                onTap: () => _confirmReset(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Confirms, then resets, and takes the user somewhere useful afterwards.
  ///
  /// The navigation back to `/secret` is part of the fix, not a flourish: a
  /// reset performed from this page leaves the user staring at a Settings list
  /// offering "Change PIN", which requires the *old* PIN to do anything — the one
  /// they have just said they do not have. Dropping them onto the blank secret
  /// screen puts them somewhere they can reach the calculator from, which is the
  /// entire reason they reset.
  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppConfirmationDialog.show(
      context,
      title: resetTitle,
      message: resetMessage,
      confirmLabel: 'Reset',
    );
    if (!confirmed || !context.mounted) return;

    await ref.read(secretControllerProvider.notifier).reset();
    if (!context.mounted) return;
    context.go(AppRoutes.secret);
  }
}