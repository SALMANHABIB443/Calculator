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
/// The top bar carries the two navigation entry points: a gear button on the
/// left that opens Settings, and a history clock on the right that opens the
/// History screen (prd.md §7, D-20, D-117 — About is reached only from
/// Settings).
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
                    constraints.maxWidth -
                    AppSpacing.calculatorSideMargin * 2;

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
                      horizontalPadding: AppSpacing.calculatorSideMargin,
                      leading: const _SettingsGearButton(),
                      actions: <Widget>[
                        AppIconButton(
                          icon: Icons.history,
                          tooltip: 'History',
                          size: AppSizes.calculatorHeaderAction,
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
                      indent: AppSpacing.calculatorSideMargin,
                      endIndent: AppSpacing.calculatorSideMargin,
                      color: context.appColors.ruleOnPage,
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
///
/// The glyph is this app's own [AppBackspaceIcon] rather than Material's
/// `Icons.backspace_outlined`, so that the calculator's `⌫` and the Secret Mode
/// pad's are the same drawing (**D-112**).
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
    final colors = context.appColors;

    return AppIconButton(
      key: const Key('calculator-backspace'),
      // The grey is spelled out here rather than left to `AppIconButton`'s
      // `disabledColor`, because a painted glyph does not read the button's
      // `foregroundColor` the way a Material one does — the same reason the
      // History header's trash carries its own colour (`app_icon_button.dart`).
      iconWidget: AppBackspaceIcon(
        color: enabled ? colors.textPrimary : colors.textSecondary,
      ),
      tooltip: 'Backspace',
      // Borderless: this edits the number sitting directly above it, so it is
      // drawn as a bare glyph rather than in the bordered square the screen-level
      // actions wear. The 48 px target and the disabled state are unchanged.
      bordered: false,
      onPressed: enabled ? controller.backspace : null,
    );
  }
}

/// The gear that opens Settings, which turns one slow clockwise revolution
/// before the screen it names is pushed (**D-118**).
///
/// The turn is on the *glyph* rather than on the whole [AppIconButton]: the
/// bordered square (D-74) has to keep riding the margin the keypad rides, and
/// a tumbling border would read as the button moving rather than the gear
/// turning. An [AppIconButton.iconWidget] caller owns its own glyph size, so
/// the icon spells the arithmetic the button would otherwise do —
/// `calculatorHeaderAction * calculatorHeaderGlyphRatio` keeps it pinned to
/// the token it came from.
///
/// The push waits for the revolution to land: [spinDuration] is 700 ms of
/// [Curves.easeInOutCubic], slow enough to read and eased at both ends so it
/// does not snap into or out of the turn. No route gets a slower transition to
/// match it — D-56 keeps every push on the platform's own animation and
/// `navigation_graph_test` asserts that, so delaying the *push* is what puts
/// the whole gear turn on screen before Settings arrives.
///
/// Navigation runs from the controller's status listener rather than a
/// `Timer`: the controller schedules the frames `pumpAndSettle` needs, while a
/// timer would let the harness settle on the frame the tap landed and then
/// fire mid-test.
class _SettingsGearButton extends StatefulWidget {
  const _SettingsGearButton();

  /// One full clockwise revolution, in radians (**D-118**).
  static const double turn = 2 * math.pi;

  /// How long [turn] takes — slow enough that the turn is readable.
  static const Duration spinDuration = Duration(milliseconds: 700);

  @override
  State<_SettingsGearButton> createState() => _SettingsGearButtonState();
}

class _SettingsGearButtonState extends State<_SettingsGearButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: _SettingsGearButton.spinDuration,
  );

  @override
  void initState() {
    super.initState();
    _spin.addStatusListener(_onSpinStatus);
  }

  @override
  void dispose() {
    _spin.removeStatusListener(_onSpinStatus);
    _spin.dispose();
    super.dispose();
  }

  void _onSpinStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    // The history clock can be tapped mid-revolution; pushing Settings on top
    // of History would be a route the gear does not own, so a spin that lands
    // off the root screen rewinds instead of navigating.
    if (ModalRoute.of(context)?.isCurrent != true) {
      _spin.value = 0;
      return;
    }
    context.push(AppRoutes.settings);
    // 360° paints exactly as 0°, so rewinding under the incoming route is
    // pixel-identical — the next tap starts from the top with no snap.
    _spin.value = 0;
  }

  void _spinThenOpenSettings() {
    // A second tap mid-turn would restart the controller and could starve
    // the completed status the push hangs on.
    if (_spin.isAnimating) return;
    _spin.forward();
  }

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      tooltip: 'Settings',
      size: AppSizes.calculatorHeaderAction,
      onPressed: _spinThenOpenSettings,
      iconWidget: AnimatedBuilder(
        animation: _spin,
        builder: (context, glyph) => Transform.rotate(
          key: const Key('settings-gear-spin'),
          angle:
              Curves.easeInOutCubic.transform(_spin.value) *
              _SettingsGearButton.turn,
          child: glyph,
        ),
        child: const Icon(
          Icons.settings,
          size: AppSizes.calculatorHeaderAction *
              AppSizes.calculatorHeaderGlyphRatio,
        ),
      ),
    );
  }
}