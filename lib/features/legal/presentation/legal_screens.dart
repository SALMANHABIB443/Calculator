import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/widgets/core_widgets.dart';
import '../data/legal_content.dart';

/// Shared scaffold for the in-app legal pages (D-07).
///
/// Both documents are plain local text — no web view, no URL launcher, no
/// new dependency. The copy itself lives in `data/legal_content.dart` so it can
/// be reviewed without reading widget code (D-68).
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    required this.title,
    required this.sections,
    super.key,
  });

  /// Page title and header label, e.g. `Privacy Policy`.
  final String title;

  /// Ordered `(heading, body)` pairs rendered down the page.
  final List<({String heading, String body})> sections;

  @override
  Widget build(BuildContext context) {
    return SecondaryPageScaffold(
      header: SecondaryPageHeader(title: title),
      // A document with no sections yet shows a message rather than a blank
      // page (feature.md FEAT-LEGAL-001).
      body: sections.isEmpty
          ? const EmptyState(
              icon: Icons.description_outlined,
              title: 'Content coming soon',
              message: 'This document has not been written yet.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.lg,
                AppSpacing.screenHorizontal,
                AppSpacing.sectionGap,
              ),
              children: [
                for (final section in sections) ...[
                  Text(
                    section.heading,
                    style: AppTypography.legalHeading,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Bodies contain hard line breaks — the Privacy Policy uses
                  // them for its bulleted list of stored data. A plain `Text`
                  // already honours `\n`, so no paragraph splitting is needed,
                  // but each line must not wrap mid-list-item at narrow widths,
                  // which is what the horizontal padding plus body size buys.
                  Text(section.body, style: AppTypography.body),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ],
            ),
    );
  }
}

/// In-app Privacy Policy page (D-07).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      title: 'Privacy Policy',
      sections: privacyPolicySections,
    );
  }
}

/// In-app Terms of Service page (D-07).
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      title: 'Terms of Service',
      sections: termsOfServiceSections,
    );
  }
}
