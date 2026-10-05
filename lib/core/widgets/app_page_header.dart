import 'package:flutter/material.dart';

import '../design/app_spacing.dart';
import '../design/app_typography.dart';

/// The top bar of a screen that is a *destination* rather than a page inside
/// one — the calculator's own bar, and the debug component catalogue (D-74).
///
/// It is a plain `Row` under the screen margin, not an `AppBar`. D-70 already
/// showed that `AppBar` reserves a leading slot and an action inset of its own,
/// which is the whole reason the header geometry used to be derived arithmetic;
/// a `Row` the component builds has no such opinion to fight. The boxes then sit
/// on [AppSpacing.screenHorizontal] themselves, so the header, the cards, and
/// the keypad share one left and right edge by construction rather than by
/// arithmetic that has to be kept in step with three other files.
///
/// The title is optional and, when present, is [TextAlign.start]-ed — a page
/// *name* rather than a banner between two icons. The calculator passes no
/// title at all, because desing.md §6.1 puts the display where a title would
/// go; the catalogue passes one and reads as a normal page.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    this.title,
    this.leading,
    this.actions = const <Widget>[],
    this.titleStyle,
  });

  /// Page name, or `null` for a bar that is only actions.
  final String? title;

  /// Left-hand action, e.g. the calculator's Settings hamburger.
  final Widget? leading;

  /// Right-hand actions, laid out in order against the right margin.
  final List<Widget> actions;

  /// The title's style, defaulting to [context.type.screenTitle].
  ///
  /// A named token at the call site rather than a `copyWith`, so a reduction
  /// stays scoped to the screen that asked for it (D-71).
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    // The middle of the row is one widget so the title's slot and the spacer
    // that replaces it cannot both be built: with a title the row is
    // [leading, title, ...actions] and the title takes the slack; without one
    // it is [leading, spacer, ...actions] and the actions are pushed right.
    final Widget middle = title == null
        ? const Spacer()
        : Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: leading == null ? 0 : AppSpacing.md,
              ),
              child: Text(
                title!,
                style: titleStyle ?? context.type.screenTitle,
                // One line, ellipsised. A title the wrap let onto a second line
                // would make this bar taller than the 56 px the page is laid out
                // around, and every screen's top spacing is measured from it.
                // Dynamic Type still grows the line's own height, so the bar
                // yields to larger type without ever taking a second line —
                // which is what D-54 needs and what a wrap would have broken.
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );

    return Padding(
      // The top padding is the screen's own breathing room above the bar
      // ([AppSpacing.headerTopGap]) and sits *on top of* the `SafeArea` inset
      // the screens wrap this in, exactly as the QR Scanner app stacks the two.
      // It belongs to the widget rather than to each call site so a new screen
      // cannot come out flush against the status bar by forgetting it.
      //
      // The `ConstrainedBox` below is unaffected: `minHeight` bounds the *row*,
      // and padding is applied outside it, so the bar is now
      // `headerTopGap + max(56, content)` tall rather than a fixed 56.
      padding: const EdgeInsets.only(
        left: AppSpacing.screenHorizontal,
        right: AppSpacing.screenHorizontal,
        top: AppSpacing.headerTopGap,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.headerHeight),
        child: Row(
          children: <Widget>[
            ?leading,
            middle,
            ...actions,
          ],
        ),
      ),
    );
  }
}