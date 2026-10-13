import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:calculator/features/secret/images/data/vault_image_store.dart';
import 'package:calculator/features/secret/images/domain/vault_image.dart';
import 'package:calculator/features/secret/images/presentation/vault_image_viewer.dart';
import 'package:calculator/features/secret/images/presentation/vault_images_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the Vault image preview zoom/swipe bug.
///
/// Root causes covered:
///  - one shared TransformationController across all PageView pages (zoom on
///    page N also transformed off-screen pages => cropped / misplaced);
///  - InteractiveViewer pan competing with PageView swipe at scale 1;
///  - a fresh image-byte Future on every build, throwing away gesture state;
///  - double-tap zoom matrix built in the wrong order (off-screen landing).
class _FakeStore extends VaultImageStore {
  _FakeStore(this.bytes);

  final Uint8List bytes;
  int reads = 0;

  @override
  Future<Uint8List?> readBytes(
    String vaultFileName, {
    bool trashed = false,
  }) async {
    reads++;
    return bytes;
  }

  @override
  Future<void> importBytes(Uint8List bytes, String vaultFileName) async {}

  @override
  Future<void> moveToTrash(String vaultFileName) async {}

  @override
  Future<void> restoreFromTrash(String vaultFileName) async {}

  @override
  Future<void> deletePermanently(String vaultFileName) async {}

  @override
  Future<bool> get isEmpty async => false;
}

VaultImage _image(String id) => VaultImage(
      id: id,
      fileName: '$id.jpg',
      vaultFileName: '$id.jpg',
      mimeType: 'image/jpeg',
      fileSize: 100,
      dateAdded: DateTime(2026, 1, 2),
      dateModified: DateTime(2026, 1, 2),
    );

Uint8List _pixel() => base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );

Widget _viewer(_FakeStore store, List<VaultImage> images, {int initial = 0}) {
  return ProviderScope(
    overrides: [vaultImageStoreProvider.overrideWithValue(store)],
    child: MaterialApp(
      home: VaultImageViewer(images: images, initialIndex: initial),
    ),
  );
}

InteractiveViewer _zoomViewer(WidgetTester tester, String id) {
  final finder = find.byKey(ValueKey('vault-viewer-zoom-$id'));
  // Off-screen PageView pages are lazily built: page N's viewer only mounts
  // once the pager scrolls near it. Fall back to the live viewer when the
  // requested page has not been built yet.
  if (finder.evaluate().isEmpty) {
    return tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
  }
  return tester.widget<InteractiveViewer>(finder);
}

double _scaleOf(Matrix4 matrix) {
  final s = matrix.storage;
  final squared = s[0] * s[0] + s[1] * s[1] + s[2] * s[2];
  return squared > 0 ? math.sqrt(squared) : 1.0;
}

Matrix4 _matrix(WidgetTester tester, String id) =>
    _zoomViewer(tester, id).transformationController!.value;

Future<void> _doubleTap(WidgetTester tester, Finder page) async {
  await tester.tap(page);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(page);
  await tester.pumpAndSettle();
}

/// Simulates a real two-finger pinch through the gesture arena: two pointers
/// land together and move apart (`outward`) or together (`inward`).
Future<void> _pinch(
  WidgetTester tester,
  Offset center, {
  required bool outward,
  double halfSpan = 24,
  double step = 12,
  int steps = 12,
}) async {
  final dir = outward ? -1.0 : 1.0;
  final finger1 = await tester.startGesture(
    center - Offset(halfSpan, 0),
    pointer: 101,
  );
  final finger2 = await tester.startGesture(
    center + Offset(halfSpan, 0),
    pointer: 102,
  );
  await tester.pump();
  for (var i = 0; i < steps; i++) {
    await finger1.moveBy(Offset(dir * step, 0));
    await finger2.moveBy(Offset(-dir * step, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await finger1.up();
  await finger2.up();
  await tester.pumpAndSettle();
}

void main() {
  group('vault image viewer zoom / swipe', () {
    testWidgets('double-tap zooms and back out', (tester) async {
      final store = _FakeStore(_pixel());
      await tester.pumpWidget(_viewer(store, [_image('a')]));
      await tester.pumpAndSettle();
      expect(_zoomViewer(tester, 'a').panEnabled, isFalse);
      final page = find.byKey(const ValueKey('vault-viewer-page-a'));
      await _doubleTap(tester, page);
      expect(_zoomViewer(tester, 'a').panEnabled, isTrue);
      expect(
        _scaleOf(_matrix(tester, 'a')),
        closeTo(3, 0.001),
      );
      expect(
        tester.widget<PageView>(find.byType(PageView)).physics,
        isA<NeverScrollableScrollPhysics>(),
      );
      await _doubleTap(tester, page);
      expect(_matrix(tester, 'a'), Matrix4.identity());
      expect(_zoomViewer(tester, 'a').panEnabled, isFalse);
      // Swiping is driven by the viewer's own gesture layer, so the pager
      // stays locked (NeverScrollableScrollPhysics) at every zoom level: its
      // drag recognizer must never enter the gesture arena and race the
      // pinch/pan scale recognizer.
      expect(
        tester.widget<PageView>(find.byType(PageView)).physics,
        isA<NeverScrollableScrollPhysics>(),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('navigating away resets the previous page zoom',
        (tester) async {
      final store = _FakeStore(_pixel());
      await tester.pumpWidget(_viewer(store, [_image('a'), _image('b')]));
      await tester.pumpAndSettle();
      final first = find.byKey(const ValueKey('vault-viewer-page-a'));
      await _doubleTap(tester, first);
      expect(_zoomViewer(tester, 'a').panEnabled, isTrue);
      await _doubleTap(tester, first);
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 2000);
      await tester.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget);
      // The previous page is lazily rebuilt when swiped back to; the live
      // page (b) must start at identity with pan disabled.
      expect(_matrix(tester, 'b'), Matrix4.identity());
      expect(_zoomViewer(tester, 'b').panEnabled, isFalse);
      // Swipe back: page (a) must have been reset, not restored zoomed.
      await tester.fling(find.byType(PageView), const Offset(400, 0), 2000);
      await tester.pumpAndSettle();
      expect(find.text('1 of 2'), findsOneWidget);
      expect(_matrix(tester, 'a'), Matrix4.identity());
      expect(tester.takeException(), isNull);
    });

    testWidgets('zoom on one page never moves the neighbour', (tester) async {
      final store = _FakeStore(_pixel());
      await tester.pumpWidget(_viewer(store, [_image('a'), _image('b')]));
      await tester.pumpAndSettle();
      // Zoom page (a), leave, come back: neighbour (b) is identity.
      await _doubleTap(
          tester, find.byKey(const ValueKey('vault-viewer-page-a')));
      expect(_zoomViewer(tester, 'a').panEnabled, isTrue);
      await _doubleTap(
          tester, find.byKey(const ValueKey('vault-viewer-page-a')));
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 2000);
      await tester.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget);
      expect(_matrix(tester, 'b'), Matrix4.identity());
      // Zoom (b) now; (a) was reset on leave so returning shows identity.
      await _doubleTap(
          tester, find.byKey(const ValueKey('vault-viewer-page-b')));
      expect(_zoomViewer(tester, 'b').panEnabled, isTrue);
      await _doubleTap(
          tester, find.byKey(const ValueKey('vault-viewer-page-b')));
      await tester.fling(find.byType(PageView), const Offset(400, 0), 2000);
      await tester.pumpAndSettle();
      expect(find.text('1 of 2'), findsOneWidget);
      expect(_matrix(tester, 'a'), Matrix4.identity());
      expect(tester.takeException(), isNull);
    });

    testWidgets('chrome toggle does not reload bytes or drop zoom',
        (tester) async {
      final store = _FakeStore(_pixel());
      await tester.pumpWidget(_viewer(store, [_image('a')]));
      await tester.pumpAndSettle();
      final page = find.byKey(const ValueKey('vault-viewer-page-a'));
      await _doubleTap(tester, page);
      expect(_zoomViewer(tester, 'a').panEnabled, isTrue);
      final readsAfterZoom = store.reads;
      await tester.tap(page);
      await tester.pumpAndSettle();
      expect(store.reads, readsAfterZoom,
          reason: 'toggling chrome must not re-read image bytes');
      expect(_zoomViewer(tester, 'a').panEnabled, isTrue,
          reason: 'rebuild must not drop the zoom state');
      expect(tester.takeException(), isNull);
    });

    testWidgets('reopening starts unzoomed', (tester) async {
      final store = _FakeStore(_pixel());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [vaultImageStoreProvider.overrideWithValue(store)],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => VaultImageViewer(
                      images: [_image('a')],
                      initialIndex: 0,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final page = find.byKey(const ValueKey('vault-viewer-page-a'));
      await _doubleTap(tester, page);
      expect(_zoomViewer(tester, 'a').panEnabled, isTrue);
      // Close via Back (pop) and reopen: a fresh viewer at identity zoom.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(VaultImageViewer), findsNothing);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(_matrix(tester, 'a'), Matrix4.identity());
      expect(_zoomViewer(tester, 'a').panEnabled, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('repeated zoom in/out stays responsive', (tester) async {
      final store = _FakeStore(_pixel());
      await tester.pumpWidget(_viewer(store, [_image('a')]));
      await tester.pumpAndSettle();
      final page = find.byKey(const ValueKey('vault-viewer-page-a'));
      for (var i = 0; i < 3; i++) {
        await _doubleTap(tester, page);
        expect(_zoomViewer(tester, 'a').panEnabled, isTrue,
            reason: 'zoom-in #$i must engage');
        await _doubleTap(tester, page);
        expect(_matrix(tester, 'a'), Matrix4.identity(),
            reason: 'zoom-out #$i must return to identity');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('pinch-out residue still counts as unzoomed', (tester) async {
      // Pinch gestures rarely settle on an exact identity matrix: the scale
      // returns to ~1x while a small translation survives. The viewer must
      // snap that back, or the next double-tap takes the reset branch and
      // further zooming appears to fail until reopen.
      final store = _FakeStore(_pixel());
      await tester.pumpWidget(_viewer(store, [_image('a')]));
      await tester.pumpAndSettle();
      final viewer = _zoomViewer(tester, 'a');
      viewer.transformationController!.value =
          Matrix4.translationValues(8, -6, 0);
      await tester.pumpAndSettle();
      expect(_zoomViewer(tester, 'a').panEnabled, isFalse,
          reason: 'scale-1 with residue must read as unzoomed');
      expect(_matrix(tester, 'a'), Matrix4.identity(),
          reason: 'residue must snap back to identity');
      await _doubleTap(
          tester, find.byKey(const ValueKey('vault-viewer-page-a')));
      expect(_zoomViewer(tester, 'a').panEnabled, isTrue,
          reason: 'zoom must engage after the snap-back');
      expect(tester.takeException(), isNull);
    });

    testWidgets('swiping while zoomed stays on the page, then resets on leave',
        (tester) async {
      // While zoomed the pager locks (NeverScrollablePhysics) so a horizontal
      // drag pans the picture instead of cropping it mid-flight. Swiping only
      // works again after zoom-out, and leaving then clears the stale matrix.
      final store = _FakeStore(_pixel());
      await tester.pumpWidget(_viewer(store, [_image('a'), _image('b')]));
      await tester.pumpAndSettle();
      await _doubleTap(
          tester, find.byKey(const ValueKey('vault-viewer-page-a')));
      expect(_zoomViewer(tester, 'a').panEnabled, isTrue);
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 2000);
      await tester.pumpAndSettle();
      expect(find.text('1 of 2'), findsOneWidget,
          reason: 'swipe while zoomed must not leave the page');
      await _doubleTap(
          tester, find.byKey(const ValueKey('vault-viewer-page-a')));
      expect(_zoomViewer(tester, 'a').panEnabled, isFalse);
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 2000);
      await tester.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget);
      await tester.fling(find.byType(PageView), const Offset(400, 0), 2000);
      await tester.pumpAndSettle();
      expect(find.text('1 of 2'), findsOneWidget);
      expect(_matrix(tester, 'a'), Matrix4.identity(),
          reason: 'returning to a zoomed page must reset its matrix');
      // And zoom still engages afterwards.
      await _doubleTap(
          tester, find.byKey(const ValueKey('vault-viewer-page-a')));
      expect(_zoomViewer(tester, 'a').panEnabled, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('two-finger pinch-out zooms in and never changes the page',
        (tester) async {
      // Synthetic touch pointers are the closest a widget test can get to a
      // real two-finger pinch; the scale recognizer must win the arena with
      // both pointers down and hand the fingers to oh zoom, not to paging.
      final store = _FakeStore(_pixel());
      await tester.pumpWidget(_viewer(store, [_image('a'), _image('b')]));
      await tester.pumpAndSettle();
      final page = find.byKey(const ValueKey('vault-viewer-page-a'));
      await _pinch(tester, tester.getCenter(page), outward: true);
      expect(
        _scaleOf(_matrix(tester, 'a')),
        greaterThan(1.5),
        reason: 'a real two-finger spread must zoom the image in',
      );
      expect(_zoomViewer(tester, 'a').panEnabled, isTrue,
          reason: 'zoomed images must accept one-finger panning');
      expect(find.text('1 of 2'), findsOneWidget,
          reason: 'a pinch must not be swallowed by page swiping');
      expect(tester.takeException(), isNull);
    });

    testWidgets('one-finger drag pans a zoomed image without paging',
        (tester) async {
      final store = _FakeStore(_pixel());
      await tester.pumpWidget(_viewer(store, [_image('a'), _image('b')]));
      await tester.pumpAndSettle();
      final page = find.byKey(const ValueKey('vault-viewer-page-a'));
      await _doubleTap(tester, page);
      expect(_zoomViewer(tester, 'a').panEnabled, isTrue);
      final before = _matrix(tester, 'a').getTranslation();
      final drag =
          await tester.startGesture(tester.getCenter(page), pointer: 51);
      await tester.pump(const Duration(milliseconds: 16));
      for (var i = 0; i < 6; i++) {
        await drag.moveBy(const Offset(-20, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await drag.up();
      await tester.pumpAndSettle();
      final after = _matrix(tester, 'a').getTranslation();
      expect(after.x, lessThan(before.x),
          reason: 'dragging left must pan the zoomed image left');
      expect(find.text('1 of 2'), findsOneWidget,
          reason: 'panning must not change the page');
      expect(_zoomViewer(tester, 'a').panEnabled, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('vertical drag while unzoomed moves neither image nor page',
        (tester) async {
      final store = _FakeStore(_pixel());
      await tester.pumpWidget(_viewer(store, [_image('a'), _image('b')]));
      await tester.pumpAndSettle();
      final page = find.byKey(const ValueKey('vault-viewer-page-a'));
      final drag =
          await tester.startGesture(tester.getCenter(page), pointer: 61);
      await tester.pump(const Duration(milliseconds: 16));
      for (var i = 0; i < 6; i++) {
        await drag.moveBy(const Offset(0, 25));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await drag.up();
      await tester.pumpAndSettle();
      expect(_matrix(tester, 'a'), Matrix4.identity(),
          reason: 'unzoomed vertical drag must leave the matrix untouched');
      expect(_zoomViewer(tester, 'a').panEnabled, isFalse);
      expect(find.text('1 of 2'), findsOneWidget,
          reason: 'unzoomed vertical drag must not page');
      expect(tester.takeException(), isNull);
    });

    testWidgets('pinch back in restores the fitted view', (tester) async {
      final store = _FakeStore(_pixel());
      await tester.pumpWidget(_viewer(store, [_image('a')]));
      await tester.pumpAndSettle();
      final page = find.byKey(const ValueKey('vault-viewer-page-a'));
      final center = tester.getCenter(page);
      await _pinch(tester, center, outward: true);
      expect(
        _scaleOf(_matrix(tester, 'a')),
        greaterThan(1.5),
        reason: 'opening pinch must zoom in first',
      );
      // A closing pinch must land at 1x and snap the residual translation back
      // to identity so the next double-tap zooms instead of "resetting".
      await _pinch(tester, center, outward: false, halfSpan: 150, step: 12);
      expect(_matrix(tester, 'a'), Matrix4.identity(),
          reason: 'pinch back in must restore identity');
      expect(_zoomViewer(tester, 'a').panEnabled, isFalse,
          reason: 'scale ~1 must read as unzoomed');
      expect(tester.takeException(), isNull);
    });
  });
}
