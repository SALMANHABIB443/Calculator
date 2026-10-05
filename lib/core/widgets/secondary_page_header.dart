import 'package:flutter/material.dart';

import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import 'app_icon_button.dart';

/// Shared chrome for the screens that are pushed on top of another one (D-74).
///
/// One component covers History, Settings, About, and both legal documents: a
/// bordered back box on the left, a centred title, and an optional trailing
/// slot that History fills with its trash.
///
/// The header is the title and nothing else. It used to take an optional
/// `subtitle` and grow a second line under the title — only the About screen
/// ever passed one — and the parameter has been removed rather than left
/// unused, so no screen can reintroduce the two-line banner by accident.
///
/// The title is centred by *geometry* rather than by a framework flag. Both
/// sides of the row are the same width — a [AppSizes.iconTouchTarget] box on the
/// left, and either the caller's action or an equal-width blank on the right —
/// so the middle the title is laid out in is symmetric about the screen and the
/// word lands in the optical centre at any title length. That is the whole
/// reason the trailing slot is padded with a blank when a screen has no action:
/// without it a lone back arrow would shift its own title 60 px to the right,
/// and two headers that looked identical on the mockup would disagree on the
/// device.
///
/// This replaces `AppHeader`, which was an `AppBar` and had to derive a
/// `leadingWidth` and an action inset to land its glyph on the 24 px margin
/// (D-70). A `Row` has no slot to derive, and the boxes it places are the
/// objects that ride the margin, so the arithmetic is gone rather than ported.
class SecondaryPageHeader extends StatelessWidget {
  const SecondaryPageHeader({
    required this.title,
    super.key,
    this.onBack,
    this.trailing,
    this.titleStyle,
    this.backIcon = Icons.arrow_back,
  });

  /// Screen title, e.g. `History`.
  final String title;

  /// Overrides the default `Navigator.pop`. Used by tests.
  final VoidCallback? onBack;

  /// Optional right-hand action, e.g. the History trash. A
  /// [AppSizes.iconTouchTarget] blank takes its place when it is absent, which
  /// is what keeps the title centred.
  final Widget? trailing;

  /// The title's style, defaulting to [context.type.screenTitle].
  ///
  /// A named token at the call site rather than a `copyWith`, so a reduction
  /// stays scoped to the screen that asked for it — the About hero card prints
  /// `AppInfo.name` through the same default, and an in-place size edit would
  /// demote the app's own name along with the caller's title (D-71, D-75).
  ///
  /// No screen passes one today: with the header subtitle gone everywhere
  /// (D-75), every header is the shared size.
  final TextStyle? titleStyle;

  /// The leading glyph. A parameter so the token that names it is read in
  /// application code rather than spelled again in test code.
  final IconData backIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // The same [AppSpacing.headerTopGap] the calculator's own bar gets, for
      // the same reason: the six screens pushed on top of another one share this
      // component, so stating it here is what makes a pushed screen's header sit
      // as far down as the root screen's rather than jumping to the status bar.
      // Like that one it stacks with the `SafeArea` the scaffold wraps it in, and
      // it is outside the `ConstrainedBox`, so [AppSizes.headerHeight] still
      // bounds the row alone and a long title still grows the bar.
      padding: const EdgeInsets.only(
        left: AppSpacing.screenHorizontal,
        right: AppSpacing.screenHorizontal,
        top: AppSpacing.headerTopGap,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.headerHeight),
        child: Row(
          children: <Widget>[
            AppIconButton(
              icon: backIcon,
              tooltip: 'Back',
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                style: titleStyle ?? context.type.screenTitle,
                textAlign: TextAlign.center,
                // One line, ellipsised. A wrapped title would make this bar
                // taller than the 56 px the page is laid out around, and
                // every screen's top spacing is measured from that. Dynamic
                // Type still grows the line's own height, so a larger system
                // font is yielded to rather than clipped (D-54).
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // The mirror of the back box. A caller's action sits in the slot;
            // an absent one is filled with its own width so the title stays
            // centred either way.
            SizedBox(
              width: AppSizes.iconTouchTarget,
              child: trailing,
            ),
          ],
        ),
      ),
    );
  }
}