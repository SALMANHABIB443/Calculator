import '../../../../core/design/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/core_widgets.dart';
import '../domain/secret_code.dart';
import 'secret_controller.dart';
import 'secret_pin_field.dart';

/// The three-step Change PIN flow (FEAT-SEC-005, AC-021).
///
/// Verify the current code, enter a new one, confirm it — one screen stepped
/// through rather than three pushed routes. Pushing would leave a PIN prompt on
/// the stack under the one being answered, so the system back gesture would step
/// *backwards* through the prompt to a screen that looks identical. One screen
/// with one visible keypad cannot do that.
///
/// **The new code exists only in [_ChangePinScreenState._pending] until the
/// confirmation matches** (D-113). Every one of the three exits from this screen
/// before that point — the back button, the system gesture, a process death —
/// leaves the stored code untouched, so there is no state in which a user is
/// locked out of a code they did not choose.
class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  /// How long the success line stays up before the flow ends (D-113).
  ///
  /// **Published rather than kept private, for the same reason the app does this
  /// elsewhere** (D-82's hold duration, the settings repository's keys): the value
  /// a test pumps against must be the one that ships, and a literal restated in a
  /// test is a number free to drift from the behaviour it is claiming to check.
  static const Duration successPause = Duration(milliseconds: 1200);

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

/// Which of the three steps is on screen.
enum _Step {
  /// The current code, checked before anything can be changed (D-85).
  verifyCurrent,

  /// The new code.
  enterNew,

  /// The new code again; a mismatch re-asks here with [_ChangePinScreenState._pending] kept.
  confirmNew,
}

/// The line each step shows above the dots.
///
/// A table rather than a `switch` buried in `build` so the wording lives in one
/// table, and a step cannot be added to the enum without also being given the
/// line that explains it. Wording is deliberately the user's own framing —
/// "current" and "new" — because the three steps are otherwise three identical
/// dot rows and a wrong entry at step 1 is indistinguishable from a wrong entry
/// at step 3 without it.
///
/// **Three steps, three questions, and each one named.** The bare verbs are the
/// whole design: the same widget, the same four dots and the same keypad ask all
/// three questions, so the one thing telling them apart is the line above the
/// dots.
///
/// None of these name the default code. §6.8 withholds it so a screenshot cannot
/// spoil the feature, and the recovery route for a forgotten current PIN is the
/// reset flow on the secret settings page.
const Map<_Step, String> _stepPrompts = <_Step, String>{
  _Step.verifyCurrent: 'Enter current PIN',
  _Step.enterNew: 'Enter new PIN',
  _Step.confirmNew: 'Confirm new PIN',
};

/// The complaint under the dots after a rejected entry, per step (D-113).
///
/// Null on step 2, and that null is not an oversight: there is nothing step 2 can
/// reject. Any four digits is a legal new PIN — it may equal the old one, and
/// neither the code type nor the flow forbids that — so the only step that can
/// refuse an entry is step 1 (the code is wrong) and step 3 (the two entries
/// disagree). A wording table rather than a second `switch` in `build`, for the
/// reason [SecretPinField.wrongPinMessage] takes one: the screen that knows what
/// the user was trying to do owns the sentence.
const Map<_Step, String?> _stepErrors = <_Step, String?>{
  _Step.verifyCurrent: 'Incorrect PIN',
  _Step.enterNew: null,
  _Step.confirmNew: 'PINs do not match',
};

/// How long the success line is left on screen before the flow ends.
///
/// The number lives on [ChangePinScreen.successPause], which the flow uses and a
/// test pumps against, so the two cannot drift.
///
/// **Long enough to read, short enough not to be in the way.** The line is the
/// only feedback the user gets that the code they were told had changed actually
/// changed, so it cannot be a frame; and it is not a confirmation dialog either,
/// because the flow is already over and the user chose the new code themselves —
/// there is nothing here they are being asked to decide. A little over a second
/// is the shortest span in which a caption line registers as read rather than as
/// a flash.

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  _Step _step = _Step.verifyCurrent;

  /// The new code from step 2, held so step 3 can compare against it.
  ///
  /// **In memory only, and never written until step 3 matches it.** This is the
  /// field the whole flow's safety rests on: a new code that exists solely here
  /// cannot be persisted, so abandoning the flow — by the back button, the system
  /// gesture, or a process death — leaves the stored code exactly as it was. The
  /// alternative, saving at step 2 and correcting at step 3, means every
  /// interrupted confirmation leaves the user locked out of a code they did not
  /// choose (D-113).
  SecretCode? _pending;

  /// Whether the confirmed code has been persisted and the success line is up.
  ///
  /// Gates the keypad and the back button for the length of
  /// [ChangePinScreen.successPause], so nothing can be typed, submitted, or
  /// navigated while the confirmation is on screen. Nothing about the *save*
  /// needs this — [SecretCodeNotifier.change] has already returned by then — it is
  /// there so the one line the user is reading is the only thing happening.
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.headerTopGap,
            AppSpacing.screenHorizontal,
            AppSpacing.bottomSafe,
          ),
          child: Column(
            children: <Widget>[
              // The header sits above the dots rather than being a `Scaffold`
              // bar: this flow is a dialog over the secret area rather than a
              // place of its own, and a page title here would name it.
              Align(
                alignment: Alignment.centerLeft,
                child: AppIconButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Back',
                  // Inert while the confirmation is up, so
                  // [ChangePinScreen.successPause] cannot be cut short and the
                  // success line never seen.
                  onPressed: _confirmed ? null : _stepBack,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: SecretPinField(
                  // Keyed by step: advancing rebuilds the field from scratch,
                  // which is what clears the dots. Stepping *within* the screen
                  // rather than pushing three routes is what makes this
                  // necessary — one screen, one keypad, and the previous step's
                  // four digits still in it otherwise.
                  //
                  // It also clears the rejection for free. `onSubmit` returning
                  // false reddens the dots, and a step change is exactly the
                  // moment that verdict is stale.
                  key: ValueKey<_Step>(_step),
                  // No autofocus between steps: the keypad is already mounted,
                  // and pulling focus mid-step would make the dots fill without
                  // the user touching anything.
                  autofocusFirstKey: false,
                  // Which of the three questions is being asked. Without it the
                  // three steps are three identical dot rows and a rejection at
                  // step 1 looks exactly like a rejection at step 3. The step is
                  // the rebuild key below, so the line changes the instant the
                  // step does and the dots clear with it.
                  prompt: _stepPrompts[_step],
                  // **On for every step** (D-113). It used to be off, on the
                  // reasoning that a user who mistypes a code they just chose is
                  // being asked to try again rather than being told off — but
                  // that left step 1 rejecting a genuinely wrong code in silence,
                  // and silence there is indistinguishable from a stuck keypad.
                  // The remedy for the original worry is the *wording*, not the
                  // absence of feedback: `_stepErrors` says which of the two
                  // rejections this is.
                  showErrors: true,
                  // Step 2's null is what keeps a red indicator off a step that
                  // cannot reject — see [_stepErrors].
                  wrongPinMessage: _stepErrors[_step],
                  successMessage: _confirmed
                      ? 'PIN changed successfully'
                      : null,
                  // A confirmed code is a finished flow; nothing more may be
                  // entered into a pad whose answer is already written.
                  inputEnabled: !_confirmed,
                  onSubmit: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Advances, stays put, or finishes, depending on the step and the code.
  ///
  /// **Returns whether the code was accepted**, which is what
  /// [SecretPinField] reacts to: `false` clears the dots and paints the error
  /// for the current step. Every path here is one of the three in the flow —
  /// advance, refuse, or finish — so a rejection can never be mistaken for an
  /// advance, and no path writes anything to the store except the confirmed one.
  Future<bool> _submit(SecretCode entered) async {
    switch (_step) {
      case _Step.verifyCurrent:
        final accepted = await ref
            .read(secretControllerProvider.notifier)
            .verify(entered);
        if (!accepted) return false;
        setState(() => _step = _Step.enterNew);
        return true;

      case _Step.enterNew:
        // Held, not saved: step 3 is what makes it real (D-113).
        setState(() {
          _pending = entered;
          _step = _Step.confirmNew;
        });
        return true;

      case _Step.confirmNew:
        if (entered != _pending) {
          // **Stay on step 3 with [_pending] intact** (D-113), clearing only the
          // confirmation. This used to drop back to step 2 and throw the new code
          // away, on the reasoning that a clean field was less confusable — but
          // the user did not make a mistake there. They typed what they believe is
          // their new PIN, twice, and mistyped the second one; throwing away the
          // first makes them choose it a third time, and a third attempt is a
          // third chance to land somewhere they did not intend. Keeping it costs
          // only that they re-enter the confirmation, and the new code stays in
          // memory, so it is still not saved.
          return false;
        }
        // Persisted the instant it is confirmed — a process death one frame
        // later must not lose a code the user was told had changed (AC-021), and
        // it is the *only* write in the flow.
        await ref.read(secretControllerProvider.notifier).change(entered);
        if (!mounted) return false;
        setState(() => _confirmed = true);
        // The success line, then out through the same `pop` the back arrow uses
        // on step 1 — so the flow ends where it began: the secret settings page
        // the user opened it from, with the new code already stored.
        await Future<void>.delayed(ChangePinScreen.successPause);
        if (!mounted) return false;
        context.pop();
        return true;
    }
  }

  /// Goes back one step, or leaves the flow from the first step (D-113).
  ///
  /// **A back arrow that never leaves, and never loses anything.** From step 1 it
  /// pops the route — there is nowhere earlier in this flow to go. From step 2 it
  /// returns to step 1 and *drops* [_pending]: the new code was a candidate, not
  /// a code, and carrying it back to the verification step would let a user
  /// re-enter it after a failed check of the old one. From step 3 it returns to
  /// step 2 and *keeps* it, because the user is about to type it again and making
  /// them re-choose it is the same mistake the confirmation mismatch used to make.
  ///
  /// In all three cases nothing is written: [SecretCodeNotifier.change] is
  /// reachable only from the confirmed branch of [_submit].
  void _stepBack() {
    switch (_step) {
      case _Step.verifyCurrent:
        context.pop();
        return;
      case _Step.enterNew:
        setState(() {
          _pending = null;
          _step = _Step.verifyCurrent;
        });
        return;
      case _Step.confirmNew:
        setState(() => _step = _Step.enterNew);
        return;
    }
  }
}