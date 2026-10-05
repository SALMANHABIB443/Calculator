import '../../../../core/design/app_palette.dart';
import 'package:flutter/material.dart';

import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../domain/app_settings.dart';

/// The Decimal Places picker behind the Settings chevron (feature.md
/// FEAT-SET-004, D-46).
///
/// A modal bottom sheet rather than a route. `prd.md`'s navigation map calls this
/// a "sub-screen", but no mockup of one exists, so the sheet is chosen for the
/// affordance the row actually shows: a chevron promising something *below*. A
/// route would also buy a back arrow and a screen title that have no
/// counterpart in any mockup, and this setting is a single choice, not a place
/// the user can get lost in. Seven options fit without scrolling.
class DecimalPlacesSheet extends StatelessWidget {
  const DecimalPlacesSheet({required this.selected, super.key});

  /// The precision currently in effect, so the check lands on the right row
  /// before the user touches anything.
  final int selected;

  /// Presents the sheet and returns the chosen precision, or `null` if the user
  /// dismissed it without choosing.
  static Future<int?> show(BuildContext context, {required int selected}) {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: context.appColors.surface,
      // The platform drag handle and the default rounded top corners are
      // Material's, not the app's; the app's shapes come from AppRadius.
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.dialog),
        ),
      ),
      isScrollControlled: true,
      builder: (context) => DecimalPlacesSheet(selected: selected),
    );
  }

  /// The widget key of the row offering [places].
  ///
  /// The option's label is also the Settings row's own subtitle, so a test
  /// cannot find it by text while the sheet is open without disambiguating.
  /// Exposing the key from here keeps the two sides from drifting.
  static Key optionKey(int places) => Key('decimal-places-$places');

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      // Without `isScrollControlled` the sheet is capped at a fraction of the
      // screen and the rows are clipped rather than scrollable. Seven options
      // plus a heading and a caption clear the 442x890 phone in desing.md §9,
      // but not every viewport, and not a user who has turned Dynamic Type up.
      // The scroll view is what makes the sheet safe on both, and it costs
      // nothing when the content already fits.
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
              child: Text('Decimal Places', style: context.type.legalHeading),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.cardPadding,
                0,
                AppSpacing.cardPadding,
                AppSpacing.lg,
              ),
              child: Text(
                'Rounding for results only. Values you are still typing are '
                'left as entered.',
                style: context.type.rowSubtitle,
              ),
            ),
            for (final places in AppSettings.decimalPlacesOptions)
              _DecimalPlacesOption(
                key: optionKey(places),
                places: places,
                isSelected: places == selected,
                // Popping with the value rather than calling back into the
                // notifier keeps the sheet a pure picker: the caller decides
                // whether to persist, and dismissing is free of side effects.
                onTap: () => Navigator.of(context).pop(places),
              ),
          ],
        ),
      ),
    );
  }
}

class _DecimalPlacesOption extends StatelessWidget {
  const _DecimalPlacesOption({
    required this.places,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final int places;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // D-59: the seven options are one radio group, so a screen reader should
    // report which is current rather than reading a bare "Selected" and
    // leaving the user to remember the list. `Semantics(selected:)` is what a
    // screen reader announces as the checked item; the visual check below is
    // excluded so the two do not stack into a doubled word.
    return Semantics(
      container: true,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      button: true,
      label: _label(places),
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSizes.rowMinHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.cardPadding,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _label(places),
                        style: context.type.rowTitle,
                      ),
                    ),
                    // A check rather than a radio: the accent is reserved for
                    // primary actions, and a single checked row among unselected
                    // ones is the same signal without competing with the operator
                    // keys for attention (desing.md §5.4).
                    if (isSelected)
                      Icon(
                        Icons.check,
                        color: context.appColors.accent,
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

  /// Matches the row subtitle the specification quotes — “2 decimal places” —
  /// including the singular for one place, which the docs never pin down.
  static String _label(int places) =>
      '$places decimal ${places == 1 ? 'place' : 'places'}';
}