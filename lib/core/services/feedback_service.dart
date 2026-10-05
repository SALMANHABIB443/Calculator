import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Key-press feedback, sound and haptics (FEAT-FEEDBACK-001, D-16).
///
/// Both channels are Flutter's own `services` APIs, so the feature costs no
/// package: a system click for the sound and the platform's selection tick for
/// the haptics.
///
/// The flags are passed in rather than read from a provider so this stays free
/// of any `features` import — putting the settings lookup here would make it the
/// second `core → features` import, which D-24 holds to one. The calculator
/// controller, which can read `settingsProvider`, supplies them.
final feedbackServiceProvider = Provider<FeedbackService>(
  (ref) => const FeedbackService(),
);

class FeedbackService {
  const FeedbackService();

  /// Fires the key-press feedback for the current preferences.
  ///
  /// Fire and forget by design: neither channel should be able to delay a key
  /// press or surface an error into the calculator, and a platform channel
  /// that is unavailable (unit tests, unsupported host) simply does nothing.
  Future<void> keyPress({
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) async {
    if (vibrationEnabled) {
      await HapticFeedback.selectionClick();
    }
    if (soundEnabled) {
      await SystemSound.play(SystemSoundType.click);
    }
  }
}