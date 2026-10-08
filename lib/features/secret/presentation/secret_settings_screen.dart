import '../../../core/design/app_palette.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/core_widgets.dart';
import '../../../routing/app_routes.dart';
import 'secret_controller.dart';

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
///
/// **Its own file as of D-115**, when the Vault's overflow button stopped
/// navigating here directly and started opening the panel
/// ([SecretMenu]) that leads to this page instead. Nothing about the page
/// changed with the extra hop — same route, same two rows, same keys — and it is
/// a separate file for the ordinary reason that a screen the Vault reaches
/// through a menu is no longer a sibling of the Vault's own screens in any way a
/// reader of one file would care about.
class SecretSettingsScreen extends ConsumerWidget {
  const SecretSettingsScreen({super.key});

  /// Confirmation copy for the reset.
  ///
  /// **Public** so a test can assert the wording without reaching through a
  /// private field. It used to be reachable from a "Forgot PIN?" link on the lock
  /// screen as well; **D-88 removed that link**, because with the 30-second lockout
  /// in place it was an unlimited bypass of it.
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
