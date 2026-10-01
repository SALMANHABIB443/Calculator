import 'package:flutter/material.dart';

import '../design/app_spacing.dart';
import '../design/app_typography.dart';

/// Uppercase group label — “APPEARANCE”, “PREFERENCES”, “Today”
/// (desing.md §6.2, §6.3).
///
/// Renders [label] uppercased in the secondary colour so callers pass readable
/// text and cannot ship a label whose casing drifts from the mockups.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.label, {super.key, this.trailing});

  /// The group name, in sentence case as written in the design.
  final String label;

  /// Optional right-hand content, e.g. a count.
  final Widget? trailing;

  /// Top padding above the label — the gap that separates two groups.
  static const double topPadding = 24;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        topPadding,
        AppSpacing.screenHorizontal,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            // D-59: `header: true` so a screen reader can jump between groups
            // instead of reading the list linearly. The uppercase styling is a
            // *visual* device — TalkBack does not infer shouting from letter
            // case, so without this a "PREFERENCES" group is announced exactly
            // like the body text beneath it.
            child: Semantics(
              header: true,
              child: Text(
                label.toUpperCase(),
                style: AppTypography.sectionHeader,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
