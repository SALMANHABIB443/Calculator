import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_typography.dart';

/// The confirmation gate for a destructive, irreversible action (D-05).
///
/// Not in any mockup, because it is a safety requirement rather than a design
/// element: **Clear History** is offered both from the header trash icon and
/// from the bottom action, both must pass through here, and nothing is deleted
/// until the user confirms (feature.md FEAT-HIST-003).
///
/// The confirm action is orange to match the Clear History action that opened
/// it, so the two read as a pair rather than the dialog looking like an
/// unrelated system alert.
class AppConfirmationDialog extends StatelessWidget {
  const AppConfirmationDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    super.key,
    this.cancelLabel = 'Cancel',
  });

  /// Dialog title, e.g. `Clear history?`.
  final String title;

  /// One line explaining what cannot be undone.
  final String message;

  /// Label on the destructive confirm action, e.g. `Clear`.
  final String confirmLabel;

  /// Label on the dismissing action.
  final String cancelLabel;

  /// Shows the dialog and resolves to `true` only if the user confirms.
  ///
  /// Dismissing by the system back gesture or by tapping the barrier resolves
  /// to `false`; the barrier is not dismissible so a stray tap outside cannot
  /// destroy data.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title, style: AppTypography.rowTitle),
      content: Text(message, style: AppTypography.body),
      titleTextStyle: AppTypography.rowTitle,
      contentTextStyle: AppTypography.body,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            cancelLabel,
            style: AppTypography.rowTitle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            confirmLabel,
            style: AppTypography.rowTitle.copyWith(color: AppColors.accent),
          ),
        ),
      ],
    );
  }
}
