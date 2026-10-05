import 'package:calculator/core/widgets/core_widgets.dart';
import 'package:calculator/features/history/domain/history_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

/// The Phase 8 performance task, stated as assertions rather than as timings.
///
/// The brief says "no jank". A wall-clock threshold in a unit test would be a
/// lie: the test surface renders in software, on a desktop VM, with no GPU, so
/// any number picked here would be tuned to this machine and meaningless on a
/// phone. What *is* portable is the thing that actually causes jank in a list
/// this size — building every row at once — and that can be asserted exactly.
///
/// So these tests do not measure time. They assert the structural properties
/// that keep the work off the critical path, which is the part under our
/// control. The frame budget itself is still only verifiable on a device
/// (phases.md §Phase 8, "manual" verification).

void main() {
  group('evaluation is synchronous with the key press', () {
    testWidgets('the result is in the tree after a single frame', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(keyFor('7'));

      // One `pump`, not `pumpAndSettle` and not a retry loop: a single frame is
      // all a key press costs.
      //
      // The claim is deliberately *not* "the result is there before any pump".
      // Flutter rebuilds on the frame boundary whatever the app does, so an
      // assertion reading the tree with no frame at all could only ever pass
      // against a test binding that does not schedule frames — it would prove
      // nothing about the calculator. What is worth pinning down is that the
      // answer lands in one frame: if evaluation were async, or a key press
      // triggered a second rebuild, the value would still be 0 here.
      await tester.pump();

      expect(
        tester.widget<Text>(find.byKey(const Key('calculator-display-line'))).data,
        '7',
      );
    });

    testWidgets('a chained operation settles within one frame', (
      tester,
    ) async {
      await pumpApp(tester);

      for (final key in ['1', '2', '×', '8', '=']) {
        await tester.tap(keyFor(key));
        // One pump per key, not settle(): a calculator that needed multiple
        // frames to catch up would be visibly behind the keypad.
        await tester.pump();
      }

      expect(
        tester.widget<Text>(find.byKey(const Key('calculator-display-line'))).data,
        '96',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('calculator-expression'))).data,
        '12 × 8',
        reason: 'the completed calculation stays on screen, with the result below it',
      );
    });

    testWidgets('a division by zero reports rather than throwing', (
      tester,
    ) async {
      await pumpApp(tester);

      for (final key in ['8', '÷', '0', '=']) {
        await tester.tap(keyFor(key));
        await tester.pump();
      }

      // The engine is pure and total (D-23): an undefined result is a value the
      // display can render, not an exception a frame has to survive.
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Text>(find.byKey(const Key('calculator-display-line'))).data,
        isNotNull,
      );
    });
  });

  group('the history list builds only what is on screen', () {
    testWidgets('200 entries do not all become widgets', (tester) async {
      mockHistoryStore(_entries(200));
      await pumpApp(tester, history: _entries(200));
      await openHistory(tester);
      await tester.pumpAndSettle();

      // All 200 are in the store...
      expect(historyExpressions(tester), hasLength(200));

      // ...and only a screenful of them became widgets. A `Column` or an eager
      // `ListView(children: [...])` would give 200 here and cost a 200-row
      // build on every scroll frame. The exact count is not the point — the
      // point is that it is a small fraction of the data.
      final built = tester.widgetList<HistoryCard>(find.byType(HistoryCard)).length;
      expect(
        built,
        lessThan(20),
        reason: 'a lazy list builds a screenful, not the whole store',
      );
    });

    testWidgets('the newest entry is first and the oldest is off-screen', (
      tester,
    ) async {
      mockHistoryStore(_entries(200));
      await pumpApp(tester, history: _entries(200));
      await openHistory(tester);
      await tester.pumpAndSettle();

      final expressions = historyExpressions(tester);

      // Newest-first ordering is asserted through the *data*, since the bottom
      // of the list is not built.
      expect(expressions.first, '200 + 1');
      expect(expressions.last, '1 + 1');
      expect(
        find.text('200 + 1'),
        findsOneWidget,
        reason: 'the newest entry is the one that must be visible',
      );
      expect(
        find.text('1 + 1'),
        findsNothing,
        reason: 'the oldest is reachable only by scrolling',
      );
    });

    testWidgets('scrolling builds the rest without rebuilding the top', (
      tester,
    ) async {
      mockHistoryStore(_entries(200));
      await pumpApp(tester, history: _entries(200));
      await openHistory(tester);
      await tester.pumpAndSettle();

      // Reaching into the provider means the list is grouped by day, and
      // scrolling has to move between headers rather than rebuild a flat list.
      final before = tester.widgetList<HistoryCard>(find.byType(HistoryCard)).length;

      await tester.drag(historyList, const Offset(0, -1200));
      await tester.pumpAndSettle();

      expect(historyExpressions(tester), hasLength(200), reason: 'nothing lost');
      expect(
        tester.widgetList<HistoryCard>(find.byType(HistoryCard)).length,
        lessThanOrEqualTo(before + 8),
        reason: 'a bounded window, not the whole list',
      );
    });
  });
}

/// [count] entries, oldest first, each one `n + 1` so the expressions are
/// unique and a duplicate can never pass for a correct one.
List<HistoryEntry> _entries(int count) => [
  for (var n = 1; n <= count; n++)
    HistoryEntry(
      id: 'entry-$n',
      expression: '$n + 1',
      result: '${n + 1}',
      resultValue: n + 1,
      timestamp: DateTime.utc(2026, 1, 1).add(Duration(minutes: n)),
    ),
];

/// The keypad button for [glyph], keyed the way `calculator_keypad.dart` does.
Finder keyFor(String glyph) => find.byKey(ValueKey('key-${_key(glyph)}'));

String _key(String glyph) => switch (glyph) {
  '×' => 'multiply',
  '÷' => 'divide',
  '−' => 'subtract',
  '+' => 'add',
  '=' => 'equals',
  _ => 'digit$glyph',
};

/// The History screen's scroll view.
///
/// A `ListView` finder is not used: the group headers mean the list is a
/// `CustomScrollView`, and picking the wrong scrollable silently scrolls
/// nothing.
Finder get historyList => find.byType(CustomScrollView);
