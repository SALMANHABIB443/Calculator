/// Past calculations, grouped by day (desing.md §6.2, mockup `02_17_57`).
///
/// The screen owns three concerns and nothing else: which body to show for the
/// repository's current state, the two destructive actions behind their
/// confirmation gate, and handing a tapped result to the calculator. Reading
/// storage, deciding what to record, and grouping by day all happen below this
/// file, so none of that is reachable from here.
///
/// The page was rebuilt in **D-72** and rescaled in **D-73**: a black screen with
/// a start-aligned "History" title, a bare trash, and rounded cards. D-72's
/// cards were 150 pt tall, inset 48 px, and printed a 44 pt result; D-73 returns
/// the type to desing.md §3's bands and the cards to the app's 24 px margin, and
/// gives both delete actions the design's own trash glyph. Only the presentation
/// changed — grouping, persistence, the confirmation gate, and tap-to-load are
/// the code that was already here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/widgets/core_widgets.dart';
import '../../calculator/presentation/calculator_controller.dart';
import '../data/history_repository.dart';
import '../domain/history_entry.dart';
import 'history_controller.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyControllerProvider);

    // Stated once because the button's *behaviour* and its *paint* have to
    // agree. A white icon that does nothing reads as a working button that is
    // merely not responding, which is worse than either an enabled button or a
    // visibly inert one — so nothing to clear means grey, not white.
    final hasEntries = history.valueOrNull != null && history.value!.isNotEmpty;
    final trashColor = hasEntries
        ? AppColors.textPrimary
        : AppColors.textSecondary;

    return SecondaryPageScaffold(
      header: SecondaryPageHeader(
        title: 'History',
        // D-74: the action is one of the shared bordered boxes, and the box is
        // what rides the 24 px margin the cards below it sit on. The title is
        // centred by the header's own left/right symmetry rather than by a
        // start-alignment flag.
        trailing: AppIconButton(
          // D-38: the header trash is part of the fixed header D-10 specifies, so
          // it stays put even with nothing to delete — but it returns early
          // rather than opening a confirmation for an empty list.
          onPressed: hasEntries ? () => _confirmClear(context, ref) : null,
          // D-73: the design's own trash rather than Material's `delete_outline`.
          // The bottom action paints the same widget, so the screen still has
          // exactly one delete glyph on it. The colour is still the screen's to
          // decide: a painted glyph does not read `disabledForegroundColor` the
          // way a Material one does, so `trashColor` above is what greys the
          // inert state.
          iconWidget: AppTrashIcon(color: trashColor),
          tooltip: 'Clear History',
        ),
      ),
      body: _HistoryBody(history: history),
    );
  }

  /// D-05: both entry points to clearing route through one dialog, and nothing
  /// is deleted until the user confirms (AC-008).
  static Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(historyControllerProvider.notifier);

    final confirmed = await AppConfirmationDialog.show(
      context,
      title: 'Clear history?',
      message: 'This will permanently delete all your saved calculations.',
      confirmLabel: 'Clear',
    );

    if (confirmed) await notifier.clearAll();
  }
}

/// Picks the body for the repository's state.
///
/// Loading, failed, and empty are three separate branches rather than one
/// "nothing here" case: an empty history is a normal state the user should see
/// a reassuring message about, and a failed read is a different problem with a
/// different remedy. Collapsing them would show "No calculations yet" for a
/// storage failure, which is a lie.
class _HistoryBody extends ConsumerWidget {
  const _HistoryBody({required this.history});

  final AsyncValue<List<HistoryDayGroup>> history;

  /// What the user is told when the read fails (D-58).
  ///
  /// A fixed sentence, never the exception itself. `struction.md` §12 requires
  /// the presentation layer to map errors to user-visible messages, and this
  /// branch used to interpolate `'$error'` — which put `Exception: ...` and
  /// platform detail in front of the user for a fully offline app where the
  /// only useful thing to say is that the app could not read its own storage.
  static const String _errorMessage =
      'Your saved calculations could not be read. '
      'Try again, or restart the app.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (history) {
      AsyncError() => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load history',
        message: _errorMessage,
        // The one state with a remedy: the repository falls back to memory when
        // `shared_preferences` is unavailable (D-44), so a retry is a real
        // second attempt rather than a decorative button.
        action: TextButton(
          key: const Key('history-retry'),
          onPressed: () => ref.invalidate(historyControllerProvider),
          child: const Text('Try again'),
        ),
      ),
      AsyncData(:final value) when value.isEmpty => const EmptyState(
        icon: Icons.history,
        title: 'No calculations yet',
        message: 'Results you calculate will appear here.',
        // D-72: 40 px, not the 44 px [AppIconSize.hero] the empty state
        // defaults to — that bucket is sized for the About brand mark, and a
        // placeholder glyph as large as the app's own logo reads as a missing
        // asset rather than as "nothing here yet".
        iconSize: AppIconSize.illustration,
      ),
      AsyncData(:final value) => _HistoryList(groups: value),
      _ => const Center(
        key: Key('history-loading'),
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
    };
  }
}

/// The day-grouped cards, plus the Clear History action pinned below them
/// (desing.md §6.2).
class _HistoryList extends ConsumerWidget {
  const _HistoryList({required this.groups});

  final List<HistoryDayGroup> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            key: const Key('history-list'),
            slivers: <Widget>[
              // The scroll view starts below the header rather than flush under
              // it: the first day label carries its own [AppSpacing.historyGroupGap]
              // for the days that follow it, and a gap that only applies from the
              // second group onwards would put the newest day hard against the
              // title. One `lg` puts the whole page's top rhythm back in balance
              // (D-72).
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
              for (final group in groups) ..._sliversFor(context, ref, group),
              // Clears the gesture bar / home indicator, and keeps the last card
              // from being the thing a scroll fling ends on.
              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.bottomSafe),
              ),
            ],
          ),
        ),
        // D-38: hidden when there is nothing to clear. The header trash stays
        // visible, so the action remains reachable either way.
        _ClearHistoryAction(
          onPressed: () => HistoryScreen._confirmClear(context, ref),
        ),
      ],
    );
  }

  /// A day label followed by its cards.
  ///
  /// [HistoryDayLabel] supplies its own [AppSpacing.screenHorizontal] side
  /// padding, so the slivers below add none — [HistoryCard] brings its own too.
  List<Widget> _sliversFor(
    BuildContext context,
    WidgetRef ref,
    HistoryDayGroup group,
  ) => <Widget>[
    SliverToBoxAdapter(child: HistoryDayLabel(group.label)),
    SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => HistoryCard(
          expression: group.entries[index].expression,
          result: group.entries[index].result,
          onTap: () => _load(context, ref, group.entries[index]),
        ),
        childCount: group.entries.length,
      ),
    ),
  ];

  /// FEAT-HIST-002 / AC-003: load the result and go back to the Calculator.
  ///
  /// `pop` rather than `go`, because the calculator pushed this route, so the
  /// user returns to the screen they left instead of the stack being rebuilt.
  void _load(BuildContext context, WidgetRef ref, HistoryEntry entry) {
    ref
        .read(calculatorControllerProvider.notifier)
        .loadResult(entry.resultValue);
    context.pop();
  }
}

/// The bottom action: orange text with a trash icon, centred (desing.md §6.2,
/// feature.md FEAT-HIST-003).
class _ClearHistoryAction extends StatelessWidget {
  const _ClearHistoryAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.md,
        AppSpacing.screenHorizontal,
        AppSpacing.bottomSafe,
      ),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          key: const Key('history-clear-button'),
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          ),
          icon: const AppTrashIcon(
            size: AppIconSize.row,
            color: AppColors.accent,
          ),
          label: Text('Clear History', style: AppTypography.bottomAction),
        ),
      ),
    );
  }
}
