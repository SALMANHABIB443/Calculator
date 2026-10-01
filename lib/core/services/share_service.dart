import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_info.dart';

/// Outcome of a Share App attempt.
enum ShareOutcome {
  /// The system share sheet was summoned.
  sheetShown,

  /// The sheet could not be summoned (plugin unavailable, exception thrown).
  unavailable,
}

/// The thin surface of `share_plus` the service needs, so a test can fake the
/// platform instead of driving a method channel (D-53).
abstract interface class ShareApi {
  Future<ShareResult> share(ShareParams params);
}

/// Adapter over the plugin's singleton.
class SharePlusApi implements ShareApi {
  const SharePlusApi();

  @override
  Future<ShareResult> share(ShareParams params) =>
      SharePlus.instance.share(params);
}

/// Wraps the system share sheet behind the About "Share App" action
/// (feature.md FEAT-ABOUT-003, AC-013).
///
/// Follows the `FeedbackService` / `ReviewService` pattern (D-34, D-53): no
/// provider dependency, exposed as a provider so tests override the seam.
/// The message and subject come from [AppInfo] so the action text is defined
/// once. `sharePositionOrigin` is not set because v1.0 is Android-only (D-22);
/// an iPad release needs it and Phase 10 should add it.
class ShareService {
  const ShareService(this.api);

  final ShareApi api;

  /// Summons the system share sheet with the app message.
  ///
  /// A platform exception — a missing channel in a test host, or a device that
  /// cannot resolve a share target — yields [ShareOutcome.unavailable] rather
  /// than escaping.
  Future<ShareOutcome> shareApp() async {
    try {
      await api.share(
        ShareParams(
          text: AppInfo.shareMessage,
          subject: AppInfo.name,
        ),
      );
      return ShareOutcome.sheetShown;
    } on Exception {
      return ShareOutcome.unavailable;
    }
  }
}

final shareServiceProvider = Provider<ShareService>(
  (ref) => const ShareService(SharePlusApi()),
);