import 'package:flutter/material.dart';

import 'app_toggle.dart';
import 'settings_row.dart';

/// A [SettingsRow] whose control is a toggle switch (desing.md §6.3).
///
/// The whole row is a tap target, so the switch can be operated from anywhere
/// across the row's 56pt height rather than only on the 52x32 control.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    super.key,
    this.subtitle,
  });

  /// Leading glyph, e.g. the speaker or phone.
  final IconData icon;

  /// Primary label, e.g. `Sound`.
  final String title;

  /// Supporting label, e.g. `Key press sound`.
  final String? subtitle;

  /// Current position of the switch.
  final bool value;

  /// Called with the requested position. A `null` callback disables the row.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      // D-59: the row is labelled as one node, but the `Switch` inside
      // `trailing` stays a separate focusable one, and on its own it would
      // announce a bare "on" / "off" with nothing to attach it to. Passing the
      // row title is what `AppToggle.semanticsLabel` has always been for; until
      // now no caller did, which left the parameter dead.
      trailing: AppToggle(
        value: value,
        onChanged: onChanged,
        semanticsLabel: title,
      ),
    );
  }
}