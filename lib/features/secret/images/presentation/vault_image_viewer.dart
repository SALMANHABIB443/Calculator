import 'dart:io';

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
  final TransformationController _zoom = TransformationController();
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
    _zoom.dispose();
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

  Future<Uint8List?> _bytes(VaultImage image) async {
    final store = ref.read(vaultImageStoreProvider);
    return store.readBytes(image.vaultFileName, trashed: image.isTrashed);
  }

  void _toggleChrome() => setState(() => _chrome = !_chrome);

  void _doubleTapZoom(TapDownDetails details) {
    if (_zoom.value != Matrix4.identity()) {
      _zoom.value = Matrix4.identity();
    } else {
      final pos = details.localPosition;
      _zoom.value = Matrix4.identity()
        ..translateByDouble(-pos.dx * 2, -pos.dy * 2, 0, 1)
        ..scaleByDouble(3, 3, 1, 1);
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
              onPageChanged: (i) {
                _zoom.value = Matrix4.identity();
                setState(() => _index = i);
              },
              itemBuilder: (context, i) {
                final image = widget.images[i];
                return GestureDetector(
                  onTap: _toggleChrome,
                  onDoubleTapDown: (d) => _doubleTap = d,
                  onDoubleTap: () {
                    if (_doubleTap != null) _doubleTapZoom(_doubleTap!);
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
                      return InteractiveViewer(
                        transformationController: _zoom,
                        minScale: 1,
                        maxScale: 4,
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
                  // screen edges; the small vertical gap keeps them off the
                  // status bar inset without eating the photo.
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    AppSpacing.sm,
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
