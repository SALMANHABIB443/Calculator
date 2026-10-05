import 'package:flutter/material.dart';

import '../../../../core/design/app_palette.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../domain/app_settings.dart';

/// The theme picker behind the Settings chevron (D-90).
///
/// A modal bottom sheet rather than a route, for the reason
/// [DecimalPlacesSheet] gives: the row shows a chevron, which promises something
/// *below*, and a route would add a back arrow and a screen title that the row
/// never implied.
///
/// Each option carries a **live swatch of the palette it selects** rather than a
/// name alone. The two themes are named Dark and White, which is a promise the
/// UI cannot keep honest on its own — the keypad, the cards and the accent all
/// move when the theme does — so the sheet shows three chips of the real palette
/// and lets the user recognise a theme by what it looks like, the way the
/// sibling Ethar app's Appearance card does.
class ThemeSheet extends StatelessWidget {
  const ThemeSheet({required this.selected, super.key});

  /// The theme in effect now, so the check lands on the right row.
  final AppThemeName selected;

  /// Presents the sheet and resolves to the chosen theme, or `null` if the user
  /// dismissed it without choosing.
  static Future<AppThemeName?> show(
    BuildContext context, {
    required AppThemeName selected,
  }) {
    return showModalBottomSheet<AppThemeName>(
      context: context,
      backgroundColor: context.appColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.dialog),
        ),
      ),
      isScrollControlled: true,
      builder: (context) => ThemeSheet(selected: selected),
    );
  }

  /// The widget key of the row offering [theme].
  ///
  /// The option's label is also the Settings row's own subtitle, so a test
  /// cannot find it by text while the sheet is open without disambiguating —
  /// exactly the trap [DecimalPlacesSheet.optionKey] documents.
  static Key optionKey(AppThemeName theme) => Key('theme-${theme.name}');

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.cardPadding,
                AppSpacing.lg,
                AppSpacing.cardPadding,
                AppSpacing.sm,
              ),
              child: Text('Theme', style: context.type.legalHeading),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.cardPadding,
                0,
                AppSpacing.cardPadding,
                AppSpacing.lg,
              ),
              child: Text(
                'Your display theme. Dark is the original black look; White '
                'matches the Ethar app.',
                style: context.type.rowSubtitle,
              ),
            ),
            for (final theme in AppThemeName.values)
              _ThemeOption(
                key: optionKey(theme),
                theme: theme,
                isSelected: theme == selected,
                // Popping with the value rather than calling back into the
                // notifier keeps the sheet a pure picker: the caller decides
                // whether to persist, and dismissing is free of side effects.
                onTap: () => Navigator.of(context).pop(theme),
              ),
          ],
        ),
      ),
    );
  }
}
class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.theme,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final AppThemeName theme;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final preview = theme == AppThemeName.dark
        ? AppPalette.dark
        : AppPalette.light;

    // D-59: the options are one radio group, so a screen reader should report
    // which is current rather than leaving the user to remember it.
    return Semantics(
      container: true,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      button: true,
      label: theme.label,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSizes.rowMinHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.cardPadding,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    _SwatchStrip(palette: preview),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Text(
                        theme.label,
                        style: context.type.rowTitle,
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check,
                        color: colors.accent,
                        semanticLabel: 'Selected',
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three chips of [palette] — page, card, accent — at thumbnail size.
///
/// Deliberately not a full mockup: the point is for an option to be recognisable
/// at a glance, and three chips say "black page" or "white page" faster than a
/// miniature of a screen would, at a fraction of the height.
class _SwatchStrip extends StatelessWidget {
  const _SwatchStrip({required this.palette});

  final AppPalette palette;

  static const double _side = 34;
  static const double _overlap = 8;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _side * 3 - _overlap * 2,
      height: _side,
      child: Stack(
        children: [
          // The card chip sits over the page chip, so the pair reads as a
          // surface on a page rather than as two unrelated squares.
          _chip(context, palette.background, 0),
          _chip(context, palette.surface, 1),
          _chip(context, palette.accent, 2),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, Color color, int index) => Positioned(
    left: index * (_side - _overlap),
    child: Container(
      width: _side,
      height: _side,
      decoration: BoxDecoration(
        color: color,
        // The hairline is what makes the white card visible *on* the white page
        // — without it the middle chip would vanish into its neighbour and the
        // two themes would look identical in the one place they must not.
        border: Border.all(color: context.appColors.divider),
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  );
}