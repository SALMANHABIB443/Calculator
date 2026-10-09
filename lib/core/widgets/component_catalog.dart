import '../../../core/design/app_palette.dart';
import 'package:flutter/material.dart';

import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import 'app_brand_icon.dart';
import 'app_dialog.dart';
import 'app_icon.dart';
import 'app_trash_icon.dart';
import 'calculator_button.dart';
import 'empty_state.dart';
import 'history_card.dart';
import 'secondary_page_header.dart';
import 'secondary_page_scaffold.dart';
import 'section_header.dart';
import 'settings_row.dart';
import 'toggle_row.dart';

/// A catalogue of every shared component, for eyeballing the design system
/// against the mockups (phases.md §Phase 3, "component catalog").
///
/// **Debug only.** It is registered as `/catalog` behind `kDebugMode` in
/// `app_router.dart` and is unreachable from the shipped navigation graph
/// (D-20), so no release build contains it. There is deliberately no button
/// anywhere in the app that opens it; navigate to the route by hand, e.g.
/// `flutter run` then a deep link, or temporarily inverting
/// [AppRoutes.calculator] as the router's `initialLocation`.
///
/// This screen resolved both long-standing residual unknowns in Phase 9: the
/// toggle OFF track (R-1, closed as a decision in **D-61**) and the calculator
/// key diameter (R-2, closed by measurement in **D-60**). It is the place to
/// eyeball any future change to the palette or the type scale.
class ComponentCatalogScreen extends StatefulWidget {
  const ComponentCatalogScreen({super.key});

  @override
  State<ComponentCatalogScreen> createState() => _ComponentCatalogScreenState();
}

class _ComponentCatalogScreenState extends State<ComponentCatalogScreen> {
  bool _sound = true;
  bool _vibration = false;

  @override
  Widget build(BuildContext context) {
    return SecondaryPageScaffold(
      header: const SecondaryPageHeader(title: 'Catalog'),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.sectionGap),
        children: [
          _label('Colors'),
          _swatches(),
          const SectionHeader('Typography'),
          ..._typographySamples(),
          const SectionHeader('Calculator keys'),
          _calculatorKeys(),
          const SectionHeader('Rows and cards'),
          SettingsGroup(
            children: [
              SettingsRow(
                icon: Icons.wb_sunny_outlined,
                title: 'Theme',
                subtitle: 'Dark mode',
                onTap: () {},
              ),
              SettingsRow(
                icon: Icons.numbers,
                title: 'Decimal Places',
                subtitle: '2 decimal places',
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ],
          ),
          SectionHeader('Toggles'),
          SettingsGroup(
            children: [
              ToggleRow(
                icon: Icons.volume_up_outlined,
                title: 'Sound',
                subtitle: 'Key press sound',
                value: _sound,
                onChanged: (value) => setState(() => _sound = value),
              ),
              ToggleRow(
                icon: Icons.phone_iphone,
                title: 'Vibration',
                subtitle: 'Haptic feedback',
                value: _vibration,
                onChanged: (value) => setState(() => _vibration = value),
              ),
            ],
          ),
          const SectionHeader('History card'),
          const HistoryCard(
            expression: '125 × 8',
            result: '1,000',
            onTap: _noop,
          ),
          const SectionHeader('Brand mark'),
          const Center(child: AppBrandIcon()),
          const SectionHeader('Icons'),
          _icons(),
          const SectionHeader('Empty state'),
          const SizedBox(
            height: 260,
            child: EmptyState(
              icon: Icons.history,
              title: 'No calculations yet',
              message: 'Results you calculate will appear here.',
            ),
          ),
          const SectionHeader('Dialog'),
          Center(
            child: TextButton(
              onPressed: () => AppConfirmationDialog.show(
                context,
                title: 'Clear history?',
                message: 'This removes every saved calculation. '
                    'This cannot be undone.',
                confirmLabel: 'Clear',
              ),
              child: Text(
                'Show confirmation dialog',
                style: context.type.bottomAction,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.screenHorizontal,
      AppSpacing.lg,
      AppSpacing.screenHorizontal,
      AppSpacing.sm,
    ),
    child: Text(text.toUpperCase(), style: context.type.sectionHeader),
  );

  /// Every palette token with its hex, so a Phase 9 correction is visible here
  /// before it is compared against the mockup.
  Widget _swatches() {
    // Built per build rather than as a `const` map: a palette is theme state,
    // and this catalogue is exactly where a designer should see the values the
    // running theme is actually using, not the dark theme's.
    final tokens = <String, Color>{
      'background': context.appColors.background,
      'surface': context.appColors.surface,
      'accent': context.appColors.accent,
      'buttonDigit': context.appColors.buttonDigit,
      'buttonFunction': context.appColors.buttonFunction,
      'textPrimary': context.appColors.textPrimary,
      'onFunction': context.appColors.textOnFunction,
      'textSecondary': context.appColors.textSecondary,
      'divider': context.appColors.divider,
      'trackOn': context.appColors.toggleTrackOn,
      'trackOff': context.appColors.toggleTrackOff,
      'thumb': context.appColors.toggleThumb,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          for (final entry in tokens.entries)
            _Swatch(name: entry.key, color: entry.value),
        ],
      ),
    );
  }

  List<Widget> _typographySamples() {
    final samples = <String, TextStyle>{
      'resultLarge': context.type.resultLarge,
      'expression': context.type.expression,
      'screenTitle': context.type.screenTitle,
      'subtitle': context.type.subtitle,
      'sectionHeader': context.type.sectionHeader,
      'rowTitle': context.type.rowTitle,
      'rowSubtitle': context.type.rowSubtitle,
      'historyExpression': context.type.historyExpression,
      'historyResult': context.type.historyResult,
      'buttonLabel': context.type.buttonLabel,
      'bottomAction': context.type.bottomAction,
      'caption': context.type.caption,
      'body': context.type.body,
    };

    return [
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in samples.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 132,
                      child: Text(
                        '${entry.key} ${entry.value.fontSize!.toStringAsFixed(0)}',
                        style: context.type.caption,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'The quick brown fox',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: entry.value,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
  }

  /// A miniature of the real keypad: three variants plus the wide `0`.
  Widget _calculatorKeys() {
    Widget key(String label, CalculatorButtonVariant variant,
            {bool isWide = false}) =>
        CalculatorButton(
          label: label,
          variant: variant,
          isWide: isWide,
          onPressed: () {},
          semanticLabel: '$label key',
        );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 88,
            child: Row(
              children: [
                key('7', CalculatorButtonVariant.digit),
                const SizedBox(width: AppSpacing.md),
                key('AC', CalculatorButtonVariant.function),
                const SizedBox(width: AppSpacing.md),
                key('÷', CalculatorButtonVariant.operator),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 88,
            child: Row(
              children: [
                key('0', CalculatorButtonVariant.digit, isWide: true),
                const SizedBox(width: AppSpacing.md),
                key('.', CalculatorButtonVariant.digit),
                const SizedBox(width: AppSpacing.md),
                key('=', CalculatorButtonVariant.operator),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _icons() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          AppIcon(Icons.menu),
          AppIcon(Icons.history),
          AppTrashIcon(color: context.appColors.accent),
          AppIcon(Icons.star_outline),
          AppIcon(Icons.calculate_outlined, size: AppIconSize.small),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final hex = color.toARGB32().toRadixString(16).padLeft(8, '0');
    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.tile),
              border: Border.all(color: context.appColors.divider),
            ),
          ),
          const SizedBox(height: AppSpacing.sm / 2),
          Text(name, style: context.type.caption),
          Text('#${hex.toUpperCase()}', style: context.type.caption),
        ],
      ),
    );
  }
}

/// Placeholder tap handler for catalog cards, which are shown for their
/// appearance rather than their behaviour.
void _noop() {}