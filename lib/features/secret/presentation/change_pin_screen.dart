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
class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

/// Which of the three steps is on screen.
enum _Step {
  /// The current code, checked before anything can be changed (D-85).
  verifyCurrent,

  /// The new code.
  enterNew,

  /// The new code again; a mismatch drops back to [_Step.enterNew].
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
/// None of these name the default code. §6.8 withholds it so a screenshot cannot
/// spoil the feature, and the recovery route for a forgotten current PIN is the
/// reset flow on the secret settings page.
const Map<_Step, String> _stepPrompts = <_Step, String>{
  _Step.verifyCurrent: 'Enter your current PIN',
  _Step.enterNew: 'Enter a new PIN',
  _Step.confirmNew: 'Enter the new PIN again',
};

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  _Step _step = _Step.verifyCurrent;

  /// The new code from step 2, held so step 3 can compare against it.
  SecretCode? _pending;

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
                  icon: Icons.close,
                  tooltip: 'Cancel',
                  onPressed: () => context.pop(),
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
                  onSubmit: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Advances, stays put, or resets depending on the step and the code.
  Future<bool> _submit(SecretCode entered) async {
    switch (_step) {
      case _Step.verifyCurrent:
        final accepted = await ref
            .read(secretControllerProvider.notifier)
            .verify(entered);
        if (!accepted) return false;
        setState(() => _step = _Step.enterNew);

      case _Step.enterNew:
        setState(() {
          _pending = entered;
          _step = _Step.confirmNew;
        });

      case _Step.confirmNew:
        if (entered != _pending) {
          // A mismatch goes back to step 2 with the dots cleared, so the new code
          // is typed twice from a clean field rather than appended to the
          // half-typed one that failed (feature.md FEAT-SEC-005).
          setState(() {
            _pending = null;
            _step = _Step.enterNew;
          });
          return false;
        }
        // Persisted the instant it is confirmed — a process death one frame
        // later must not lose a code the user was told had changed (AC-021).
        await ref.read(secretControllerProvider.notifier).change(entered);
        if (mounted) context.pop();
    }

    return true;
  }
}