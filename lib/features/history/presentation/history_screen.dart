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

import '../../../../core/design/app_palette.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/widgets/core_widgets.dart';
import '../../calculator/presentation/calculator_controller.dart';
import '../data/history_repository.dart';
import '../domain/history_entry.dart';
import 'history_controller.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

/// Holds the multi-select state the screen did not previously need (D-76).
///
/// A [ConsumerState] rather than a provider on purpose: a selection is a property
/// of *this visit to this screen*. It is not derived from storage, it is not
/// read by any other widget, and it must be gone the moment the user leaves —
/// all three of which a scoped notifier would have to be told about, and a
/// future that survived a back-and-forth would leave rows ticked for a delete
/// the user never asked for.
class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  /// Ids of the entries the user has chosen; order is irrelevant.
  ///
  /// Ids rather than entries because the list re-groups and re-reads from
  /// storage on every write; a held [HistoryEntry] would go stale the moment the
  /// calculator recorded something new.
  final Set<String> _selectedIds = <String>{};

  /// Whether the screen is in selection mode.
  ///
  /// Derived from the set rather than stored, so there is no state in which a
  /// flag says yes and the set is empty — the mode cannot be entered and then
  /// quietly left behind.
  bool get _selecting => _selectedIds.isNotEmpty;

  /// Leaves selection mode, keeping every entry.
  void _cancelSelection() {
    if (_selectedIds.isEmpty) return;
    setState(_selectedIds.clear);
  }

  /// Adds or removes one entry from the selection.
  void _toggleSelection(String id) {
    setState(() {
      _selectedIds.contains(id)
          ? _selectedIds.remove(id)
          : _selectedIds.add(id);
    });
  }

  /// Selects every entry on screen, or clears the selection when they are all
  /// selected already.
  ///
  /// Takes the entries rather than reading the rendered widgets: a card scrolled
  /// out of view is still visible *in the list*, and a "Select all" that skipped
  /// it would leave the header claiming a count the user cannot account for.
  void _selectAllVisible(List<HistoryEntry> entries) {
    final ids = {for (final entry in entries) entry.id};
    setState(() {
      ids.every(_selectedIds.contains)
          ? _selectedIds.removeAll(ids)
          : _selectedIds.addAll(ids);
    });
  }

  /// Deletes the chosen entries, after the same confirmation gate every other
  /// destructive path on this screen goes through (D-05, AC-008).
  Future<void> _deleteSelected(int count) async {
    final ids = Set<String>.from(_selectedIds);
    if (!mounted) return;

    final confirmed = await AppConfirmationDialog.show(
      context,
      // Pluralised, and the singular drops the number: "Delete this item?" reads
      // as deliberate where "Delete 1 item?" reads as a miscount, and the
      // dialog that states *how many* is about to be deleted is the last place
      // to get that wrong.
      title: count == 1 ? 'Delete this item?' : 'Delete these $count items?',
      message: count == 1
          ? 'This will permanently delete the selected calculation.'
          : 'This will permanently delete $count saved calculations.',
      confirmLabel: 'Delete',
    );

    if (!confirmed || !mounted) return;

    await ref.read(historyControllerProvider.notifier).deleteSelected(ids);
    // The entries are gone, so their ids must not outlive them. Leaving the set
    // alone would have the header keep claiming rows that no longer exist, and
    // a second tap on the delete button would come back with an empty delete.
    if (mounted) setState(_selectedIds.clear);
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyControllerProvider);
    final selecting = _selecting;

    // Stated once because the button's *behaviour* and its *paint* have to
    // agree. A white icon that does nothing reads as a working button that is
    // merely not responding, which is worse than either an enabled button or a
    // visibly inert one — so nothing to clear means grey, not white.
    final groups = history.valueOrNull;
    final hasEntries = groups != null && groups.isNotEmpty;

    // Every entry on screen, flattened out of the day groups. Read once here so
    // the header's "all selected" test and the select-all action cannot
    // disagree about what "everything" means.
    final visible = <HistoryEntry>[
      for (final group in groups ?? const <HistoryDayGroup>[])
        for (final entry in group.entries) entry,
    ];

    return PopScope(
      // D-76: keyed so a test can reach the gate itself rather than inferring
      // it from the route stack.
      key: const Key('history-selection-scope'),
      // D-76: the system back gesture cancels the selection rather than leaving
      // the screen. A mode that swallowed the back button would make this screen
      // unreachable by the gesture every other pushed screen answers to, and
      // losing a selection is a far smaller loss than losing the page.
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && selecting) _cancelSelection();
      },
      child: SecondaryPageScaffold(
        // One header, swapped rather than stacked (D-76): a screen showing both
        // "History" and "3 selected" would give two answers to what mode the
        // user is in, and the delete action would have nowhere to sit.
        header: selecting
            ? AppSelectionHeader(
                count: _selectedIds.length,
                allVisibleSelected:
                    visible.isNotEmpty &&
                    visible.every(
                      (entry) => _selectedIds.contains(entry.id),
                    ),
                onSelectAll: () => _selectAllVisible(visible),
                onDelete: () => _deleteSelected(_selectedIds.length),
                onCancel: _cancelSelection,
              )
            : SecondaryPageHeader(
                title: 'History',
                // D-74: the action is one of the shared bordered boxes, and the
                // box is what rides the 24 px margin the cards below it sit on.
                // The title is centred by the header's own left/right symmetry
                // rather than by a start-alignment flag.
                trailing: AppIconButton(
                  // D-38: the header trash is part of the fixed header D-10
                  // specifies, so it stays put even with nothing to delete — but
                  // it returns early rather than opening a confirmation for an
                  // empty list.
                  onPressed: hasEntries
                      ? () => _confirmClear(context, ref)
                      : null,
                  // D-73: the design's own trash rather than Material's
                  // `delete_outline`. The bottom action paints the same widget,
                  // so the screen still has exactly one delete glyph on it. The
                  // colour is still the screen's to decide: a painted glyph does
                  // not read `disabledForegroundColor` the way a Material one
                  // does, so it is spelled out here.
                  iconWidget: AppTrashIcon(
                    color: hasEntries
                        ? context.appColors.textPrimary
                        : context.appColors.textSecondary,
                  ),
                  tooltip: 'Clear History',
                ),
              ),
        body: _HistoryBody(
          history: history,
          selectedIds: _selectedIds,
          onToggle: _toggleSelection,
          onClearAll: () => _confirmClear(context, ref),
        ),
      ),
    );
  }

  /// D-05: both entry points to clearing route through one dialog, and nothing
  /// is deleted until the user confirms (AC-008).
  ///
  /// An instance method rather than the static one it replaced, because the
  /// header and the bottom action now reach it from inside the state rather than
  /// through `HistoryScreen._confirmClear`, and passing a [WidgetRef] down to a
  /// widget that has no need for one only spreads the coupling.
  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
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
  const _HistoryBody({
    required this.history,
    required this.selectedIds,
    required this.onToggle,
    required this.onClearAll,
  });

  final AsyncValue<List<HistoryDayGroup>> history;

  /// The entries the user has chosen (D-76).
  ///
  /// Passed down rather than reached for: the body is a `ConsumerWidget` with no
  /// access to the screen's state, and threading the set in is what keeps the
  /// selection in one place — the place that has to forget it.
  final Set<String> selectedIds;

  /// Adds or removes one entry by id (D-76).
  final void Function(String id) onToggle;

  /// Opens the Clear History confirmation (D-05).
  final VoidCallback onClearAll;

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
      AsyncData(:final value) => _HistoryList(
        groups: value,
        selectedIds: selectedIds,
        onToggle: onToggle,
        onClearAll: onClearAll,
      ),
      _ => Center(
        key: Key('history-loading'),
        child: CircularProgressIndicator(color: context.appColors.accent),
      ),
    };
  }
}

/// The day-grouped cards, plus the Clear History action pinned below them
/// (desing.md §6.2).
class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.groups,
    required this.selectedIds,
    required this.onToggle,
    required this.onClearAll,
  });

  final List<HistoryDayGroup> groups;

  /// The entries the user has chosen (D-76).
  final Set<String> selectedIds;

  /// Adds or removes one entry by id (D-76).
  final void Function(String id) onToggle;

  /// Opens the Clear History confirmation (D-05).
  final VoidCallback onClearAll;

  /// Whether the list is multi-selecting.
  ///
  /// Derived from [selectedIds] for the same reason the screen derives it: one
  /// source of truth, so the cards cannot draw checkboxes while the bottom
  /// action still offers to clear everything.
  bool get _selecting => selectedIds.isNotEmpty;

  @override
  Widget build(BuildContext context) {
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
              for (final group in groups) ..._sliversFor(context, group),
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
        //
        // D-76: also hidden while selecting. "Clear History" and "Delete 3
        // selected" are two different destructive actions wearing the same
        // bottom slot, and the user who has just chosen three rows and then
        // taps the button expecting to delete three rows must not lose all
        // seven instead.
        if (!_selecting) _ClearHistoryAction(onPressed: onClearAll),
      ],
    );
  }

  /// A day label followed by its cards.
  ///
  /// [HistoryDayLabel] supplies its own [AppSpacing.screenHorizontal] side
  /// padding, so the slivers below add none — [HistoryCard] brings its own too.
  List<Widget> _sliversFor(BuildContext context, HistoryDayGroup group) => <Widget>[
    SliverToBoxAdapter(child: HistoryDayLabel(group.label)),
    SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final entry = group.entries[index];
        final selected = selectedIds.contains(entry.id);
        return HistoryCard(
          expression: entry.expression,
          result: entry.result,
          // D-76: a long-press enters selection; a *tap* toggles while the mode
          // is already on. The tap has to change meaning, because a user who
          // has already entered selection mode and then taps a row means
          // "include this one" — popping back to the calculator with the
          // result loaded would throw away the mode they are halfway through.
          onTap: _selecting
              ? () => onToggle(entry.id)
              : () => _load(context, entry),
          onLongPress: () => onToggle(entry.id),
          selecting: _selecting,
          selected: selected,
        );
      }, childCount: group.entries.length),
    ),
  ];

  /// FEAT-HIST-002 / AC-003: load the result and go back to the Calculator.
  ///
  /// `pop` rather than `go`, because the calculator pushed this route, so the
  /// user returns to the screen they left instead of the stack being rebuilt.
  ///
  /// Takes only a [BuildContext] now that the list is a plain [StatelessWidget]
  /// (D-76): the [WidgetRef] it used to carry was read once, for the
  /// calculator controller, and [calculatorControllerProvider] is a plain
  /// `Provider` readable from any context's container — carrying a ref into a
  /// widget that has no other use for one would only tie this list to Riverpod.
  void _load(BuildContext context, HistoryEntry entry) {
    final calculator = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(calculatorControllerProvider.notifier);
    calculator.loadResult(entry.resultValue);
    context.pop();
  }
}

/// The bottom action: orange text with a trash icon, centred (desing.md §6.2,
/// feature.md FEAT-HIST-003).
///
/// A plain tap opens the Clear History confirmation (D-05).
class _ClearHistoryAction extends StatelessWidget {
  const _ClearHistoryAction({required this.onPressed});

  /// A tap — the Clear History confirmation (D-05).
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
            foregroundColor: context.appColors.accent,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          ),
          icon: AppTrashIcon(
            size: AppIconSize.row,
            color: context.appColors.accent,
          ),
          label: Text('Clear History', style: context.type.bottomAction),
        ),
      ),
    );
  }
}