import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_palette.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/widgets/core_widgets.dart';
import '../data/device_storage_repository.dart';
import '../audio/domain/vault_audio.dart';
import '../documents/domain/vault_document.dart';
import '../documents/presentation/vault_document_widgets.dart';
import '../images/domain/vault_image.dart';
import '../images/presentation/vault_images_providers.dart';

/// One recoverable thing in the Vault's global recycle bin.
///
/// The bin is the one place deleted items from every vault section land: a
/// document from the Documents place, a picture from the Gallery, an audio
/// from the Audio place. All three are metadata rows that carry a `trashedAt`,
/// so the bin can list them together without owning any kind — it wraps
/// whichever it is, and the screen dispatches restore and delete-forever back
/// to that section's own notifier.
///
/// **A wrapper rather than a shared base class.** Neither [VaultDocument] nor
/// [VaultImage] nor [VaultAudio] should grow fields (a "kind" flag, a common
/// name) to make the bin convenient; the bin is the thing that has three
/// kinds, so the union lives here, at the one call site that needs it.
class VaultTrashEntry {
  VaultTrashEntry.document(VaultDocument document)
    : id = document.id,
      name = document.fileName,
      fileSize = document.fileSize,
      trashedAt = document.trashedAt ?? document.dateModified,
      document = document,
      image = null,
      audio = null;

  VaultTrashEntry.image(VaultImage image)
    : id = image.id,
      name = image.fileName,
      fileSize = image.fileSize,
      trashedAt = image.trashedAt ?? image.dateModified,
      document = null,
      image = image,
      audio = null;

  VaultTrashEntry.audio(VaultAudio audio)
    : id = audio.id,
      name = audio.fileName,
      fileSize = audio.fileSize,
      trashedAt = audio.trashedAt ?? audio.dateModified,
      document = null,
      image = null,
      audio = audio;

  final String id;
  final String name;
  final int fileSize;

  /// When the entry entered the bin — the only date the bin ever orders by.
  final DateTime trashedAt;

  /// Set when this entry is a document; `null` for a picture or an audio.
  final VaultDocument? document;

  /// Set when this entry is a picture; `null` for a document or an audio.
  final VaultImage? image;

  /// Set when this entry is an audio; `null` for a document or a picture.
  final VaultAudio? audio;

  bool get isImage => image != null;

  bool get isAudio => audio != null;
}

/// One picture in the global recycle bin, as a row.
///
/// A picture cannot wear the gallery's grid tile here — the bin is a list, and
/// the tile's square would sit beside a document's filename row and read as two
/// different screens stacked. So it takes the document row's shape instead: a
/// thumbnail where the type tile goes, the name, and `IMAGE · size · date`.
class VaultTrashImageRow extends StatelessWidget {
  const VaultTrashImageRow({
    required this.image,
    this.selected = false,
    this.selecting = false,
    this.onTap,
    this.onMenu,
    super.key,
  });

  final VaultImage image;
  final bool selected;
  final bool selecting;
  final VoidCallback? onTap;
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
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    _TrashThumbnail(image: image),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            image.fileName,
                            style: context.type.rowTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'IMAGE · ${formatBytes(image.fileSize)} · '
                            '${formatDocumentDate(image.dateModified)}',
                            style: context.type.rowSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (selecting)
                      VaultSelectionCheck(selected: selected)
                    else if (onMenu != null)
                      AppIconButton(
                        icon: Icons.more_vert,
                        tooltip: '${image.fileName} actions',
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

/// The "Details" sheet the recycle bin shows for a trashed picture.
///
/// The document twin of this is [showVaultDocumentInfo]. Kept as a second,
/// picture-shaped function rather than one widget with two branches because the
/// facts differ (a picture has no extension label, no content hash) and the
/// list the bin shows them in is the only place either is ever read.
Future<void> showVaultImageInfo(BuildContext context, VaultImage image) async {
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
                _TrashThumbnail(image: image),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Text(
                    image.fileName,
                    style: context.type.rowTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _infoRow(context, 'Type', image.mimeType),
            _infoRow(context, 'Size', formatBytes(image.fileSize)),
            _infoRow(context, 'Added', formatDocumentDate(image.dateAdded)),
            _infoRow(
              context,
              'Modified',
              formatDocumentDate(image.dateModified),
            ),
            _infoRow(context, 'Stored', 'Inside this app\'s vault'),
          ],
        ),
      ),
    ),
  );
}

Widget _infoRow(BuildContext context, String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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

/// A 44 px rounded thumbnail, matching the document row's type tile.
///
/// The bytes come from the same store the gallery reads, with `trashed: true`
/// because a recycle-bin picture is already in the trash bucket. A missing blob
/// paints the broken-image glyph rather than an empty square, so a row whose
/// pixels are gone still says so honestly.
///
/// The read is issued **once per picture**, in [initState], not inline in [build].
/// A `FutureBuilder` handed a fresh future on every build resets itself to
/// "waiting", re-subscribes, and completes again — a rebuild loop that never
/// settles. Holding the future in state turns it into the single fetch it was
/// meant to be.
class _TrashThumbnail extends ConsumerStatefulWidget {
  const _TrashThumbnail({required this.image});

  final VaultImage image;

  @override
  ConsumerState<_TrashThumbnail> createState() => _TrashThumbnailState();
}

class _TrashThumbnailState extends ConsumerState<_TrashThumbnail> {
  late Future<Uint8List?> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _read();
  }

  @override
  void didUpdateWidget(_TrashThumbnail old) {
    super.didUpdateWidget(old);
    if (old.image.vaultFileName != widget.image.vaultFileName) {
      _bytes = _read();
    }
  }

  Future<Uint8List?> _read() => ref
      .read(vaultImageStoreProvider)
      .readBytes(widget.image.vaultFileName, trashed: true);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: SizedBox(
        width: 44,
        height: 44,
        child: FutureBuilder<Uint8List?>(
          future: _bytes,
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (bytes == null) {
              return ColoredBox(
                color: colors.surfaceSoft,
                child: Icon(
                  snapshot.connectionState == ConnectionState.done
                      ? Icons.broken_image_outlined
                      : Icons.image_outlined,
                  size: 20,
                  color: colors.textSecondary,
                ),
              );
            }
            return Image.memory(bytes, fit: BoxFit.cover, cacheWidth: 132);
          },
        ),
      ),
    );
  }
}
