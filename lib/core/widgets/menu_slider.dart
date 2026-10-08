import 'package:flutter/material.dart';

import 'menu_colors.dart';

/// One destination in a [MenuSlider]: a leading glyph, a label, and what
/// happens when the row is tapped.
typedef MenuSliderEntry = ({
  IconData icon,
  String label,
  VoidCallback onTap,
  Key? key,
});

/// The slide-in menu panel, copied from Ethar's profile drawer
/// (`Ethar/lib/src/features/profile/profile_drawer.dart`).
///
/// **Why this exists.** The Vault screen's overflow wanted Ethar's profile
/// drawer, and the first draft of it hand-rolled a second copy of the geometry,
/// the animation, and eight colour getters beside a `_SecretMenuDrawerTile`
/// that was never defined. One widget means the panel and Ethar's own cannot
/// drift apart, and the caller supplies only what differs: the header, the
/// rows, and an optional footer.
///
/// **The geometry is Ethar's, not a fresh design.** Width
/// `(screenWidth * .86).clamp(300, 380)`, a right-edge radius of 18, the
/// 10/0/28 shadow, `SafeArea` + `fromLTRB(22, 24, 22, 20)`, and rows of height
/// 60 with a 12 px bottom gap. Keeping the numbers identical is the point of
/// the request: the two apps should read as one family, and a menu that is
/// *almost* the same reads as a bug rather than as a variant.
class MenuSlider extends StatelessWidget {
  const MenuSlider({
    super.key,
    required this.header,
    required this.entries,
    this.footer,
  });

  /// Shown at the top of the panel, above the rows — the header block (icon
  /// tile + titles) rather than a bare string, because Ethar's drawer leads
  /// with a 64 px avatar chip and a two-line identity block, and a title-only
  /// header reads as a different component.
  final Widget header;

  /// The rows, in order. Each is a full-width [MenuSliderTile].
  final List<MenuSliderEntry> entries;

  /// Optional action pinned below the rows — Ethar's logout button.
  final Widget? footer;

  /// Opens [menu] as a general dialog sliding in from the left.
  ///
  /// The transition is Ethar's verbatim: 340 ms, `easeOutQuart` in,
  /// `easeInCubic` out, `Offset(-1, 0)` → `Offset.zero` under a fade, with a
  /// `Colors.black54` scrim. `showGeneralDialog` rather than `Drawer` because
  /// the scrim here is not the framework's drawer scrim: Ethar dims with a flat
  /// 54 % black and dismisses on barrier tap, and this is the call that makes
  /// the two apps' menus animate as the same object.
  ///
  /// A row dismisses the panel itself before running its callback (see
  /// [MenuSliderTile]), so an entry's `onTap` only navigates — which is what
  /// keeps `push` from landing under a panel that is still on the stack.
  static Future<void> show(
    BuildContext context, {
    required MenuSlider menu,
    String barrierLabel = 'Menu',
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: barrierLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 340),
      pageBuilder: (_, animation, secondary) =>
          Align(alignment: Alignment.centerLeft, child: menu),
      transitionBuilder: (_, animation, secondary, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutQuart,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(curved),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MenuColors(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = (screenWidth * 0.86).clamp(300.0, 380.0);

    return SizedBox(
      width: width,
      height: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(18),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 28,
              offset: Offset(10, 0),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                children: [
                  for (final entry in entries)
                    MenuSliderTile(
                      key: entry.key,
                      icon: entry.icon,
                      label: entry.label,
                      // **The panel pops itself, then the caller navigates.**
                      // Popping is guarded by `isCurrent` so the same widget can
                      // be rendered as a plain preview (in the catalog, say)
                      // without its rows dismissing whatever screen holds it.
                      onTap: () {
                        final route = ModalRoute.of(context);
                        if (route != null && route.isCurrent) {
                          Navigator.of(context).pop();
                        }
                        entry.onTap();
                      },
                    ),
                ],
                  ),
                ),
                if (footer != null) ...[
                  const SizedBox(height: 8),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/// One destination row: a 44 px icon tile, the label, and a chevron — Ethar's
/// `_DrawerTile` (`profile_drawer.dart:435`) with the same 60 px height, 12 px
/// radius, and 16/w600 label.
class MenuSliderTile extends StatelessWidget {
  const MenuSliderTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MenuColors(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                MenuSliderIconTile(icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.secondary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 44 px rounded square behind a row's glyph — Ethar's `_SettingsIconTile`
/// (`settings_components.dart:346`): 44×44, radius 13, `surfaceSoft` fill,
/// 21 px glyph in primary ink.
class MenuSliderIconTile extends StatelessWidget {
  const MenuSliderIconTile(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = MenuColors(context);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: colors.text, size: 21),
    );
  }
}


/// The header block: a 64 px leading chip (avatar or glyph) beside a title and
/// an optional second line, mirroring Ethar's avatar → name → email stack.
class MenuSliderHeader extends StatelessWidget {
  const MenuSliderHeader({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
  });

  /// The 64 px circle on the left — Ethar's avatar chip. Callers pass an
  /// [Image], an initials container, or an icon tile of their own.
  final Widget leading;

  final String title;

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = MenuColors(context);
    return Row(
      children: [
        leading,
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.secondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The footer action — Ethar's logout row: full-width `softOrange` fill,
/// radius 12, a glyph and a 16/w800 label in the brand orange.
class MenuSliderFooter extends StatelessWidget {
  const MenuSliderFooter({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MenuColors(context);
    return Material(
      color: colors.softOrange,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: colors.accent),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
