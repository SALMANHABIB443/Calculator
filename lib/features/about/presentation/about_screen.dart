import '../../../../core/design/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_info.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/services/review_service.dart';
import '../../../core/services/share_service.dart';
import '../../../core/widgets/core_widgets.dart';
import '../../../routing/app_routes.dart';

/// App branding, version, and the share/rate system actions
/// (prd.md §10, desing.md §6.4).
///
/// The hero, the three APP INFORMATION rows, and the three MORE rows follow
/// `desing.md` §6.4 and `feature.md` §D. Rate and Share go through
/// [reviewServiceProvider] / [shareServiceProvider] so the plugin calls stay
/// behind a test seam (D-53); an `unavailable` outcome surfaces as a SnackBar
/// rather than a blank press.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void rateApp() async {
      final outcome = await ref.read(reviewServiceProvider).rateApp();
      if (!context.mounted) return;
      if (outcome == ReviewOutcome.unavailable) {
        _showUnavailable(context);
      }
    }

    void shareApp() async {
      final outcome = await ref.read(shareServiceProvider).shareApp();
      if (!context.mounted) return;
      if (outcome == ShareOutcome.unavailable) {
        _showUnavailable(context);
      }
    }

    return SecondaryPageScaffold(
      header: const SecondaryPageHeader(title: 'About'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          0,
          AppSpacing.lg,
          0,
          AppSpacing.bottomSafe,
        ),
        children: [
          const _HeroCard(),
          const SectionHeader('App Information'),
          SettingsGroup(
            children: [
              SettingsRow(
                icon: Icons.label_outline,
                title: 'App Name',
                trailing: Text(
                  AppInfo.name,
                  style: context.type.rowValue,
                ),
              ),
              SettingsRow(
                icon: Icons.info_outline,
                title: 'Version',
                trailing: Text(
                  AppInfo.version.split('+').first,
                  style: context.type.rowValue,
                ),
              ),
              SettingsRow(
                icon: Icons.person_outline,
                title: 'Developer',
                trailing: Text(
                  AppInfo.developer,
                  style: context.type.rowValue,
                ),
              ),
            ],
          ),
          const SectionHeader('More'),
          SettingsGroup(
            children: [
              SettingsRow(
                icon: Icons.star_outline,
                title: 'Rate App',
                subtitle: 'Support us with your rating',
                onTap: rateApp,
              ),
              SettingsRow(
                icon: Icons.share_outlined,
                title: 'Share App',
                subtitle: 'Tell your friends about this app',
                onTap: shareApp,
              ),
              SettingsRow(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                subtitle: 'Read our terms and conditions',
                onTap: () => context.push(AppRoutes.terms),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A system action the platform could not perform (D-53): kept quiet enough
  /// to be unobtrusive while still telling the user the press did something.
  void _showUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: context.appColors.surface,
          content: Text('This action is unavailable right now', style: context.type.body),
        ),
      );
  }
}

/// Brand mark + name + version + description (desing.md §6.4).
class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sectionGap,
        horizontal: AppSpacing.cardPadding,
      ),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.dialog),
      ),
      child: Column(
        children: [
          const AppBrandIcon(size: AppSizes.brandIcon),
          const SizedBox(height: AppSpacing.lg),
          Text(AppInfo.name, style: context.type.screenTitle),
          const SizedBox(height: 4),
          Text(
            'Version ${AppInfo.version.split('+').first}',
            style: context.type.subtitle,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            AppInfo.description,
            textAlign: TextAlign.center,
            style: context.type.body,
          ),
        ],
      ),
    );
  }
}