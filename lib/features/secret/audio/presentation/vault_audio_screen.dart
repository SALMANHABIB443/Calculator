import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_palette.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/widgets/core_widgets.dart';
import '../../data/device_storage_repository.dart';
import '../../presentation/secret_home_button.dart';
import '../../presentation/vault_search_header.dart';
import '../data/vault_audio_picker.dart';
import '../domain/vault_audio.dart';
import '../player/vault_audio_playback.dart';
import '../player/vault_audio_player_screen.dart';
import 'vault_audio_controller.dart';
import 'vault_audio_state.dart';
import 'vault_audio_widgets.dart';

/// The private audio vault: Music / Recordings / Podcasts (FEAT-SEC-010).
///
/// One screen in two modes, mirroring how the documents vault handles a type
/// page: landing (no [initialFilter]) with Browse-by-type card + All-audios
/// row + five most recent, and collection ([initialFilter] set) pushed as its
/// own route so Back returns to whatever opened it. Only the All-audios page
/// carries the filter chips. Search text and chips are local state, never in
/// a provider, so a data mutation cannot clear what the user typed.
class VaultAudioScreen extends ConsumerStatefulWidget {
  const VaultAudioScreen({super.key, this.initialFilter, this.title});

  final VaultAudioFilter? initialFilter;
  final String? title;

  static const Key searchFieldKey = Key('vault-audios-search');
  static const Key addButtonKey = Key('vault-audios-add');
  static const Key listKey = Key('vault-audios-list');
  static const Key selectionBarKey = Key('vault-audios-selection-bar');

  @override
  ConsumerState<VaultAudioScreen> createState() => _VaultAudioScreenState();
}

class _VaultAudioScreenState extends ConsumerState<VaultAudioScreen> {
  bool get _collectionMode => widget.initialFilter != null;

  late VaultAudioFilter _filter;
  String _query = '';
  bool _searching = false;
  final Set<String> _selected = <String>{};
  bool _importing = false;
  String? _importLabel;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter ?? VaultAudioFilter.all;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  VaultAudioView get _view =>
      VaultAudioView(query: _query, typeFilter: _filter);

  @override
  Widget build(BuildContext context) {
    final audios = ref.watch(vaultAudiosProvider);
    return audios.when(
      loading: () => const SecondaryPageScaffold(
        header: SecondaryPageHeader(),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => SecondaryPageScaffold(
        header: const SecondaryPageHeader(),
        body: EmptyState(
          icon: Icons.error_outline,
          title: 'Could not open the audios',
          message: 'Your audios are still safe. Try again.',
          action: FilledButton(
            onPressed: () => ref.invalidate(vaultAudiosProvider),
            child: const Text('Try again'),
          ),
        ),
      ),
      data: (state) => _buildLoaded(context, state),
    );
  }

  Widget _buildLoaded(BuildContext context, VaultAudiosState state) {
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
                  child: _selecting
                      ? _selectionList(resolved)
                      : _searching
                      ? _searchResults(_searchList(state))
                      : _collectionMode
                      ? _collectionBody(state, resolved)
                      : _landing(state, resolved),
                ),
                if (_selecting) _selectionBar(state),
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

  Widget _header(
    VaultAudiosState state,
    List<VaultAudio> resolved,
    bool allSelected,
  ) {
    if (!_selecting && _searching) {
      return VaultSearchHeader(
        fieldKey: VaultAudioScreen.searchFieldKey,
        controller: _searchController,
        query: _query,
        hintText: 'Search audios',
        onChanged: (value) => setState(() => _query = value),
        onClose: _closeSearch,
      );
    }
    return VaultAudioHeader(
      selecting: _selecting,
      selectedCount: _selected.length,
      allSelected: allSelected,
      onCancel: () => setState(_selected.clear),
      onSelectAll: () => _selectAll(resolved),
      onSearch: () => setState(() => _searching = true),
      onMore: () => _showMoreSheet(state),
    );
  }

  List<VaultAudio> _searchList(VaultAudiosState state) => state.resolve(
    VaultAudioView(
      query: _query,
      typeFilter: _collectionMode ? _filter : VaultAudioFilter.all,
    ),
  );

  Widget _searchResults(List<VaultAudio> results) {
    if (_query.trim().isEmpty) {
      return const EmptyState(
        icon: Icons.search,
        title: 'Search your audios',
        message: 'Type to search by file name',
      );
    }
    if (results.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'No audios found',
        message: 'No audios match the current search or filter',
      );
    }
    return ListView.builder(
      key: VaultAudioScreen.listKey,
      controller: _scrollController,
      padding: _listPadding,
      itemCount: results.length,
      itemBuilder: (context, index) {
        final audio = results[index];
        return VaultAudioRow(
          key: Key('vault-audio-${audio.id}'),
          audio: audio,
          onTap: () => _openPlayer(results, index),
          onMenu: () => _showRowSheet(audio),
        );
      },
    );
  }

  Widget _landing(VaultAudiosState state, List<VaultAudio> resolved) {
    return ListView(
      key: const Key('vault-audios-landing'),
      controller: _scrollController,
      padding: _listPadding,
      children: [
        const SectionHeader('Browse by type'),
        VaultAudioBrowseCard(
          countOf: state.countOf,
          onSelected: _openCollection,
        ),
        const SizedBox(height: AppSpacing.xl),
        VaultAudioCollectionRow(
          count: state.visible.length,
          totalBytes: state.totalBytes,
          onTap: () => _openCollection(VaultAudioFilter.all),
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader('Recent audios', trailing: _addBadge()),
        if (resolved.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
              vertical: AppSpacing.xl,
            ),
            child: Text(
              state.visible.isEmpty
                  ? 'No audios yet. Tap ADD to import.'
                  : 'No audios match the current search or filter.',
              textAlign: TextAlign.center,
              style: context.type.rowSubtitle,
            ),
          )
        else
          for (final entry in resolved.take(5).toList().asMap().entries)
            VaultAudioRow(
              key: Key('vault-audio-${entry.value.id}'),
              audio: entry.value,
              onTap: () => _openPlayer(resolved, entry.key),
              onMenu: () => _showRowSheet(entry.value),
            ),
      ],
    );
  }

  bool get _showsTypeChips => widget.initialFilter == VaultAudioFilter.all;

  Widget _collectionBody(VaultAudiosState state, List<VaultAudio> resolved) {
    final list = _collectionList(state, resolved);
    if (!_showsTypeChips) return list;
    return Column(
      children: [
        const SizedBox(height: AppSpacing.lg),
        VaultAudioFilterBar(
          selected: _filter,
          countOf: state.countOf,
          onSelected: (filter) => setState(() => _filter = filter),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(child: list),
      ],
    );
  }

  Widget _collectionList(VaultAudiosState state, List<VaultAudio> resolved) {
    if (resolved.isEmpty) {
      final query = _query.trim();
      return ListView(
        key: VaultAudioScreen.listKey,
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
                  ? (_filter == VaultAudioFilter.all
                        ? 'No audios in this vault yet.'
                        : 'No ${_filter.label} audios in this vault.')
                  : 'No audios match the current search or filter.',
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
                key: VaultAudioScreen.addButtonKey,
                onPressed: _pickAndImport,
                icon: const Icon(Icons.add),
                label: const Text('Add Audios'),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      key: VaultAudioScreen.listKey,
      controller: _scrollController,
      padding: _listPadding,
      itemCount: resolved.length,
      itemBuilder: (context, index) {
        final audio = resolved[index];
        final selected = _selected.contains(audio.id);
        return VaultAudioRow(
          key: Key('vault-audio-${audio.id}'),
          audio: audio,
          selected: selected,
          selecting: _selecting,
          onTap: () {
            if (_selecting) {
              _toggleSelect(audio);
            } else {
              _openPlayer(resolved, index);
            }
          },
          onMenu: () => _showRowSheet(audio),
        );
      },
    );
  }

  Widget _selectionList(List<VaultAudio> resolved) {
    if (resolved.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'Nothing to select',
        message: 'No audios match the current search or filter.',
      );
    }
    return ListView.builder(
      key: VaultAudioScreen.listKey,
      controller: _scrollController,
      padding: _listPadding,
      itemCount: resolved.length,
      itemBuilder: (context, index) {
        final audio = resolved[index];
        return VaultAudioRow(
          key: Key('vault-audio-${audio.id}'),
          audio: audio,
          selected: _selected.contains(audio.id),
          selecting: true,
          onTap: () => _toggleSelect(audio),
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
      label: 'Add audios',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: VaultAudioScreen.addButtonKey,
          onTap: _pickAndImport,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 4,
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
            child: Text(
              _importLabel ?? 'Importing…',
              style: context.type.rowSubtitle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectionBar(VaultAudiosState state) {
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
        key: VaultAudioScreen.selectionBarKey,
        decoration: BoxDecoration(
          color: context.appColors.surface,
          border: Border(top: BorderSide(color: context.appColors.divider)),
        ),
        child: Row(
          children: [
            action(const Icon(Icons.play_arrow), 'Play', _playSelected),
            action(
              const Icon(Icons.star_border),
              'Favorite',
              _favoriteSelected,
            ),
            action(const Icon(Icons.ios_share), 'Share', _shareSelected),
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

  void _toggleSelect(VaultAudio audio) {
    setState(() {
      if (_selected.contains(audio.id)) {
        _selected.remove(audio.id);
      } else {
        _selected.add(audio.id);
      }
    });
  }

  void _selectAll(List<VaultAudio> list) {
    setState(() {
      if (list.every((e) => _selected.contains(e.id))) {
        _selected.clear();
      } else {
        _selected.addAll(list.map((e) => e.id));
      }
    });
  }

  void _openCollection(VaultAudioFilter filter) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VaultAudioScreen(
          initialFilter: filter,
          title: filter == VaultAudioFilter.all ? 'All audios' : filter.label,
        ),
      ),
    );
  }

  void _openPlayer(List<VaultAudio> queue, int index) {
    VaultAudioPlayerScreen.open(context, ref, queue, index);
  }

  /// Appends [audios] to the app-wide session queue.
  ///
  /// With nothing playing yet this also starts the first one; otherwise it
  /// grows the queue behind whatever is playing, which survives leaving this
  /// screen.
  Future<void> _addToQueue(List<VaultAudio> audios) async {
    if (audios.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(vaultAudioPlaybackProvider.notifier).addToQueue(audios);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          audios.length == 1
              ? 'Added to queue'
              : '${audios.length} added to queue',
        ),
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

  Future<void> _pickAndImport() async {
    if (_importing) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _importing = true;
      _importLabel = 'Importing…';
    });
    try {
      final result = await ref
          .read(vaultAudiosProvider.notifier)
          .importAudios();
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

  void _reportImport(
    VaultAudioImportResult result,
    ScaffoldMessengerState messenger,
  ) {
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

  Future<void> _importDuplicates(List<PickedAudio> duplicates) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _importing = true;
      _importLabel = 'Importing…';
    });
    try {
      final result = await ref
          .read(vaultAudiosProvider.notifier)
          .importDuplicatesAnyway(duplicates);
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
        const SnackBar(content: Text('Could not import these audios')),
      );
    }
  }

  Future<void> _showRowSheet(VaultAudio audio) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Play'),
              onTap: () => Navigator.of(context).pop('play'),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Add to queue'),
              onTap: () => Navigator.of(context).pop('queue'),
            ),
            ListTile(
              leading: Icon(audio.isFavorite ? Icons.star : Icons.star_border),
              title: Text(
                audio.isFavorite ? 'Remove from favorites' : 'Add to favorites',
              ),
              onTap: () => Navigator.of(context).pop('favorite'),
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename'),
              onTap: () => Navigator.of(context).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Category'),
              subtitle: Text(audio.effectiveType.label),
              onTap: () => Navigator.of(context).pop('category'),
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
      case 'play':
        final queue = [audio];
        _openPlayer(queue, 0);
      case 'queue':
        await _addToQueue(<VaultAudio>[audio]);
      case 'favorite':
        await ref.read(vaultAudiosProvider.notifier).toggleFavorite(audio.id);
      case 'rename':
        await _rename(audio);
      case 'category':
        await _category(audio);
      case 'share':
        await _shareAudios(<VaultAudio>[audio]);
      case 'info':
        if (!mounted) return;
        await showVaultAudioInfo(context, audio);
      case 'delete':
        await _deleteWithConfirm(<String>{audio.id});
    }
  }

  Future<void> _rename(VaultAudio audio) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => VaultAudioNameDialog(initialName: audio.fileName),
    );
    if (name == null || !mounted) return;
    try {
      await ref.read(vaultAudiosProvider.notifier).renameAudio(audio.id, name);
    } on VaultAudioNameException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not rename this audio. Please try again.'),
        ),
      );
    }
  }

  Future<void> _category(VaultAudio audio) async {
    final picked = await chooseVaultAudioCategory(context, audio);
    if (!mounted) return;
    if (picked == null) {
      if (audio.categoryOverride == null) return;
      final confirmed = await AppConfirmationDialog.show(
        context,
        title: 'Reset category?',
        message: '"${audio.fileName}" will be categorised automatically again.',
        confirmLabel: 'Reset',
      );
      if (!confirmed || !mounted) return;
      await ref.read(vaultAudiosProvider.notifier).setCategory(audio.id, null);
      return;
    }
    await ref.read(vaultAudiosProvider.notifier).setCategory(audio.id, picked);
  }

  void _playSelected() {
    final state = ref.read(vaultAudiosProvider).valueOrNull;
    if (state == null) return;
    final list = state.resolve(_view);
    final selected = [
      for (final audio in list)
        if (_selected.contains(audio.id)) audio,
    ];
    if (selected.isEmpty) return;
    setState(_selected.clear);
    _openPlayer(selected, 0);
  }

  Future<void> _favoriteSelected() async {
    final ids = Set<String>.from(_selected);
    final notifier = ref.read(vaultAudiosProvider.notifier);
    for (final id in ids) {
      try {
        await notifier.toggleFavorite(id);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(_selected.clear);
  }

  Future<void> _shareSelected() async {
    final ids = Set<String>.from(_selected);
    final state = ref.read(vaultAudiosProvider).valueOrNull;
    if (state == null || ids.isEmpty) return;
    final audios = state.visible.where((e) => ids.contains(e.id)).toList();
    await _shareAudios(audios, clearSelection: true);
  }

  Future<void> _deleteSelectedDialog() async {
    await _deleteWithConfirm(Set<String>.from(_selected));
  }

  Future<void> _deleteWithConfirm(Set<String> ids) async {
    if (ids.isEmpty) return;
    final count = ids.length;
    final confirmed = await AppConfirmationDialog.show(
      context,
      title: count == 1
          ? 'Move audio to recycle bin?'
          : 'Delete $count audios?',
      message:
          'They move to the recycle bin for 30 days inside this private '
          'vault.',
      confirmLabel: 'Move to recycle bin',
    );
    if (!confirmed || !mounted) return;
    await ref.read(vaultAudiosProvider.notifier).moveToTrash(ids);
    if (!mounted) return;
    setState(_selected.clear);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Moved to recycle bin')));
  }

  Future<void> _shareAudios(
    List<VaultAudio> audios, {
    bool clearSelection = false,
  }) async {
    if (audios.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final shared = await ref
          .read(vaultAudiosProvider.notifier)
          .shareAudios(audios);
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
        const SnackBar(content: Text('Could not share these audios')),
      );
    }
  }

  Future<void> _showMoreSheet(VaultAudiosState state) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.checklist),
              title: const Text('Select audios'),
              onTap: () => Navigator.of(context).pop('select'),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Add selected to queue'),
              onTap: () => Navigator.of(context).pop('queue'),
            ),
            ListTile(
              leading: const Icon(Icons.sort),
              title: Text('Sort: ${state.sort.label}'),
              onTap: () => Navigator.of(context).pop('sort'),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add audios'),
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
      case 'queue':
        final ids = Set<String>.from(_selected);
        final audios = state.visible.where((e) => ids.contains(e.id)).toList();
        await _addToQueue(audios);
        if (mounted) setState(_selected.clear);
      case 'sort':
        await _sortSheet();
      case 'add':
        await _pickAndImport();
      case 'storage':
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${state.visible.length} audios · '
                '${formatBytes(state.totalBytes)} encrypted in this vault',
              ),
            ),
          );
        }
    }
  }

  Future<void> _sortSheet() async {
    final picked = await showModalBottomSheet<VaultAudioSort>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final sort in VaultAudioSort.values)
              ListTile(
                title: Text(sort.label),
                onTap: () => Navigator.of(context).pop(sort),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await ref.read(vaultAudiosProvider.notifier).setSort(picked);
  }
}
