import 'package:flutter/material.dart';

import '../../../../core/design/app_palette.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/widgets/core_widgets.dart';
import '../../data/device_storage_repository.dart';
import '../domain/vault_audio.dart';

/// Content-type accents for the vault's audio glyphs.
///
/// **Not theme tokens, and deliberately so.** [AppColors] is the app's palette
/// and every value in it means something about the *app*. These three mean
/// something about the *content*: the colour a user already associates with
/// music, a voice recording, and a podcast. Stated here so a change to the
/// app's own palette cannot re-colour an audio type by accident.
abstract final class VaultAudioAccents {
  static const Color music = Color(0xFF4C8DF6);
  static const Color recording = Color(0xFFE5534B);
  static const Color podcast = Color(0xFF9B6BF3);
}

/// The glyph that stands for [type] everywhere an audio is listed.
IconData audioTypeIcon(VaultAudioType type) => switch (type) {
  VaultAudioType.music => Icons.music_note,
  VaultAudioType.recording => Icons.mic_outlined,
  VaultAudioType.podcast => Icons.podcasts_outlined,
  VaultAudioType.other => Icons.audio_file_outlined,
};

/// The accent for [type], falling back to the theme's secondary text for an
/// audio the app has no family for — which is the honest colour for "unknown".
Color audioAccent(BuildContext context, VaultAudioType type) => switch (type) {
  VaultAudioType.music => VaultAudioAccents.music,
  VaultAudioType.recording => VaultAudioAccents.recording,
  VaultAudioType.podcast => VaultAudioAccents.podcast,
  VaultAudioType.other => context.appColors.textSecondary,
};

const List<String> _monthNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `12 Oct 2026` — short, unambiguous, and never locale-shifting per row.
String formatAudioDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

/// `3:12` — the player-style clock a duration is read as.
///
/// Accepts a [Duration] or raw milliseconds, because rows carry the stored
/// `durationMs` int while the player hands over live `Duration`s. `null`
/// (unmeasured yet) reads as `--:--`, never `0:00`, so an unknown length is
/// not mistaken for an empty file.
String formatAudioDuration(Object? duration) {
  final millis = switch (duration) {
    Duration d => d.inMilliseconds,
    int ms => ms,
    _ => null,
  };
  if (millis == null || millis < 0) return '--:--';
  final totalSeconds = millis ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// `MP3 · 2.4 MB · 12 Oct 2026 · 3:12` — the one metadata line every row shows.
///
/// The duration trails only when it has been measured; an unmeasured audio
/// shows the same line a document row would.
String audioMetaLine(VaultAudio audio) {
  final base =
      '${audio.extensionLabel} · ${formatBytes(audio.fileSize)} · '
      '${formatAudioDate(audio.dateModified)}';
  final durationMs = audio.durationMs;
  if (durationMs == null) return base;
  return '$base · ${formatAudioDuration(durationMs)}';
}

/// An audio's type glyph in a soft rounded tile, the leading element of a row.
class VaultAudioTypeTile extends StatelessWidget {
  const VaultAudioTypeTile({
    required this.type,
    this.dimension = 44,
    super.key,
  });

  final VaultAudioType type;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        color: context.appColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Icon(
        audioTypeIcon(type),
        size: dimension * 0.5,
        color: audioAccent(context, type),
      ),
    );
  }
}

/// The Audio header: back + search + overflow, or the selection variant.
class VaultAudioHeader extends StatelessWidget {
  const VaultAudioHeader({
    required this.selecting,
    required this.selectedCount,
    required this.allSelected,
    required this.onCancel,
    required this.onSelectAll,
    required this.onSearch,
    required this.onMore,
    super.key,
  });

  final bool selecting;
  final int selectedCount;
  final bool allSelected;
  final VoidCallback onCancel;
  final VoidCallback onSelectAll;
  final VoidCallback onSearch;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.screenHorizontal,
        right: AppSpacing.screenHorizontal,
        top: AppSpacing.headerTopGap,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.headerHeight),
        child: selecting
            ? Row(
                children: [
                  AppIconButton(
                    icon: Icons.close,
                    tooltip: 'Cancel selection',
                    onPressed: onCancel,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      '$selectedCount selected',
                      style: context.type.selectionCount,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  TextButton(
                    onPressed: onSelectAll,
                    child: Text(allSelected ? 'None' : 'All'),
                  ),
                ],
              )
            : Row(
                children: [
                  AppIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Spacer(),
                  const SizedBox(width: AppSpacing.sm),
                  AppIconButton(
                    icon: Icons.search,
                    tooltip: 'Search audios',
                    onPressed: onSearch,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppIconButton(
                    icon: Icons.more_vert,
                    tooltip: 'More options',
                    onPressed: onMore,
                  ),
                ],
              ),
      ),
    );
  }
}

/// The All / Music / Recordings / Podcasts filter chips, with live counts.
class VaultAudioFilterBar extends StatelessWidget {
  const VaultAudioFilterBar({
    required this.selected,
    required this.countOf,
    required this.onSelected,
    super.key,
  });

  final VaultAudioFilter selected;
  final int Function(VaultAudioFilter filter) countOf;
  final ValueChanged<VaultAudioFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: Row(
        children: [
          for (final filter in VaultAudioFilter.values) ...[
            if (filter != VaultAudioFilter.all)
              const SizedBox(width: AppSpacing.sm),
            ChoiceChip(
              label: Text('${filter.label} (${countOf(filter)})'),
              selected: selected == filter,
              onSelected: (_) => onSelected(filter),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Browse by type": one tappable row per audio family with its live count.
class VaultAudioBrowseCard extends StatelessWidget {
  const VaultAudioBrowseCard({
    required this.countOf,
    required this.onSelected,
    super.key,
  });

  final int Function(VaultAudioFilter filter) countOf;
  final ValueChanged<VaultAudioFilter> onSelected;

  static const List<VaultAudioFilter> _families = <VaultAudioFilter>[
    VaultAudioFilter.music,
    VaultAudioFilter.recording,
    VaultAudioFilter.podcast,
  ];

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      children: <Widget>[
        for (final filter in _families)
          SettingsRow(
            key: Key('vault-audios-browse-${filter.name}'),
            icon: audioTypeIcon(filter.type!),
            iconColor: audioAccent(context, filter.type!),
            title: filter.label,
            subtitle: _subtitle(countOf(filter)),
            onTap: () => onSelected(filter),
          ),
      ],
    );
  }

  static String _subtitle(int count) => count == 1 ? '1 file' : '$count files';
}

/// The bottom "All audios" row: collection count, total size, and a chevron.
class VaultAudioCollectionRow extends StatelessWidget {
  const VaultAudioCollectionRow({
    required this.count,
    required this.totalBytes,
    required this.onTap,
    super.key,
  });

  final int count;
  final int totalBytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      children: <Widget>[
        SettingsRow(
          key: const Key('vault-audios-collection'),
          icon: Icons.folder_outlined,
          title: 'All audios',
          subtitle: count == 0
              ? 'Nothing stored'
              : '$count ${count == 1 ? 'file' : 'files'} · '
                    '${formatBytes(totalBytes)}',
          onTap: onTap,
        ),
      ],
    );
  }
}

/// One audio as a card: type glyph, name, metadata, and an actions menu.
class VaultAudioRow extends StatelessWidget {
  const VaultAudioRow({
    required this.audio,
    this.selected = false,
    this.selecting = false,
    this.onTap,
    this.onLongPress,
    this.onMenu,
    super.key,
  });

  final VaultAudio audio;
  final bool selected;
  final bool selecting;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final base = SettingsGroup.decoration(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: 4,
      ),
      child: DecoratedBox(
        decoration: base.copyWith(
          color: selected ? colors.surfaceSelected : base.color,
          border: selected
              ? Border.all(color: colors.selectionAccent, width: 1.5)
              : base.border,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress ?? onMenu,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    VaultAudioTypeTile(type: audio.effectiveType),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  audio.fileName,
                                  style: context.type.rowTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (audio.isFavorite)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: AppSpacing.sm,
                                  ),
                                  child: Icon(
                                    Icons.star,
                                    size: 16,
                                    color: colors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            audioMetaLine(audio),
                            style: context.type.rowSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (selecting)
                      VaultAudioSelectionCheck(selected: selected)
                    else ...[
                      Text(
                        formatAudioDuration(audio.durationMs),
                        style: context.type.rowSubtitle,
                      ),
                      if (onMenu != null)
                        AppIconButton(
                          icon: Icons.more_vert,
                          tooltip: '${audio.fileName} actions',
                          onPressed: onMenu,
                          bordered: false,
                        ),
                    ],
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

/// The circular tick the gallery uses, restated for a list row.
///
/// The documents vault's tick, shared so pictures, documents, and audios wear
/// one selection check across every list — two rows of the same vault wearing
/// two different checks would be the drift this reuse exists to stop.
class VaultAudioSelectionCheck extends StatelessWidget {
  const VaultAudioSelectionCheck({required this.selected, super.key});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? colors.selectionAccent : Colors.transparent,
        border: Border.all(
          color: selected ? colors.selectionAccent : colors.cardBorder,
          width: 1.5,
        ),
      ),
      child: selected
          ? Icon(Icons.check, size: 16, color: colors.selectionCheck)
          : null,
    );
  }
}

/// The "File info" sheet: type, extension, size, duration, dates, and storage.
Future<void> showVaultAudioInfo(BuildContext context, VaultAudio audio) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                VaultAudioTypeTile(type: audio.effectiveType),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Text(
                    audio.fileName,
                    style: context.type.rowTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _infoRow(context, 'Type', audio.effectiveType.label),
            _infoRow(context, 'Extension', audio.extensionLabel),
            _infoRow(context, 'Size', formatBytes(audio.fileSize)),
            if (audio.durationMs != null)
              _infoRow(
                context,
                'Duration',
                formatAudioDuration(audio.durationMs),
              ),
            _infoRow(context, 'Added', formatAudioDate(audio.dateAdded)),
            _infoRow(context, 'Modified', formatAudioDate(audio.dateModified)),
            _infoRow(context, 'Stored', 'Encrypted in this app\'s vault'),
          ],
        ),
      ),
    ),
  );
}

Widget _infoRow(BuildContext context, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(label, style: context.type.rowSubtitle),
        ),
        Expanded(child: Text(value, style: context.type.rowTitle)),
      ],
    ),
  );
}

/// The rename prompt: a text field and Cancel/Save.
class VaultAudioNameDialog extends StatefulWidget {
  const VaultAudioNameDialog({required this.initialName, super.key});

  final String initialName;

  @override
  State<VaultAudioNameDialog> createState() => _VaultAudioNameDialogState();
}

class _VaultAudioNameDialogState extends State<VaultAudioNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );
  bool _submitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_submitted) return;
    _submitted = true;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      title: const Text('Rename'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 120,
        cursorColor: context.appColors.textPrimary,
        decoration: InputDecoration(
          hintText: 'Audio name',
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: context.appColors.textPrimary),
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: context.appColors.divider),
          ),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

/// The category picker: Music, Recordings, Podcasts, or Automatic.
///
/// Automatic clears the override so the filename guess decides again — the
/// honest default for a file the user never pinned anywhere.
Future<VaultAudioType?> chooseVaultAudioCategory(
  BuildContext context,
  VaultAudio audio,
) {
  return showModalBottomSheet<VaultAudioType?>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('Automatic'),
            subtitle: Text('Currently: ${audio.effectiveType.label}'),
            onTap: () => Navigator.of(context).pop(null),
          ),
          for (final type in VaultAudioType.values.where(
            (type) => type != VaultAudioType.other,
          ))
            ListTile(
              leading: Icon(audioTypeIcon(type)),
              title: Text(type.label),
              trailing: audio.categoryOverride == type
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(context).pop(type),
            ),
        ],
      ),
    ),
  );
}
