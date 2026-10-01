import 'package:calculator/core/services/review_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The D-08 decision (D-51): prompt when the platform says it can, store
/// listing otherwise, and never let a platform failure escape to the screen.
void main() {
  group('ReviewService.rateApp', () {
    test('requests the native prompt when the platform is available', () async {
      final api = _FakeReviewApi(available: true);
      final service = ReviewService(api);

      expect(await service.rateApp(), ReviewOutcome.promptShown);
      expect(api.isAvailableCalls, 1);
      expect(api.requestReviewCalls, 1);
      expect(api.openStoreListingCalls, 0);
    });

    test('opens the store listing when the prompt is unavailable', () async {
      final api = _FakeReviewApi(available: false);
      final service = ReviewService(api);

      expect(await service.rateApp(), ReviewOutcome.storeOpened);
      expect(api.isAvailableCalls, 1);
      expect(api.requestReviewCalls, 0);
      expect(api.openStoreListingCalls, 1);
    });

    test('reports unavailable when the availability check throws', () async {
      final api = _FakeReviewApi(available: true, throwOnAvailable: true);
      final service = ReviewService(api);

      expect(await service.rateApp(), ReviewOutcome.unavailable);
      expect(api.requestReviewCalls, 0);
      expect(api.openStoreListingCalls, 0);
    });

    test('reports unavailable when the prompt itself throws', () async {
      final api = _FakeReviewApi(available: true, throwOnRequest: true);
      final service = ReviewService(api);

      expect(await service.rateApp(), ReviewOutcome.unavailable);
      expect(api.openStoreListingCalls, 0);
    });

    test('reports unavailable when the store listing throws', () async {
      final api = _FakeReviewApi(available: false, throwOnStore: true);
      final service = ReviewService(api);

      expect(await service.rateApp(), ReviewOutcome.unavailable);
    });
  });
}

class _FakeReviewApi implements ReviewApi {
  _FakeReviewApi({
    required this.available,
    this.throwOnAvailable = false,
    this.throwOnRequest = false,
    this.throwOnStore = false,
  });

  final bool available;
  final bool throwOnAvailable;
  final bool throwOnRequest;
  final bool throwOnStore;

  int isAvailableCalls = 0;
  int requestReviewCalls = 0;
  int openStoreListingCalls = 0;

  @override
  Future<bool> isAvailable() async {
    isAvailableCalls++;
    if (throwOnAvailable) throw Exception('no channel');
    return available;
  }

  @override
  Future<void> requestReview() async {
    requestReviewCalls++;
    if (throwOnRequest) throw Exception('prompt denied');
  }

  @override
  Future<void> openStoreListing() async {
    openStoreListingCalls++;
    if (throwOnStore) throw Exception('no store');
  }
}