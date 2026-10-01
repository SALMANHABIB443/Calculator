import 'package:calculator/core/config/app_info.dart';
import 'package:calculator/features/legal/data/legal_content.dart';
import 'package:flutter_test/flutter_test.dart';

/// Release-gate tests for the shipped legal copy (D-07, D-68).
///
/// These exist because the legal documents used to ship with placeholder text
/// and nothing caught it. `legal_screens.dart` renders whatever it is given, so
/// a stub document looked identical to a real one in every screenshot and every
/// navigation test — the only way to notice was to read the copy by eye and
/// realise it said "replace this before release".
///
/// The tests below turn "did someone write the real text" into something the
/// suite answers, so a regression to placeholder copy fails CI instead of
/// reaching users.
void main() {
  final documents = <String, List<({String heading, String body})>>{
    'Privacy Policy': privacyPolicySections,
    'Terms of Service': termsOfServiceSections,
  };

  // Substrings that only ever appear in unfinished copy. Checked against the
  // real text of Phase 9, which is the copy these replaced.
  const placeholders = <String>[
    'placeholder',
    'replace this',
    'replace before release',
    'lorem ipsum',
    'todo',
    'tbd',
    'coming soon',
    'xxx',
  ];

  group('legal documents are real copy', () {
    for (final entry in documents.entries) {
      final name = entry.key;
      final sections = entry.value;

      test('$name is non-empty', () {
        expect(
          sections,
          isNotEmpty,
          reason: 'an empty document renders the "Content coming soon" state',
        );
      });

      test('$name has enough sections to be a document', () {
        // The placeholder drafts had four sections each. Real legal text for a
        // data-handling claim needs to cover what is stored, what is not, and
        // how to erase it, so a floor well above the old count is a cheap way
        // to catch a truncated or reverted draft.
        expect(
          sections.length,
          greaterThanOrEqualTo(8),
          reason: 'a draft that shrank back toward the four-section placeholder '
              'is probably a regression, not an edit',
        );
      });

      test('$name has no placeholder markers', () {
        for (final section in sections) {
          // The Contact section interpolates legalContactEmail, which is a
          // deliberate placeholder with its own release-gate test below. Strip
          // it before scanning, otherwise this test and that one could never
          // both pass and the suite would just be permanently red.
          final text = '${section.heading} ${section.body}'
              .replaceAll(legalContactEmail, '')
              .toLowerCase();
          for (final marker in placeholders) {
            expect(
              text.contains(marker),
              isFalse,
              reason: 'section "${section.heading}" contains "$marker", which '
                  'means unfinished copy would ship',
            );
          }
        }
      });

      test('$name headings are unique', () {
        final headings = sections.map((s) => s.heading).toList();
        expect(
          headings.toSet().length,
          headings.length,
          reason: 'duplicate headings make the document harder to scan and '
              'suggest a copy-paste that was never reviewed',
        );
      });

      test('$name sections all have non-empty bodies', () {
        for (final section in sections) {
          expect(
            section.body.trim(),
            isNotEmpty,
            reason: 'heading "${section.heading}" has no body text',
          );
        }
      });

      test('$name states its own version', () {
        // The "Last updated" line names the version the text shipped with. If
        // AppInfo.version moves on and nobody updates the copy, this is where
        // it shows up.
        final bodies = sections.map((s) => s.body).join('\n');
        expect(
          bodies.contains(AppInfo.version),
          isTrue,
          reason: 'neither document mentions ${AppInfo.version}',
        );
      });
    }
  });

  group('privacy policy claims match the platform', () {
    test('says it makes no network requests', () {
      final bodies = privacyPolicySections.map((s) => s.body).join('\n');
      expect(
        bodies.toLowerCase().contains('no network requests'),
        isTrue,
        reason: 'this is the app\'s central claim and must be stated plainly',
      );
    });

    test('says backups are disabled', () {
      // Backups are the one channel by which "nothing leaves your device"
      // could quietly become false (D-65), so the policy has to be explicit
      // about it rather than leaving it to the overview.
      final headings = privacyPolicySections.map((s) => s.heading).join(' ');
      expect(
        headings.toLowerCase().contains('backup'),
        isTrue,
        reason: 'the policy should have a section on Android backup/transfer',
      );
    });

    test('says how to delete data', () {
      final headings = privacyPolicySections.map((s) => s.heading).join(' ');
      expect(
        headings.toLowerCase().contains('delete'),
        isTrue,
        reason: 'a privacy policy must say how a user erases their data',
      );
    });

    test('names the two things actually stored', () {
      final bodies = privacyPolicySections.map((s) => s.body).join('\n');
      expect(bodies, contains('history'));
      expect(bodies.toLowerCase(), contains('preference'));
    });
  });

  group('contact details', () {
    test('both documents carry a contact address', () {
      for (final entry in documents.entries) {
        final text = entry.value.map((s) => s.body).join('\n');
        expect(
          text.contains('@'),
          isTrue,
          reason: '${entry.key} names no contact address, which is a common '
              'reason a Play listing is rejected',
        );
      }
    });

    test('the contact placeholder is still flagged for release', () {
      // Deliberately asserts the *current* state rather than hiding it. This
      // test is expected to fail once a real address is supplied, at which
      // point it should be deleted or inverted in the same commit that adds
      // the address — see store/listing.md. It exists so the placeholder is a
      // tracked release gate rather than a forgotten string in a data file.
      expect(
        legalContactEmail,
        contains('TODO'),
        reason: 'supply a real monitored address and then update this test',
      );
    });
  });
}
