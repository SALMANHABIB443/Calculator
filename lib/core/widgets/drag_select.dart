import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// One selectable item inside a [DragSelectRegion] (D-120).
///
/// A marker, not a control: it paints nothing and handles no gestures. Its
/// only job is to travel with the item's render object so the region can answer
/// "which item is under this point?" by running one hit test and reading the
/// ids off the path. Wrapping a card/row/tile with this is what makes it
/// reachable by a drag; an item without one is simply never painted.
///
/// A render-object marker rather than a `GlobalKey` per item: the key approach
/// needs every item to register and unregister itself through an inherited
/// widget, which costs a `StatefulWidget` on each cell and a registry to keep
/// honest as the list recycles. A proxy box that carries its id has no state,
/// nothing to register, and cannot go stale — the hit test walks the tree that
/// is actually on screen.
class DragSelectItem<T extends Object> extends SingleChildRenderObjectWidget {
  const DragSelectItem({required this.id, required super.child, super.key});

  /// The identity reported to [DragSelectRegion.onBegin] / `.onPaint`. For
  /// every screen that uses this it is the same id the selection set is keyed
  /// by, so no mapping table is needed anywhere.
  final T id;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderDragSelectItem(id);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderDragSelectItem).id = id;
  }
}

/// The render half of [DragSelectItem]: a pass-through that remembers its id.
///
/// Kept package-private: the region is the only reader, and the id is the only
/// thing it carries. It participates in hit testing as an ordinary box, so a
/// point that lands anywhere on the item's child is answered with the id.
class _RenderDragSelectItem extends RenderProxyBox {
  _RenderDragSelectItem(this.id);

  Object id;
}

/// Turns a long-press into a drag that paints a multi-selection (D-120).
///
/// **The gesture.** A long-press on one item selects it and *arms* the drag;
/// from then on every item the finger passes over is set to that same state,
/// without lifting the finger. The direction is decided by the item the press
/// landed on: an unselected item means the drag **adds** to the selection, an
/// already-selected one means it **removes**. Dragging back over an item it has
/// already touched does nothing, because items are *set* to a state rather than
/// toggled — a paint that undid itself on the way back would make the gesture
/// impossible to finish.
///
/// **Why long-press rather than a plain drag.** The region's child is a
/// scrollable, and a plain drag is already how the list scrolls. Requiring a
/// long-press first means an ordinary swipe still scrolls in every mode, while
/// a press-and-hold that never moves becomes a selection, then a move paints.
/// The two gestures stay legible by *when* they start, not by which part of the
/// screen they are on.
///
/// **Auto-scroll.** While the finger is held near the top or bottom edge the
/// region scrolls the list itself, so an item off-screen can be reached without
/// releasing the selection. Each scroll is followed by another hit test at the
/// same point, so the items coming into view are painted as they arrive.
///
/// The region is deliberately unaware of what a selection *is*: it reports ids
/// and a boolean and nothing else. Each screen decides whether an id belongs in
/// its `Set<String>`, what entering and leaving selection mode means, and what
/// the header says — all of which already existed before this widget.
class DragSelectRegion<T extends Object> extends StatefulWidget {
  const DragSelectRegion({
    required this.onBegin,
    required this.onPaint,
    required this.child,
    this.controller,
    super.key,
  });

  /// Called when a long-press lands on an item.
  ///
  /// The screen enters selection mode here and returns the mode the drag should
  /// paint in: **true** to select the items the finger passes over, **false**
  /// to deselect them. Returning null leaves the drag unarmed — used for a
  /// press that landed on empty space or a control that is not selectable.
  final bool? Function(T id) onBegin;

  /// Called once per item the finger reaches, with the mode from [onBegin].
  ///
  /// Never called twice for the same item in one drag, and never for the item
  /// [onBegin] was already handed.
  final void Function(T id, bool select) onPaint;

  /// Scrolls while the finger rests near an edge. Omit to disable auto-scroll
  /// (a short, non-scrolling list has nothing to reach).
  final ScrollController? controller;

  /// The scrollable to wrap.
  final Widget child;

  /// How close to an edge, in logical pixels, starts the auto-scroll.
  static const double edgeZone = 72;

  /// The most the list moves per auto-scroll tick.
  static const double maxScrollStep = 12;

  /// How often the auto-scroll moves the list. One animation frame.
  static const Duration scrollTick = Duration(milliseconds: 16);

  @override
  State<DragSelectRegion<T>> createState() => _DragSelectRegionState<T>();
}

class _DragSelectRegionState<T extends Object>
    extends State<DragSelectRegion<T>> {
  /// The region's own box, for turning a global point into an edge distance.
  final GlobalKey _regionKey = GlobalKey();

  /// The mode the current drag paints in, or null when no drag is armed.
  bool? _mode;

  /// The last global position the finger was seen at, so the auto-scroll timer
  /// can keep painting at the point the finger is holding even when it is not
  /// moving and therefore sending no move events.
  Offset? _pointer;

  /// The items this drag has already set, and to what. Keeps a finger that
  /// wanders back over an item from re-reporting it, and keeps the timer from
  /// piling up identical callbacks.
  final Map<Object, bool> _applied = <Object, bool>{};

  Timer? _autoScroll;

  /// −1 to the top, +1 to the bottom, 0 for no scroll. Magnitude carries how
  /// deep into the edge zone the finger is.
  double _velocity = 0;

  @override
  void dispose() {
    _stopAutoScroll();
    super.dispose();
  }

  /// The id of the [DragSelectItem] under [globalPosition], if any.
  ///
  /// A hit test from the root rather than a registry of rects: the answer comes
  /// from the tree that is on screen right now, so a recycled sliver child, a
  /// rebuild under the finger, or a scroll that moved mid-drag all resolve to
  /// what the user is actually touching.
  T? _idAt(Offset globalPosition) {
    final context = _regionKey.currentContext;
    if (context == null) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return null;

    final result = BoxHitTestResult();
    WidgetsBinding.instance.hitTestInView(
      result,
      globalPosition,
      View.of(context).viewId,
    );

    for (final entry in result.path) {
      final target = entry.target;
      if (target is _RenderDragSelectItem) {
        final id = target.id;
        if (id is T) return id;
      }
    }
    return null;
  }

  void _handleStart(LongPressStartDetails details) {
    _applied.clear();
    _stopAutoScroll();
    _pointer = details.globalPosition;

    final id = _idAt(details.globalPosition);
    if (id == null) {
      _mode = null;
      return;
    }

    final mode = widget.onBegin(id);
    _mode = mode;
    // The press already put the item in [mode] through `onBegin`, so record it
    // as done: a move that happens to re-cross it must not report it again.
    if (mode != null) _applied[id] = mode;
  }

  void _handleMove(LongPressMoveUpdateDetails details) {
    if (_mode == null) return;
    _pointer = details.globalPosition;
    _paint(details.globalPosition);
    _updateAutoScroll(details.globalPosition);
  }

  void _handleEnd(LongPressEndDetails details) => _reset();

  void _reset() {
    _mode = null;
    _pointer = null;
    _applied.clear();
    _stopAutoScroll();
  }

  void _paint(Offset globalPosition) {
    final mode = _mode;
    if (mode == null) return;

    final id = _idAt(globalPosition);
    if (id == null) return;
    if (_applied[id] == mode) return;

    _applied[id] = mode;
    widget.onPaint(id, mode);
  }

  void _updateAutoScroll(Offset globalPosition) {
    final controller = widget.controller;
    final context = _regionKey.currentContext;
    if (controller == null || !controller.hasClients || context == null) {
      return;
    }
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return;

    final local = box.globalToLocal(globalPosition);
    const zone = DragSelectRegion.edgeZone;
    final height = box.size.height;

    double velocity = 0;
    if (local.dy < zone) {
      velocity = -(zone - local.dy) / zone;
    } else if (local.dy > height - zone) {
      velocity = (local.dy - (height - zone)) / zone;
    }

    _velocity = velocity.clamp(-1.0, 1.0);
    if (_velocity == 0) {
      _stopAutoScroll();
    } else {
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    _autoScroll ??= Timer.periodic(
      DragSelectRegion.scrollTick,
      (_) => _autoScrollTick(),
    );
  }

  void _stopAutoScroll() {
    _autoScroll?.cancel();
    _autoScroll = null;
  }

  void _autoScrollTick() {
    final controller = widget.controller;
    if (_mode == null || controller == null || !controller.hasClients) {
      _stopAutoScroll();
      return;
    }

    final position = controller.position;
    final next = (position.pixels + _velocity * DragSelectRegion.maxScrollStep)
        .clamp(position.minScrollExtent, position.maxScrollExtent);

    if (next == position.pixels) {
      // The list is already at this end; there is nothing more to reveal, so
      // the timer has no reason to keep running.
      _stopAutoScroll();
      return;
    }

    controller.jumpTo(next);

    // Paint against the frame the jump just scheduled rather than the one still
    // on screen, so the item scrolling under the held finger is caught on the
    // frame it arrives rather than one frame late.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pointer = _pointer;
      if (!mounted || _mode == null || pointer == null) return;
      _paint(pointer);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _regionKey,
      // Opaque so a press on the blank space below the last row still starts a
      // selection; children are hit first, so taps and scrolls are unaffected.
      behavior: HitTestBehavior.opaque,
      onLongPressStart: _handleStart,
      onLongPressMoveUpdate: _handleMove,
      onLongPressEnd: _handleEnd,
      child: widget.child,
    );
  }
}
