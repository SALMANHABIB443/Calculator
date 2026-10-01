import 'package:calculator/core/config/app_info.dart';
import 'package:calculator/core/services/share_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

/// The Share App action (feature.md FEAT-ABOUT-003, AC-013): the system share
/// sheet is summoned with the app message, and a platform failure degrades to
/// `unavailable` instead of escaping.
void main() {
  group('ShareService.shareApp', () {
    test('summons the sheet with the app message and subject', () async {
      final api = _FakeShareApi();
      final service = ShareService(api);

      expect(await service.shareApp(), ShareOutcome.sheetShown);
      expect(api.params, isNotNull);
      expect(api.params!.text, AppInfo.shareMessage);
      expect(api.params!.subject, AppInfo.name);
      expect(api.params!.uri, isNull, reason: 'text-only share (AC-013)');
    });

    test('reports unavailable when the platform throws', () async {
      final api = _FakeShareApi(throwOnShare: true);
      final service = ShareService(api);

      expect(await service.shareApp(), ShareOutcome.unavailable);
    });
  });
}

class _FakeShareApi implements ShareApi {
  _FakeShareApi({this.throwOnShare = false});

  final bool throwOnShare;

  ShareParams? params;

  @override
  Future<ShareResult> share(ShareParams params) async {
    if (throwOnShare) throw Exception('no share target');
    this.params = params;
    return const ShareResult('', ShareResultStatus.success);
  }
}