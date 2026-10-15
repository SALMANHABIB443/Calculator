import 'package:flutter/material.dart';

import '../../../../core/design/app_spacing.dart';
import '../../../../core/widgets/core_widgets.dart';

/// The hidden area's inline search bar: a bare back arrow beside a filled,
/// borderless field, sitting exactly where the page's own header sits.
///
/// **One widget rather than four copies.** The Vault page grew this search bar
/// first (it replaces its header in place when the search icon is tapped), and
/// the gallery, the documents page, and the recycle bin each want the *same*
/// search experience rather than their own version of it. The alternative —
/// each screen hand-drawing a `Row` around an `AppIconButton` and a `TextField`
/// — is how four search bars start to disagree about the fill, the corner
/// radius, or whether a clear button exists at all. Extract it once and the
/// four screens are the same search bar by construction.
///
/// **The field is filled rather than outlined.** The list pages used to show a
/// bordered `TextField` on a padded row *below* the header; this is the search
/// bar the Vault page already ships — a soft grey fill with no outline, drawn
/// at the header's own height and margin so opening search reads as the header
/// itself changing rather than a second bar sliding in. The back arrow closes
/// search ([AppIconButton] with `bordered: false`) so the field has the whole
/// row to grow into, and clearing the query is the field's own trailing `×`
/// rather than a separate control.
class VaultSearchHeader extends StatelessWidget {
  const VaultSearchHeader({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClose,
    required this.hintText,
    this.fieldKey,
    super.key,
  });

  /// The text the field shows and edits.
  final TextEditingController controller;

  /// The current query, so the trailing clear button can appear only when there
  /// is something to clear.
  final String query;

  /// Called on every keystroke — and once with `''` when the clear button is
  /// tapped, so a caller has one place to react to the text changing.
  final ValueChanged<String> onChanged;

  /// Leaves search: restores whatever header and body the page shows at rest.
  final VoidCallback onClose;

  /// The field's placeholder, e.g. `'Search documents'`.
  final String hintText;

  /// The handle a test reaches the field by. Optional so the field can also be
  /// found through its hint, but every list page passes its own published key.
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    // The left inset is the tighter `md` the Vault page uses for its back
    // arrow — a back arrow that reads as closing the field rather than as a
    // screen-level action — while the right stays on the page's 24 px margin,
    // matching every other header in the app (D-74).
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.screenHorizontal,
        top: AppSpacing.headerTopGap,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.headerHeight),
        child: Row(
          children: [
            AppIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Close search',
              onPressed: onClose,
              bordered: false,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                key: fieldKey,
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: hintText,
                  filled: true,
                  fillColor: Colors.grey.withValues(alpha: 0.15),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Clear search',
                          onPressed: () {
                            controller.clear();
                            onChanged('');
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
