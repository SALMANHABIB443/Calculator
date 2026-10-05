import 'package:flutter/material.dart';


/// The app's toggle switch (desing.md §5.2).
///
/// A thin, purpose-built wrapper rather than a raw [Switch] so that:
/// - the control keeps the standard 52x32 Material box (the size the mockups
///   show) instead of drifting with whatever theme is applied;
/// - there is exactly one widget the Settings rows construct, which is where
///   the R-1 OFF-track colour is resolved — `AppTheme.switchTheme` maps
///   [context.appColors.toggleTrackOn] / [context.appColors.toggleTrackOff] and clears the
///   Material 3 track outline, which the mockups do not show.
///
/// [R-1] the OFF track colour is unmeasured: no mockup shows a toggle in the
/// OFF state, so `context.appColors.toggleTrackOff` is a chosen stand-in until Phase 9.
class AppToggle extends StatelessWidget {
  const AppToggle({
    required this.value,
    required this.onChanged,
    super.key,
    this.semanticsLabel,
  });

  /// Current position.
  final bool value;

  /// Called with the position the user is asking for. A `null` callback
  /// disables the control.
  final ValueChanged<bool>? onChanged;

  /// Accessible name, e.g. `Sound`. Usually the row title already names the
  /// control, so this is only passed when the row is not itself labelled.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final toggle = Switch(
      value: value,
      onChanged: onChanged,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
    if (semanticsLabel == null) return toggle;

    // `container: true` is what makes this a node in its own right rather than
    // text folded into whatever encloses it (D-59). A [Switch] already builds
    // its own semantics with the on/off state; merging *into* the row would
    // have left the state attached to a node named after the whole row, so a
    // screen reader reaching the switch would announce "Sound, Key press
    // sound" with nothing saying which position it was in. The switch's own
    // semantics are deliberately left in place rather than excluded — the
    // label is added here, the state comes from below.
    return Semantics(container: true, label: semanticsLabel, child: toggle);
  }
}