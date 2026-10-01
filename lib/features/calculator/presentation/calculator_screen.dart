import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
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
/// Everything is anchored to the bottom, matching the mockup's "large vertical
/// space above the buttons". That space is inherent rather than accidental: on
/// a phone the keypad's height follows from the column's *width*, so a taller
/// window cannot make the keys any bigger and the surplus has nowhere to go but
/// above the display. What D-69 removed was the keypad floating 80 px off the
/// floor, not the top space the design asks for.
class CalculatorScreen extends ConsumerWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(calculatorControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
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
                final keypadHeight = math.max(
                  CalculatorKeypad.minGridHeight,
                  constraints.maxHeight -
                      AppSizes.headerHeight -
                      AppSpacing.headerTopGap -
                      AppSpacing.bottomSafe -
                      AppSpacing.calculatorDisplayGap -
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
                        // with. The display's lines are right-aligned, so
                        // filling the column is what puts the number flush
                        // with the operator column (**D-69**).
                        child: const CalculatorDisplay(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.calculatorDisplayGap),
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
