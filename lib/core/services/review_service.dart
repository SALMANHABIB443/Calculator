import 'package:in_app_review/in_app_review.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Outcome of a Rate App attempt.
///
/// The screen needs to know whether the prompt could be raised so a total
/// failure can be surfaced; a platform that answers but cannot show the
/// prompt is not the same thing as a platform that never answered.
enum ReviewOutcome {
  /// The native in-app review prompt was raised (or will be).
  promptShown,

  /// The prompt was unavailable, so the store listing was opened instead.
  storeOpened,

  /// Neither path could complete (plugin unavailable, exception thrown).
  unavailable,
}

/// The thin surface of `InAppReview` the service needs, so a test can fake
/// the platform instead of driving a method channel (D-53).
abstract interface class ReviewApi {
  Future<bool> isAvailable();

  Future<void> requestReview();

  Future<void> openStoreListing();
}

/// Adapter over the plugin's singleton.
class InAppReviewApi implements ReviewApi {
  const InAppReviewApi();

  @override
  Future<bool> isAvailable() => InAppReview.instance.isAvailable();

  @override
  Future<void> requestReview() => InAppReview.instance.requestReview();

  @override
  Future<void> openStoreListing() => InAppReview.instance.openStoreListing();
}

/// Wraps the native in-app review prompt and its store-listing fallback
/// (D-08, D-51).
///
/// Follows the `FeedbackService` pattern (D-34): the service holds no provider
/// dependency and is exposed as a provider so tests override the whole seam.
/// The `InAppReview.instance` singleton is hidden behind [ReviewApi] so the
/// D-08 decision — prompt when `isAvailable()`, store listing otherwise — is
/// unit-tested without a device.
class ReviewService {
  const ReviewService(this.api);

  final ReviewApi api;

  /// The action behind the About "Rate App" row (feature.md FEAT-ABOUT-003).
  ///
  /// Raises the native review prompt when the platform says it can, otherwise
  /// opens the Play Store listing. A platform exception on either path — a
  /// plugin channel that is missing, or a device that cannot launch the store
  /// — yields [ReviewOutcome.unavailable] rather than escaping.
  Future<ReviewOutcome> rateApp() async {
    try {
      if (await api.isAvailable()) {
        await api.requestReview();
        return ReviewOutcome.promptShown;
      }
      await api.openStoreListing();
      return ReviewOutcome.storeOpened;
    } on Exception {
      return ReviewOutcome.unavailable;
    }
  }
}

final reviewServiceProvider = Provider<ReviewService>(
  (ref) => const ReviewService(InAppReviewApi()),
);