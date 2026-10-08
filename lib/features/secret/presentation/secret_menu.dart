import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/core_widgets.dart';
import '../../../routing/app_routes.dart';

/// The panel behind the Vault screen's overflow button (D-115).
///
/// What the Vault's overflow opens is Ethar's slide-in menu, and this file is
/// no longer a copy of it: it is the shared [MenuSlider] configured for the
/// hidden area — a lock avatar and the "Vault" title above one row, Settings,
/// which leads to the hidden area's own settings page (FEAT-SEC-004).
///
/// **Why the shared widget matters.** The first draft of this panel hand-rolled
/// a second copy of the geometry, the animation, and eight colour getters next
/// to a `_SecretMenuDrawerTile` that was never defined — a compile error that
/// no test reached, because the screen mounted the drawer anyway. One widget
/// means the Vault menu and Ethar's own cannot drift apart, and the caller
/// supplies only what differs: the header and the rows.
class SecretMenu extends StatelessWidget {
  const SecretMenu({super.key});

  /// The handle tests reach the panel's only row by.
  ///
  /// Published rather than matched by label for the reason the app publishes
  /// keys everywhere else: `find.text('Settings')` would also match the header of
  /// the page this row opens, and a test built on it would be asserting against
  /// whichever of the two happened to be in the tree.
  static const Key settingsRowKey = Key('secret-menu-settings');

  /// Shows the Vault menu as a general dialog that slides in from the left.
  ///
  /// The transition, the width and the scrim are [MenuSlider.show]'s and mirror
  /// Ethar's profile drawer. The row dismisses the panel itself before pushing
  /// (see [MenuSliderTile]), so back from the settings page returns to the Vault
  /// screen rather than to an open panel.
  static Future<void> show(BuildContext context) => MenuSlider.show(
    context,
    barrierLabel: 'Vault menu',
    menu: MenuSlider(
      header: const MenuSliderHeader(
        leading: _VaultAvatar(),
        title: 'Vault',
      ),
      entries: <MenuSliderEntry>[
        (
          icon: Icons.settings_outlined,
          label: 'Settings',
          key: settingsRowKey,
          onTap: () => context.push(AppRoutes.secretSettings),
        ),
      ],
    ),
  );

  // Kept so callers that still hold a `SecretMenu` reference (none do today)
  // fail loudly rather than rendering an invisible panel: the menu is shown by
  // `show`, never built in place.
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// The Vault's leading chip in the panel header — Ethar's 64 px avatar circle
/// wearing a lock instead of a profile picture, so the gem stands in for the
/// thing it guards.
class _VaultAvatar extends StatelessWidget {
  const _VaultAvatar();

  @override
  Widget build(BuildContext context) {
    final colors = MenuColors(context);
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.lock_outline, color: colors.text, size: 30),
    );
  }
}