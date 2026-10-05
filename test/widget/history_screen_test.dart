import 'dart:async';

import 'package:calculator/core/storage/preferences_provider.dart';
import 'package:calculator/core/utils/date_group.dart';
import 'package:calculator/features/history/data/history_repository.dart';
import 'package:calculator/features/history/data/shared_preferences_history_repository.dart';
import 'package:calculator/features/history/domain/history_entry.dart';
import 'package:calculator/features/history/presentation/history_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/pump_app.dart';

/// The header trash's tooltip, which D-38 keeps mounted in every state.
Finder headerTrashTooltip() => find.byTooltip('Clear History');

/// The trash [IconButton] itself, reached through the tooltip because
/// `find.byTooltip` matches the `Tooltip`, not the button it labels.
Finder headerTrash() =>
    find.ancestor(of: headerTrashTooltip(), matching: find.byType(IconButton));

/// The bottom Clear History action, which D-38 hides when there is nothing to
/// clear.
Finder bottomClear() => find.byKey(const Key('history-clear-button'));

/// The copy the History screen shows when a read fails (D-58).
///
/// Held here rather than inlined so the "the raw exception is not on screen"
/// assertion and the "this is what the user reads" assertion cannot drift apart
/// — and so a copy change has to be a deliberate edit on both sides.
const historyErrorCopy =
    'Your saved calculations could not be read. '
    'Try again, or restart the app.';

/// The rendered state of the header trash: enabled, or a disabled placeholder.
bool headerTrashEnabled(WidgetTester tester) =>
    tester.widget<IconButton>(headerTrash()).onPressed != null;

/// Fails reads while [shouldFail] says so, then delegates to [inner].
///
/// The failure is placed on `getAllGroupedByDay` rather than on the provider
/// build because that is where it happens in the app: the repository is built
/// once per scope and cached, and it is the read against storage that fails. A
/// fake that threw from the provider would be testing Riverpod's caching
/// instead of the retry.
class _FlakyReadRepository implements HistoryRepository {
  _FlakyReadRepository({required this.inner, required this.shouldFail});

  final HistoryRepository inner;
  final bool Function() shouldFail;

  @override
  Future<List<HistoryDayGroup>> getAllGroupedByDay() async {
    if (shouldFail()) throw StateError('transient read failure');
    return inner.getAllGroupedByDay();
  }

  @override
  Future<void> add(HistoryEntry entry) => inner.add(entry);

  @override
  Future<HistoryEntry> addResult({
    required String expression,
    required String result,
    required double resultValue,
  }) => inner.addResult(
    expression: expression,
    result: result,
    resultValue: resultValue,
  );

  @override
  Future<void> deleteByIds(Set<String> ids) => inner.deleteByIds(ids);

  @override
  Future<void> clearAll() => inner.clearAll();

  @override
  Future<bool> isEnabled() => inner.isEnabled();
}

void main() {
  testWidgets('an empty history explains itself and offers no clear', (
    tester,
  ) async {
    await pumpApp(tester);
    await openHistory(tester);

    expect(find.text('No calculations yet'), findsOneWidget);
    expect(
      find.text('Results you calculate will appear here.'),
      findsOneWidget,
    );

    // D-38: no bottom action, but the header trash stays in place.
    expect(bottomClear(), findsNothing);
    expect(
      headerTrashEnabled(tester),
      isFalse,
      reason: 'the header trash is disabled rather than removed',
    );
  });

  testWidgets('entries are grouped into day sections, newest day first', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 9);
    final yesterday = today.subtract(const Duration(days: 1));
    final older = today.subtract(const Duration(days: 3));

    await pumpApp(
      tester,
      // Oldest-first, the order the calculations happened: `mockHistoryStore`
      // reverses its input to get the newest-first storage order, so passing
      // them newest-first here would put "Today" at the *bottom* of the screen.
      history: [
        seededEntry(
          expression: '3 + 3',
          result: '6',
          resultValue: 6,
          timestamp: older,
          id: 'older',
        ),
        seededEntry(
          expression: '2 + 2',
          result: '4',
          resultValue: 4,
          timestamp: yesterday,
          id: 'yesterday',
        ),
        seededEntry(
          expression: '1 + 1',
          result: '2',
          resultValue: 2,
          timestamp: today,
          id: 'today',
        ),
      ],
    );
    await openHistory(tester);

    // The labels come from the one shared grouping rule, so this asserts the
    // screen renders them in order rather than re-deriving the date format.
    // D-72 replaced the shared uppercase `SectionHeader` with `HistoryDayLabel`,
    // which keeps the sentence case the grouping rule produced.
    expect(
      find.text('Today'),
      findsOneWidget,
      reason: 'today is the newest day, so it heads the list',
    );

    // The remaining sections may be below the fold. D-73's shorter cards fit
    // noticeably more of the list than D-72's 150 pt ones did, but the set of
    // groups is open-ended and a test that asserted "the first group only"
    // would be asserting a fact about the screen's height rather than about its
    // ordering. `find.text` sees lazily-built slivers, so each label is scrolled
    // into view rather than asserted up front — and a forward-only scroll is
    // itself evidence of the order, since a label *above* the current position
    // could not be reached this way.
    final list = find.byType(Scrollable).first;
    for (final label in <String>['Yesterday', dayGroupLabel(older, now: now)]) {
      await tester.scrollUntilVisible(find.text(label), 200, scrollable: list);
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('entries within a day are newest first', (tester) async {
    final now = DateTime.now();
    final morning = DateTime(now.year, now.month, now.day, 8);
    final evening = DateTime(now.year, now.month, now.day, 20);

    await pumpApp(
      tester,
      history: [
        seededEntry(
          expression: 'old',
          result: '1',
          resultValue: 1,
          timestamp: morning,
          id: 'old',
        ),
        seededEntry(
          expression: 'new',
          result: '2',
          resultValue: 2,
          timestamp: evening,
          id: 'new',
        ),
      ],
    );
    await openHistory(tester);

    // Storage hands back newest first and the screen must not reverse it.
    expect(historyExpressions(tester), ['new', 'old']);
  });

  testWidgets('a non-empty history shows both clear entry points', (
    tester,
  ) async {
    await pumpApp(
      tester,
      history: [
        seededEntry(
          expression: '1 + 1',
          result: '2',
          resultValue: 2,
          timestamp: DateTime.now(),
        ),
      ],
    );
    await openHistory(tester);

    expect(bottomClear(), findsOneWidget);
    expect(headerTrashEnabled(tester), isTrue);
  });

  testWidgets('a failed read is reported, not shown as an empty history', (
    tester,
  ) async {
    await pumpApp(
      tester,
      overrides: [
        historyRepositoryProvider.overrideWith(
          (ref) async => throw StateError('disk on fire'),
        ),
      ],
    );
    await openHistory(tester);

    // An empty list and a failed read are different problems, and telling a
    // user "No calculations yet" after a failure would be a lie.
    expect(find.text('Could not load history'), findsOneWidget);
    expect(find.text('No calculations yet'), findsNothing);

    // D-58: the underlying error is a *message for us*, not for the user. It can
    // carry a file path, a class name, or an exception the user cannot act on,
    // and it has been shown verbatim. The exception is still available through
    // the log; the screen says only what the user can do about it.
    expect(find.textContaining('disk on fire'), findsNothing);
    expect(find.text(historyErrorCopy), findsOneWidget);
  });

  testWidgets('the error state offers a retry that re-reads the store', (
    tester,
  ) async {
    // Fails the first *read*, not the first repository build. A throw from the
    // provider would be cached by Riverpod, and invalidating the screen's
    // provider would then re-subscribe to the same cached error — the retry
    // would appear to do nothing. In the app the read is what fails, so that is
    // what the fake reproduces.
    var failNextRead = true;

    await pumpApp(
      tester,
      overrides: [
        historyRepositoryProvider.overrideWith((ref) async {
          final preferences = await SharedPreferences.getInstance();
          return _FlakyReadRepository(
            inner: SharedPreferencesHistoryRepository(preferences: preferences),
            shouldFail: () => failNextRead,
          );
        }),
      ],
      history: [
        seededEntry(
          expression: '1 + 1',
          result: '2',
          resultValue: 2,
          timestamp: DateTime.now(),
        ),
      ],
    );
    await openHistory(tester);

    expect(find.byKey(const Key('history-retry')), findsOneWidget);
    expect(find.text('Could not load history'), findsOneWidget);

    // The retry is a real re-read, not a reload of the same failed future.
    failNextRead = false;
    await tester.tap(find.byKey(const Key('history-retry')));
    await tester.pumpAndSettle();

    // The entries that were in the store all along now appear.
    expect(find.text('Could not load history'), findsNothing);
    expect(historyExpressions(tester), ['1 + 1']);
    expect(find.byKey(const Key('history-retry')), findsNothing);
  });

  testWidgets('a retry that fails again returns to the error state', (
    tester,
  ) async {
    await pumpApp(
      tester,
      overrides: [
        historyRepositoryProvider.overrideWith(
          (ref) async => throw StateError('still broken'),
        ),
      ],
    );
    await openHistory(tester);

    await tester.tap(find.byKey(const Key('history-retry')));
    await tester.pumpAndSettle();

    // Retrying must not leave a blank screen or an empty history if it fails a
    // second time. Staying on the error state is the honest outcome.
    expect(find.text('Could not load history'), findsOneWidget);
    expect(find.text('No calculations yet'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the error state is reachable and retryable at 1.3x text scale', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(
      tester,
      overrides: [
        historyRepositoryProvider.overrideWith(
          (ref) async => throw StateError('disk on fire'),
        ),
      ],
    );
    await openHistory(tester);

    // The error state's message and its retry action have to survive the font
    // the user chose, and the retry has to stay tappable.
    expect(find.text(historyErrorCopy), findsOneWidget);
    expect(find.byKey(const Key('history-retry')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a slow read shows a progress indicator until it resolves', (
    tester,
  ) async {
    final gate = Completer<SharedPreferences>();

    await pumpApp(
      tester,
      overrides: [preferencesProvider.overrideWith((ref) => gate.future)],
    );
    await tester.tap(find.byIcon(Icons.history));
    // Frames are pumped by hand here on purpose: `pumpAndSettle` would never
    // return, because the progress indicator animates for as long as it is on
    // screen, which is exactly the state under test.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('history-loading')), findsOneWidget);

    // Finishing the read replaces the spinner rather than stacking on it.
    mockHistoryStore(const []);
    gate.complete(await SharedPreferences.getInstance());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('history-loading')), findsNothing);
    expect(find.text('No calculations yet'), findsOneWidget);
  });
}
