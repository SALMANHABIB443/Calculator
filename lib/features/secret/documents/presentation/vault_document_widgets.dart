import 'package:flutter/material.dart';

import '../../../../core/design/app_palette.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/widgets/core_widgets.dart';
import '../../data/device_storage_repository.dart';
import '../domain/vault_document.dart';

/// Content-type accents for the vault's file glyphs (FEAT-SEC-009).
///
/// **Not theme tokens, and deliberately so.** [AppColors] is the app's palette
/// and every value in it means something about the *app* — a surface, an accent,
/// a danger. These three mean something about the *file*: the colour a user
/// already associates with a PDF, a Word document, and plain text, the way every
/// file manager on the platform tints them. They are stated here rather than in
/// the palette so a change to the app's own palette cannot re-colour a document
/// type by accident, and so a reader can see at a glance that they are content,
/// not chrome.
abstract final class VaultDocumentAccents {
  static const Color pdf = Color(0xFFE5534B);
  static const Color word = Color(0xFF4C8DF6);
  static const Color text = Color(0xFF8B949E);
}

/// The glyph that stands for [type] everywhere a document is listed.
IconData documentTypeIcon(VaultDocumentType type) => switch (type) {
  VaultDocumentType.pdf => Icons.picture_as_pdf_outlined,
  VaultDocumentType.word => Icons.description_outlined,
  VaultDocumentType.text => Icons.article_outlined,
  VaultDocumentType.other => Icons.insert_drive_file_outlined,
};

/// The accent for [type], falling back to the theme's secondary text for a file
/// the app has no family for — which is the honest colour for "unknown".
Color documentAccent(BuildContext context, VaultDocumentType type) =>
    switch (type) {
      VaultDocumentType.pdf => VaultDocumentAccents.pdf,
      VaultDocumentType.word => VaultDocumentAccents.word,
      VaultDocumentType.text => VaultDocumentAccents.text,
      VaultDocumentType.other => context.appColors.textSecondary,
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
String formatDocumentDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

/// `PDF · 2.4 MB · 12 Oct 2026` — the one metadata line every row shows.
String documentMetaLine(VaultDocument document) =>
    '${document.extensionLabel} · ${formatBytes(document.fileSize)} · '
    '${formatDocumentDate(document.dateModified)}';

/// A document's type glyph in a soft rounded tile, the leading element of a row.
class VaultDocumentTypeTile extends StatelessWidget {
  const VaultDocumentTypeTile({required this.type, this.dimension = 44, super.key});

  final VaultDocumentType type;
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
        documentTypeIcon(type),
        size: dimension * 0.5,
        color: documentAccent(context, type),
      ),
    );
  }
}

/// The Documents header: back + title + search + overflow, or the selection
/// variant (close + count + All/None).
///
/// A bespoke row rather than [SecondaryPageHeader] for the reason the gallery's
/// header is one: the shared header reserves a full 48 px trailing slot which
/// overflows at the 800 px test width once two actions are in it, so this row
/// keeps its own tighter action spacing.
class VaultDocumentsHeader extends StatelessWidget {
  const VaultDocumentsHeader({
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
                    tooltip: 'Search documents',
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

/// The All / PDF / Word / Text filter chips, each carrying its live count.
class VaultDocumentFilterBar extends StatelessWidget {
  const VaultDocumentFilterBar({
    required this.selected,
    required this.countOf,
    required this.onSelected,
    super.key,
  });

  final VaultDocumentFilter selected;

  /// The live count a chip shows, over the visible documents.
  final int Function(VaultDocumentFilter filter) countOf;

  final ValueChanged<VaultDocumentFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
        ),
        itemCount: VaultDocumentFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final filter = VaultDocumentFilter.values[index];
          final active = filter == selected;
          final count = countOf(filter);
          return Semantics(
            button: true,
            selected: active,
            label: '${filter.label} filter, $count documents',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelected(filter),
                borderRadius: BorderRadius.circular(AppRadius.iconButton),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? colors.textPrimary : colors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.iconButton),
                    border: null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        filter.label,
                        style: context.type.caption.copyWith(
                          color: active ? colors.background : colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          '$count',
                          style: context.type.caption.copyWith(
                            color: active
                                ? colors.background
                                : colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One document as a card: type glyph, name, metadata, and an actions menu.
class VaultDocumentRow extends StatelessWidget {
  const VaultDocumentRow({
    required this.document,
    this.selected = false,
    this.selecting = false,
    this.onTap,
    this.onLongPress,
    this.onMenu,
    super.key,
  });

  final VaultDocument document;
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
              onLongPress: onLongPress,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    VaultDocumentTypeTile(type: document.type),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            document.fileName,
                            style: context.type.rowTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            documentMetaLine(document),
                            style: context.type.rowSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (selecting)
                      _SelectionCheck(selected: selected)
                    else if (onMenu != null)
                      AppIconButton(
                        icon: Icons.more_vert,
                        tooltip: '${document.fileName} actions',
                        onPressed: onMenu,
                        bordered: false,
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

/// The circular tick the gallery uses, restated for a document row.
class _SelectionCheck extends StatelessWidget {
  const _SelectionCheck({required this.selected});

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

/// "Browse by type": one tappable row per viewer family with its live count.
class VaultDocumentBrowseCard extends StatelessWidget {
  const VaultDocumentBrowseCard({
    required this.countOf,
    required this.onSelected,
    super.key,
  });

  final int Function(VaultDocumentFilter filter) countOf;
  final ValueChanged<VaultDocumentFilter> onSelected;

  static const List<VaultDocumentFilter> _families = <VaultDocumentFilter>[
    VaultDocumentFilter.pdf,
    VaultDocumentFilter.word,
    VaultDocumentFilter.text,
  ];

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      children: <Widget>[
        for (final filter in _families)
          SettingsRow(
            key: Key('vault-documents-browse-${filter.name}'),
            icon: documentTypeIcon(filter.type!),
            iconColor: documentAccent(context, filter.type!),
            title: filter.label,
            subtitle: _subtitle(countOf(filter)),
            onTap: () => onSelected(filter),
          ),
      ],
    );
  }

  static String _subtitle(int count) =>
      count == 1 ? '1 file' : '$count files';
}

/// The bottom "All documents" row: collection count, total size, and a chevron.
class VaultDocumentCollectionRow extends StatelessWidget {
  const VaultDocumentCollectionRow({
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
          key: const Key('vault-documents-collection'),
          icon: Icons.folder_outlined,
          title: 'All documents',
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

/// The "File info" sheet: type, extension, size, dates, and where it is stored.
///
/// A shared function rather than a method on each screen so the Documents list,
/// its collection pages, and the recycle bin all describe a document the same
/// way. The last row is the privacy claim, stated plainly so a user can see it
/// rather than have to trust it.
Future<void> showVaultDocumentInfo(
  BuildContext context,
  VaultDocument document,
) async {
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
                VaultDocumentTypeTile(type: document.type),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Text(
                    document.fileName,
                    style: context.type.rowTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _infoRow(context, 'Type', document.type.label),
            _infoRow(context, 'Extension', document.extensionLabel),
            _infoRow(context, 'Size', formatBytes(document.fileSize)),
            _infoRow(
              context,
              'Added',
              formatDocumentDate(document.dateAdded),
            ),
            _infoRow(
              context,
              'Modified',
              formatDocumentDate(document.dateModified),
            ),
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
        SizedBox(width: 96, child: Text(label, style: context.type.rowSubtitle)),
        Expanded(child: Text(value, style: context.type.rowTitle)),
      ],
    ),
  );
}

/// The rename prompt: a text field and Cancel/Save.
///
/// A `StatefulWidget` owning its own controller for the reason the gallery's
/// album dialog owns its own: `showDialog`'s future completes while the route is
/// still animating out, so a controller created by the caller and disposed on
/// return would be touched during the exit transition. Save latches after the
/// first press so a double-tap cannot pop twice.
class VaultDocumentNameDialog extends StatefulWidget {
  const VaultDocumentNameDialog({required this.initialName, super.key});

  final String initialName;

  @override
  State<VaultDocumentNameDialog> createState() => _VaultDocumentNameDialogState();
}

class _VaultDocumentNameDialogState extends State<VaultDocumentNameDialog> {
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
          hintText: 'Document name',
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
