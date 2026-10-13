import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_palette.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/widgets/core_widgets.dart';
import '../../data/device_storage_repository.dart';
import '../../presentation/secret_home_button.dart';
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
/// * **Landing** (no [initialFilter]) — the filter chips, the five most recent
///   documents, a Browse-by-type card, and the All-documents collection row,
///   with the floating Home button the rest of the secret area carries.
/// * **Collection** ([initialFilter] set) — the same rows for one family (or
///   all), pushed from a Browse row or the collection row. A pushed route rather
///   than an in-place swap, so Back returns to whatever opened it.
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

  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter ?? VaultDocumentFilter.all;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  VaultDocumentView get _view =>
      VaultDocumentView(query: _query, typeFilter: _filter);

  @override
  Widget build(BuildContext context) {
    final documents = ref.watch(vaultDocumentsProvider);
    return documents.when(
      loading: () => SecondaryPageScaffold(
        header: const SecondaryPageHeader(title: 'Documents'),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => SecondaryPageScaffold(
        header: const SecondaryPageHeader(title: 'Documents'),
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
    final title = _selecting
        ? '${_selected.length} selected'
        : (widget.title ?? 'Documents');
    final allSelected =
        resolved.isNotEmpty && resolved.every((e) => _selected.contains(e.id));

    return SecondaryPageScaffold(
      header: VaultDocumentsHeader(
        selecting: _selecting,
        selectedCount: _selected.length,
        title: title,
        allSelected: allSelected,
        onCancel: () => setState(_selected.clear),
        onSelectAll: () => _selectAll(resolved),
        onSearch: _toggleSearch,
        onMore: () => _showMoreSheet(state),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                if (_searching) _searchField(),
                Expanded(
                  child: _selecting
                      ? _documentList(resolved)
                      : _collectionMode
                      ? _collectionBody(state, resolved)
                      : _landing(state, resolved),
                ),
                if (_selecting) _selectionBar(state, resolved),
                if (_importing) _importBanner(),
              ],
            ),
          ),
          if (!_selecting)
            const Positioned.fill(child: SecretHomeButton()),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bodies
  // ---------------------------------------------------------------------------

  Widget _landing(VaultDocumentsState state, List<VaultDocument> resolved) {
    return ListView(
      key: const Key('vault-documents-landing'),
      padding: _listPadding,
      children: [
        VaultDocumentFilterBar(
          selected: _filter,
          countOf: state.countOf,
          onSelected: (filter) => setState(() => _filter = filter),
        ),
        const SizedBox(height: AppSpacing.lg),
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
            VaultDocumentRow(
              key: Key('vault-document-${document.id}'),
              document: document,
              onTap: () => _openViewer(document),
              onLongPress: () => setState(() => _selected.add(document.id)),
              onMenu: () => _showRowSheet(document),
            ),
      ],
    );
  }

  Widget _collectionBody(
    VaultDocumentsState state,
    List<VaultDocument> resolved,
  ) {
    if (resolved.isEmpty) {
      final query = _query.trim();
      return ListView(
        key: VaultDocumentsScreen.listKey,
        padding: _listPadding,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
              vertical: AppSpacing.xl * 2,
            ),
            child: Text(
              query.isEmpty
                  ? 'No ${_filter.label} documents in this vault.'
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
      padding: _listPadding,
      itemCount: resolved.length,
      itemBuilder: (context, index) {
        final document = resolved[index];
        final selected = _selected.contains(document.id);
        return VaultDocumentRow(
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
          onLongPress: () => setState(() => _selected.add(document.id)),
          onMenu: () => _showRowSheet(document),
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
      padding: _listPadding,
      itemCount: resolved.length,
      itemBuilder: (context, index) {
        final document = resolved[index];
        return VaultDocumentRow(
          key: Key('vault-document-${document.id}'),
          document: document,
          selected: _selected.contains(document.id),
          selecting: true,
          onTap: () => _toggleSelect(document),
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



  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.sm,
        AppSpacing.screenHorizontal,
        AppSpacing.sm,
      ),
      child: TextField(
        key: VaultDocumentsScreen.searchFieldKey,
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search documents',
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
              border: Border.all(color: colors.cardBorder),
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
    Widget action(IconData icon, String label, VoidCallback onTap) {
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
                Icon(
                  icon,
                  size: AppSizes.rowIcon,
                  color: context.appColors.textPrimary,
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
            action(Icons.ios_share, 'Share', _shareSelected),
            action(Icons.delete_outline, 'Delete', _deleteSelectedDialog),
            action(
              Icons.more_vert,
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

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _query = '';
        _searchController.clear();
      }
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
              leading: const Icon(Icons.delete_outline),
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
