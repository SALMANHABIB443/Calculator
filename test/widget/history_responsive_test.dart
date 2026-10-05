/// The redesigned History list across the supported phone widths (D-72,
/// rescaled in D-73).
///
/// `design_system_test.dart` proves the card's *tokens*; this proves the card's
/// *geometry* — that the app margin, the 14 px radius, and the 88 pt floor
/// survive the three widths `desing.md` §9 supports, and that the one line that
/// must never truncate does not.
///
/// The device-pixel ratio is pinned to 1 so a physical size is also a logical
/// one and an inset can be compared to a token directly. The narrow 320 dp case
/// is the point of the file: it is where the result line and the chevron are
/// tightest against each other.
library;

import 'package:calculator/core/design/app_colors.dart';
import 'package:calculator/core/design/app_spacing.dart';
import 'package:calculator/core/widgets/core_widgets.dart';
import 'package:calculator/features/history/domain/history_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

/// The cards' visible surface — the box the card's fill and outline are painted
/// on.
///
/// Measured on the `AnimatedContainer` rather than on the `HistoryCard` itself
/// because the widget's outer `Padding` spans the full width; the inset the
/// design states belongs to the surface inside it.
///
/// D-93: this was the `Material`, when the fill was the `Material`'s own colour
/// and the card carried no outline. The fill now belongs to the decoration
/// wrapping it, so the `Material` is transparent and inset by the outline's
/// width — reading it would assert Ethar's border width rather than this app's
/// margin.
Finder surfaceOf(Finder card) =>
    find.descendant(of: card, matching: find.byType(AnimatedContainer)).first;

Finder firstCard() => find.byType(HistoryCard).first;

Finder firstSurface() => surfaceOf(firstCard());

/// Two entries on the same day, so the gap *between* cards is on screen as well
/// as the margin around them.
List<HistoryEntry> twoToday() {
  final now = DateTime.now();
  return [
    seededEntry(
      expression: '125 × 8',
      result: '1,000',
      resultValue: 1000,
      timestamp: now,
      id: 'a',
    ),
    seededEntry(
      expression: '12 + 30',
      result: '42',
      resultValue: 42,
      timestamp: now,
      id: 'b',
    ),
  ];
}

void main() {
  const widths = <Size>[Size(320, 568), Size(360, 640), Size(480, 1000)];

  group('the card geometry holds on every supported width', () {
    for (final size in widths) {
      testWidgets('at ${size.width.toInt()}x${size.height.toInt()}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await pumpApp(tester, history: twoToday());
        await openHistory(tester);

        expect(tester.takeException(), isNull);

        final surface = tester.getRect(firstSurface());

        // D-72 pulled the cards *inboard* of the 24 px line every other screen
        // uses, on a dedicated `historyHorizontal` of 48. D-73 deleted that
        // token, so the cards are back on the shared margin — the same line the
        // header's back arrow glyph lands on, which is asserted separately in
        // `header_alignment_test.dart`.
        expect(
          surface.left,
          closeTo(AppSpacing.screenHorizontal, 0.5),
          reason: 'the card is on the app margin every screen shares',
        );
        expect(
          size.width - surface.right,
          closeTo(AppSpacing.screenHorizontal, 0.5),
          reason: 'and it is symmetric',
        );

        // A floor, not a fixed height: content fits inside 88 at 1x, so the
        // card is the floor exactly. Asserted with a small band rather than an
        // exact 88 so a future padding tweak does not fail on rounding.
        expect(surface.height, inInclusiveRange(86, 92));

        final decoration =
            (tester.widget<AnimatedContainer>(firstSurface()).decoration!
                as BoxDecoration);
        expect(
          decoration.borderRadius,
          BorderRadius.circular(AppRadius.historyCard),
        );
        expect(decoration.color, AppColors.surfaceRaised);
      });
    }
  });

  testWidgets('the day label starts on the same margin as the cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester, history: twoToday());
    await openHistory(tester);

    expect(
      tester.getRect(find.text('Today')).left,
      closeTo(AppSpacing.screenHorizontal, 0.5),
      reason: 'the heading and the cards share one left edge',
    );
  });

  testWidgets('nothing but the cards separates the rows', (tester) async {
    await pumpApp(tester, history: twoToday());
    await openHistory(tester);

    // The old list leaned on a `ListTile` per row; the redesign leans on the
    // card fill. A divider creeping back in would double the separation.
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('a screen holds enough of them to be worth reading (D-73, D-76)', (
    tester,
  ) async {
    // The reason the card was rescaled at all. A History page is a list the user
    // scans, not a stack of posters, and at D-72's 150 pt card a 640 dp phone
    // showed three entries — with everything else pushed off the fold and behind
    // a scroll before the user had seen a single day. Counting the cards that
    // finish inside the viewport is the user-visible consequence, which the token
    // assertions above cannot express on their own.
    //
    // The floor is 4, not the 5 it was under D-73, and the reason is
    // [AppSpacing.headerTopGap] (**D-76**). The 24 px above the header is spent
    // out of this page's height, and on the shortest viewport in the matrix that
    // is exactly one card: 4 still hold whole where D-72 fitted 3, so the
    // complaint this test exists for — a list that opens on posters rather than
    // entries — stays fixed, and the cost of the top gap is stated here rather
    // than absorbed silently. Raising the gap back to 24 would be the only way
    // to hold 5, and the user chose the gap; the alternative to honouring it is
    // to make the header flush against the status bar, which is what the gap
    // exists to prevent.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    await pumpApp(
      tester,
      history: List<HistoryEntry>.generate(
        10,
        (i) => seededEntry(
          expression: '$i + 1',
          result: '${i + 1}',
          resultValue: i + 1,
          timestamp: now,
          id: '$i',
        ),
      ),
    );
    await openHistory(tester);

    final fullyVisible = tester
        .widgetList<HistoryCard>(find.byType(HistoryCard))
        .where(
          (card) =>
              tester.getRect(find.byWidget(card)).bottom <=
              640 - AppSpacing.bottomSafe,
        )
        .length;

    expect(
      fullyVisible,
      greaterThanOrEqualTo(4),
      reason:
          'D-72\'s geometry fitted three; the point of the rescale is that '
          'it does not',
    );
  });

  group('the result line', () {
    testWidgets('is allowed to shrink but never to truncate', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpApp(
        tester,
        history: [
          seededEntry(
            expression: '123456789 × 1000000000',
            result: '123,456,789,000,000,000',
            resultValue: 1.23456789e17,
            timestamp: DateTime.now(),
          ),
        ],
      );
      await openHistory(tester);

      // The expression may lose its tail; the result may not. `null` overflow
      // plus the `FittedBox` above it means "scale down to fit", which is the
      // whole reason the two lines are styled differently (D-72).
      expect(
        tester.widget<Text>(find.text('123456789 × 1000000000')).overflow,
        TextOverflow.ellipsis,
      );
      expect(
        tester.widget<Text>(find.text('123,456,789,000,000,000')).overflow,
        isNull,
      );
      expect(
        find.ancestor(
          of: find.text('123,456,789,000,000,000'),
          matching: find.byType(FittedBox),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the 88 floor is a floor: the card grows at the text clamp', (
    tester,
  ) async {
    // D-54 clamps the system scale; 2.0 is what Android offers, and the app
    // resolves it to its own ceiling. Short content is deliberate, so the result
    // line is not shrunk by its `FittedBox` and the only thing growing the card
    // is the type itself.
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(tester, history: twoToday());
    await openHistory(tester);

    expect(
      tester.getSize(firstSurface()).height,
      greaterThan(AppSizes.historyCardMinHeight),
      reason: 'a fixed height would clip the enlarged type instead of yielding',
    );
    expect(tester.takeException(), isNull);
  });
}
