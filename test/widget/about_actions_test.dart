import 'package:calculator/core/services/review_service.dart';
import 'package:calculator/core/services/share_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart'
    show ShareParams, ShareResult, ShareResultStatus;

import '../support/pump_app.dart';

/// The About screen's system actions: **AC-012** (Rate App behaves as D-08),
/// **AC-013** (Share App summons the sheet), and the Terms row that makes the
/// legal screens reachable from About (D-52, AC-011).
///
/// The services are real seams over plugins that cannot run in a test host, so
/// each is overridden with a recorder that answers a fixed outcome — mirroring
/// the `RecordingFeedbackService` pattern from Phase 6 (D-34, D-53). Each test
/// builds its own recorders so call counts never leak between tests.
void main() {
  Future<({_RecordingReviewService review, _RecordingShareService share})>
  pumpAbout(WidgetTester tester) async {
    final review = _RecordingReviewService();
    final share = _RecordingShareService();
    await pumpApp(tester, overrides: [
      reviewServiceProvider.overrideWithValue(review),
      shareServiceProvider.overrideWithValue(share),
    ]);
    await openSettings(tester);
    await tester.scrollUntilVisible(
      find.text('App Version'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('App Version'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('App Version'));
    await tester.pumpAndSettle();
    expect(find.text('APP INFORMATION'), findsOneWidget, reason: 'did not land on About');
    return (review: review, share: share);
  }

  /// Scrolls a MORE row fully into view and taps it. The About list builds
  /// lazily, so rows below the fold are not in the tree until scrolled to — and
  /// a row can be *built* while still off-screen, so `ensureVisible` is needed
  /// before the tap actually lands on it.
  Future<void> tapMoreRow(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(
      find.text(label),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('Rate App asks the prompt; successes show no snack bar', (
    tester,
  ) async {
    final services = await pumpAbout(tester);
    services.review.outcome = ReviewOutcome.promptShown;

    await tapMoreRow(tester, 'Rate App');

    expect(services.review.calls, 1);
    // The D-08 branch is exercised inside ReviewService (unit-tested in
    // `review_service_test`); the screen only sees the outcome.
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Rate App surfaces a snack bar when nothing could run', (
    tester,
  ) async {
    final services = await pumpAbout(tester);
    services.review.outcome = ReviewOutcome.unavailable;

    await tapMoreRow(tester, 'Rate App');

    expect(services.review.calls, 1);
    expect(find.text('This action is unavailable right now'), findsOneWidget);
  });

  testWidgets('Share App summons the sheet; successes show no snack bar', (
    tester,
  ) async {
    final services = await pumpAbout(tester);
    services.share.outcome = ShareOutcome.sheetShown;

    await tapMoreRow(tester, 'Share App');

    expect(services.share.calls, 1);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Share App surfaces a snack bar when the sheet cannot open', (
    tester,
  ) async {
    final services = await pumpAbout(tester);
    services.share.outcome = ShareOutcome.unavailable;

    await tapMoreRow(tester, 'Share App');

    expect(services.share.calls, 1);
    expect(find.text('This action is unavailable right now'), findsOneWidget);
  });

  testWidgets('Terms of Service opens the in-app Terms screen and back returns', (
    tester,
  ) async {
    await pumpAbout(tester);

      await tapMoreRow(tester, 'Terms of Service');
      expect(find.text('Agreement'), findsOneWidget);
      expect(find.text('Terms of Service'), findsWidgets);

    await goBack(tester);
    // Back on About. The header is the title alone now, so the title is what
    // proves we returned rather than the subtitle that used to sit under it.
    expect(find.text('About'), findsOneWidget);
  });
}

class _RecordingReviewService extends ReviewService {
  _RecordingReviewService() : super(const _NoopReviewApi());

  ReviewOutcome outcome = ReviewOutcome.promptShown;
  int calls = 0;

  @override
  Future<ReviewOutcome> rateApp() async {
    calls++;
    return outcome;
  }
}

class _RecordingShareService extends ShareService {
  _RecordingShareService() : super(const _NoopShareApi());

  ShareOutcome outcome = ShareOutcome.sheetShown;
  int calls = 0;

  @override
  Future<ShareOutcome> shareApp() async {
    calls++;
    return outcome;
  }
}

class _NoopReviewApi implements ReviewApi {
  const _NoopReviewApi();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<void> openStoreListing() async {}

  @override
  Future<void> requestReview() async {}
}

class _NoopShareApi implements ShareApi {
  const _NoopShareApi();

  @override
  Future<ShareResult> share(ShareParams params) async {
    return const ShareResult('', ShareResultStatus.success);
  }
}