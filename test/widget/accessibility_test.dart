import 'package:calculator/core/widgets/core_widgets.dart';
import 'package:flutter/material.dart';
import 'dart:ui' show SemanticsFlag, Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

/// D-59 — accessibility labels, and the `prd.md` §12 touch-target floor.
///
/// These assert the *semantics tree*, not the pixels: a label that renders
/// correctly but is never announced is the failure this file exists to catch,
/// and it is invisible in a screenshot. Each test therefore looks a node up by
/// its label and inspects the flags on it.
///
/// This is not a from-scratch audit — the screens were already reachable and
/// already named their buttons before this phase. It locks in what Phase 8
/// changed (one node per row, per card, per picker option) and puts the first
/// regression test behind the touch-target minimum, which nothing checked.

/// Opens the semantics tree for the duration of [body].
///
/// Flutter only builds the tree when something asks for it, so a lookup that
/// did not opt in would read an empty tree and every assertion below would
/// pass vacuously. The handle is disposed in a `finally` rather than through
/// `addTearDown`, because the framework verifies at the *end* of the test body
/// that no handle is still live — a teardown callback runs after that check.
Future<void> withSemantics(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  final handle = tester.ensureSemantics();
  try {
    await body();
  } finally {
    handle.dispose();
  }
}

/// Every labelled node in the tree, walking children eagerly.
///
/// The walk is explicit rather than a `matchesSemantics` finder because these
/// tests ask "how many nodes carry this label", and a finder reports matches
/// without distinguishing one merged node from two that happen to agree.
/// Whether [flag] is set on [node].
///
/// `SemanticsNode.hasFlag` is deprecated in favour of `flagsCollection`, which
/// is a `SemanticsFlags` value rather than a bitmask. That is not a cosmetic
/// change: the tri-state members are `Tristate`s, so `isToggled` has three
/// values where the old bitmask had two, and `Tristate.isFalse` is `2` — not
/// `0`. Collapsing the value by testing it against `0` would report an
/// *explicitly off* node as on, which is the failure mode this function
/// exists to make impossible.
///
/// A node with no state for a flag reports `Tristate.none`, and that counts as
/// "not set": a row that is not a button has no button state either, and a test
/// asserting `isFalse` should not have to distinguish "off" from "never
/// applicable".
bool hasFlag(SemanticsNode node, SemanticsFlag flag) {
  final flags = node.flagsCollection;

  // `SemanticsFlags` splits into two kinds of member, and reading one as the
  // other is silently wrong: the `Tristate` ones encode "off" as `2` rather
  // than `0`, and the plain `bool` ones have no state to distinguish. So the
  // three stateful flags are matched together and the rest are not.
  final tristate = switch (flag) {
    SemanticsFlag.isToggled => flags.isToggled,
    SemanticsFlag.isSelected => flags.isSelected,
    _ => null,
  };
  if (tristate != null) return tristate == Tristate.isTrue;

  return switch (flag) {
    SemanticsFlag.isButton => flags.isButton,
    SemanticsFlag.isHeader => flags.isHeader,
    // An unlisted flag would silently report "not set" and turn the test into
    // a tautology, so it fails loudly instead.
    _ => throw ArgumentError.value(
      flag,
      'flag',
      'is not covered by hasFlag; add it if a test needs it',
    ),
  };
}

/// The switch's on/off state, failing if the node has no toggle state at all.
///
/// A plain `hasFlag(..., SemanticsFlag.isToggled)` cannot tell "off" from
/// "not a switch", so a switch test needs the distinction: a row that lost its
/// `Switch` would otherwise still pass an assertion that it reads `false`.
bool isTrueOrFalse(SemanticsNode node) {
  final toggled = node.flagsCollection.isToggled;
  if (toggled == Tristate.none) {
    fail(
      'expected a node with a toggle state, but isToggled was none '
      '(label: "${node.label}")',
    );
  }
  return toggled == Tristate.isTrue;
}

List<SemanticsNode> nodesLabelled(WidgetTester tester, String label) {
  final found = <SemanticsNode>[];

  void visit(SemanticsNode node) {
    if (node.label == label) found.add(node);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(rootSemanticsNode(tester));
  return found;
}

/// Every name a screen reader would speak, in the tree.
///
/// Reads `tooltip` as well as `label` because the icon buttons get their names
/// that way: `IconButton(tooltip: 'Settings')` puts the string on the node's
/// tooltip field, not its label, and TalkBack speaks the tooltip. Collecting
/// only `label` would report those two buttons as unnamed.
List<String> labels(WidgetTester tester) {
  final found = <String>[];

  void visit(SemanticsNode node) {
    if (node.label.isNotEmpty) found.add(node.label);
    if (node.tooltip.isNotEmpty) found.add(node.tooltip);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(rootSemanticsNode(tester));
  return found;
}

/// The root of the semantics tree for the current frame.
///
/// `pipelineOwner.semanticsOwner` is deprecated; `SemanticsBinding` owns the
/// single semantics owner an app has, so that is where it comes from now.
SemanticsNode rootSemanticsNode(WidgetTester tester) {
  // The semantics owner hangs off the `PipelineOwner` the render tree is
  // attached to, not off `rootPipelineOwner` — the binding's own
  // `pipelineOwner` getter is deprecated and `SemanticsBinding` holds no owner
  // reference, so the render view's owner is the way in that is not on its way
  // out of the framework.
  final view = tester.binding.renderViews.first;
  return view.owner!.semanticsOwner!.rootSemanticsNode!;
}

void main() {
  group('Calculator', () {
    testWidgets('every key is announced by its own name, not its glyph', (
      tester,
    ) async {
      await withSemantics(tester, () async {
        await pumpApp(tester);

        final announced = labels(tester);

        // `AC` is the one key whose glyph is not its name: a screen reader
        // saying "A C" for a key that clears everything is exactly the trap
        // `CalculatorKey.semanticsLabel` exists to avoid. The names are the
        // spelled-out words, not the glyphs.
        expect(announced, contains('all clear'));
        expect(announced, contains('seven'));
        expect(announced, contains('divide'));
        expect(announced, isNot(contains('AC')));
      });
    });

    testWidgets('the top bar buttons are named', (tester) async {
      await withSemantics(tester, () async {
        await pumpApp(tester);

        final announced = labels(tester);
        expect(announced, contains('Settings'));
        expect(announced, contains('History'));
      });
    });
  });

  group('Settings rows', () {
    testWidgets('a row is one labelled node, not three loose fragments', (
      tester,
    ) async {
      await withSemantics(tester, () async {
        await pumpApp(tester);
        await openSettings(tester);

        final row = nodesLabelled(tester, 'Sound, Key press sound');
        expect(row, hasLength(1), reason: 'the row announces as a single stop');
        expect(hasFlag(row.single, SemanticsFlag.isButton), isTrue);
      });
    });

    testWidgets('a navigational row is announced as a button', (tester) async {
      await withSemantics(tester, () async {
        await pumpApp(tester);
        await openSettings(tester);

        final row = nodesLabelled(tester, 'App Version, 1.0.0');
        expect(row, hasLength(1));
        expect(hasFlag(row.single, SemanticsFlag.isButton), isTrue);
      });
    });

    testWidgets('the Theme row is announced as a button', (tester) async {
      await withSemantics(tester, () async {
        await pumpApp(tester);
        await openSettings(tester);

        // D-90: the row opens the theme sheet, so announcing it as a button
        // promises exactly the tap it honours.
        final row = nodesLabelled(tester, 'Theme, Dark');
        expect(row, hasLength(1));
        expect(hasFlag(row.single, SemanticsFlag.isButton), isTrue);
      });
    });

    testWidgets('a toggle keeps both its name and its state', (tester) async {
      await withSemantics(tester, () async {
        await pumpApp(tester);
        await openSettings(tester);

        // The row node carries the name; the Switch inside it is a node in its
        // own right (D-59), so reaching it announces "Sound" rather than the
        // whole row label with nothing about its position.
        final toggle = nodesLabelled(tester, 'Sound');
        expect(toggle, hasLength(1), reason: 'the switch is named by its row');
        expect(
          isTrueOrFalse(toggle.single),
          isTrue,
          reason: 'the switch announces its position, not just that it exists',
        );

        // Flipping it moves the announced state with it.
        await toggleSettingsRow(tester, 'Sound');

        expect(isTrueOrFalse(nodesLabelled(tester, 'Sound').single), isFalse);
      });
    });

    testWidgets('section headers are marked as headers', (tester) async {
      await withSemantics(tester, () async {
        await pumpApp(tester);
        await openSettings(tester);

        final header = nodesLabelled(tester, 'PREFERENCES');
        expect(header, hasLength(1));
        expect(
          hasFlag(header.single, SemanticsFlag.isHeader),
          isTrue,
          reason: 'lets a screen reader jump between groups',
        );
      });
    });
  });

  group('History cards', () {
    testWidgets('a card announces its expression and result as one action', (
      tester,
    ) async {
      await withSemantics(tester, () async {
        await pumpApp(
          tester,
          history: [
            seededEntry(
              expression: '125 × 8',
              result: '1,000',
              resultValue: 1000,
              timestamp: DateTime.now(),
            ),
          ],
        );
        await openHistory(tester);

        final card = nodesLabelled(tester, '125 × 8, 1,000');
        expect(card, hasLength(1));
        expect(hasFlag(card.single, SemanticsFlag.isButton), isTrue);
      });
    });

    testWidgets('the card is the only stop for its entry', (tester) async {
      await withSemantics(tester, () async {
        await pumpApp(
          tester,
          history: [
            seededEntry(
              expression: '125 × 8',
              result: '1,000',
              resultValue: 1000,
              timestamp: DateTime.now(),
            ),
          ],
        );
        await openHistory(tester);

        // The expression and the result must not also survive as separate
        // nodes, or TalkBack stops twice on the same content.
        expect(labels(tester), isNot(contains('125 × 8')));
        expect(labels(tester), isNot(contains('1,000')));
      });
    });
  });

  group('Decimal Places sheet', () {
    testWidgets('the current option announces as selected', (tester) async {
      await withSemantics(tester, () async {
        await pumpApp(tester);
        await openSettings(tester);
        await tapSettingsRow(tester, 'Decimal Places');

        final selected = nodesLabelled(tester, '2 decimal places');
        expect(selected, hasLength(1));
        expect(hasFlag(selected.single, SemanticsFlag.isSelected), isTrue);
      });
    });

    testWidgets('an unselected option is not announced as selected', (
      tester,
    ) async {
      await withSemantics(tester, () async {
        await pumpApp(tester);
        await openSettings(tester);
        await tapSettingsRow(tester, 'Decimal Places');

        final other = nodesLabelled(tester, '4 decimal places');
        expect(other, hasLength(1));
        expect(hasFlag(other.single, SemanticsFlag.isSelected), isFalse);
      });
    });
  });

  group('prd.md §12 — touch targets', () {
    testWidgets('a settings row is at least 44pt tall', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      expect(
        tester.getSize(find.widgetWithText(ToggleRow, 'Sound')).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('every calculator key is at least 44pt across', (
      tester,
    ) async {
      // The narrowest supported phone (desing.md §9), where the grid is
      // tightest and a key is most likely to fall under the floor.
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpApp(tester);

      final keys = tester
          .widgetList<CalculatorButton>(find.byType(CalculatorButton))
          .toList();
      // Five rows of four *columns*, but the last row spends two of them on
      // the wide `0` key (D-29), so nineteen keys are drawn.
      expect(keys, hasLength(19));

      for (final key in keys) {
        final size = tester.getSize(find.byKey(key.key!));
        expect(
          size.shortestSide,
          greaterThanOrEqualTo(44),
          reason: '${key.label} is ${size.shortestSide}pt',
        );
      }
    });

    testWidgets('the clear-history action is at least 44pt tall', (
      tester,
    ) async {
      await pumpApp(
        tester,
        history: [
          seededEntry(
            expression: '1 + 1',
            result: '2',
            resultValue: 2,
            timestamp: DateTime.now(),
          ),
        ],
      );
      await openHistory(tester);

      expect(
        tester.getSize(find.byKey(const Key('history-clear-button'))).height,
        greaterThanOrEqualTo(44),
      );
    });
  });
}
