import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/widgets/core_widgets.dart';

import '../../data/device_storage_repository.dart';
import '../domain/vault_image.dart';
import 'vault_images_controller.dart';
import 'vault_images_providers.dart';

/// Full-screen viewer: swipe, pinch/double-tap zoom, hideable chrome.
class VaultImageViewer extends ConsumerStatefulWidget {
  const VaultImageViewer({
    required this.images,
    required this.initialIndex,
    super.key,
  });

  final List<VaultImage> images;
  final int initialIndex;

  @override
  ConsumerState<VaultImageViewer> createState() => _VaultImageViewerState();
}

class _VaultImageViewerState extends ConsumerState<VaultImageViewer>
    with WidgetsBindingObserver {
  late final PageController _pages;
  late int _index;
  bool _chrome = true;
  // One zoom controller per page (keyed by page index). The previous
  // implementation shared a single TransformationController across every
  // PageView child, so zooming page N also transformed the off-screen pages
  // (wrong size => cropped / misplaced) and resetting on page-change fought
  // the swipe gesture mid-flight. Per-page controllers keep each image's
  // matrix in its own viewport.
  final Map<int, TransformationController> _zooms =
      <int, TransformationController>{};
  // Cached image-byte futures per vault file: FutureBuilder must not mint a
  // new future on every build (chrome toggle, page change) or the image
  // reloads to a spinner and the InteractiveViewer subtree — and its gesture
  // state — is thrown away, which read as "zoom stuck".
  final Map<String, Future<Uint8List?>> _bytesCache =
      <String, Future<Uint8List?>>{};
  bool _zoomed = false;
  // Re-entrancy guard for the snap-to-identity inside [_onZoomChanged]:
  // assigning `controller.value` fires its listener synchronously, which
  // would re-enter this same handler mid-assignment.
  bool _settlingZoom = false;
  TapDownDetails? _doubleTap;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pages = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pages.dispose();
    for (final controller in _zooms.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive) &&
        mounted) {
      Navigator.of(context).maybePop();
    }
  }

  VaultImage get _current => widget.images[_index];

  TransformationController _zoomFor(int page) {
    return _zooms.putIfAbsent(page, () {
      final controller = TransformationController();
      controller.addListener(() => _onZoomChanged(page, controller));
      return controller;
    });
  }

  void _onZoomChanged(int page, TransformationController controller) {
    // Only the visible page drives swipe-vs-pan. Off-screen pages keep their
    // matrices untouched so a neighbour's transform can never crop this page.
    if (page != _index || !mounted || _settlingZoom) return;
    final scale = _scaleOf(controller.value);
    final zoomed = scale > 1.02;
    if (!zoomed && controller.value != Matrix4.identity()) {
      // Pinch-out rarely lands on an exact identity matrix: the scale is back
      // at ~1x but a residual translation survives. Leaving it means the next
      // double-tap takes the "reset" branch instead of zooming (read as
      // "further zooming fails until reopen") and the picture sits offset.
      // Snap back so scale-1 always means unzoomed-and-centred.
      _settlingZoom = true;
      try {
        controller.value = Matrix4.identity();
      } finally {
        _settlingZoom = false;
      }
    }
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  void _resetZoom(int page) {
    final controller = _zooms[page];
    if (controller == null) {
      if (_zoomed) setState(() => _zoomed = false);
      return;
    }
    if (controller.value != Matrix4.identity()) {
      // Setting the value fires the listener above, which clears [_zoomed].
      controller.value = Matrix4.identity();
    } else if (_zoomed) {
      setState(() => _zoomed = false);
    }
  }

  /// Clears every cached matrix except [current]: a page left zoomed (or with
  /// a residual translation) and later swiped back to would otherwise show a
  /// cropped / misplaced picture from its stale transform.
  void _resetStaleZooms(int current) {
    for (final entry in _zooms.entries) {
      if (entry.key == current) continue;
      if (entry.value.value != Matrix4.identity()) {
        // Listener ignores non-current pages, so this cannot recurse into
        // setState; it only drops the stale matrix.
        entry.value.value = Matrix4.identity();
      }
    }
  }

  /// Uniform scale of a transform matrix (column-vector length of X axis).
  static double _scaleOf(Matrix4 matrix) {
    final storage = matrix.storage;
    final x = storage[0];
    final y = storage[1];
    final z = storage[2];
    final squared = x * x + y * y + z * z;
    return squared > 0 ? math.sqrt(squared) : 1.0;
  }

  Future<Uint8List?> _bytes(VaultImage image) {
    final store = ref.read(vaultImageStoreProvider);
    return _bytesCache.putIfAbsent(
      '${image.isTrashed ? 'trash' : 'vault'}/${image.vaultFileName}',
      () => store.readBytes(image.vaultFileName, trashed: image.isTrashed),
    );
  }

  void _toggleChrome() => setState(() => _chrome = !_chrome);

  void _doubleTapZoom(int page, TapDownDetails details) {
    final controller = _zoomFor(page);
    // Scale-based (not `!= identity`): a pinch-out that settles at ~1x with a
    // residual translation must still count as "zoomed out", or the tap would
    // reset instead of zooming and further zooming would appear to fail.
    if (_scaleOf(controller.value) > 1.02) {
      controller.value = Matrix4.identity();
    } else {
      // Zoom 3x around the tapped point: translate first, then scale about
      // that focal point. The old code multiplied local pixels by an
      // arbitrary factor and applied translate+scale in the wrong order, so
      // the image landed off-screen (cropped / misplaced) after double-tap.
      final pos = details.localPosition;
      controller.value = Matrix4.identity()
        ..translateByDouble(pos.dx, pos.dy, 0, 1)
        ..scaleByDouble(3.0, 3.0, 3.0, 1)
        ..translateByDouble(-pos.dx, -pos.dy, 0, 1);
    }
  }

  Future<void> _shareCurrent() async {
    final messenger = ScaffoldMessenger.of(context);
    if (kIsWeb) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Sharing is not available in this browser preview'),
        ),
      );
      return;
    }
    try {
      final store = ref.read(vaultImageStoreProvider);
      final bytes = await store.readBytes(
        _current.vaultFileName,
        trashed: _current.isTrashed,
      );
      if (bytes == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Photo file is missing')),
        );
        return;
      }
      final scratch = Directory(
        '${(await getTemporaryDirectory()).path}/vault-share',
      );
      if (!await scratch.exists()) await scratch.create(recursive: true);
      final temp = File('${scratch.path}/${_current.vaultFileName}');
      await temp.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(temp.path, mimeType: _current.mimeType)]),
      );
      try {
        await scratch.delete(recursive: true);
      } catch (_) {}
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not share this photo')),
      );
    }
  }

  Future<void> _deleteCurrent() async {
    final confirmed = await AppConfirmationDialog.show(
      context,
      title: 'Move to Trash?',
      message:
          'This photo moves to Trash for 30 days. It stays private to this vault.',
      confirmLabel: 'Move to Trash',
    );
    if (!confirmed || !mounted) return;
    await ref.read(vaultImagesProvider.notifier).moveToTrash({_current.id});
    if (!mounted) return;
    if (widget.images.length <= 1) {
      Navigator.of(context).maybePop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Moved to Trash')),
      );
    }
  }

  void _details(VaultImage image) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Details', style: sheetContext.type.rowTitle),
              const SizedBox(height: AppSpacing.md),
              _detailRow(sheetContext, 'Name', image.fileName),
              _detailRow(sheetContext, 'Type', image.mimeType),
              _detailRow(
                sheetContext,
                'Size',
                formatBytes(image.fileSize),
              ),
              _detailRow(
                sheetContext,
                'Added',
                image.dateAdded.toLocal().toString(),
              ),
              _detailRow(
                sheetContext,
                'Modified',
                image.dateModified.toLocal().toString(),
              ),
              _detailRow(
                sheetContext,
                'Storage',
                'Private vault (this device only)',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 92, child: Text(label, style: context.type.caption)),
          Expanded(child: Text(value, style: context.type.rowSubtitle)),
        ],
      ),
    );
  }

  /// Renders one bottom-bar action; [icon] is a widget so the bar can carry
  /// the painted [AppTrashIcon] (the History screen's delete glyph) as well as
  /// Material [Icon]s.
  Widget _action(Widget icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme(
              data: const IconThemeData(color: Colors.white, size: 22),
              child: icon,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: context.type.caption.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pages,
              itemCount: widget.images.length,
              // While zoomed the page must not swipe: the drag belongs to the
              // image pan. At scale 1 the viewer yields so swipes navigate.
              physics: _zoomed
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              onPageChanged: (i) {
                final previous = _index;
                _resetZoom(previous);
                _resetStaleZooms(i);
                final next = _zooms[i];
                final zoomed =
                    next != null && _scaleOf(next.value) > 1.02;
                setState(() {
                  _index = i;
                  _zoomed = zoomed;
                });
              },
              itemBuilder: (context, i) {
                final image = widget.images[i];
                return GestureDetector(
                  key: ValueKey('vault-viewer-page-${image.id}'),
                  onTap: _toggleChrome,
                  onDoubleTapDown: (d) => _doubleTap = d,
                  onDoubleTap: () {
                    if (_doubleTap != null) _doubleTapZoom(i, _doubleTap!);
                  },
                  child: FutureBuilder<Uint8List?>(
                    future: _bytes(image),
                    builder: (context, snapshot) {
                      final bytes = snapshot.data;
                      if (bytes == null) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      final zoom = _zoomFor(i);
                      // Pan only once zoomed so a scale-1 horizontal drag
                      // reaches the PageView (swipe) instead of being eaten
                      // by the viewer (which would look like "swipe stuck").
                      // Pinch stays enabled so zoom-in always starts.
                      final zoomed = i == _index
                          ? _zoomed
                          : _scaleOf(zoom.value) > 1.02;
                      return InteractiveViewer(
                        key: ValueKey('vault-viewer-zoom-${image.id}'),
                        transformationController: zoom,
                        minScale: 1,
                        maxScale: 4,
                        panEnabled: zoomed,
                        scaleEnabled: true,
                        boundaryMargin: EdgeInsets.zero,
                        clipBehavior: Clip.hardEdge,
                        child: Center(
                          child: Image.memory(
                            bytes,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Text(
                              'This photo is damaged',
                              style: context.type.rowSubtitle.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            if (_chrome)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Padding(
                  // The app's 24 px screen margin, so the chrome buttons line up
                  // with every other header in the app instead of sitting on the
                  // screen edges; the top gap is [AppSpacing.headerTopGap], the
                  // same breathing room every other header keeps below the
                  // status-bar inset, so these buttons are not glued to the top.
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    AppSpacing.headerTopGap,
                    AppSpacing.screenHorizontal,
                    0,
                  ),
                  child: SizedBox(
                    height: AppSizes.iconTouchTarget,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AppIconButton(
                              icon: Icons.arrow_back,
                              tooltip: 'Back',
                              onPressed: () =>
                                  Navigator.of(context).maybePop(),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Consumer(
                                  builder: (context, ref, _) {
                                    final watched = ref
                                        .watch(vaultImagesProvider)
                                        .valueOrNull
                                        ?.images;
                                    VaultImage? match;
                                    if (watched != null) {
                                      for (final entry in watched) {
                                        if (entry.id == _current.id) {
                                          match = entry;
                                          break;
                                        }
                                      }
                                    }
                                    final fav = match?.isFavorite ??
                                        _current.isFavorite;
                                    return AppIconButton(
                                      icon: fav
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      tooltip: fav
                                          ? 'Remove favorite'
                                          : 'Mark favorite',
                                      onPressed: () => ref
                                          .read(vaultImagesProvider.notifier)
                                          .toggleFavorite(_current.id),
                                    );
                                  },
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                AppIconButton(
                                  icon: Icons.more_vert,
                                  tooltip: 'Details',
                                  onPressed: () => _details(_current),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Centred on the screen rather than in the space left
                        // over between the two sides: the left side carries one
                        // button and the right side two, so a `Row`/`Expanded`
                        // title would sit off-centre.
                        Text(
                          '${_index + 1} of ${widget.images.length}',
                          style: context.type.rowSubtitle.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_chrome)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _action(
                      const Icon(Icons.share_outlined),
                      'Share',
                      _shareCurrent,
                    ),
                    _action(
                      const AppTrashIcon(color: Colors.white),
                      'Delete',
                      _deleteCurrent,
                    ),
                    _action(
                      const Icon(Icons.info_outline),
                      'Details',
                      () => _details(_current),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
