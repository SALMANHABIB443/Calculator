import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_info.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/widgets/core_widgets.dart';
import '../../../routing/app_routes.dart';
import '../domain/app_settings.dart';
import 'decimal_places_sheet.dart';
import 'settings_controller.dart';
import 'theme_sheet.dart';

/// User preferences plus the entry points to About and the legal screens
/// (desing.md §6.3).
///
/// Rows, sections, and copy follow `desing.md` §6.3 and `feature.md` §C. A
/// [ConsumerWidget] because every control reads its value from
/// [settingsProvider] and writes through [SettingsNotifier]; the three
/// toggles are [ToggleRow]s and the precision opens [DecimalPlacesSheet].
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    // `unawaited` throughout: a toggle must move on the frame it was touched,
    // never after a disk write. The controller publishes optimistically, so the
    // effect is immediate even though the persist is not (AC-004).
    void setSound(bool value) =>
        unawaited(controller.apply((s) => s.copyWith(soundEnabled: value)));

    void setVibration(bool value) => unawaited(
      controller.apply((s) => s.copyWith(vibrationEnabled: value)),
    );

    void setHistory(bool value) =>
        unawaited(controller.apply((s) => s.copyWith(historyEnabled: value)));

    return SecondaryPageScaffold(
      // Every secondary header is now the same: the title alone, at the shared
      // `screenTitle`. The header no longer grows a subtitle line, so there is
      // nothing left for this one to step down for.
      header: const SecondaryPageHeader(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.bottomSafe),
        children: [
          const SectionHeader('Appearance'),
          SettingsGroup(
            children: [
              SettingsRow(
                icon: Icons.wb_sunny_outlined,
                title: 'Theme',
                subtitle: _themeLabel(settings.theme),
                // A picker rather than an inline toggle. The row's chevron
                // promises something *below*, which is the same affordance the
                // Decimal Places row uses, and two named options do not fit on
                // one row without either truncating or stealing the row's tap
                // target. D-45 made this read-only because dark was the only
                // theme; with two (D-90) it becomes a choice, and the sheet is
                // the smallest surface that expresses one.
                onTap: () async {
                  final chosen = await ThemeSheet.show(
                    context,
                    selected: AppThemeName.from(settings.theme),
                  );
                  // Dismissing without choosing leaves the theme alone.
                  if (chosen == null) return;
                  await controller.apply(
                    (s) => s.copyWith(theme: chosen.storageValue),
                  );
                },
                // D-92: the chevron is deliberately *not* passed as
                // `trailing`. This row is tappable, so `SettingsRow` draws
                // the chevron itself — in the same 8 px gap and the same
                // `ExcludeSemantics` as every navigational row. Handing it one
                // explicitly bought nothing visually and cost the alignment:
                // an explicit trailing skips that gap, so this arrow sat 8 px
                // further right than the ones on App Version, Privacy Policy,
                // and Terms of Service.
              ),
            ],
          ),
          const SectionHeader('Preferences'),
          SettingsGroup(
            children: [
              ToggleRow(
                icon: Icons.volume_up_outlined,
                title: 'Sound',
                subtitle: 'Key press sound',
                value: settings.soundEnabled,
                onChanged: setSound,
              ),
              ToggleRow(
                icon: Icons.phone_iphone,
                title: 'Vibration',
                subtitle: 'Vibrate on key press',
                value: settings.vibrationEnabled,
                onChanged: setVibration,
              ),
              SettingsRow(
                icon: Icons.numbers,
                title: 'Decimal Places',
                subtitle: _decimalPlacesLabel(settings.decimalPlaces),
                onTap: () async {
                  final chosen = await DecimalPlacesSheet.show(
                    context,
                    selected: settings.decimalPlaces,
                  );
                  // Dismissing without choosing leaves the precision alone.
                  if (chosen == null) return;
                  await controller.apply(
                    (s) => s.copyWith(decimalPlaces: chosen),
                  );
                },
              ),
              ToggleRow(
                icon: Icons.history,
                title: 'History',
                subtitle: 'Keep calculation history',
                value: settings.historyEnabled,
                onChanged: setHistory,
              ),
            ],
          ),
          const SectionHeader('About'),
          SettingsGroup(
            children: [
              // feature.md FEAT-SET-006 calls this the App Version row and
              // says tapping it opens the About screen, which is what the
              // mockup's ABOUT section shows.
              SettingsRow(
                icon: Icons.info_outline,
                title: 'App Version',
                subtitle: AppInfo.version.split('+').first,
                onTap: () => context.push(AppRoutes.about),
              ),
              SettingsRow(
                icon: Icons.shield_outlined,
                title: 'Privacy Policy',
                onTap: () => context.push(AppRoutes.privacy),
              ),
              SettingsRow(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () => context.push(AppRoutes.terms),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Text(
              '${AppInfo.name} ${AppInfo.version.split('+').first}',
              style: context.type.caption,
            ),
          ),
          const SizedBox(height: AppSpacing.bottomSafe),
        ],
      ),
    );
  }

  /// “2 decimal places” — the wording feature.md FEAT-SET-004 quotes for the
  /// row subtitle. Singular at one place, which the docs leave unstated.
  static String _decimalPlacesLabel(int places) =>
      '$places decimal ${places == 1 ? 'place' : 'places'}';

  /// The human name of the stored [AppSettings.theme] (D-90).
  ///
  /// Resolved through [AppThemeName.from] rather than compared against a
  /// literal, so an unrecognised stored name renders the default's label instead
  /// of leaking the raw string into the UI — the old version's fallback returned
  /// `AppSettings.defaults.theme`, which happened to be `'dark'` and would have
  /// shown the word "dark" as if it were a label.
  static String _themeLabel(String theme) =>
      AppThemeName.from(theme).label;
}