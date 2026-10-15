import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_palette.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/widgets/core_widgets.dart';
import '../../presentation/vault_search_header.dart';
import '../../presentation/vault_trash.dart';
import '../../images/domain/vault_image.dart';
import '../../images/presentation/vault_images_controller.dart';
import '../../images/presentation/vault_images_state.dart';
import 'vault_document_widgets.dart';
import 'vault_documents_controller.dart';
import 'vault_documents_state.dart';

/// The global Recycle bin: everything deleted anywhere in the vault, kept for
/// 30 days (FEAT-SEC-009, D-116).
///
/// The `recycle-bin` place's page, and the vault's *one* bin. It lists trashed
/// documents **and** trashed pictures together, because both are rows the same
/// vault keeps and both carry a `trashedAt`; a user who deleted a photo and a
/// PDF on the same afternoon should find them in the same list, ordered the way
/// they were deleted.
///
/// **The gallery's own Trash tab is untouched.** A picture moved to trash still
/// shows under Pictures ▸ Trash; this page is a second view over the same
/// `trashedAt` flag, not a second copy. Restoring or deleting an entry here
/// flips the one flag both views read, so the two can never disagree.
///
/// Everything here is recoverable until the 30-day purge; nothing on this page
/// deletes without a confirmation.
class VaultDocumentsTrashScreen extends ConsumerStatefulWidget {
  const VaultDocumentsTrashScreen({super.key});

  static const Key listKey = Key('vault-documents-trash-list');
  static const Key selectionBarKey = Key('vault-documents-trash-selection-bar');
  static const Key searchFieldKey = Key('vault-documents-trash-search');

  @override
  ConsumerState<VaultDocumentsTrashScreen> createState() =>
      _VaultDocumentsTrashScreenState();
}

class _VaultDocumentsTrashScreenState
    extends ConsumerState<VaultDocumentsTrashScreen> {
  String _query = '';
  bool _searching = false;
  final Set<String> _selected = <String>{};
  final TextEditingController _searchController = TextEditingController();

  /// Drives the list's scroll position for the drag's auto-scroll (D-120).
  final ScrollController _scrollController = ScrollController();

  bool get _selecting => _selected.isNotEmpty;

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// The bin's entries — documents and pictures — filtered by the search text
  /// and most recently deleted first.
  ///
  /// [images] is optional: a bin that can list documents must render the moment
  /// the document vault is readable, without waiting on the gallery's provider.
  /// The pictures join the list the frame that provider lands, if it ever does.
  List<VaultTrashEntry> _resolved(
    VaultDocumentsState documents,
    VaultImagesState? images,
  ) {
    final needle = _query.trim().toLowerCase();
    final list = <VaultTrashEntry>[
      for (final document in documents.trash) VaultTrashEntry.document(document),
      for (final image in images?.trash ?? <VaultImage>[])
        VaultTrashEntry.image(image),
    ];
    final filtered = <VaultTrashEntry>[
      for (final entry in list)
        if (needle.isEmpty || entry.name.toLowerCase().contains(needle)) entry,
    ];
    filtered.sort((a, b) => b.trashedAt.compareTo(a.trashedAt));
    return filtered;
  }

  /// Every id currently in the bin, regardless of the search text.
  ///
  /// Used by "Empty recycle bin", which deletes the whole bin rather than the
  /// rows a search happens to be showing.
  Set<String> _allIds(VaultDocumentsState documents, VaultImagesState? images) {
    return <String>{
      for (final document in documents.trash) document.id,
      for (final image in images?.trash ?? <VaultImage>[]) image.id,
    };
  }

  bool _isDocument(VaultDocumentsState documents, String id) {
    for (final document in documents.trash) {
      if (document.id == id) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final documents = ref.watch(vaultDocumentsProvider);
    final documentsValue = documents.valueOrNull;

    if (documentsValue == null) {
      if (documents.hasError) {
        return SecondaryPageScaffold(
          header: const SecondaryPageHeader(),
          body: EmptyState(
            icon: Icons.error_outline,
            title: 'Could not open the recycle bin',
            message: 'Try again.',
            action: FilledButton(
              onPressed: () => ref.invalidate(vaultDocumentsProvider),
              child: const Text('Try again'),
            ),
          ),
        );
      }
      return const SecondaryPageScaffold(
        header: SecondaryPageHeader(),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // The pictures are optional: the bin renders its documents now and folds the
    // gallery's trashed pictures in the frame that provider lands. Watching it
    // without gating on it keeps the page honest when the gallery store is slow
    // or unavailable — a deleted PDF is still findable.
    final images = ref.watch(vaultImagesProvider).valueOrNull;

    return _buildLoaded(context, documentsValue, images);
  }

  Widget _buildLoaded(
    BuildContext context,
    VaultDocumentsState documents,
    VaultImagesState? images,
  ) {
    final resolved = _resolved(documents, images);
    final allSelected =
        resolved.isNotEmpty && resolved.every((e) => _selected.contains(e.id));
    final isEmpty =
        documents.trash.isEmpty && (images?.trash.isEmpty ?? true);

    return SecondaryPageScaffold(
      header: _header(resolved, allSelected),
      body: Column(
        children: [
          Expanded(
            // D-120: hold a row and drag to paint a selection down the list.
            child: DragSelectRegion(
              controller: _scrollController,
              onBegin: _beginDrag,
              onPaint: _paintDrag,
              child: _body(resolved, isEmpty),
            ),
          ),
          if (_selecting) _selectionBar(),
        ],
      ),
    );
  }

  /// The top row: the documents header, or the shared search bar when a search
  /// is open (and no selection has taken the row over).
  Widget _header(List<VaultTrashEntry> resolved, bool allSelected) {
    if (!_selecting && _searching) {
      return VaultSearchHeader(
        fieldKey: VaultDocumentsTrashScreen.searchFieldKey,
        controller: _searchController,
        query: _query,
        hintText: 'Search recycle bin',
        onChanged: (value) => setState(() => _query = value),
        onClose: _closeSearch,
      );
    }
    return VaultDocumentsHeader(
      selecting: _selecting,
      selectedCount: _selected.length,
      allSelected: allSelected,
      onCancel: () => setState(_selected.clear),
      onSelectAll: () => _selectAll(resolved),
      onSearch: () => setState(() => _searching = true),
      onMore: _showMoreSheet,
    );
  }

  Widget _body(List<VaultTrashEntry> resolved, bool isEmpty) {
    if (isEmpty) {
      return EmptyState(
        iconWidget: AppTrashIcon(color: context.appColors.textSecondary),
        title: 'Recycle bin is empty',
        message: 'Deleted photos and documents rest here for 30 days.',
      );
    }
    if (resolved.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'Nothing found',
        message: 'Try a different name.',
      );
    }
    return ListView.builder(
      key: VaultDocumentsTrashScreen.listKey,
      controller: _scrollController,
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.xl,
      ),
      itemCount: resolved.length,
      itemBuilder: (context, index) {
        final entry = resolved[index];
        return DragSelectItem(
          id: entry.id,
          child: _row(entry),
        );
      },
    );
  }

  Widget _row(VaultTrashEntry entry) {
    final image = entry.image;
    if (image != null) {
      return VaultTrashImageRow(
        key: Key('vault-image-trash-${entry.id}'),
        image: image,
        selected: _selected.contains(entry.id),
        selecting: _selecting,
        onTap: () {
          if (_selecting) {
            _toggleSelect(entry.id);
          } else {
            showVaultImageInfo(context, image);
          }
        },
        onMenu: () => _showRowSheet(entry),
      );
    }
    final document = entry.document!;
    return VaultDocumentRow(
      key: Key('vault-document-trash-${entry.id}'),
      document: document,
      selected: _selected.contains(entry.id),
      selecting: _selecting,
      onTap: () {
        if (_selecting) {
          _toggleSelect(entry.id);
        } else {
          showVaultDocumentInfo(context, document);
        }
      },
      onMenu: () => _showRowSheet(entry),
    );
  }

  Widget _selectionBar() {
    // [icon] is a widget so the bar can carry the painted [AppTrashIcon] (the
    // History screen's delete glyph, D-119) as well as Material [Icon]s — the
    // same shape the gallery's and the documents screen's bars already use.
    Widget action(Widget icon, String label, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.md,
              bottom: AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconTheme(
                  data: IconThemeData(
                    color: context.appColors.textPrimary,
                    size: AppSizes.rowIcon,
                  ),
                  child: icon,
                ),
                const SizedBox(height: 4),
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
        key: VaultDocumentsTrashScreen.selectionBarKey,
        decoration: BoxDecoration(
          color: context.appColors.surface,
          border: Border(top: BorderSide(color: context.appColors.divider)),
        ),
        child: Row(
          children: [
            action(const Icon(Icons.restore), 'Restore', _restoreSelected),
            // D-119's glyph, not Material's `delete_forever`: even a permanent
            // delete paints the one trash the History screen deletes with.
            action(
              const AppTrashIcon(),
              'Delete forever',
              _deleteForeverSelected,
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _selectAll(List<VaultTrashEntry> list) {
    setState(() {
      if (list.every((e) => _selected.contains(e.id))) {
        _selected.clear();
      } else {
        _selected.addAll(list.map((e) => e.id));
      }
    });
  }

  /// Starts a long-press-and-drag selection (D-120).
  ///
  /// The row under the press is entered, and the drag's direction comes back as
  /// the return value: an unselected row means the drag adds, an already chosen
  /// one means it removes.
  bool _beginDrag(String id) {
    final selecting = !_selected.contains(id);
    setState(() {
      if (selecting) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
    return selecting;
  }

  /// Applies the drag's mode to one row it passed over (D-120).
  ///
  /// *Sets* rather than toggles, so a finger that drifts back over a row does
  /// not undo what it just did.
  void _paintDrag(String id, bool select) {
    if (select == _selected.contains(id)) return;
    setState(() {
      if (select) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
  }

  void _closeSearch() {
    setState(() {
      _searching = false;
      _query = '';
      _searchController.clear();
    });
  }

  /// Splits [ids] into the document and picture halves of the bin.
  ///
  /// The two sections persist to different stores, so restore and delete-forever
  /// have to be routed to the right notifier. An id the documents list claims is
  /// a document; everything else is a picture. The two id spaces are uuid v4 and
  /// never collide.
  ({Set<String> documents, Set<String> images}) _split(Set<String> ids) {
    final documents = ref.read(vaultDocumentsProvider).valueOrNull;
    final documentIds = <String>{};
    final imageIds = <String>{};
    for (final id in ids) {
      if (documents != null && _isDocument(documents, id)) {
        documentIds.add(id);
      } else {
        imageIds.add(id);
      }
    }
    return (documents: documentIds, images: imageIds);
  }

  Future<void> _restoreSelected() async {
    if (_selected.isEmpty) return;
    final split = _split(Set<String>.from(_selected));
    if (split.documents.isNotEmpty) {
      await ref
          .read(vaultDocumentsProvider.notifier)
          .restoreFromTrash(split.documents);
    }
    if (split.images.isNotEmpty) {
      await ref
          .read(vaultImagesProvider.notifier)
          .restoreFromTrash(split.images);
    }
    if (!mounted) return;
    setState(_selected.clear);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Restored')),
    );
  }

  Future<void> _deleteForeverSelected() async {
    await _deleteForever(Set<String>.from(_selected));
  }

  Future<void> _deleteForever(Set<String> ids) async {
    if (ids.isEmpty) return;
    final count = ids.length;
    final confirmed = await AppConfirmationDialog.show(
      context,
      title: count == 1 ? 'Delete forever?' : 'Delete $count forever?',
      message: 'This cannot be undone. The private copy is removed.',
      confirmLabel: 'Delete forever',
    );
    if (!confirmed || !mounted) return;
    final split = _split(ids);
    if (split.documents.isNotEmpty) {
      await ref
          .read(vaultDocumentsProvider.notifier)
          .deletePermanently(split.documents);
    }
    if (split.images.isNotEmpty) {
      await ref
          .read(vaultImagesProvider.notifier)
          .deletePermanently(split.images);
    }
    if (!mounted) return;
    setState(_selected.clear);
  }

  Future<void> _showRowSheet(VaultTrashEntry entry) async {
    final image = entry.image;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Restore'),
              onTap: () => Navigator.of(context).pop('restore'),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(image != null ? 'Details' : 'File info'),
              onTap: () => Navigator.of(context).pop('info'),
            ),
            ListTile(
              // D-119: the History screen's trash rather than Material's
              // `delete_forever`, so every delete in the sheet wears the one
              // glyph the rest of the app deletes with.
              leading: const AppTrashIcon(),
              title: const Text('Delete forever'),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'restore':
        final split = _split(<String>{entry.id});
        if (split.documents.isNotEmpty) {
          await ref
              .read(vaultDocumentsProvider.notifier)
              .restoreFromTrash(split.documents);
        } else {
          await ref
              .read(vaultImagesProvider.notifier)
              .restoreFromTrash(split.images);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restored')),
        );
      case 'info':
        if (image != null) {
          await showVaultImageInfo(context, image);
        } else {
          await showVaultDocumentInfo(context, entry.document!);
        }
      case 'delete':
        await _deleteForever(<String>{entry.id});
    }
  }

  Future<void> _showMoreSheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.checklist),
              title: const Text('Select items'),
              onTap: () => Navigator.of(context).pop('select'),
            ),
            ListTile(
              leading: const AppTrashIcon(),
              title: const Text('Empty recycle bin'),
              onTap: () => Navigator.of(context).pop('empty'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    final documents = ref.read(vaultDocumentsProvider).valueOrNull;
    if (documents == null) return;
    final images = ref.read(vaultImagesProvider).valueOrNull;
    switch (action) {
      case 'select':
        final resolved = _resolved(documents, images);
        if (resolved.isNotEmpty) {
          setState(() => _selected.add(resolved.first.id));
        }
      case 'empty':
        await _deleteForever(_allIds(documents, images));
    }
  }
}
