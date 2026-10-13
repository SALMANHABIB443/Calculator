import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_palette.dart';
import '../../../core/design/app_spacing.dart';
import '../../../routing/app_routes.dart';

/// The floating way home from inside the unlocked secret area (D-86, D-87).
///
/// **Extracted from `secret_screens.dart` when the Documents page arrived.** The
/// argument for it is unchanged and is repeated here so the two screens that use
/// it cannot drift apart: D-84 held that the system back gesture was the *only*
/// exit and that a second exit "would be an affordance telling the user this page
/// is somewhere they arrived at". The reason that was reversed is that the user
/// who actually arrived there could not get out at all. A screen nobody can leave
/// teaches the wrong lesson — that the app has trapped them — which is a worse way
/// to reveal a hidden feature than an extra button is.
///
/// Bottom-right and white, in the position and at the contrast a Material FAB
/// occupies, because that is a shape every phone user already reads as "go back
/// to the main thing". The glyph is black on the white fill
/// ([AppPalette.textOnFunction] on [AppPalette.textPrimary]) — the app's own
/// inverted pair, not a new colour.
///
/// **Why it stayed a FAB while the PIN screen's became an arrow** (D-87): the
/// screens that carry it have no primary action at all, so a bottom-right circle
/// reads as *the* control rather than as a rival to one.
class SecretHomeButton extends StatelessWidget {
  const SecretHomeButton({super.key});

  /// The handle tests and `find.byKey` reach this button by.
  ///
  /// Applied to the **[Material]** rather than to this widget, which sounds like
  /// a detail and is not: a `Key` on this widget resolves to the `Align` that
  /// fills the screen, so `tester.getRect` would measure the whole page and every
  /// assertion about the button's size and position would be measuring the
  /// layout instead of the control. On the `Material`, the key resolves to the
  /// 56 px circle the tests mean to measure.
  ///
  /// Published as a constant rather than written at the call sites, for the same
  /// reason the app does this elsewhere (D-82's hold duration, the settings
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
