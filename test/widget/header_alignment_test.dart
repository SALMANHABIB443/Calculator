/// Header chrome alignment and the empty state's placement (D-74).
///
/// Three layout facts are asserted here that no other test covers, and each is
/// something a framework default gets wrong on its own:
///
/// 1. **The screen margin is an optical one, and it is the *box* that rides
///    it.** The header actions are bordered squares on a side, so the box's own
///    edge — not the glyph inside it — is what has to land on the screen's
///    margin: [AppSpacing.screenHorizontal]'s 24 px for the secondary screens,
///    and [AppSpacing.calculatorSideMargin]'s 16 px for the calculator, whose
///    header heads a column of 90 px keys rather than a column of 24 px-margined
///    cards (**D-110**). A stock `IconButton` puts its glyph three pixels inside
///    a line like that; only the rendered rect catches the drift, because a token
///    assertion cannot see a position.
///
/// 2. **A secondary title is centred by geometry, not by a flag.** The header
///    is a row with an equal-width box (or blank) on each side, so the title's
///    middle sits on the screen's middle whatever the title is. If one side were
///    allowed to differ the title would slide off centre while every
///    finder-based test still passed.
///
/// 3. **A `Center` inside a vertical `SingleChildScrollView` does not centre.**
///    The scroll view hands its child an unbounded main axis, so the `Center`
///    collapses to its child's height and the empty state sticks to the top of
///    the page — silently violating desing.md §9's "Centered illustration or
///    icon" while every finder-based test still passes.
library;

import 'package:calculator/core/design/app_colors.dart';
import 'package:calculator/core/design/app_spacing.dart';
import 'package:calculator/core/widgets/core_widgets.dart';
import 'package:calculator/features/calculator/domain/calculator_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

/// Sub-pixel slack for a layout measurement.
///
/// A header box is pinned to a whole number of logical pixels by
/// [AppSizes.iconTouchTarget], so this asserts "on the margin" to the nearest
/// pixel rather than to the last decimal place. A regression here is a whole
/// step of the spacing scale — the gap a wrong inset leaves — so a one pixel
/// tolerance cannot hide a real failure.
const double _slack = 1.0;

/// The logical width of the surface under test.
double surfaceWidth(WidgetTester tester) =>
    tester.view.physicalSize.width / tester.view.devicePixelRatio;

/// The button around [icon], as a finder.
Finder actionFinder(IconData icon) => find.ancestor(
  of: find.byIcon(icon),
  matching: find.byType(IconButton),
);

/// The rendered rect of the button around [icon].
///
/// The *button* rather than the glyph, because D-74 made the box the object that
/// rides the screen margin — the glyph sits [AppSizes.iconTouchTarget] minus its
/// own size further in, which is exactly the drift this file exists to catch.
Rect actionBox(WidgetTester tester, IconData icon) =>
    tester.getRect(actionFinder(icon));

/// The header's own back button, as a finder.
Finder backArrowFinder() => actionFinder(Icons.arrow_back);

/// The rendered rect of the header's back button.
Rect backArrowBox(WidgetTester tester) => actionBox(tester, Icons.arrow_back);

/// The rendered rect of the calculator key [key] (**D-110**).
///
/// The calculator's header is judged against the column it heads rather than
/// against the app's card margin, so this file needs to see where a key lands.
Rect rectOfKey(WidgetTester tester, CalculatorKey key) => tester.getRect(
  find.byKey(ValueKey('key-${key.name}')),
);

/// How far the back button's *box* sits from the screen's left edge.
double backArrowInset(WidgetTester tester) => backArrowBox(tester).left;

/// The History header's trash button.
///
/// Reached through the tooltip rather than the glyph, because the header trash
/// and the bottom Clear History action paint the *same* widget; a bare
/// `find.byType` would match two and any `getRect` on it would throw. The
/// tooltip is unique to the header (the bottom action is a labelled
/// `TextButton`), so this is the stable handle.
Finder headerTrashButton() => find.ancestor(
  of: find.byTooltip('Clear History'),
  matching: find.byType(IconButton),
);

/// The header trash's glyph.
Finder headerTrashGlyph() => find.descendant(
  of: headerTrashButton(),
  matching: find.byType(AppTrashIcon),
);

/// The trash glyph the header paints.
AppTrashIcon headerTrashIcon(WidgetTester tester) =>
    tester.widget<AppTrashIcon>(headerTrashGlyph());

/// How far the delete button's *box* sits from the screen's right edge.
double deleteInset(WidgetTester tester) =>
    surfaceWidth(tester) - tester.getRect(headerTrashButton()).right;

/// The rendered rect of the title of the header currently on screen.
Rect headerTitle(WidgetTester tester, String title) => tester.getRect(
  find.descendant(
    of: find.byType(SecondaryPageHeader),
    matching: find.text(title),
  ),
);

/// Opens each screen that uses [SecondaryPageHeader], one after another, in the
/// order a user reaches them, and hands each to [check].
///
/// The walk is deliberate: each of these rows is laid out from the *live* width,
/// so a header that lines up on History can still be wrong on a screen with a
/// longer title. Every secondary screen therefore gets measured,
/// and the calculator's own bar is measured with them so the two headers cannot
/// drift apart unnoticed.
Future<void> walkSecondaryScreens(
  WidgetTester tester,
  Future<void> Function(WidgetTester tester) check,
) async {
  await openHistory(tester);
  await check(tester);
  await goBack(tester);

  await openSettings(tester);
  await check(tester);

  // About, and both legal documents, hang off Settings rows. The row is
  // "App Version", not "About": "About" is the *section* label, and a
  // `SectionHeader` uppercases it to "ABOUT", so the row is the only case
  // that matches the About screen.
  for (final row in <String>[
    'App Version',
    'Privacy Policy',
    'Terms of Service',
  ]) {
    await tapSettingsRow(tester, row);
    await check(tester);
    await goBack(tester);
  }
}

void main() {
  group('header chrome sits on the screen margin (D-74)', () {
    testWidgets('the History back button lands on the 24 px margin', (
      tester,
    ) async {
      await pumpApp(tester);
      await openHistory(tester);

      expect(
        backArrowInset(tester),
        closeTo(AppSpacing.screenHorizontal, _slack),
        reason: 'the button box has to line up with the cards below it',
      );
    });

    testWidgets('the History delete button lands 24 px from the right edge', (
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

      expect(deleteInset(tester), closeTo(AppSpacing.screenHorizontal, _slack));
    });

    testWidgets('every header action is the same 48 px square', (tester) async {
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

      // The centring is symmetry, so the two sides have to be the same width.
      // A box that sized itself from its own padding would move the title by
      // the difference.
      final expected = Size.square(AppSizes.iconTouchTarget);
      expect(tester.getSize(backArrowFinder()), expected);
      expect(tester.getSize(headerTrashButton()), expected);
    });

    testWidgets('the History title is centred on the screen', (tester) async {
      await pumpApp(tester);
      await openHistory(tester);

      // D-74 centres the secondary titles: the back box and the blank that
      // stands in for an absent action are the same width, so the title's own
      // middle is the screen's middle. A start-aligned title would sit at the
      // leading edge of whatever the two boxes left behind.
      expect(
        headerTitle(tester, 'History').center.dx,
        closeTo(surfaceWidth(tester) / 2, _slack),
      );
    });

    testWidgets('the calculator top bar rides the calculator column (D-110)', (
      tester,
    ) async {
      // The calculator panel is capped at [AppSizes.calculatorPanelMaxWidth] and
      // centred (D-09's portrait-phone scope), so on a wider surface its own top
      // bar sits *inside* the panel and no longer shares a screen edge with the
      // full-width secondary headers. Measuring on the reference canvas keeps the
      // comparison meaningful: at 442 the panel fills the width, which is the
      // case the two headers are meant to agree on.
      tester.view.physicalSize = const Size(442, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpApp(tester);

      // D-110: the calculator's header is no longer on the app's 24 px card
      // margin. Its header, display, and keypad are *one column* on a 16 px
      // side margin, because the grid derives its key size from whatever width
      // it is handed — so the assertion that matters is no longer "it agrees
      // with the secondary headers" but "it agrees with the keys below it".
      // Asserting the bare 16 px would pass on a bar floating inboard of
      // everything else on the screen, which is the drift this file exists for.
      const margin = AppSpacing.calculatorSideMargin;
      expect(actionBox(tester, Icons.settings).left, closeTo(margin, _slack));
      expect(
        surfaceWidth(tester) - actionBox(tester, Icons.history).right,
        closeTo(margin, _slack),
      );

      // The header rides the *same* edge as the column it heads: the leading
      // `AC` key and the leading button box, one right of the other.
      expect(
        actionBox(tester, Icons.settings).left,
        closeTo(rectOfKey(tester, CalculatorKey.ac).left, _slack),
      );

      // And it is the calculator's own larger scale — 56, not the app-wide 48.
      // A 48 px box above a 90 px key reads as a header drawn for a smaller
      // calculator than the one underneath it.
      expect(
        tester.getSize(actionFinder(Icons.settings)),
        Size.square(AppSizes.calculatorHeaderAction),
      );
      expect(
        tester.getSize(actionFinder(Icons.history)),
        Size.square(AppSizes.calculatorHeaderAction),
      );
    });

    testWidgets('the secondary headers keep the 24 px card margin', (
      tester,
    ) async {
      // The counterpart to the test above, and the reason the calculator took an
      // override rather than the app-wide token moving: History, Settings, and
      // About are columns of cards, and their edges are still measured at 24.
      await pumpApp(tester);
      await openHistory(tester);

      expect(backArrowInset(tester), closeTo(AppSpacing.screenHorizontal, _slack));
      expect(deleteInset(tester), closeTo(AppSpacing.screenHorizontal, _slack));
      expect(
        tester.getSize(backArrowFinder()),
        Size.square(AppSizes.iconTouchTarget),
      );
    });

    testWidgets('every screen with a header agrees', (tester) async {
      await pumpApp(tester);

      final measured = <String>[];
      await walkSecondaryScreens(tester, (tester) async {
        final title = tester.widget<Text>(
          find
              .descendant(
                of: find.byType(SecondaryPageHeader),
                matching: find.byType(Text),
              )
              .first,
        );
        expect(
          backArrowInset(tester),
          closeTo(AppSpacing.screenHorizontal, _slack),
          reason: 'the "${title.data}" header is off the margin',
        );
        expect(
          headerTitle(tester, title.data!).center.dx,
          closeTo(surfaceWidth(tester) / 2, _slack),
          reason: 'the "${title.data}" title is off centre',
        );
        measured.add(title.data!);
      });

      // Guards the walk itself: a screen that failed to open would make the loop
      // above pass on the same screen five times.
      expect(measured, <String>[
        'History',
        'Settings',
        'About',
        'Privacy Policy',
        'Terms of Service',
      ]);
    });
  });

  group("the History delete action is the design's own trash (D-72, D-73)", () {
    testWidgets('one glyph, painted, inside the shared bordered box', (
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

      // D-73 swapped Material's `delete_outline` for the design's own trash. The
      // expectation is the widget rather than the glyph because the glyph is no
      // longer an `IconData` to name — so the finder is what pins the swap, and
      // the old glyph's absence is what proves nothing else is painting here.
      expect(headerTrashGlyph(), findsOneWidget);
      expect(
        find.descendant(of: headerTrashButton(), matching: find.byType(Icon)),
        findsNothing,
        reason: 'the header no longer paints a Material icon',
      );
      expect(find.byIcon(Icons.delete_rounded), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);

      // The button is the shared header box, pinned to the same size as the back
      // arrow opposite it — that equality is what centres the title (D-74).
      expect(
        tester.getSize(headerTrashButton()),
        Size.square(AppSizes.iconTouchTarget),
      );
      expect(
        tester.widget<IconButton>(headerTrashButton()).padding,
        EdgeInsets.zero,
        reason: 'the box owns its own padding, so a call site cannot widen it',
      );

      // White when the action is live.
      expect(headerTrashIcon(tester).color, AppColors.textPrimary);
    });

    testWidgets('it keeps a 44pt-plus touch target', (tester) async {
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

      // The box is sized by the header rather than by the design system's glyph
      // bucket, so the prd.md §12 floor is a property of the component.
      expect(
        tester.getSize(headerTrashButton()).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('an empty history greys it instead of advertising it', (
      tester,
    ) async {
      await pumpApp(tester);
      await openHistory(tester);

      // A white icon that does nothing reads as a working button that is not
      // responding, which is the worst of the three possible states. Nothing to
      // clear means inert paint (D-38). The grey is the screen's own argument to
      // the glyph: a painted icon does not read the button's disabled colour.
      expect(headerTrashIcon(tester).color, AppColors.textSecondary);
    });
  });

  group('an empty history is centred (D-70)', () {
    /// The block the empty state actually paints, from the top of its icon to
    /// the bottom of its message.
    ///
    /// Measured rather than taken from the widget's own box: that box is the
    /// viewport, so it would report "centred" for a child stuck to the top —
    /// which is exactly the bug.
    Rect paintedBlock(WidgetTester tester) {
      final top = tester.getRect(find.byIcon(Icons.history)).top;
      final bottom = tester
          .getRect(find.text('Results you calculate will appear here.'))
          .bottom;
      return Rect.fromLTRB(0, top, 0, bottom);
    }

    testWidgets('the empty state sits in the middle of the page', (
      tester,
    ) async {
      await pumpApp(tester);
      await openHistory(tester);

      final viewport = tester.getRect(find.byType(EmptyState));
      expect(
        paintedBlock(tester).center.dy,
        closeTo(viewport.center.dy, _slack),
        reason: 'desing.md §9 asks for a centred empty state, not a top-aligned one',
      );
    });

    testWidgets('it is still centred with history present, after a clear', (
      tester,
    ) async {
      // The same widget serves the post-clear state, and that transition is the
      // one a user actually sees: tap Clear, confirm, and the list it was
      // scrolled into disappears.
      await pumpApp(
        tester,
        history: [
          for (var i = 0; i < 20; i++)
            seededEntry(
              expression: '$i + 1',
              result: '${i + 1}',
              resultValue: (i + 1).toDouble(),
              timestamp: DateTime.now().subtract(Duration(minutes: i)),
              id: 'seed-$i',
            ),
        ],
      );
      await openHistory(tester);

      // Confirm through the bottom action, the way a user does.
      await tester.tap(find.byKey(const Key('history-clear-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      final viewport = tester.getRect(find.byType(EmptyState));
      expect(
        paintedBlock(tester).center.dy,
        closeTo(viewport.center.dy, _slack),
      );
    });

    testWidgets('it stays centred at the text-scale clamp', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpApp(tester);
      await openHistory(tester);

      // The centring must not come from removing the scroll view: a large
      // Dynamic Type factor still has to fit, so this and the 320x568 no-overflow
      // test in `text_scaling_test.dart` together pin both halves.
      final viewport = tester.getRect(find.byType(EmptyState));
      expect(
        paintedBlock(tester).center.dy,
        closeTo(viewport.center.dy, _slack),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the shared header components (D-74)', () {
    testWidgets('an icon button is a 48 px bordered box', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppIconButton(icon: Icons.menu, tooltip: 'Settings'),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(AppIconButton)), const Size(48, 48));
      expect(find.byTooltip('Settings'), findsOneWidget);
    });

    testWidgets('a page header puts its title on the margin', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppPageHeader(title: 'Catalog')),
        ),
      );

      expect(
        tester.getRect(find.text('Catalog')).left,
        AppSpacing.screenHorizontal,
      );
    });

    testWidgets('a secondary header centres its title between equal boxes', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SecondaryPageHeader(title: 'History', onBack: () {}),
          ),
        ),
      );

      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(
        tester.getRect(find.text('History')).center.dx,
        closeTo(width / 2, _slack),
      );
      // The blank that stands in for an absent action is exactly as wide as the
      // back box, which is what the centring above is bought with.
      expect(tester.getSize(find.byType(AppIconButton)), const Size(48, 48));
    });
  });
}
