import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_palette.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/widgets/core_widgets.dart';
import '../../data/device_storage_repository.dart';
import '../../presentation/secret_home_button.dart';
import '../../presentation/vault_search_header.dart';
import '../data/vault_document_picker.dart';
import '../domain/vault_document.dart';
import 'vault_document_viewer.dart';
import 'vault_document_widgets.dart';
import 'vault_documents_controller.dart';
import 'vault_documents_state.dart';

/// The private document vault (FEAT-SEC-009).
///
/// One screen in two modes, mirroring how the gallery handles an album page:
///
/// * **Landing** (no [initialFilter]) — a Browse-by-type card, the
///   All-documents collection row, and the five most recent documents, with the
///   floating Home button the rest of the secret area carries.
/// * **Collection** ([initialFilter] set) — the same rows for one family (or
///   all), pushed from a Browse row or the collection row. A pushed route rather
///   than an in-place swap, so Back returns to whatever opened it. Only the
///   All-documents page carries the type filter chips; a single-family page does
///   not, since every row there already belongs to that family.
///
/// The search text and the chip filter are local to the screen rather than in a
/// provider: they are transient, and a mutation that invalidated the data
/// provider must not also clear what the user typed.
class VaultDocumentsScreen extends ConsumerStatefulWidget {
  const VaultDocumentsScreen({super.key, this.initialFilter, this.title});

  /// When set, this instance is a pushed collection page scoped to one family.
  final VaultDocumentFilter? initialFilter;

  /// The header title a collection page shows. Ignored on the landing page.
  final String? title;

  static const Key searchFieldKey = Key('vault-documents-search');
  static const Key addButtonKey = Key('vault-documents-add');
  static const Key listKey = Key('vault-documents-list');
  static const Key selectionBarKey = Key('vault-documents-selection-bar');

  @override
  ConsumerState<VaultDocumentsScreen> createState() =>
      _VaultDocumentsScreenState();
}

class _VaultDocumentsScreenState extends ConsumerState<VaultDocumentsScreen> {
  bool get _collectionMode => widget.initialFilter != null;

  late VaultDocumentFilter _filter;
  String _query = '';
  bool _searching = false;
  final Set<String> _selected = <String>{};
  bool _importing = false;
  String? _importLabel;
  final TextEditingController _searchController = TextEditingController();

  /// Drives whichever list is showing, so a drag can auto-scroll to documents
  /// that started off screen (D-120). One controller: only one body is built at
  /// a time.
  final ScrollController _scrollController = ScrollController();

  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter ?? VaultDocumentFilter.all;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  VaultDocumentView get _view =>
      VaultDocumentView(query: _query, typeFilter: _filter);

  @override
  Widget build(BuildContext context) {
    final documents = ref.watch(vaultDocumentsProvider);
    return documents.when(
      loading: () => SecondaryPageScaffold(
        header: const SecondaryPageHeader(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => SecondaryPageScaffold(
        header: const SecondaryPageHeader(),
        body: EmptyState(
          icon: Icons.error_outline,
          title: 'Could not open the documents',
          message: 'Your documents are still safe. Try again.',
          action: FilledButton(
            onPressed: () => ref.invalidate(vaultDocumentsProvider),
            child: const Text('Try again'),
          ),
        ),
      ),
      data: (state) => _buildLoaded(context, state),
    );
  }

  Widget _buildLoaded(BuildContext context, VaultDocumentsState state) {
    final resolved = state.resolve(_view);
    final allSelected =
        resolved.isNotEmpty && resolved.every((e) => _selected.contains(e.id));

    return SecondaryPageScaffold(
      header: _header(state, resolved, allSelected),
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                Expanded(
                  // D-120: one region wraps whichever body is showing, so the
                  // drag survives the landing→selection swap that a long-press
                  // triggers, and every list gets auto-scroll from one place.
                  child: DragSelectRegion(
                    controller: _scrollController,
                    onBegin: _beginDrag,
                    onPaint: _paintDrag,
                    child: _selecting
                        ? _documentList(resolved)
                        : _searching
                        ? _searchResults(_searchList(state))
                        : _collectionMode
                        ? _collectionBody(state, resolved)
                        : _landing(state, resolved),
                  ),
                ),
                if (_selecting) _selectionBar(state, resolved),
                if (_importing) _importBanner(),
              ],
            ),
          ),
          if (!_selecting && !_searching)
            const Positioned.fill(child: SecretHomeButton()),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  /// The top row: the documents header, or the shared search bar when a search
  /// is open (and no selection has taken the row over).
  Widget _header(
    VaultDocumentsState state,
    List<VaultDocument> resolved,
    bool allSelected,
  ) {
    if (!_selecting && _searching) {
      return VaultSearchHeader(
        fieldKey: VaultDocumentsScreen.searchFieldKey,
        controller: _searchController,
        query: _query,
        hintText: 'Search documents',
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
      onMore: () => _showMoreSheet(state),
    );
  }

  // ---------------------------------------------------------------------------
  // Bodies
  // ---------------------------------------------------------------------------

  /// The documents a search looks through.
  ///
  /// **All types on the landing page, the page's own selection in a collection.**
  /// The landing page carries no type filter, so a search there reaches every
  /// document. A collection page *is* its selection's page — the All-documents
  /// page searches within its chosen chip, a single-family page within its
  /// family — so a search there stays inside it.
  List<VaultDocument> _searchList(VaultDocumentsState state) => state.resolve(
    VaultDocumentView(
      query: _query,
      typeFilter: _collectionMode ? _filter : VaultDocumentFilter.all,
    ),
  );

  /// The results of an open search: a prompt before anything is typed, an
  /// honest empty state when nothing matches, and the matching rows otherwise.
  ///
  /// **The landing sections do not appear here.** Search replaces the
  /// filter chips, the Browse-by-type card, the collection row, and Recent
  /// documents rather than sitting under them, so the field has the screen and
  /// a result is not one more row buried in a page of other controls.
  Widget _searchResults(List<VaultDocument> results) {
    if (_query.trim().isEmpty) {
      return const EmptyState(
        icon: Icons.search,
        title: 'Search your documents',
        message: 'Type to search by file name',
      );
    }
    if (results.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'No documents found',
        message: 'No documents match the current search or filter',
      );
    }
    return ListView.builder(
      key: VaultDocumentsScreen.listKey,
      controller: _scrollController,
      padding: _listPadding,
      itemCount: results.length,
      itemBuilder: (context, index) {
        final document = results[index];
        return DragSelectItem(
          id: document.id,
          child: VaultDocumentRow(
            key: Key('vault-document-${document.id}'),
            document: document,
            onTap: () => _openViewer(document),
            onMenu: () => _showRowSheet(document),
          ),
        );
      },
    );
  }

  Widget _landing(VaultDocumentsState state, List<VaultDocument> resolved) {
    return ListView(
      key: const Key('vault-documents-landing'),
      controller: _scrollController,
      padding: _listPadding,
      children: [
        const SectionHeader('Browse by type'),
        VaultDocumentBrowseCard(
          countOf: state.countOf,
          onSelected: _openCollection,
        ),
        const SizedBox(height: AppSpacing.xl),
        VaultDocumentCollectionRow(
          count: state.visible.length,
          totalBytes: state.totalBytes,
          onTap: () => _openCollection(VaultDocumentFilter.all),
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader('Recent documents', trailing: _addBadge()),
        if (resolved.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
              vertical: AppSpacing.xl,
            ),
            child: Text(
              state.visible.isEmpty
                  ? 'No documents yet. Tap ADD to import.'
                  : 'No documents match the current search or filter.',
              textAlign: TextAlign.center,
              style: context.type.rowSubtitle,
            ),
          )
        else
          for (final document in resolved.take(5))
            DragSelectItem(
              id: document.id,
              child: VaultDocumentRow(
                key: Key('vault-document-${document.id}'),
                document: document,
                onTap: () => _openViewer(document),
                onMenu: () => _showRowSheet(document),
              ),
            ),
      ],
    );
  }

  /// Whether this collection page carries the type filter chips.
  ///
  /// Only the All-documents page does: a single-family page already shows one
  /// family, so a chip row there would only ever hide rows the user came to see.
  bool get _showsTypeChips => widget.initialFilter == VaultDocumentFilter.all;

  Widget _collectionBody(
    VaultDocumentsState state,
    List<VaultDocument> resolved,
  ) {
    final list = _collectionList(state, resolved);
    if (!_showsTypeChips) return list;
    return Column(
      children: [
        // The chips sit directly under the header here, so they need the gap the
        // landing page used to give them before this bar moved onto this page.
        const SizedBox(height: AppSpacing.lg),
        VaultDocumentFilterBar(
          selected: _filter,
          countOf: state.countOf,
          onSelected: (filter) => setState(() => _filter = filter),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(child: list),
      ],
    );
  }

  Widget _collectionList(
    VaultDocumentsState state,
    List<VaultDocument> resolved,
  ) {
    if (resolved.isEmpty) {
      final query = _query.trim();
      return ListView(
        key: VaultDocumentsScreen.listKey,
        controller: _scrollController,
        padding: _listPadding,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
              vertical: AppSpacing.xl * 2,
            ),
            child: Text(
              query.isEmpty
                  ? (_filter == VaultDocumentFilter.all
                        ? 'No documents in this vault yet.'
                        : 'No ${_filter.label} documents in this vault.')
                  : 'No documents match the current search or filter.',
              textAlign: TextAlign.center,
              style: context.type.rowSubtitle,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            child: Center(
              child: FilledButton.icon(
                key: VaultDocumentsScreen.addButtonKey,
                onPressed: _pickAndImport,
                icon: const Icon(Icons.add),
                label: const Text('Add Documents'),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      key: VaultDocumentsScreen.listKey,
      controller: _scrollController,
      padding: _listPadding,
      itemCount: resolved.length,
      itemBuilder: (context, index) {
        final document = resolved[index];
        final selected = _selected.contains(document.id);
        return DragSelectItem(
          id: document.id,
          child: VaultDocumentRow(
            key: Key('vault-document-${document.id}'),
            document: document,
            selected: selected,
            selecting: _selecting,
            onTap: () {
              if (_selecting) {
                _toggleSelect(document);
              } else {
                _openViewer(document);
              }
            },
            onMenu: () => _showRowSheet(document),
          ),
        );
      },
    );
  }

  Widget _documentList(List<VaultDocument> resolved) {
    if (resolved.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'Nothing to select',
        message: 'No documents match the current search or filter.',
      );
    }
    return ListView.builder(
      key: VaultDocumentsScreen.listKey,
      controller: _scrollController,
      padding: _listPadding,
      itemCount: resolved.length,
      itemBuilder: (context, index) {
        final document = resolved[index];
        return DragSelectItem(
          id: document.id,
          child: VaultDocumentRow(
            key: Key('vault-document-${document.id}'),
            document: document,
            selected: _selected.contains(document.id),
            selecting: true,
            onTap: () => _toggleSelect(document),
          ),
        );
      },
    );
  }

  EdgeInsets get _listPadding => const EdgeInsets.only(
    top: AppSpacing.sm,
    bottom:
        AppSizes.secretHomeButton +
        AppSecretSpacing.homeButtonInset +
        AppSpacing.md,
  );

  Widget _addBadge() {
    final colors = context.appColors;
    return Semantics(
      button: true,
      label: 'Add documents',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: VaultDocumentsScreen.addButtonKey,
          onTap: _pickAndImport,
          borderRadius: BorderRadius.circular(AppRadius.iconButton),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.iconButton),
              border: null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 16, color: colors.textPrimary),
                const SizedBox(width: 4),
                Text(
                  'ADD',
                  style: context.type.caption.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
            child: Text(_importLabel ?? 'Importing…', style: context.type.rowSubtitle),
          ),
        ],
      ),
    );
  }

  Widget _selectionBar(
    VaultDocumentsState state,
    List<VaultDocument> resolved,
  ) {
    // [icon] is a widget so the bar can carry the painted [AppTrashIcon] (the
    // History screen's delete glyph, D-119) as well as Material [Icon]s — the
    // same shape the gallery's bottom bar already uses, so the two selection
    // bars read as one component.
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
        key: VaultDocumentsScreen.selectionBarKey,
        decoration: BoxDecoration(
          color: context.appColors.surface,
          border: Border(top: BorderSide(color: context.appColors.divider)),
        ),
        child: Row(
          children: [
            action(const Icon(Icons.ios_share), 'Share', _shareSelected),
            // D-119's glyph, not Material's `delete_outline`: this bar deletes
            // with the same trash the History screen paints, so the app keeps
            // one delete glyph across every selection bar.
            action(const AppTrashIcon(), 'Delete', _deleteSelectedDialog),
            action(
              const Icon(Icons.more_vert),
              'More',
              () => _showMoreSheet(state),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Selection
  // ---------------------------------------------------------------------------

  void _toggleSelect(VaultDocument document) {
    setState(() {
      if (_selected.contains(document.id)) {
        _selected.remove(document.id);
      } else {
        _selected.add(document.id);
      }
    });
  }

  void _selectAll(List<VaultDocument> list) {
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
  /// The document under the press is entered, and the drag's direction comes
  /// back as the return value: an unselected row means the drag adds, an
  /// already chosen one means it removes.
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

  /// Applies the drag's mode to one document it passed over (D-120).
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

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _openCollection(VaultDocumentFilter filter) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VaultDocumentsScreen(
          initialFilter: filter,
          title: filter == VaultDocumentFilter.all
              ? 'All documents'
              : filter.label,
        ),
      ),
    );
  }

  void _openViewer(VaultDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VaultDocumentViewerScreen(document: document),
      ),
    );
  }

  void _closeSearch() {
    setState(() {
      _searching = false;
      _query = '';
      _searchController.clear();
    });
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  Future<void> _pickAndImport() async {
    if (_importing) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _importing = true;
      _importLabel = 'Importing…';
    });
    try {
      final result = await ref
          .read(vaultDocumentsProvider.notifier)
          .importDocuments();
      if (!mounted) return;
      setState(() {
        _importing = false;
        _importLabel = null;
      });
      if (result.cancelled) return;
      _reportImport(result, messenger);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _importLabel = null;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the file picker')),
      );
    }
  }

  void _reportImport(VaultImportResult result, ScaffoldMessengerState messenger) {
    final parts = <String>[];
    if (result.imported > 0) parts.add('${result.imported} imported');
    if (result.duplicates.isNotEmpty) {
      parts.add('${result.duplicates.length} already in vault');
    }
    if (result.failed > 0) parts.add('${result.failed} failed');
    final duplicates = result.duplicates;
    messenger.showSnackBar(
      SnackBar(
        content: Text(parts.isEmpty ? 'Nothing imported' : parts.join(' · ')),
        action: duplicates.isEmpty
            ? null
            : SnackBarAction(
                label: 'Import anyway',
                onPressed: () => _importDuplicates(duplicates),
              ),
      ),
    );
  }

  Future<void> _importDuplicates(List<PickedDocument> duplicates) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _importing = true;
      _importLabel = 'Importing…';
    });
    try {
      final result = await ref
          .read(vaultDocumentsProvider.notifier)
          .importDocuments(selection: duplicates, allowDuplicates: true);
      if (!mounted) return;
      setState(() {
        _importing = false;
        _importLabel = null;
      });
      messenger.showSnackBar(
        SnackBar(content: Text('${result.imported} imported')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _importLabel = null;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not import these documents')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Row actions
  // ---------------------------------------------------------------------------

  Future<void> _showRowSheet(VaultDocument document) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open'),
              onTap: () => Navigator.of(context).pop('open'),
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename'),
              onTap: () => Navigator.of(context).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Share'),
              onTap: () => Navigator.of(context).pop('share'),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('File info'),
              onTap: () => Navigator.of(context).pop('info'),
            ),
            ListTile(
              // D-119: the History screen's trash rather than Material's
              // `delete_outline`, so the row sheet deletes with the same glyph
              // as the selection bar above it.
              leading: const AppTrashIcon(),
              title: const Text('Delete'),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'open':
        _openViewer(document);
      case 'rename':
        await _rename(document);
      case 'share':
        await _shareDocuments(<VaultDocument>[document]);
      case 'info':
        await showVaultDocumentInfo(context, document);
      case 'delete':
        await _deleteWithConfirm(<String>{document.id});
    }
  }

  Future<void> _rename(VaultDocument document) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => VaultDocumentNameDialog(initialName: document.fileName),
    );
    if (name == null || !mounted) return;
    try {
      await ref
          .read(vaultDocumentsProvider.notifier)
          .renameDocument(document.id, name);
    } on VaultDocumentNameException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not rename this document. Please try again.'),
        ),
      );
    }
  }

  Future<void> _deleteSelectedDialog() async {
    await _deleteWithConfirm(Set<String>.from(_selected));
  }

  Future<void> _deleteWithConfirm(Set<String> ids) async {
    if (ids.isEmpty) return;
    final count = ids.length;
    final confirmed = await AppConfirmationDialog.show(
      context,
      title: count == 1 ? 'Move document to recycle bin?' : 'Delete $count documents?',
      message: 'They move to the recycle bin for 30 days inside this private '
          'vault.',
      confirmLabel: 'Move to recycle bin',
    );
    if (!confirmed || !mounted) return;
    await ref.read(vaultDocumentsProvider.notifier).moveToTrash(ids);
    if (!mounted) return;
    setState(_selected.clear);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Moved to recycle bin')),
    );
  }

  // ---------------------------------------------------------------------------
  // Share
  // ---------------------------------------------------------------------------

  Future<void> _shareSelected() async {
    final ids = Set<String>.from(_selected);
    final state = ref.read(vaultDocumentsProvider).valueOrNull;
    if (state == null || ids.isEmpty) return;
    final documents = state.visible.where((e) => ids.contains(e.id)).toList();
    await _shareDocuments(documents, clearSelection: true);
  }

  Future<void> _shareDocuments(
    List<VaultDocument> documents, {
    bool clearSelection = false,
  }) async {
    if (documents.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final shared = await ref
          .read(vaultDocumentsProvider.notifier)
          .shareDocuments(documents);
      if (!mounted) return;
      if (!shared) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Sharing is not available in this browser preview'),
          ),
        );
        return;
      }
      if (clearSelection) setState(_selected.clear);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not share these documents')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Overflow
  // ---------------------------------------------------------------------------

  Future<void> _showMoreSheet(VaultDocumentsState state) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.checklist),
              title: const Text('Select documents'),
              onTap: () => Navigator.of(context).pop('select'),
            ),
            ListTile(
              leading: const Icon(Icons.sort),
              title: Text('Sort: ${state.sort.label}'),
              onTap: () => Navigator.of(context).pop('sort'),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add documents'),
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
        final list = state.resolve(_view);
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
                '${state.visible.length} documents · '
                '${formatBytes(state.totalBytes)} encrypted in this vault',
              ),
            ),
          );
        }
    }
  }

  Future<void> _sortSheet() async {
    final picked = await showModalBottomSheet<VaultDocumentSort>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final sort in VaultDocumentSort.values)
              ListTile(
                title: Text(sort.label),
                onTap: () => Navigator.of(context).pop(sort),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await ref.read(vaultDocumentsProvider.notifier).setSort(picked);
  }
}
