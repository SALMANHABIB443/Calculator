import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/design/app_palette.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/widgets/core_widgets.dart';
import '../../data/device_storage_repository.dart';
import '../domain/vault_image.dart';
import 'vault_gallery_widgets.dart';
import 'vault_image_viewer.dart';
import 'vault_images_controller.dart';
import 'vault_images_providers.dart';
import 'vault_images_state.dart';

/// Private image gallery: Pictures / Albums / Favorites / Trash (D-116).
///
/// Reuses the app's own chrome (`SecondaryPageScaffold`, selection header,
/// confirmation dialog, empty state) so it reads as part of this app rather
/// than a copied gallery. The 3-column grid, circular selection checks, and
/// bottom Create/Share/Delete/More bar follow the screenshot behaviour.
class VaultImagesScreen extends ConsumerStatefulWidget {
  const VaultImagesScreen({super.key});

  static const Key searchFieldKey = Key('vault-images-search');
  static const Key addButtonKey = Key('vault-images-add');
  static const Key gridKey = Key('vault-images-grid');

  @override
  ConsumerState<VaultImagesScreen> createState() => _VaultImagesScreenState();
}

enum _VaultTab { pictures, albums, favorites, trash }

class _VaultImagesScreenState extends ConsumerState<VaultImagesScreen>
    with WidgetsBindingObserver {
  _VaultTab _tab = _VaultTab.pictures;
  String _albumId = 'all';
  String _query = '';
  bool _searching = false;
  final Set<String> _selected = <String>{};
  bool _importing = false;
  String? _importLabel;
  final TextEditingController _searchController = TextEditingController();

  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Hide sensitive UI the moment the app backgrounds (vault security).
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_selected.isNotEmpty && mounted) setState(_selected.clear);
    }
  }

  List<VaultImage> _currentList(VaultImagesState gallery) {
    switch (_tab) {
      case _VaultTab.pictures:
        return gallery.search(_query);
      case _VaultTab.albums:
        if (_query.trim().isNotEmpty) {
          final inAlbum = gallery.inAlbum(_albumId).map((e) => e.id).toSet();
          return gallery
              .search(_query)
              .where((e) => inAlbum.contains(e.id))
              .toList();
        }
        return gallery.inAlbum(_albumId);
      case _VaultTab.favorites:
        if (_query.trim().isNotEmpty) {
          final favs = gallery.favorites.map((e) => e.id).toSet();
          return gallery
              .search(_query)
              .where((e) => favs.contains(e.id))
              .toList();
        }
        return gallery.sorted(gallery.favorites);
      case _VaultTab.trash:
        return gallery.sorted(gallery.trash);
    }
  }

  void _toggleSelect(VaultImage image) {
    setState(() {
      if (_selected.contains(image.id)) {
        _selected.remove(image.id);
      } else {
        _selected.add(image.id);
      }
    });
  }

  void _selectAll(List<VaultImage> list) {
    setState(() {
      if (list.every(_selected.contains)) {
        _selected.clear();
      } else {
        _selected.addAll(list.map((e) => e.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gallery = ref.watch(vaultImagesProvider);
    return gallery.when(
      loading: () => SecondaryPageScaffold(
        header: const SecondaryPageHeader(title: 'Pictures'),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => SecondaryPageScaffold(
        header: const SecondaryPageHeader(title: 'Pictures'),
        body: EmptyState(
          icon: Icons.broken_image_outlined,
          title: 'Could not open the gallery',
          message: 'Your photos are still safe. Try again.',
          action: FilledButton(
            onPressed: () => ref.invalidate(vaultImagesProvider),
            child: const Text('Try again'),
          ),
        ),
      ),
      data: (state) => _buildLoaded(context, state),
    );
  }

  Widget _buildLoaded(BuildContext context, VaultImagesState gallery) {
    final list = _currentList(gallery);
    final title = _selecting
        ? '${_selected.length} selected'
        : switch (_tab) {
            _VaultTab.pictures => 'Pictures',
            _VaultTab.albums => 'Albums',
            _VaultTab.favorites => 'Favorites',
            _VaultTab.trash => 'Trash',
          };
    final allSelected =
        list.isNotEmpty && list.every((e) => _selected.contains(e.id));
    return SecondaryPageScaffold(
      header: VaultGalleryHeader(
        selecting: _selecting,
        selectedCount: _selected.length,
        title: title,
        allSelected: allSelected,
        onCancel: () => setState(_selected.clear),
        onSelectAll: () => _selectAll(list),
        onSearch: () => setState(() {
          _searching = !_searching;
          if (!_searching) {
            _query = '';
            _searchController.clear();
          }
        }),
        onMore: () => _showMoreSheet(gallery),
      ),
      body: Column(
        children: [
          if (_searching) _searchField(),
          if (!_selecting) _tabRow(),
          Expanded(child: _content(context, gallery, list)),
          if (!_selecting) _bottomTabs(),
          if (_selecting) _selectionBar(gallery, list),
          if (_importing) _importBanner(),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.sm,
        AppSpacing.screenHorizontal,
        AppSpacing.sm,
      ),
      child: TextField(
        key: VaultImagesScreen.searchFieldKey,
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search name, album, or date',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear search',
                  onPressed: () => setState(() {
                    _query = '';
                    _searchController.clear();
                  }),
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),
        onChanged: (value) => setState(() => _query = value),
      ),
    );
  }

  /// Top text tabs. No numeric counters — the active tab is marked by a
  /// small white underline pill instead of a filled background, which keeps
  /// the row calm while still making the current tab unmistakable.
  Widget _tabRow() {
    Widget tab(_VaultTab tab, String label) {
      final active = _tab == tab;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() {
            _tab = tab;
            _selected.clear();
          }),
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.rowTitle.copyWith(
                    color: active
                        ? context.appColors.textPrimary
                        : context.appColors.textSecondary,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                // Reserved transparent slot for inactive tabs so selecting
                // one never shifts the row.
                Container(
                  width: 24,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: active
                        ? context.appColors.textPrimary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          tab(_VaultTab.pictures, 'Pictures'),
          tab(_VaultTab.albums, 'Albums'),
          tab(_VaultTab.favorites, 'Favorites'),
          tab(_VaultTab.trash, 'Trash'),
        ],
      ),
    );
  }

  Widget _content(
    BuildContext context,
    VaultImagesState gallery,
    List<VaultImage> list,
  ) {
    if (_tab == _VaultTab.albums && _albumId == 'all' && _query.isEmpty) {
      return _albumsList(gallery);
    }
    if (list.isEmpty) return _emptyContent();
    return _photoGrid(list);
  }

  Widget _emptyContent() {
    if (_query.trim().isNotEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'No photos found',
        message: 'Try a different name, album, or date.',
      );
    }
    if (_tab == _VaultTab.trash) {
      return const EmptyState(
        icon: Icons.delete_outline,
        title: 'Trash is empty',
        message: 'Deleted photos rest here for 30 days.',
      );
    }
    if (_tab == _VaultTab.favorites) {
      return const EmptyState(
        icon: Icons.favorite_border,
        title: 'No favorites yet',
        message: 'Tap the heart on any photo to keep it here.',
      );
    }
    return EmptyState(
      icon: Icons.image_outlined,
      title: 'No private photos yet',
      message: 'Import photos to keep them private to this vault.',
      iconSize: AppIconSize.illustration,
      action: FilledButton.icon(
        key: VaultImagesScreen.addButtonKey,
        onPressed: _pickAndImport,
        icon: const Icon(Icons.add),
        label: const Text('Add Photos'),
      ),
    );
  }

  Widget _photoGrid(List<VaultImage> list) {
    return Stack(
      children: [
        GridView.builder(
          key: VaultImagesScreen.gridKey,
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final image = list[index];
            final selected = _selected.contains(image.id);
            return FutureBuilder<File>(
              future: _vaultFile(image),
              builder: (context, snapshot) {
                final file = snapshot.data;
                if (file == null) {
                  return Container(color: context.appColors.surface);
                }
                return VaultGridTile(
                  image: image,
                  file: file,
                  selected: selected,
                  selecting: _selecting,
                  onTap: () {
                    if (_selecting) {
                      _toggleSelect(image);
                    } else {
                      _openViewer(list, index);
                    }
                  },
                  onLongPress: () => setState(() {
                    _selected.add(image.id);
                  }),
                );
              },
            );
          },
        ),
        if (!_selecting && _tab == _VaultTab.pictures)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              key: VaultImagesScreen.addButtonKey,
              heroTag: 'vault-add',
              tooltip: 'Add Photos',
              onPressed: _pickAndImport,
              child: const Icon(Icons.add),
            ),
          ),
      ],
    );
  }

  /// Bottom navigation. Minimal: 22 px glyphs, caption labels, and a small
  /// white bar under the active item instead of a filled background. The bar
  /// slot is reserved for every item so switching never shifts the row, and
  /// [SafeArea] keeps it clear of gesture insets on any screen size.
  Widget _bottomTabs() {
    Widget item(_VaultTab tab, IconData icon, String label) {
      final active = _tab == tab;
      final color = active
          ? context.appColors.textPrimary
          : context.appColors.textSecondary;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() {
            _tab = tab;
            _selected.clear();
          }),
          child: Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.md,
              bottom: AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.caption.copyWith(
                    color: color,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 16,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: active ? color : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: context.appColors.surface,
          border: Border(top: BorderSide(color: context.appColors.divider)),
        ),
        child: Row(
          children: [
            item(_VaultTab.pictures, Icons.image_outlined, 'Pictures'),
            item(_VaultTab.albums, Icons.photo_album_outlined, 'Albums'),
            item(_VaultTab.favorites, Icons.favorite_border, 'Favorites'),
            item(_VaultTab.trash, Icons.delete_outline, 'Trash'),
          ],
        ),
      ),
    );
  }

  Widget _selectionBar(VaultImagesState gallery, List<VaultImage> list) {
    Widget action(IconData icon, String label, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: context.appColors.textPrimary, size: 22),
                const SizedBox(height: 2),
                Text(label, style: context.type.caption),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: context.appColors.surface,
          border: Border(top: BorderSide(color: context.appColors.divider)),
        ),
        child: Row(
          children: [
            if (_tab == _VaultTab.trash) ...[
              action(Icons.restore, 'Restore', _restoreSelected),
              action(
                Icons.share_outlined,
                'Share',
                () => _shareSelected(list),
              ),
              action(
                Icons.delete_forever_outlined,
                'Delete',
                _deletePermanentlyDialog,
              ),
            ] else ...[
              action(Icons.create_new_folder_outlined, 'Create', () {
                _addToAlbumSheet(gallery);
              }),
              action(Icons.share_outlined, 'Share', () => _shareSelected(list)),
              action(Icons.delete_outline, 'Delete', _deleteDialog),
            ],
            action(Icons.more_vert, 'More', () => _showMoreSheet(gallery)),
          ],
        ),
      ),
    );
  }

  Future<File> _vaultFile(VaultImage image) {
    final store = ref.read(vaultImageStoreProvider);
    return store.fileFor(image.vaultFileName, trashed: image.isTrashed);
  }

  void _openViewer(List<VaultImage> list, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VaultImageViewer(images: list, initialIndex: index),
      ),
    );
  }

  Future<void> _pickAndImport() async {
    if (_importing) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final imagePicker = ref.read(vaultImagePickerProvider);
      final picked = await imagePicker.pickMultiImage();
      if (picked.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _importing = true;
        _importLabel = 'Importing ${picked.length} photos…';
      });
      final result = await ref
          .read(vaultImagesProvider.notifier)
          .importPickedFiles(picked);
      if (!mounted) return;
      setState(() {
        _importing = false;
        _importLabel = null;
      });
      final parts = <String>[];
      if (result.imported > 0) parts.add('${result.imported} imported');
      if (result.failed > 0) parts.add('${result.failed} failed');
      messenger.showSnackBar(
        SnackBar(
          content: Text(parts.isEmpty ? 'Nothing imported' : parts.join(' · ')),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _importLabel = null;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the photo picker')),
      );
    }
  }

  Future<void> _shareSelected(List<VaultImage> list) async {
    final messenger = ScaffoldMessenger.of(context);
    final selected = list.where((e) => _selected.contains(e.id)).toList();
    if (selected.isEmpty) return;
    try {
      final store = ref.read(vaultImageStoreProvider);
      final scratch = await store.shareScratch();
      final files = <XFile>[];
      for (final image in selected) {
        final src = await store.fileFor(
          image.vaultFileName,
          trashed: image.isTrashed,
        );
        if (!await src.exists()) continue;
        final temp = File('${scratch.path}/${image.vaultFileName}');
        await src.copy(temp.path);
        files.add(XFile(temp.path, mimeType: image.mimeType));
      }
      if (files.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Photo files are missing')),
        );
        return;
      }
      await SharePlus.instance.share(ShareParams(files: files));
      await store.cleanShareScratch();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not share these photos')),
      );
    }
  }

  Widget _importBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      color: context.appColors.surface,
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              _importLabel ?? 'Importing…',
              style: context.type.rowSubtitle,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDialog() async {
    final count = _selected.length;
    final confirmed = await AppConfirmationDialog.show(
      context,
      title: count == 1 ? 'Move photo to Trash?' : 'Delete $count photos?',
      message: 'They move to Trash for 30 days inside this private vault.',
      confirmLabel: 'Move to Trash',
    );
    if (!confirmed || !mounted) return;
    await ref
        .read(vaultImagesProvider.notifier)
        .moveToTrash(Set<String>.from(_selected));
    if (!mounted) return;
    setState(_selected.clear);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Moved to Trash')),
    );
  }

  Future<void> _deletePermanentlyDialog() async {
    final count = _selected.length;
    final confirmed = await AppConfirmationDialog.show(
      context,
      title: count == 1 ? 'Delete forever?' : 'Delete $count forever?',
      message: 'This cannot be undone. The private copy is removed.',
      confirmLabel: 'Delete forever',
    );
    if (!confirmed || !mounted) return;
    await ref
        .read(vaultImagesProvider.notifier)
        .deletePermanently(Set<String>.from(_selected));
    if (!mounted) return;
    setState(_selected.clear);
  }

  Future<void> _restoreSelected() async {
    if (_selected.isEmpty) return;
    await ref
        .read(vaultImagesProvider.notifier)
        .restoreFromTrash(Set<String>.from(_selected));
    if (!mounted) return;
    setState(_selected.clear);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Restored')),
    );
  }

  Future<void> _createAlbumDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        // 24 px insets instead of the framework's 40 px default, so the
        // dialog spans the same 312 dp as the page's cards and its edges
        // line up with the header gutters rather than looking squeezed.
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
        ),
        title: const Text('New album'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          // White caret and white focus underline instead of the theme's
          // orange accent — the gallery's interactive lines are white.
          cursorColor: context.appColors.textPrimary,
          decoration: InputDecoration(
            hintText: 'Album name',
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: context.appColors.textPrimary),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: context.appColors.divider),
            ),
          ),
          onSubmitted: (_) =>
              Navigator.of(context).pop(controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return;
    await ref.read(vaultImagesProvider.notifier).createAlbum(name);
  }

  Future<void> _addToAlbumSheet(VaultImagesState gallery) async {
    final ids = Set<String>.from(_selected);
    if (ids.isEmpty) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('New album'),
              onTap: () => Navigator.of(context).pop('__new__'),
            ),
            for (final album in gallery.albums)
              ListTile(
                leading: const Icon(Icons.photo_album_outlined),
                title: Text(album.name),
                onTap: () => Navigator.of(context).pop(album.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final notifier = ref.read(vaultImagesProvider.notifier);
    if (picked == '__new__') {
      await _createAlbumDialog();
      final albums = ref.read(vaultImagesProvider).valueOrNull?.albums;
      if (albums == null || albums.isEmpty || !mounted) return;
      await notifier.addToAlbum(albums.last.id, ids);
    } else {
      await notifier.addToAlbum(picked, ids);
    }
    if (!mounted) return;
    setState(_selected.clear);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to album')),
    );
  }

  Future<void> _sortSheet() async {
    final picked = await showModalBottomSheet<VaultImageSort>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final sort in VaultImageSort.values)
              ListTile(
                title: Text(sort.label),
                onTap: () => Navigator.of(context).pop(sort),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await ref.read(vaultImagesProvider.notifier).setSort(picked);
  }

  Future<void> _showMoreSheet(VaultImagesState gallery) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.checklist),
              title: const Text('Select photos'),
              onTap: () => Navigator.of(context).pop('select'),
            ),
            ListTile(
              leading: const Icon(Icons.sort),
              title: Text('Sort: ${gallery.sort.label}'),
              onTap: () => Navigator.of(context).pop('sort'),
            ),
            ListTile(
              leading: const Icon(Icons.add_photo_alternate_outlined),
              title: const Text('Add photos'),
              onTap: () => Navigator.of(context).pop('add'),
            ),
            ListTile(
              leading: const Icon(Icons.storage_outlined),
              title: const Text('Storage'),
              onTap: () => Navigator.of(context).pop('storage'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'select':
        final list = _currentList(gallery);
        if (list.isNotEmpty) setState(() => _selected.add(list.first.id));
      case 'sort':
        await _sortSheet();
      case 'add':
        await _pickAndImport();
      case 'storage':
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${gallery.visible.length} photos · '
                '${formatBytes(gallery.visible.fold<int>(0, (s, e) => s + e.fileSize))}',
              ),
            ),
          );
        }
    }
  }

  /// The Albums landing view: one compact Quick Access card, then the
  /// My Albums header with a small NEW action, and either the album list or
  /// an intentional empty-state card.
  Widget _albumsList(VaultImagesState gallery) {
    Widget row(String id, String name, int count, IconData icon) {
      return SettingsRow(
        icon: icon,
        title: name,
        subtitle: '$count photos',
        onTap: () => setState(() => _albumId = id),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.xl,
      ),
      children: [
        SettingsGroup(
          children: [
            row(
              'all',
              'All Photos',
              gallery.visible.length,
              Icons.image_outlined,
            ),
            row(
              'favorites',
              'Favorites',
              gallery.favorites.length,
              Icons.favorite_border,
            ),
            row(
              'recent',
              'Recently Added',
              gallery.inAlbum('recent').length,
              Icons.history,
            ),
          ],
        ),
        SectionHeader('My Albums', trailing: _newAlbumBadge()),
        if (gallery.albums.isEmpty)
          _emptyAlbumsCard()
        else
          SettingsGroup(
            children: [
              for (final album in gallery.albums)
                SettingsRow(
                  icon: Icons.photo_album_outlined,
                  title: album.name,
                  subtitle:
                      '${gallery.visible.where((e) => e.albumIds.contains(album.id)).length} photos',
                  onTap: () => setState(() => _albumId = album.id),
                ),
            ],
          ),
      ],
    );
  }

  /// Small NEW badge that opens the create-album dialog. A bordered pill
  /// rather than a filled button so it reads as a quiet action inside the
  /// section header, not as a primary call to action.
  Widget _newAlbumBadge() {
    final colors = context.appColors;
    return Semantics(
      button: true,
      label: 'New album',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _createAlbumDialog,
          borderRadius: BorderRadius.circular(AppRadius.iconButton),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.iconButton),
              border: Border.all(color: colors.cardBorder),
            ),
            child: Text(
              'NEW',
              style: context.type.caption.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Empty-state card for My Albums: album glyph, headline, guidance, and a
  /// small add affordance. The whole card opens the create-album dialog so
  /// the state is a starting point rather than a dead end. It reuses
  /// [SettingsGroup.decoration] so it is the same object as the cards above
  /// it — not a card inside a card.
  Widget _emptyAlbumsCard() {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: DecoratedBox(
        decoration: SettingsGroup.decoration(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _createAlbumDialog,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colors.surfaceSoft,
                        borderRadius: BorderRadius.circular(AppRadius.tile),
                      ),
                      child: Icon(
                        Icons.photo_album_outlined,
                        size: AppIconSize.large.value,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('No albums yet', style: context.type.rowTitle),
                    const SizedBox(height: 4),
                    Text(
                      'Create your first album',
                      style: context.type.rowSubtitle,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colors.surfaceSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add,
                        size: AppIconSize.small.value,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
