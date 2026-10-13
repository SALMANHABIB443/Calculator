import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_palette.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/widgets/core_widgets.dart';
import '../domain/vault_document.dart';
import 'vault_document_widgets.dart';
import 'vault_documents_controller.dart';
import 'vault_documents_state.dart';

/// The Recycle bin: documents deleted from the vault, kept for 30 days
/// (FEAT-SEC-009).
///
/// The `recycle-bin` place's page. It lists only *documents* — the image
/// gallery keeps its own Trash tab — because this is the page the Vault screen
/// opens, and the Vault screen's deletion story is the documents one. Everything
/// here is recoverable until the 30-day purge; nothing on this page deletes
/// without a confirmation.
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

  bool get _selecting => _selected.isNotEmpty;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Trashed documents, most recently deleted first, matching the search text.
  List<VaultDocument> _resolved(VaultDocumentsState state) {
    final needle = _query.trim().toLowerCase();
    final list = <VaultDocument>[
      for (final document in state.trash)
        if (needle.isEmpty || document.fileName.toLowerCase().contains(needle))
          document,
    ];
    list.sort((a, b) {
      final aAt = a.trashedAt ?? a.dateModified;
      final bAt = b.trashedAt ?? b.dateModified;
      return bAt.compareTo(aAt);
    });
    return list;
  }

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
          title: 'Could not open the recycle bin',
          message: 'Try again.',
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
    final resolved = _resolved(state);
    final allSelected =
        resolved.isNotEmpty && resolved.every((e) => _selected.contains(e.id));

    return SecondaryPageScaffold(
      header: VaultDocumentsHeader(
        selecting: _selecting,
        selectedCount: _selected.length,
        allSelected: allSelected,
        onCancel: () => setState(_selected.clear),
        onSelectAll: () => _selectAll(resolved),
        onSearch: _toggleSearch,
        onMore: _showMoreSheet,
      ),
      body: Column(
        children: [
          if (_searching) _searchField(),
          Expanded(child: _body(state, resolved)),
          if (_selecting) _selectionBar(state),
        ],
      ),
    );
  }

  Widget _body(VaultDocumentsState state, List<VaultDocument> resolved) {
    if (state.trash.isEmpty) {
      return EmptyState(
        iconWidget: AppTrashIcon(color: context.appColors.textSecondary),
        title: 'Recycle bin is empty',
        message: 'Deleted documents rest here for 30 days.',
      );
    }
    if (resolved.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'No documents found',
        message: 'Try a different name.',
      );
    }
    return ListView.builder(
      key: VaultDocumentsTrashScreen.listKey,
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.xl,
      ),
      itemCount: resolved.length,
      itemBuilder: (context, index) {
        final document = resolved[index];
        return VaultDocumentRow(
          key: Key('vault-document-trash-${document.id}'),
          document: document,
          selected: _selected.contains(document.id),
          selecting: _selecting,
          onTap: () {
            if (_selecting) {
              _toggleSelect(document);
            } else {
              showVaultDocumentInfo(context, document);
            }
          },
          onLongPress: () => setState(() => _selected.add(document.id)),
          onMenu: () => _showRowSheet(document),
        );
      },
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
        key: VaultDocumentsTrashScreen.searchFieldKey,
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search recycle bin',
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

  Widget _selectionBar(VaultDocumentsState state) {
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
        key: VaultDocumentsTrashScreen.selectionBarKey,
        decoration: BoxDecoration(
          color: context.appColors.surface,
          border: Border(top: BorderSide(color: context.appColors.divider)),
        ),
        child: Row(
          children: [
            action(Icons.restore, 'Restore', _restoreSelected),
            action(Icons.delete_forever, 'Delete forever', _deleteForeverSelected),
          ],
        ),
      ),
    );
  }

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

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _query = '';
        _searchController.clear();
      }
    });
  }

  Future<void> _restoreSelected() async {
    if (_selected.isEmpty) return;
    final ids = Set<String>.from(_selected);
    await ref.read(vaultDocumentsProvider.notifier).restoreFromTrash(ids);
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
      message: 'This cannot be undone. The encrypted copy is removed.',
      confirmLabel: 'Delete forever',
    );
    if (!confirmed || !mounted) return;
    await ref.read(vaultDocumentsProvider.notifier).deletePermanently(ids);
    if (!mounted) return;
    setState(_selected.clear);
  }

  Future<void> _showRowSheet(VaultDocument document) async {
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
              title: const Text('File info'),
              onTap: () => Navigator.of(context).pop('info'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever),
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
        await ref
            .read(vaultDocumentsProvider.notifier)
            .restoreFromTrash(<String>{document.id});
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restored')),
        );
      case 'info':
        await showVaultDocumentInfo(context, document);
      case 'delete':
        await _deleteForever(<String>{document.id});
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
              title: const Text('Select documents'),
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
    switch (action) {
      case 'select':
        final resolved = _resolved(ref.read(vaultDocumentsProvider).requireValue);
        if (resolved.isNotEmpty) {
          setState(() => _selected.add(resolved.first.id));
        }
      case 'empty':
        final state = ref.read(vaultDocumentsProvider).valueOrNull;
        if (state == null) return;
        await _deleteForever(state.trash.map((e) => e.id).toSet());
    }
  }
}
