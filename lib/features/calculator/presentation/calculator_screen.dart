import '../../../../core/design/app_palette.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/core_widgets.dart';
import '../../../routing/app_routes.dart';
import 'calculator_controller.dart';
import 'calculator_display.dart';
import 'calculator_keypad.dart';

/// Root screen of the app (desing.md §6.1, prd.md §7).
///
/// The top bar carries the two navigation entry points: a hamburger on the
/// left that opens Settings, and a history clock on the right that opens the
/// History screen (prd.md §7, D-20 — About is reached only from Settings).
///
/// **One column, capped** (**D-69**). The header, the display, and the keypad
/// are laid out inside a single [ConstrainedBox] and therefore share their left
/// and right edges at every window size — which is what lets the result's right
/// edge land on the `=` column rather than drifting away from it as the window
/// widens. The cap keeps that column a calculator's width on a desktop or
/// resizable window instead of stretching the keys with it, and centres the
/// surplus (D-09's portrait-phone scope, handled rather than re-decided).
///
/// The keypad is anchored to the bottom, matching the mockup's "large vertical
/// space above the buttons"; the display takes everything above it. That space
/// is inherent rather than accidental: on a phone the keypad's height follows
/// from the column's *width*, so a taller window cannot make the keys any
/// bigger and the surplus has nowhere to go but into the display above it. What
/// D-69 removed was the keypad floating 80 px off the floor, not the top
/// space the design asks for.
///
/// Between the display and the rule sits the **backspace** row (**D-81**), which
/// takes the last digit off the entry. It is a slot in this column like any
/// other, so its height is part of the keypad's budget above rather than
/// something laid on top of a finished layout.
class CalculatorScreen extends ConsumerWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(calculatorControllerProvider.notifier);

    return Scaffold(
      backgroundColor: context.appColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.calculatorPanelMaxWidth,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width =
                    constraints.maxWidth - AppSpacing.screenHorizontal * 2;

                // D-54: the display's reserved height is read from the ambient
                // font scale, so the keypad is sized against the space the
                // display will actually occupy at the user's chosen text size
                // rather than the 1x figure. Without this the two would
                // disagree as soon as the font grew, and the keypad would be
                // laid out for space the result line had already taken.
                final displayMinimum = CalculatorDisplay.minimumHeight(
                  MediaQuery.textScalerOf(context),
                );

                // D-69: the height the keypad is *offered* is whatever is left
                // once the display has been guaranteed its minimum — but never
                // less than the height a 44 pt keypad needs. On a window too
                // short for both, the floor wins and the display's `Expanded`
                // below is the one that gives way, because a key that shrinks
                // below the touch floor is a worse outcome than a display line
                // that compresses.
                //
                // `headerTopGap` is subtracted here for the same reason
                // `headerHeight` is: the reserve has to name the bar's *full*
                // height as it is actually laid out. The header's padding is
                // outside its `ConstrainedBox`, so the bar occupies
                // `headerTopGap + max(headerHeight, content)` — reserving only
                // `headerHeight` would overstate the space available by a whole
                // 24 px and push the keypad's last row past the bottom padding,
                // which is a render overflow rather than a layout that merely
                // looks wrong.
                //
                // D-81's backspace row is in this list for the same reason: it is
                // a real slot between the display and the rule, so leaving it out
                // of the budget would hand its 48 px to the keypad's box and push
                // the last row off the floor.
                final keypadHeight = math.max(
                  CalculatorKeypad.minGridHeight,
                  constraints.maxHeight -
                      AppSizes.headerHeight -
                      AppSpacing.headerTopGap -
                      AppSpacing.bottomSafe -
                      AppSpacing.calculatorDisplayGap -
                      AppSizes.calculatorBackspaceRow -
                      displayMinimum,
                );

                // The grid sizes itself to whichever axis is tighter (D-27), so
                // the screen resolves the same cell only to learn how big the
                // grid will be — that is what the display and the keypad are
                // both given, which is what puts their edges on one line.
                final cellSize = CalculatorKeypad.cellSizeFor(
                  width: width,
                  height: keypadHeight,
                );
                final gridWidth = CalculatorKeypad.gridWidth(cellSize);
                final gridHeight = CalculatorKeypad.gridHeight(cellSize);

                return Column(
                  children: [
                    // The top bar is the shared page header rather than a bar of
                    // its own (D-74). It is inside this column, and therefore
                    // inside the capped, centred panel, so its two boxes ride
                    // the same left and right edge as the keypad below them —
                    // which is what D-69 wanted the result's right edge to line
                    // up with, extended to the header.
                    AppPageHeader(
                      leading: AppIconButton(
                        icon: Icons.menu,
                        tooltip: 'Settings',
                        onPressed: () => context.push(AppRoutes.settings),
                      ),
                      actions: <Widget>[
                        AppIconButton(
                          icon: Icons.history,
                          tooltip: 'History',
                          onPressed: () => context.push(AppRoutes.history),
                        ),
                      ],
                    ),
                    Expanded(
                      child: SizedBox(
                        width: gridWidth,
                        // No horizontal padding of its own. [gridWidth] is
                        // already the column inside the screen margin — the
                        // outer keys sit on that margin, so insetting the
                        // display again would leave the result 24 px to the
                        // left of the `=` column it is supposed to line up
                        // with. The display's line is right-aligned, so filling the
                        // column is what puts the number flush with the operator
                        // column (**D-69**).
                        child: const CalculatorDisplay(),
                      ),
                    ),
                    // The backspace control, on the left of the same column the
                    // display and the keypad share, and directly above the rule
                    // (D-81). Its own row rather than a corner of the display's
                    // box, so the 48 px it needs is a slot the screen reserves
                    // rather than ink laid over a number the user is reading.
                    SizedBox(
                      width: gridWidth,
                      height: AppSizes.calculatorBackspaceRow,
                      child: const Align(
                        alignment: Alignment.centerLeft,
                        child: _BackspaceButton(),
                      ),
                    ),
                    // The rule that separates the display from the keypad. It
                    // occupies the same `calculatorDisplayGap` slot it replaced,
                    // so the keypad's height budget below (which subtracts that
                    // token) and the rendered composition are unchanged — the
                    // 1 px line just sits in the middle of that 24 px. `indent`
                    // and `endIndent` hold the line in off the screen edges by
                    // the same margin the keypad rides, so it reads as part of
                    // the column rather than spanning the full width.
                    Divider(
                      height: AppSpacing.calculatorDisplayGap,
                      thickness: 1,
                      indent: AppSpacing.screenHorizontal,
                      endIndent: AppSpacing.screenHorizontal,
                      color: context.appColors.textSecondary,
                    ),
                    SizedBox(
                      width: gridWidth,
                      height: gridHeight,
                      child: CalculatorKeypad(
                        availableWidth: gridWidth,
                        availableHeight: gridHeight,
                        onKeyPressed: controller.press,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.bottomSafe),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The `⌫` that takes the entry back one digit at a time (**D-81**).
///
/// **Outside the keypad, on purpose.** D-19 keeps `CalculatorKey` at the
/// nineteen keys desing.md §6.1 draws and the mockup shows; this is a header-style
/// action on the display's own row rather than a twentieth key, so the keypad
/// stays exactly as it was and the control sits where a user looks to fix a
/// mistyped number — on the number, not under it.
///
/// It is an [AppIconButton] so it wears the same 48 px touch target as every
/// other header action, and so "there is nothing to delete" can be painted grey
/// instead of removing the control: a button that appears and disappears as the
/// entry is typed and emptied would be read as a layout bug rather than as a
/// state. It passes `bordered: false`, because a bordered box on the display's
/// own row read as a screen-level action competing with the result above it
/// rather than as an edit to that result.
class _BackspaceButton extends ConsumerWidget {
  const _BackspaceButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(calculatorControllerProvider.notifier);
    // `select` rather than watching the whole state: the display already
    // rebuilds on every keystroke, and this row only cares about one boolean.
    final enabled = ref.watch(
      calculatorControllerProvider.select((state) => state.canBackspace),
    );

    return AppIconButton(
      key: const Key('calculator-backspace'),
      icon: Icons.backspace_outlined,
      tooltip: 'Backspace',
      // Borderless: this edits the number sitting directly above it, so it is
      // drawn as a bare glyph rather than in the bordered square the screen-level
      // actions wear. The 48 px target and the disabled state are unchanged.
      bordered: false,
      onPressed: enabled ? controller.backspace : null,
    );
  }
}