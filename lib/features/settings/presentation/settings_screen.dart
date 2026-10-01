import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_info.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/widgets/core_widgets.dart';
import '../../../routing/app_routes.dart';
import '../domain/app_settings.dart';
import 'decimal_places_sheet.dart';
import 'settings_controller.dart';

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
                // Display-only in v1.0 (D-45). The explicit `trailing` is
                // required rather than relying on the row's own chevron,
                // because SettingsRow only draws one when `onTap != null` — and
                // setting `onTap` would invent a screen the app does not have.
                trailing: const AppIcon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                ),
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
              style: AppTypography.caption,
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

  /// The human name of the stored [AppSettings.theme] (D-45).
  ///
  /// Reads the stored value rather than hard-coding “Dark mode”, so the row
  /// tells the truth if a light theme is ever added, while still collapsing to
  /// a single branch today. The default stands in for an unrecognised name, so a
  /// corrupt preference cannot render a blank subtitle.
  static String _themeLabel(String theme) =>
      theme == 'dark' ? 'Dark mode' : AppSettings.defaults.theme;
}
