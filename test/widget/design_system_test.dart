import 'package:calculator/core/design/app_colors.dart';
import 'package:calculator/core/design/app_palette.dart';
import 'package:calculator/core/design/app_spacing.dart';
import 'package:calculator/core/design/app_theme.dart';
import 'package:calculator/core/design/app_typography.dart';
import 'package:calculator/core/widgets/core_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The decoration a rendered `HistoryCard` is painted with (D-93).
///
/// D-93 moved the card's fill, outline, and shadow onto the `AnimatedContainer`
/// that wraps the `Material` — it is Ethar's `_TaskCard` shape — so the `Material`
/// can no longer answer any of those questions. Reading the decoration is what
/// lets a test assert the card's whole surface recipe from one widget.
BoxDecoration decorationOf(WidgetTester tester, {required bool selected}) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byType(HistoryCard),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return container.decoration! as BoxDecoration;
}

/// Phase 3 acceptance criteria: every shared component resolves to the values
/// measured from the mockup pixels (D-03) and to the token names the design
/// spec assigns them (desing.md §2, §3, §5).
///
/// These assert on the **tokens the widgets actually read**, not on a rendered
/// pixel diff. A golden image would prove a pixel matches, but it would also
/// pass while a screen quietly hard-codes a hex that happens to look right;
/// asserting the token fails the moment a component stops consuming the design
/// system. The complementary check — that the result looks like the mockup —
/// is a Phase 9 visual pass, not an automated one.
void main() {
  group('AppColors', () {
    test('holds the palette measured from the mockup pixels (D-03)', () {
      // These supersede the visual estimates of Phase 1 and are the values the
      // Phase 9 pixel comparison is measured against.
      expect(AppColors.background, const Color(0xFF000000));
      expect(AppColors.surface, const Color(0xFF101011));
      expect(AppColors.accent, const Color(0xFFF89508));
      expect(AppColors.buttonDigit, const Color(0xFF1E1E1E));
      expect(AppColors.buttonFunction, const Color(0xFF949494));
      expect(AppColors.textPrimary, const Color(0xFFFFFFFF));
      expect(AppColors.textOnFunction, const Color(0xFF000000));
      expect(AppColors.textSecondary, const Color(0xFF949AA4));
      expect(AppColors.toggleTrackOn, const Color(0xFFF89508));
      expect(AppColors.toggleThumb, const Color(0xFFFFFFFF));
    });

    test('the History card fill is a named token, not a shared one (D-72)', () {
      // `#151517` is one step above [surface]. It is a separate token precisely
      // so the History redesign could not restyle the Settings groups, the
      // About hero card, the dialog, or the decimal-places sheet — all of which
      // still read `surface`.
      expect(AppColors.surfaceRaised, const Color(0xFF151517));
      expect(AppColors.surfaceRaised, isNot(AppColors.surface));
      expect(
        AppColors.surfaceRaised.computeLuminance(),
        greaterThan(AppColors.surface.computeLuminance()),
        reason: 'the card has to read as a layer above the page, not below it',
      );
    });

    test('the card edge is Ethar\'s outline, not a chosen one (D-91)', () {
      // D-91 took the outline and the icon tile's fill from the sibling app, so
      // the two apps' settings screens are the same object. Asserting the
      // relationship as well as the literals: the border has to be *lighter*
      // than the card on a black page or the card loses its edge, and the tile
      // has to be lighter too or it disappears into the card it sits on.
      expect(AppColors.cardBorder, const Color(0xFF292D35));
      expect(AppColors.surfaceSoft, const Color(0xFF20232A));
      expect(
        AppColors.cardBorder.computeLuminance(),
        greaterThan(AppColors.surface.computeLuminance()),
        reason: 'the outline is the only edge a card on a black page has',
      );
      expect(
        AppColors.surfaceSoft.computeLuminance(),
        greaterThan(AppColors.surface.computeLuminance()),
        reason: 'the tile has to separate from the card it sits on',
      );
    });

    test('keeps function keys light with dark labels, inverting the contrast', () {
      // The single largest correction in the Phase 1 measurement: AC, +/− and %
      // are a light mid-gray carrying near-black labels, not a medium gray with
      // white labels. Asserting the relationship, not just the literals, so a
      // future palette edit cannot quietly restore the wrong pairing.
      final luminance = AppColors.buttonFunction.computeLuminance();
      expect(luminance, greaterThan(0.2));
      expect(
        AppColors.buttonFunction.computeLuminance(),
        greaterThan(AppColors.buttonDigit.computeLuminance()),
      );
      expect(
        AppColors.textOnFunction.computeLuminance(),
        lessThan(AppColors.textPrimary.computeLuminance()),
      );
    });

    test('the OFF track reads as "off", not as the accent (R-1, D-61)', () {
      // R-1 is CLOSED but still unmeasured: Phase 9 read all four mockups and
      // confirmed none contains a toggle in the OFF state, so this value is a
      // choice that can never be derived from the source material (D-61). What
      // is assertable is the property that makes it look right — visibly darker
      // than the ON track, or the switch would look stuck on.
      expect(AppColors.toggleTrackOff, const Color(0xFF2A2A2A));
      expect(AppColors.toggleTrackOff, isNot(AppColors.toggleTrackOn));
      expect(
        AppColors.toggleTrackOff.computeLuminance(),
        lessThan(AppColors.toggleTrackOn.computeLuminance() / 2),
      );
    });
  });

  group('AppSpacing', () {
    test('the screen margin matches the mockup card edges (D-60)', () {
      // Phase 9 measured the card edges in the History, Settings, and About
      // mockups at logical x≈24, correcting the 20 px that desing.md §4's prose
      // range (16–20) had led Phase 3 to. This token also determines the
      // calculator key size, so a silent drift here would move R-2's closed
      // answer without failing anything else.
      expect(AppSpacing.screenHorizontal, 24);
    });

    test('keeps card padding and the bottom safe area on the 8pt grid', () {
      expect(AppSpacing.cardPadding, 16);
      expect(AppSpacing.bottomSafe, 24);
      expect(AppSpacing.md, 12);
      expect(AppSpacing.sm, 8);
      expect(AppSpacing.lg, 16);
      expect(AppSpacing.xl, 24);
    });

    test('the History card geometry follows the app margin (D-73)', () {
      // D-72 gave History its own `historyHorizontal` at double the app margin
      // and D-73 deleted it, so there is no token left to assert: the cards ride
      // [AppSpacing.screenHorizontal] like every other surface, which is what
      // puts them on the same line as the header's own back arrow.
      expect(
        AppSpacing.historyCardGap,
        AppSpacing.sm,
        reason: 'the card gap is one step of the shared rhythm',
      );
      expect(
        AppSpacing.historyGroupGap,
        greaterThan(AppSpacing.historyCardGap),
        reason: 'a day boundary has to read as a change of subject',
      );
      // D-93: History's radius is Ethar's *task card* corner, 12 — no longer
      // equal to the grouped cards' 14, which D-77 had pinned. The D-77 parity
      // argument was about Ethar's Create Task *option* rows, which are a
      // different component that happens to share a number; a History entry is
      // the same kind of object as the task card (a row among peers,
      // long-pressable, multi-selectable), so it follows that one.
      //
      // Distinct from `AppRadius.card` is now the *assertion*, not a hope: the two
      // must not drift back together, which is why this is an inequality rather
      // than the equality D-77 wrote.
      expect(
        AppRadius.historyCard,
        isNot(AppRadius.card),
        reason:
            'a History card and a Settings group are different objects '
            '(D-93)',
      );
      // The number itself is stated rather than left implicit, so a change is a
      // deliberate edit here and not a silent one.
      expect(AppRadius.historyCard, 12);
      // Below half the card's own height, or the corner eats it: D-72's 30 was
      // sized for a 150 pt card and would be a stadium at 88.
      expect(
        AppRadius.historyCard,
        lessThan(AppSizes.historyCardMinHeight / 2),
      );
      expect(AppSizes.historyCardMinHeight, 88);
    });
  });

  group('AppTypography', () {
    test('result, expression, and title sizes sit in the specified ranges', () {
      // desing.md §3 gives ranges; each token is the midpoint, so the Phase 9
      // comparison has one number to move.
      expect(AppTypography.resultLarge.fontSize, inInclusiveRange(56, 64));
      expect(AppTypography.expression.fontSize, inInclusiveRange(18, 22));
      expect(AppTypography.screenTitle.fontSize, inInclusiveRange(28, 34));
      // D-71's compact title is a step *down* within the same band, not a new
      // scale — so the band is the assertion that holds it to the design doc.
      expect(
        AppTypography.screenTitleCompact.fontSize,
        inInclusiveRange(28, 34),
      );
      expect(
        AppTypography.screenTitleCompact.fontSize!,
        lessThan(AppTypography.screenTitle.fontSize!),
      );
      expect(AppTypography.rowTitle.fontSize, 17);
      // D-93 replaced the History type scale with Ethar's card scale: the result is
      // the 17/w700 title line and the expression is the 13 muted meta line, so
      // these are no longer desing.md §3's bands — they are `task_list.dart`'s
      // 496 and 519. The relationship is asserted too, because it is the whole
      // point of D-93: the result stays the visibly larger of the two, and it
      // stays the *first* line rather than merely the bigger one.
      expect(AppTypography.historyExpression.fontSize, 13);
      expect(AppTypography.historyResult.fontSize, 17);
      expect(
        AppTypography.historyResult.fontSize!,
        greaterThan(AppTypography.historyExpression.fontSize!),
      );
      expect(
        AppTypography.historyDayLabel.fontSize,
        AppTypography.rowTitle.fontSize,
        reason: 'a day heading is the same kind of thing as a row label',
      );
      // D-93: the title carries Ethar's w700; the meta line is plain w400. The
      // weights matter as much as the sizes — a 17 px meta line would read as a
      // second title rather than as supporting text.
      expect(AppTypography.historyResult.fontWeight, FontWeight.w700);
      expect(AppTypography.historyExpression.fontWeight, FontWeight.w400);
      // And it is Ethar's own task title size, which is what keeps a History
      // entry the same object as a task in the sibling app.
      expect(
        AppTypography.historyResult.fontSize,
        AppTypography.rowTitle.fontSize,
        reason: 'a History entry and an Ethar task are the same row (D-93)',
      );
      expect(AppTypography.buttonLabel.fontSize, inInclusiveRange(22, 28));
    });

    test('primary text is white and secondary text is gray', () {
      expect(AppTypography.resultLarge.color, AppColors.textPrimary);
      expect(AppTypography.expression.color, AppColors.textSecondary);
      expect(AppTypography.rowTitle.color, AppColors.textPrimary);
      expect(AppTypography.rowSubtitle.color, AppColors.textSecondary);
      expect(AppTypography.sectionHeader.color, AppColors.textSecondary);
      expect(AppTypography.historyDayLabel.color, AppColors.textSecondary);
      expect(AppTypography.historyExpression.color, AppColors.textSecondary);
      expect(AppTypography.historyResult.color, AppColors.textPrimary);
      expect(AppTypography.bottomAction.color, AppColors.accent);
    });
  });

  group('AppTheme', () {
    test('maps the toggle tracks to the tokens', () {
      // R-1 is resolved in exactly one place, so a future designer hand-off
      // corrects it by editing AppColors.toggleTrackOff alone (D-61).
      final theme = AppTheme.dark;
      expect(
        theme.switchTheme.trackColor?.resolve({WidgetState.selected}),
        AppColors.toggleTrackOn,
      );
      expect(
        theme.switchTheme.trackColor?.resolve({}),
        AppColors.toggleTrackOff,
      );
      expect(
        theme.switchTheme.thumbColor?.resolve({WidgetState.selected}),
        AppColors.toggleThumb,
      );
    });

    test('paints scaffolds on the app background with hairline dividers', () {
      final theme = AppTheme.dark;
      expect(theme.scaffoldBackgroundColor, AppColors.background);
      expect(theme.dividerTheme.color, AppColors.divider);
      expect(theme.dialogTheme.backgroundColor, AppColors.surface);
    });
  });

  group('CalculatorButtonVariant', () {
    test('pairs each fill with a contrasting label', () {
      // desing.md §5.1. Getting the label colour wrong on the function keys is
      // the failure mode this table exists to prevent.
      //
      // Read through `colors(palette)` rather than off the enum directly: D-90
      // made the pairing a *function of the palette*, because the white theme
      // wants `textOnAccent` on `=` where the dark theme wanted `textPrimary`.
      // An assertion against a fixed palette can therefore only ever check one
      // theme, and checking both is the point — a `=` with ink on orange would
      // pass a dark-only test and be the one unreadable key on the pad.
      expect(
        CalculatorButtonVariant.digit.colors(AppPalette.dark).background,
        AppColors.buttonDigit,
      );
      expect(
        CalculatorButtonVariant.digit.colors(AppPalette.dark).foreground,
        AppColors.textPrimary,
      );
      expect(
        CalculatorButtonVariant.operator.colors(AppPalette.dark).background,
        AppColors.accent,
      );
      expect(
        CalculatorButtonVariant.operator.colors(AppPalette.dark).foreground,
        AppColors.textPrimary,
      );
      expect(
        CalculatorButtonVariant.function.colors(AppPalette.dark).background,
        AppColors.buttonFunction,
      );
      expect(
        CalculatorButtonVariant.function.colors(AppPalette.dark).foreground,
        AppColors.textOnFunction,
      );

      // The white theme's one disagreement, asserted so the two cannot drift
      // into agreeing by accident.
      expect(
        CalculatorButtonVariant.operator.colors(AppPalette.light).foreground,
        AppPalette.light.textOnAccent,
      );
    });
  });

  group('CalculatorButton', () {
    testWidgets('renders its label on the variant fill', (tester) async {
      await pump(
        tester,
        const Center(
          child: CalculatorButton(
            label: '7',
            variant: CalculatorButtonVariant.digit,
          ),
        ),
      );

      expect(find.text('7'), findsOneWidget);
      expect(fillOf(tester), AppColors.buttonDigit);
      expect(labelStyleOf(tester, '7')?.color, AppColors.textPrimary);
    });

    testWidgets('function keys put a dark label on the light fill', (
      tester,
    ) async {
      await pump(
        tester,
        const Center(
          child: CalculatorButton(
            label: 'AC',
            variant: CalculatorButtonVariant.function,
          ),
        ),
      );

      expect(fillOf(tester), AppColors.buttonFunction);
      expect(labelStyleOf(tester, 'AC')?.color, AppColors.textOnFunction);
    });

    testWidgets('operator keys are the orange primary action', (tester) async {
      await pump(
        tester,
        const Center(
          child: CalculatorButton(
            label: '÷',
            variant: CalculatorButtonVariant.operator,
          ),
        ),
      );

      expect(fillOf(tester), AppColors.accent);
    });

    testWidgets('is round in a square cell', (tester) async {
      await pump(
        tester,
        const SizedBox(
          width: 90,
          height: 90,
          child: CalculatorButton(
            label: '5',
            variant: CalculatorButtonVariant.digit,
          ),
        ),
      );

      expect(tester.getSize(find.byType(CalculatorButton)), const Size(90, 90));
      expect(
        borderRadiusOf(tester),
        const BorderRadius.all(Radius.circular(45)),
      );
    });

    testWidgets('the wide 0 key spans its cell and rounds only the ends', (
      tester,
    ) async {
      await pump(
        tester,
        const SizedBox(
          width: 192,
          height: 90,
          child: CalculatorButton(
            label: '0',
            variant: CalculatorButtonVariant.digit,
            isWide: true,
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(CalculatorButton)),
        const Size(192, 90),
      );
      expect(
        borderRadiusOf(tester),
        const BorderRadius.all(Radius.circular(45)),
      );
    });

    testWidgets('a pressed key dims and shrinks', (tester) async {
      await pump(
        tester,
        Center(
          child: CalculatorButton(
            label: '9',
            variant: CalculatorButtonVariant.digit,
            onPressed: () {},
          ),
        ),
      );

      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(opacity.opacity, 1);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('9')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        AppColors.pressedOpacity,
      );
      await gesture.up();
    });

    testWidgets('reports the key by its accessible name', (tester) async {
      await pump(
        tester,
        const Center(
          child: CalculatorButton(
            label: 'AC',
            variant: CalculatorButtonVariant.function,
            semanticLabel: 'all clear',
          ),
        ),
      );

      expect(find.bySemanticsLabel('all clear'), findsOneWidget);
    });
  });

  group('SectionHeader', () {
    testWidgets('uppercases the label in the secondary colour', (tester) async {
      await pump(tester, const SectionHeader('Preferences'));

      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('PREFERENCES')).style?.color,
        AppColors.textSecondary,
      );
    });
  });

  group('SettingsRow', () {
    testWidgets('renders title and subtitle with their token styles', (
      tester,
    ) async {
      await pump(
        tester,
        const SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.volume_up_outlined,
              title: 'Sound',
              subtitle: 'Key press sound',
            ),
          ],
        ),
      );

      expect(
        tester.widget<Text>(find.text('Sound')).style,
        AppTypography.rowTitle,
      );
      expect(
        tester.widget<Text>(find.text('Key press sound')).style,
        AppTypography.rowSubtitle,
      );
    });

    testWidgets('a tappable row without a control shows a chevron', (
      tester,
    ) async {
      await pump(
        tester,
        SettingsGroup(
          children: const [
            SettingsRow(icon: Icons.info_outline, title: 'About', onTap: _noop),
          ],
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('an explicit control replaces the chevron', (tester) async {
      await pump(
        tester,
        SettingsGroup(
          children: const [
            SettingsRow(
              icon: Icons.numbers,
              title: 'Decimal Places',
              trailing: Text('2'),
              onTap: _noop,
            ),
          ],
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.text('2'), findsOneWidget);
    });

    // D-92. The trailing control used to be a `Flexible`, which made it a flex
    // child competing with the title's `Expanded` — `RenderFlex` split the
    // row's spare width 50/50 and drew the control at the *start* of its own
    // half, leaving the card's right edge bare. Asserting the geometry rather
    // than the widget arrangement, because "flush right" is the property every
    // row on the screen has to agree on, not the way this one spells it.
    testWidgets('its trailing control sits flush against the right padding', (
      tester,
    ) async {
      await pump(
        tester,
        const SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.numbers,
              title: 'Decimal Places',
              trailing: Text('2'),
              onTap: _noop,
            ),
          ],
        ),
      );

      final contentRight =
          tester.getRect(find.byType(SettingsRow)).right -
          AppSpacing.cardPadding;
      expect(
        tester.getRect(find.text('2')).right,
        moreOrLessEquals(contentRight, epsilon: 0.5),
        reason: 'a control parked mid-row is the D-91 regression, not a style',
      );
    });

    // The same assertion for the chevron a row draws for itself, so the two
    // trailing paths cannot drift apart again.
    testWidgets('its drawn chevron shares that right edge', (tester) async {
      await pump(
        tester,
        const SettingsGroup(
          children: [
            SettingsRow(icon: Icons.info_outline, title: 'About', onTap: _noop),
          ],
        ),
      );

      final contentRight =
          tester.getRect(find.byType(SettingsRow)).right -
          AppSpacing.cardPadding;
      expect(
        tester.getRect(find.byIcon(Icons.chevron_right)).right,
        moreOrLessEquals(contentRight, epsilon: 0.5),
      );
    });

    // D-92, the half of the bug nobody sees: the title column was getting half
    // the row, so a subtitle that fits on one line wrapped onto two. If the
    // trailing control is non-flex, the `Expanded` takes everything left over.
    testWidgets('the title keeps the width the trailing does not use', (
      tester,
    ) async {
      await pump(
        tester,
        const SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.history,
              title: 'History',
              subtitle: 'Keep calculation history',
              trailing: Text('On'),
            ),
          ],
        ),
      );

      expect(
        tester.getSize(find.text('Keep calculation history')).height,
        lessThan(30),
        reason: 'a wrapped subtitle is a squeezed title column',
      );
    });

    // The bound D-92 inherited from Ethar, kept as a named fact so the widget
    // and the test cannot disagree about it.
    testWidgets('the trailing slot is bounded, not free (Ethar: 105)', (
      tester,
    ) async {
      expect(SettingsRow.trailingMaxWidth, 105);

      await pump(
        tester,
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.person_outline,
              title: 'Developer',
              trailing: const Text('a very long value indeed'),
            ),
          ],
        ),
      );

      expect(
        tester.getSize(find.text('a very long value indeed')).width,
        lessThanOrEqualTo(SettingsRow.trailingMaxWidth),
      );
    });

    // D-91. The leading glyph is a 44 px soft tile — Ethar's
    // `_SettingsIconTile` — rather than a bare mark floating on the card.
    testWidgets('puts its icon in a soft tile, not bare on the card', (
      tester,
    ) async {
      await pump(
        tester,
        const SettingsGroup(
          children: [
            SettingsRow(icon: Icons.volume_up_outlined, title: 'Sound'),
          ],
        ),
      );

      final tile = find.byType(AppIconTile);
      expect(tile, findsOneWidget);
      expect(tester.getSize(tile), const Size.square(AppIconTile.size));

      // The tile paints its own fill, so the `Container` carrying the fill and
      // the corner is a *descendant* of the tile widget, not the tile itself.
      final box = tester.widget<Container>(
        find.descendant(of: tile, matching: find.byType(Container)),
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(
        decoration.color,
        AppColors.surfaceSoft,
        reason: 'the tile is Ethar surfaceSoft, so the two apps share the row',
      );
      expect(
        decoration.borderRadius,
        BorderRadius.circular(AppIconTile.radius),
      );
    });

    // A bare glyph has no edge on a near-black card and no size for the row's
    // height to be measured against, so the row went from 56 to Ethar's 64.
    testWidgets('a row is tall enough to hold its tile (D-91)', (tester) async {
      await pump(
        tester,
        const SettingsGroup(
          children: [
            SettingsRow(icon: Icons.volume_up_outlined, title: 'Sound'),
          ],
        ),
      );

      expect(AppSizes.rowMinHeight, greaterThanOrEqualTo(AppIconTile.size));
      expect(
        tester.getSize(find.byType(SettingsRow)).height,
        greaterThanOrEqualTo(AppIconTile.size),
        reason: 'a 44 px tile in a shorter row is a clipped tile',
      );
    });
  });

  group('SettingsGroup', () {
    testWidgets('is one rounded surface with a divider per boundary', (
      tester,
    ) async {
      await pump(
        tester,
        const SettingsGroup(
          children: [
            SettingsRow(icon: Icons.history, title: 'One'),
            SettingsRow(icon: Icons.history, title: 'Two'),
            SettingsRow(icon: Icons.history, title: 'Three'),
          ],
        ),
      );

      // D-91: the fill moved off a `ColoredBox` and onto the card's own
      // `BoxDecoration`, because the card now also draws an outline and a
      // shadow — three things a fill-only widget cannot express.
      expect(
        SettingsGroup.decoration(tester.element(find.byType(SettingsGroup)))
            .color,
        AppColors.surface,
      );

      final clip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byType(SettingsGroup),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, BorderRadius.circular(AppRadius.card));

      // Three rows means two internal boundaries, never a leading or trailing
      // line (desing.md §5.3).
      expect(find.byType(Divider), findsNWidgets(2));
    });

    // D-91. The card is a `DecoratedBox` now rather than a `ColoredBox`,
    // because a fill alone cannot draw an outline or a shadow — and on a black
    // page the outline is the only thing saying where the card ends. Asserted
    // through the public `decoration` helper rather than by digging a
    // `DecoratedBox` out of the tree, so the test states the recipe instead of
    // the widget arrangement that happens to implement it.
    testWidgets(
      'is the sibling app card: filled, outlined, no shadow in dark',
      (tester) async {
        await pump(
          tester,
          const SettingsGroup(
            children: [SettingsRow(icon: Icons.history, title: 'One')],
          ),
        );

        final decoration = SettingsGroup.decoration(
          tester.element(find.byType(SettingsGroup)),
        );

        expect(decoration.color, AppColors.surface);
        expect(decoration.borderRadius, BorderRadius.circular(AppRadius.card));
        expect(decoration.border, Border.all(color: AppColors.cardBorder));
        expect(
          decoration.boxShadow,
          isEmpty,
          reason: 'Ethar drops its card shadow in dark and so does this app',
        );
      },
    );

    testWidgets('the hairline starts past the icon tile, not under it', (
      tester,
    ) async {
      await pump(
        tester,
        const SettingsGroup(
          children: [
            SettingsRow(icon: Icons.history, title: 'One'),
            SettingsRow(icon: Icons.history, title: 'Two'),
          ],
        ),
      );

      // D-91: the divider used to start at 16, drawing a line under the leading
      // icon as well as the text — the icon read as belonging to the row above.
      // It now starts where the titles do.
      final divider = tester.widget<Divider>(find.byType(Divider));
      expect(divider.indent, AppSpacing.dividerIndent);
      expect(divider.endIndent, AppSpacing.dividerEndIndent);
      expect(divider.color, AppColors.divider);
      expect(
        AppSpacing.dividerIndent,
        greaterThan(AppIconTile.size),
        reason: 'the line must clear the tile, or the tile belongs to two rows',
      );
    });
  });

  group('ToggleRow', () {
    testWidgets('shows a switch reflecting the current value', (tester) async {
      var toggled = false;
      await pump(
        tester,
        SettingsGroup(
          children: [
            ToggleRow(
              icon: Icons.phone_iphone,
              title: 'Vibration',
              value: true,
              onChanged: (value) => toggled = value,
            ),
          ],
        ),
      );

      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(toggled, isFalse);
    });

    testWidgets('the whole row toggles, not just the switch', (tester) async {
      var toggled = false;
      await pump(
        tester,
        SettingsGroup(
          children: [
            ToggleRow(
              icon: Icons.phone_iphone,
              title: 'Vibration',
              value: false,
              onChanged: (value) => toggled = value,
            ),
          ],
        ),
      );

      await tester.tap(find.text('Vibration'));
      await tester.pumpAndSettle();
      expect(toggled, isTrue);
    });

    // D-92. The switch is the trailing slot of a `ToggleRow`, so it carried the
    // same mid-row float as the Theme chevron — all three preferences showed
    // their switch floating short of the card's right edge.
    testWidgets('its switch sits flush against the right padding', (
      tester,
    ) async {
      await pump(
        tester,
        SettingsGroup(
          children: [
            ToggleRow(
              icon: Icons.phone_iphone,
              title: 'Vibration',
              value: true,
              onChanged: (_) {},
            ),
          ],
        ),
      );

      final contentRight =
          tester.getRect(find.byType(SettingsRow)).right -
          AppSpacing.cardPadding;
      expect(
        tester.getRect(find.byType(Switch)).right,
        moreOrLessEquals(contentRight, epsilon: 0.5),
      );
    });
  });

  group('HistoryCard', () {
    testWidgets('leads with the result and follows with the expression (D-93)', (
      tester,
    ) async {
      await pump(
        tester,
        const HistoryCard(expression: '125 × 8', result: '1,000'),
      );

      // D-93 flips the two lines onto Ethar's hierarchy: the result is the
      // 17/w700 *title* and the expression is the 13 muted *meta* row. The
      // styles themselves are asserted in the `AppTypography` group above —
      // what matters here is that the card prints them in that order, because
      // swapping them back is the single easiest regression to reintroduce and
      // neither style says on its own which line it is.
      expect(
        tester.widget<Text>(find.text('125 × 8')).style,
        AppTypography.historyExpression,
      );
      expect(
        tester.widget<Text>(find.text('1,000')).style,
        AppTypography.historyResult,
      );

      final resultY = tester.getRect(find.text('1,000')).center.dy;
      final expressionY = tester.getRect(find.text('125 × 8')).center.dy;
      expect(
        resultY,
        lessThan(expressionY),
        reason: 'the result is the title line, so it comes first',
      );

      // The meta row carries Ethar's leading clock glyph at 17 px — the one
      // thing on the card that says *when* this happened.
      final glyph = tester.widget<Icon>(
        find.descendant(
          of: find.byType(HistoryCard),
          matching: find.byIcon(Icons.schedule_rounded),
        ),
      );
      expect(glyph.size, AppSizes.historyMetaGlyph);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('sits on the card surface', (tester) async {
      await pump(tester, const HistoryCard(expression: '1 + 1', result: '2'));

      // D-93 moved the fill off the [Material] and onto the decoration that
      // wraps it, because that decoration now also carries the outline and the
      // shadow and a second opaque `Material` on top would hide both. So the
      // fill is read off the `AnimatedContainer`, which is the widget that owns
      // the card's surface.
      expect(
        decorationOf(tester, selected: false).color,
        AppColors.surfaceRaised,
      );
    });

    testWidgets('is a rounded, outlined card with no elevation (D-93)', (
      tester,
    ) async {
      await pump(
        tester,
        const HistoryCard(expression: '125 × 8', result: '1,000'),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(HistoryCard),
          matching: find.byType(Material),
        ),
      );

      expect(
        material.elevation,
        0,
        reason:
            'the shadow is Ethar\'s, painted by the decoration, not '
            'Material elevation',
      );
      expect(
        material.color,
        Colors.transparent,
        reason:
            'the decoration owns the fill; a second opaque layer would '
            'hide the shadow',
      );

      // D-93 reverses D-72's "borderless, shadowless" rule: Ethar outlines every
      // card in both themes, and the outline is what makes a `#151517` card an
      // object on a black page. This is the assertion D-72 deliberately inverted.
      final resting = decorationOf(tester, selected: false);
      final border = resting.border! as Border;
      expect(border.top.color, AppColors.cardBorder);
      expect(border.top.width, HistoryCard.restingBorderWidth);
      expect(
        resting.borderRadius,
        BorderRadius.circular(AppRadius.historyCard),
      );
      // The dark palette has no `cardShadow`, so it draws an empty list rather
      // than a zero-alpha one — which is what makes "no shadow" readable here.
      expect(
        AppPalette.dark.cardShadow,
        isNull,
        reason: 'a shadow on a black page is invisible',
      );
      expect(resting.boxShadow, isEmpty);
    });

    testWidgets('reserves at least the design height, not a fixed one', (
      tester,
    ) async {
      await pump(tester, const HistoryCard(expression: '1 + 1', result: '2'));

      // A minimum rather than a `SizedBox(height: 88)`: at the 1.3x text-scale
      // ceiling (D-54) the content outgrows it and the card has to grow with
      // it. `history_responsive_test.dart` covers that half.
      //
      // D-93 does not move the floor: 17·1.25 + 7 + 13·1.3 is ~45 of content
      // inside 34 of padding, which is still under 88.
      expect(
        tester.getSize(find.byType(HistoryCard)).height,
        greaterThanOrEqualTo(AppSizes.historyCardMinHeight),
      );
    });

    testWidgets('sits on the app margin rather than inboard of it', (
      tester,
    ) async {
      await pump(tester, const HistoryCard(expression: '1 + 1', result: '2'));

      // D-73 removed `historyHorizontal`. The card's *outer edge* starts on the
      // shared 24 px line, which is the line the header's back arrow glyph lands
      // on (D-70) — so the whole page now shares one left edge.
      //
      // D-93: the outer edge is the `AnimatedContainer`, not the `Material`.
      // `Container` subtracts a border's width from its child's box, so the
      // `Material` inside now starts one pixel in — at 24 + the 1 px resting
      // outline. Asserting the Material would be asserting the outline's width,
      // which is a value this card borrows from a sibling app and could change;
      // asserting the decoration means asserting the card.
      final card = find.descendant(
        of: find.byType(HistoryCard),
        matching: find.byType(AnimatedContainer),
      );
      expect(tester.getRect(card).left, AppSpacing.screenHorizontal);
    });

    testWidgets('keeps the chevron in proportion to the card', (tester) async {
      await pump(tester, const HistoryCard(expression: '1 + 1', result: '2'));

      // D-73 dropped the chevron from a header-sized 28 to a row-sized 22. It is
      // an affordance, not content, and at 28 it was a third of the card's
      // height.
      final icon = tester.widget<AppIcon>(
        find.descendant(
          of: find.byType(HistoryCard),
          matching: find.byType(AppIcon),
        ),
      );
      expect(icon.size, AppIconSize.row);
      expect(
        icon.size.value,
        lessThan(AppSizes.historyCardMinHeight / 3),
        reason: 'a glyph this size would dominate the card it points from',
      );
    });
  });

  group('HistoryDayLabel', () {
    testWidgets('keeps sentence case where SectionHeader uppercases', (
      tester,
    ) async {
      await pump(tester, const HistoryDayLabel('Today'));

      // The shared SectionHeader shouts; this one does not. Asserting both makes
      // the difference explicit rather than incidental, so a future edit cannot
      // quietly hand the History list the uppercase style.
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('TODAY'), findsNothing);
    });

    testWidgets('paints the label at the day-label token', (tester) async {
      await pump(tester, const HistoryDayLabel('Yesterday'));

      expect(
        tester.widget<Text>(find.text('Yesterday')).style,
        AppTypography.historyDayLabel,
      );
    });

    testWidgets('shares the app margin with the cards below it', (
      tester,
    ) async {
      await pump(tester, const HistoryDayLabel('Today'));

      // D-73 removed the dedicated `historyHorizontal` this used to double, so
      // the heading and the cards are now flush on one edge — the same 24 px line
      // the header's back arrow lands on. A label still on its own inset would
      // read as a misalignment rather than as a design.
      expect(
        tester.getRect(find.text('Today')).left,
        AppSpacing.screenHorizontal,
      );
    });

    testWidgets('opens more space above it than it does below', (tester) async {
      await pump(tester, const HistoryDayLabel('Today'));

      // The space above is the day boundary; the space below belongs to the
      // label. Collapsing the two would make a day read as another card.
      expect(AppSpacing.historyGroupGap, greaterThan(AppSpacing.sm));
    });

    testWidgets('is announced as a header so days can be jumped to', (
      tester,
    ) async {
      await pump(tester, const HistoryDayLabel('Sep 20, 2026'));

      // D-59: the size is a visual device only. Without the flag TalkBack reads
      // the day exactly like the expressions beneath it.
      expect(
        tester.getSemantics(find.text('Sep 20, 2026')),
        matchesSemantics(
          isHeader: true,
          label: 'Sep 20, 2026',
          textDirection: TextDirection.ltr,
        ),
      );
    });
  });

  group('AppConfirmationDialog', () {
    testWidgets('resolves false when the user cancels', (tester) async {
      bool? confirmed;
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              confirmed = await AppConfirmationDialog.show(
                context,
                title: 'Clear history?',
                message: 'This cannot be undone.',
                confirmLabel: 'Clear',
              );
            },
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Clear history?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(confirmed, isFalse);
    });

    testWidgets('resolves true only on confirm', (tester) async {
      bool? confirmed;
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              confirmed = await AppConfirmationDialog.show(
                context,
                title: 'Clear history?',
                message: 'This cannot be undone.',
                confirmLabel: 'Clear',
              );
            },
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
    });

    testWidgets('the confirm action is orange, the cancel action is not', (
      tester,
    ) async {
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => AppConfirmationDialog.show(
              context,
              title: 'Clear history?',
              message: 'This cannot be undone.',
              confirmLabel: 'Clear',
            ),
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.text('Clear')).style?.color,
        AppColors.accent,
      );
      expect(
        tester.widget<Text>(find.text('Cancel')).style?.color,
        AppColors.textSecondary,
      );
    });
  });

  group('EmptyState', () {
    testWidgets('shows an icon, a title, and guidance', (tester) async {
      await pump(
        tester,
        const EmptyState(
          icon: Icons.history,
          title: 'No calculations yet',
          message: 'Results will appear here.',
        ),
      );

      expect(find.byIcon(Icons.history), findsOneWidget);
      expect(find.text('No calculations yet'), findsOneWidget);
      expect(find.text('Results will appear here.'), findsOneWidget);
    });

    testWidgets('omits the guidance when there is none', (tester) async {
      await pump(
        tester,
        const EmptyState(icon: Icons.history, title: 'No calculations yet'),
      );

      expect(find.text('No calculations yet'), findsOneWidget);
    });
  });

  group('AppBrandIcon', () {
    testWidgets('is a 2x2 grid of two light and two orange keys (§5.5)', (
      tester,
    ) async {
      await pump(tester, const Center(child: AppBrandIcon()));

      final decorations = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(AppBrandIcon),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => (box.decoration as BoxDecoration).color)
          .toList();

      // The two-orange / two-light split was confirmed by measuring the pixels
      // of mockup 02_30_45.
      expect(decorations.where((color) => color == AppColors.accent).length, 2);
      expect(
        decorations.where((color) => color == AppColors.buttonFunction).length,
        2,
      );
      expect(find.text('+'), findsOneWidget);
      expect(find.text('−'), findsOneWidget);
      expect(find.text('×'), findsOneWidget);
      expect(find.text('='), findsOneWidget);
    });
  });

  group('AppIcon', () {
    testWidgets('resolves its size from the bucket', (tester) async {
      await pump(
        tester,
        const Center(child: AppIcon(Icons.history, size: AppIconSize.small)),
      );

      expect(
        tester.widget<Icon>(find.byType(Icon)).size,
        AppIconSize.small.value,
      );
    });

    testWidgets('is decorative unless given a semantic label', (tester) async {
      await pump(tester, const Center(child: AppIcon(Icons.menu)));
      expect(find.bySemanticsLabel('menu'), findsNothing);

      await pump(
        tester,
        const Center(
          child: AppIcon(Icons.menu, semanticLabel: 'Open settings'),
        ),
      );
      expect(find.bySemanticsLabel('Open settings'), findsOneWidget);
    });
  });

  group('AppTrashIcon', () {
    testWidgets('occupies the same square an AppIcon of that bucket would', (
      tester,
    ) async {
      // D-70 places the header's delete glyph by *measuring* its box, so a
      // painted icon that came out a different size from a Material one would
      // land off the 24 px margin while every assertion about the button still
      // passed. The box is the contract, not the glyph.
      await pump(tester, const Center(child: AppTrashIcon()));
      expect(
        tester.getSize(find.byType(AppTrashIcon)).width,
        AppIconSize.row.value,
      );

      await pump(
        tester,
        const Center(child: AppTrashIcon(size: AppIconSize.large)),
      );
      expect(
        tester.getSize(find.byType(AppTrashIcon)).width,
        AppIconSize.large.value,
      );
    });

    testWidgets('paints in the colour it is given, defaulting to white', (
      tester,
    ) async {
      await pump(tester, const Center(child: AppTrashIcon()));
      expect(trashPainter(tester).color, AppColors.textPrimary);

      await pump(
        tester,
        const Center(child: AppTrashIcon(color: AppColors.accent)),
      );
      expect(trashPainter(tester).color, AppColors.accent);
    });

    testWidgets('is decorative unless given a semantic label', (tester) async {
      await pump(tester, const Center(child: AppTrashIcon()));
      expect(find.bySemanticsLabel('Clear history'), findsNothing);

      await pump(
        tester,
        const Center(child: AppTrashIcon(semanticLabel: 'Clear history')),
      );
      expect(find.bySemanticsLabel('Clear history'), findsOneWidget);
    });

    testWidgets('repaints only when the colour changes', (tester) async {
      await pump(tester, const Center(child: AppTrashIcon()));

      expect(
        trashPainter(tester)
            .shouldRepaint(const AppTrashPainter(AppColors.textPrimary)),
        isFalse,
        reason: 'nothing to redraw, and the glyph is not animated',
      );
      expect(
        trashPainter(tester)
            .shouldRepaint(const AppTrashPainter(AppColors.accent)),
        isTrue,
      );
    });

    test('the slots are holes, not bars', () {
      // The one property of the ported geometry nothing outside the file can see:
      // the two vertical slots are sub-paths of the *same* `Path` as the body and
      // they wind the opposite way, so the non-zero fill rule subtracts them.
      // Flipping either — separate paths, or `PathFillType.evenOdd`, or a
      // reversed sub-path — would paint a solid trash with two darker bars and no
      // assertion about a widget's size, colour, or position would notice. So this
      // asks the path itself what it contains, in the grid's own units.
      final path = AppTrashPainter.path;

      // The lid bar, and the body on its centre line between the two slots.
      expect(path.contains(const Offset(12, 4)), isTrue);
      expect(path.contains(const Offset(12, 15)), isTrue);
      // Each slot, at its own centre.
      expect(path.contains(const Offset(9, 15)), isFalse);
      expect(path.contains(const Offset(15, 15)), isFalse);
      // Beside the body, and in the gap between the lid and the body — the lid
      // ends at y 5 and the body starts at y 7, so y 6 is the only place the two
      // shapes do not meet.
      expect(path.contains(const Offset(3, 15)), isFalse);
      expect(path.contains(const Offset(12, 6)), isFalse);
    });

    test('is centred on its own grid', () {
      // D-70 places this glyph by measuring its box, so ink that sat off-centre
      // inside that box would land somewhere other than the 24 px margin. The path
      // is authored on a 24-unit grid and this is what makes "centred" a fact
      // about the drawing rather than a hope.
      final bounds = AppTrashPainter.path.getBounds();
      const grid = AppTrashPainter.grid;

      expect(bounds.center.dx, closeTo(grid / 2, 0.01));
      expect(bounds.center.dy, closeTo(grid / 2, 0.01));
    });
  });
}

/// The painter the mounted [AppTrashIcon] draws with.
AppTrashPainter trashPainter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(AppTrashIcon),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as AppTrashPainter;

/// Mounts [child] inside a real app theme, since the components resolve their
/// colours through it.
Future<void> pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

/// The fill colour of the single [Material] a [CalculatorButton] paints with.
Color? fillOf(WidgetTester tester) => tester
    .widget<Material>(
      find.descendant(
        of: find.byType(CalculatorButton),
        matching: find.byType(Material),
      ),
    )
    .color;

/// The corner radius the button's fill uses, which is what makes it a circle.
BorderRadius? borderRadiusOf(WidgetTester tester) {
  final border =
      tester
              .widget<Material>(
                find.descendant(
                  of: find.byType(CalculatorButton),
                  matching: find.byType(Material),
                ),
              )
              .shape
          as RoundedRectangleBorder;
  return border.borderRadius as BorderRadius?;
}

TextStyle? labelStyleOf(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style;

/// Placeholder tap handler for rows shown for their appearance only.
void _noop() {}
