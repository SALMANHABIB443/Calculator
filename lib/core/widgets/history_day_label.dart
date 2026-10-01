import 'package:flutter/material.dart';

import '../design/app_spacing.dart';
import '../design/app_typography.dart';

/// The day a group of history cards belongs to — “Today”, “Yesterday”
/// (introduced in **D-72**, rescaled in **D-73**).
///
/// Sentence case at a size of its own, which is the whole difference between
/// this and [SectionHeader]: the shared component uppercases its label at 14 px
/// for "APPEARANCE" and "PREFERENCES", while the History list wants a 17 px
/// light-gray heading that separates one day from the next. Reusing
/// [SectionHeader] would mean restyling Settings and About too, so this screen
/// gets its own label rather than a fourth mode of theirs.
///
/// It brings its own [AppSpacing.screenHorizontal] side padding, so a caller
/// must not add another — see `history_screen.dart`.
class HistoryDayLabel extends StatelessWidget {
  const HistoryDayLabel(this.label, {super.key});

  /// The day name, in the sentence case the grouping rule produced.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.screenHorizontal,
        right: AppSpacing.screenHorizontal,
        // The space above the label is what separates two *groups*; the space
        // below it belongs to the label, not to the day it introduces.
        top: AppSpacing.historyGroupGap,
        bottom: AppSpacing.sm,
      ),
      // D-59: `header: true` so a screen reader can jump between days instead of
      // reading the list linearly. The size is a *visual* device — TalkBack does
      // not infer a heading from a large grey sentence — so without this flag
      // "Today" is announced exactly like the expressions beneath it.
      child: Semantics(
        header: true,
        child: Text(label, style: AppTypography.historyDayLabel),
      ),
    );
  }
}
