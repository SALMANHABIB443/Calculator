import 'package:calculator/core/design/app_colors.dart';
import 'package:calculator/core/design/app_spacing.dart';
import 'package:calculator/core/design/app_theme.dart';
import 'package:calculator/core/design/app_typography.dart';
import 'package:calculator/core/widgets/core_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
      expect(
        AppRadius.historyCard,
        greaterThan(AppRadius.card),
        reason: 'a single card is softer than the group it sits in',
      );
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
      // D-72 replaced the History type scale with figures of its own and D-73 put
      // it back on `desing.md` §3's bands, so these assert the design doc again
      // rather than the redesign's. The relationship between the two card lines
      // is asserted too: the result has to stay visibly the larger of them.
      expect(
        AppTypography.historyExpression.fontSize,
        inInclusiveRange(15, 16),
      );
      expect(AppTypography.historyResult.fontSize, inInclusiveRange(20, 22));
      expect(
        AppTypography.historyDayLabel.fontSize,
        AppTypography.rowTitle.fontSize,
        reason: 'a day heading is the same kind of thing as a row label',
      );
      expect(
        AppTypography.historyResult.fontSize!,
        greaterThan(AppTypography.historyExpression.fontSize!),
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
      expect(CalculatorButtonVariant.digit.background, AppColors.buttonDigit);
      expect(CalculatorButtonVariant.digit.foreground, AppColors.textPrimary);
      expect(CalculatorButtonVariant.operator.background, AppColors.accent);
      expect(
        CalculatorButtonVariant.operator.foreground,
        AppColors.textPrimary,
      );
      expect(
        CalculatorButtonVariant.function.background,
        AppColors.buttonFunction,
      );
      expect(
        CalculatorButtonVariant.function.foreground,
        AppColors.textOnFunction,
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

      final surface = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(SettingsGroup),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(surface.color, AppColors.surface);

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
  });

  group('HistoryCard', () {
    testWidgets('shows the expression above the larger result', (tester) async {
      await pump(
        tester,
        const HistoryCard(expression: '125 × 8', result: '1,000'),
      );

      expect(
        tester.widget<Text>(find.text('125 × 8')).style,
        AppTypography.historyExpression,
      );
      expect(
        tester.widget<Text>(find.text('1,000')).style,
        AppTypography.historyResult,
      );
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('sits on the card surface', (tester) async {
      await pump(tester, const HistoryCard(expression: '1 + 1', result: '2'));

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(HistoryCard),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, AppColors.surfaceRaised);
    });

    testWidgets('is a rounded, borderless, shadowless card (D-72)', (
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
        reason: 'a card on a black page casts nothing',
      );
      expect(
        material.shape,
        isNull,
        reason: 'no border: the fill is the only edge',
      );

      // The fill is painted by a `Material`/`InkWell` pair, so the radius has to
      // be read off the Material's type rather than off a `ClipRRect` the way
      // `SettingsGroup` publishes its own.
      expect(
        material.borderRadius,
        BorderRadius.circular(AppRadius.historyCard),
      );
    });

    testWidgets('reserves at least the design height, not a fixed one', (
      tester,
    ) async {
      await pump(tester, const HistoryCard(expression: '1 + 1', result: '2'));

      // A minimum rather than a `SizedBox(height: 88)`: at the 1.3x text-scale
      // ceiling (D-54) the content outgrows it and the card has to grow with
      // it. `history_responsive_test.dart` covers that half.
      expect(
        tester.getSize(find.byType(HistoryCard)).height,
        greaterThanOrEqualTo(AppSizes.historyCardMinHeight),
      );
    });

    testWidgets('sits on the app margin rather than inboard of it', (
      tester,
    ) async {
      await pump(tester, const HistoryCard(expression: '1 + 1', result: '2'));

      // D-73 removed `historyHorizontal`. The card's *fill* starts on the shared
      // 24 px line, which is the line the header's back arrow glyph lands on
      // (D-70) — so the whole page now shares one left edge.
      final material = find.descendant(
        of: find.byType(HistoryCard),
        matching: find.byType(Material),
      );
      expect(tester.getRect(material).left, AppSpacing.screenHorizontal);
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
