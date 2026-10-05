import 'package:calculator/core/design/app_colors.dart';
import 'package:calculator/core/widgets/core_widgets.dart';
import 'package:calculator/features/history/domain/history_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

/// The selection header, which only exists while something is selected.
Finder selectionHeader() => find.byType(AppSelectionHeader);

/// Long-presses the card showing [expression], the gesture that enters
/// selection mode (D-76).
///
/// Targets the card rather than the text: the text is a descendant, and
/// long-pressing it would exercise the same path by accident while leaving the
/// card's own `InkWell` untested.
Future<void> longPressCard(WidgetTester tester, String expression) async {
  await tester.longPress(
    find.ancestor(
      of: find.text(expression),
      matching: find.byType(HistoryCard),
    ),
  );
  await tester.pumpAndSettle();
}

/// [expression] with its result, seeded so the entry lands in "Today" and the
/// grouping never moves a card out from under a tap.
HistoryEntry todayEntry(String expression, String result, double value) =>
    HistoryEntry(
      id: 'id-$expression',
      expression: expression,
      result: result,
      resultValue: value,
      timestamp: DateTime.now(),
    );

/// Three entries, oldest first — the order `mockHistoryStore` wants.
List<HistoryEntry> threeEntries() => [
  todayEntry('1 + 1', '2', 2),
  todayEntry('2 + 2', '4', 4),
  todayEntry('3 + 3', '6', 6),
];

/// The fill and outline a rendered [HistoryCard] is painted with.
///
/// D-76 read these from two widgets because the outline was the wrapper's
/// decoration and the fill was the `Material`'s colour. D-93 removes the split:
/// the fill, the outline, and the shadow are all Ethar `_appCard`'s decoration
/// on one `AnimatedContainer`, and the `Material` is transparent. One widget
/// therefore answers the whole question now — and a test still reading the
/// `Material` for the fill would see `null` and quietly fall back to a default.
({Color fill, Color? outline}) cardPaint(
  WidgetTester tester,
  String expression,
) {
  final card = find.ancestor(
    of: find.text(expression),
    matching: find.byType(HistoryCard),
  );

  final decoration =
      tester
              .widget<AnimatedContainer>(
                find
                    .descendant(
                      of: card,
                      matching: find.byType(AnimatedContainer),
                    )
                    .first,
              )
              .decoration!
          as BoxDecoration;

  return (
    fill: decoration.color ?? AppColors.surface,
    outline: decoration.border == null
        ? null
        : (decoration.border! as Border).top.color,
  );
}

void main() {
  group('entering selection (D-76)', () {
    testWidgets('a long-press selects that one card and swaps the header', (
      tester,
    ) async {
      await pumpApp(tester, history: threeEntries());
      await openHistory(tester);

      // Before: the title header, and no sign of a selection mode at all.
      expect(find.text('History'), findsOneWidget);
      expect(selectionHeader(), findsNothing);

      await longPressCard(tester, '2 + 2');

      expect(find.text('1 selected'), findsOneWidget);
      expect(selectionHeader(), findsOneWidget);
      // Exactly one header: a screen showing both "History" and "1 selected"
      // would give two answers to what mode the user is in.
      expect(find.text('History'), findsNothing);
    });

    testWidgets('a tap while selecting toggles rather than loading', (
      tester,
    ) async {
      await pumpApp(tester, history: threeEntries());
      await openHistory(tester);
      await longPressCard(tester, '2 + 2');

      await tester.tap(find.text('3 + 3'));
      await tester.pumpAndSettle();

      // The second row joined the selection...
      expect(find.text('2 selected'), findsOneWidget);
      // ...and the screen did NOT go back to the calculator, which is what a
      // resting tap does. Losing the mode mid-way would be the whole bug. The
      // proof is the selection bar still being there — the "History" title is
      // not, because the two headers are swapped, not stacked.
      expect(selectionHeader(), findsOneWidget);
      expect(find.byType(HistoryCard), findsNWidgets(3));

      // Tapping it again takes it back out.
      await tester.tap(find.text('3 + 3'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets(
      'a resting card still loads its result (D-76 regression guard)',
      (tester) async {
        await pumpApp(tester, history: threeEntries());
        await openHistory(tester);

        await tester.tap(find.text('2 + 2'));
        await tester.pumpAndSettle();

        // The resting behaviour is untouched: no selection, and the calculator is
        // showing the loaded value.
        expect(selectionHeader(), findsNothing);
        expect(find.text('History'), findsNothing);
      },
    );
  });

  group('the selection is white, not orange (D-76)', () {
    testWidgets('a selected card is tinted, outlined in white, ticked black', (
      tester,
    ) async {
      await pumpApp(tester, history: threeEntries());
      await openHistory(tester);
      await longPressCard(tester, '2 + 2');

      final selected = cardPaint(tester, '2 + 2');
      final resting = cardPaint(tester, '1 + 1');

      // The chosen row is lifted off the page and outlined in the accent.
      expect(selected.fill, AppColors.surfaceSelected);
      expect(selected.fill, isNot(AppColors.surface));
      expect(selected.outline, AppColors.selectionAccent);

      // The unchosen row keeps its resting fill and its *resting* outline —
      // D-76's "no stray outline on every row" no longer holds, because D-93
      // gives every card a 1 px outline the way Ethar's `_appCard` does. What
      // still has to hold is that selection does not leak onto it, so the
      // assertion is that its outline is the resting one and not the accent.
      expect(resting.fill, AppColors.surface);
      expect(resting.outline, AppColors.cardBorder);
      expect(resting.outline, isNot(AppColors.selectionAccent));

      // White, not the orange the sibling app uses. This is the whole point of
      // D-76: selection is a *mode*, and orange in this palette means "primary
      // action", so three selected rows would read as three button presses.
      expect(AppColors.selectionAccent, isNot(AppColors.accent));
      expect(AppColors.selectionAccent, AppColors.textPrimary);

      // And the tick is black, because a white tick on a white circle is
      // invisible.
      expect(AppColors.selectionCheck, isNot(AppColors.selectionAccent));
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('2 + 2'),
            matching: find.byType(HistoryCard),
          ),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
    });
  });
  group('select all (D-76)', () {
    testWidgets('selects every entry, then clears on a second press', (
      tester,
    ) async {
      await pumpApp(tester, history: threeEntries());
      await openHistory(tester);
      await longPressCard(tester, '2 + 2');

      await tester.tap(find.byKey(const Key('selection-select-all')));
      await tester.pumpAndSettle();
      expect(find.text('3 selected'), findsOneWidget);

      // The action flips to "deselect all" rather than silently doing nothing,
      // so the second press clears instead of re-adding.
      await tester.tap(find.byKey(const Key('selection-select-all')));
      await tester.pumpAndSettle();

      // Clearing the last selection leaves the mode entirely.
      expect(selectionHeader(), findsNothing);
      expect(find.text('History'), findsOneWidget);
    });

    testWidgets('on / off / on lands back on all-selected', (tester) async {
      await pumpApp(tester, history: threeEntries());
      await openHistory(tester);
      await longPressCard(tester, '2 + 2');

      // Starts at one selected, so the sequence is 1 → 3 → 0 → 3. The third
      // press has to land on "all selected" again rather than on whatever state
      // the previous two left behind — the action's icon and its meaning both
      // flip on `allVisibleSelected`, and getting that out of step would leave
      // a button that says "select all" and removes everything.
      expect(find.text('1 selected'), findsOneWidget);
      await tester.tap(find.byKey(const Key('selection-select-all')));
      await tester.pumpAndSettle();
      expect(find.text('3 selected'), findsOneWidget);

      // Clearing everything leaves the mode, so the bar is gone and the
      // action is re-entered by long-pressing a row again.
      await tester.tap(find.byKey(const Key('selection-select-all')));
      await tester.pumpAndSettle();
      expect(selectionHeader(), findsNothing);

      await longPressCard(tester, '2 + 2');
      await tester.tap(find.byKey(const Key('selection-select-all')));
      await tester.pumpAndSettle();

      expect(find.text('3 selected'), findsOneWidget);
    });
  });

  group('leaving selection without deleting (D-76)', () {
    testWidgets('the cancel action keeps every entry', (tester) async {
      await pumpApp(tester, history: threeEntries());
      await openHistory(tester);
      await longPressCard(tester, '2 + 2');

      await tester.tap(find.byKey(const Key('selection-cancel')));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryCard), findsNWidgets(3));
      expect(historyExpressions(tester), ['3 + 3', '2 + 2', '1 + 1']);
      expect(find.text('History'), findsOneWidget);
    });

    testWidgets('the back gesture cancels the selection, not the screen', (
      tester,
    ) async {
      await pumpApp(tester, history: threeEntries());
      await openHistory(tester);
      await longPressCard(tester, '2 + 2');

      // What PopScope intercepts is the system back gesture, so that is what is
      // driven here rather than the header's arrow.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Still on History with all three entries: the mode yielded, the page did
      // not. A mode that swallowed back would make this screen unreachable by
      // the gesture every other pushed screen answers to.
      expect(find.byType(HistoryCard), findsNWidgets(3));
      expect(selectionHeader(), findsNothing);
    });

    testWidgets('the bottom Clear History action is hidden while selecting', (
      tester,
    ) async {
      await pumpApp(tester, history: threeEntries());
      await openHistory(tester);
      expect(find.byKey(const Key('history-clear-button')), findsOneWidget);

      await longPressCard(tester, '2 + 2');

      // "Clear History" and "Delete 2 selected" are two different destructive
      // actions in the same slot. A user who chose two rows and tapped the
      // button must not lose all three.
      expect(find.byKey(const Key('history-clear-button')), findsNothing);
    });
  });
  group('deleting a selection requires confirmation (D-76, D-05)', () {
    testWidgets('cancelling the dialog deletes nothing', (tester) async {
      await pumpApp(tester, history: threeEntries());
      await openHistory(tester);
      await longPressCard(tester, '2 + 2');
      await tester.tap(find.text('3 + 3'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('selection-delete')));
      await tester.pumpAndSettle();

      // The dialog states how many, in the plural, and nothing is gone yet.
      expect(find.text('Delete these 2 items?'), findsOneWidget);
      expect(find.text('Delete this item?'), findsNothing);
      expect(find.byType(HistoryCard), findsNWidgets(3));

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryCard), findsNWidgets(3));
      expect(historyExpressions(tester), ['3 + 3', '2 + 2', '1 + 1']);
    });

    testWidgets('confirming deletes exactly the selected entries', (
      tester,
    ) async {
      await pumpApp(tester, history: threeEntries());
      await openHistory(tester);
      await longPressCard(tester, '2 + 2');
      await tester.tap(find.byKey(const Key('selection-select-all')));
      await tester.pumpAndSettle();
      // Back down to two, so the assertion proves the delete follows the
      // *selection* rather than "everything that was on screen a moment ago".
      // '1 + 1' is the one that drops out, so it is the one that must survive.
      await tester.tap(find.text('1 + 1'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.byKey(const Key('selection-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      // Only '2 + 2' and '3 + 3' were chosen, so '1 + 1' is the survivor.
      expect(historyExpressions(tester), ['1 + 1']);
      expect(find.byType(HistoryCard), findsOneWidget);
    });

    testWidgets(
      'the singular dialog drops the number rather than miscounting',
      (tester) async {
        await pumpApp(tester, history: threeEntries());
        await openHistory(tester);
        await longPressCard(tester, '2 + 2');

        await tester.tap(find.byKey(const Key('selection-delete')));
        await tester.pumpAndSettle();

        // "Delete 1 item?" reads as a bug; "Delete this item?" reads as deliberate.
        expect(find.text('Delete this item?'), findsOneWidget);
        expect(
          find.text('This will permanently delete the selected calculation.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('a delete that empties the list lands on the empty state', (
      tester,
    ) async {
      await pumpApp(tester, history: threeEntries());
      await openHistory(tester);
      await longPressCard(tester, '2 + 2');
      await tester.tap(find.byKey(const Key('selection-select-all')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('selection-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      // The selection is cleared along with the rows, so the screen does not
      // come back claiming a count that no longer exists.
      expect(selectionHeader(), findsNothing);
      expect(find.text('No calculations yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a cleared selection leaves the screen usable', (tester) async {
      await pumpApp(tester, history: threeEntries());
      await openHistory(tester);
      // Only one row chosen, so two survive the delete and there is something
      // left to prove the screen still works afterwards.
      await longPressCard(tester, '2 + 2');

      await tester.tap(find.byKey(const Key('selection-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(historyExpressions(tester), ['3 + 3', '1 + 1']);

      // Back to the resting screen: title header back, one card left, and that
      // card loads its result — the mode was left, not just the data.
      expect(selectionHeader(), findsNothing);
      expect(find.text('History'), findsOneWidget);
      expect(find.byKey(const Key('history-clear-button')), findsOneWidget);

      await tester.tap(find.text('3 + 3'));
      await tester.pumpAndSettle();
      expect(find.text('History'), findsNothing);
    });
  });
}
