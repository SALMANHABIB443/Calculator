import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_palette.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/widgets/core_widgets.dart';
import '../domain/vault_document.dart';
import 'vault_document_widgets.dart';
import 'vault_documents_controller.dart';
import 'vault_documents_providers.dart';

/// The in-app reader for one vault document (FEAT-SEC-009).
///
/// Pushed on its own `MaterialPageRoute` from the Documents list, so Back always
/// returns to the list rather than to a viewer that replaced it — the same
/// back-stack rule the image viewer follows.
///
/// The bytes are decrypted into memory by the controller and never written
/// anywhere except a private cache file that exists only for the duration of a
/// Share. PDFs render through the provider seam
/// ([vaultPdfViewerBuilderProvider]); text renders here; Word and anything else
/// say plainly that preview is not supported and offer Share, which is the one
/// safe action left.
class VaultDocumentViewerScreen extends ConsumerStatefulWidget {
  const VaultDocumentViewerScreen({required this.document, super.key});

  final VaultDocument document;

  /// Handle a test reaches the viewer's body by.
  static const Key bodyKey = Key('vault-document-viewer');

  @override
  ConsumerState<VaultDocumentViewerScreen> createState() =>
      _VaultDocumentViewerScreenState();
}

class _VaultDocumentViewerScreenState
    extends ConsumerState<VaultDocumentViewerScreen> {
  late final Future<Uint8List> _bytes = ref
      .read(vaultDocumentsProvider.notifier)
      .readDocument(widget.document);

  Future<void> _share() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final shared = await ref
          .read(vaultDocumentsProvider.notifier)
          .shareDocuments(<VaultDocument>[widget.document]);
      if (!mounted) return;
      if (!shared) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Sharing is not available in this browser preview'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not share this document')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SecondaryPageScaffold(
      header: _ViewerHeader(
        onShare: _share,
      ),
      body: FutureBuilder<Uint8List>(
        future: _bytes,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _UnavailableView(onShare: _share);
          }
          return _bodyFor(context, snapshot.data!);
        },
      ),
    );
  }

  Widget _bodyFor(BuildContext context, Uint8List bytes) {
    switch (widget.document.type) {
      case VaultDocumentType.pdf:
        final builder = ref.watch(vaultPdfViewerBuilderProvider);
        return Container(
          key: VaultDocumentViewerScreen.bodyKey,
          color: context.appColors.background,
          child: builder(
            context,
            bytes,
            fileName: widget.document.fileName,
            mimeType: widget.document.mimeType,
          ),
        );
      case VaultDocumentType.text:
        return _TextView(key: VaultDocumentViewerScreen.bodyKey, bytes: bytes);
      case VaultDocumentType.word:
      case VaultDocumentType.other:
        return _UnsupportedView(
          key: VaultDocumentViewerScreen.bodyKey,
          document: widget.document,
          onShare: _share,
        );
    }
  }
}

/// Back + filename + Share. A compact row rather than [SecondaryPageHeader]
/// because the header's single trailing slot is spent on Share and the title is
/// a filename that must be allowed to ellipsize.
class _ViewerHeader extends StatelessWidget {
  const _ViewerHeader({required this.onShare});

  final VoidCallback onShare;

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
        child: Row(
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
              icon: Icons.ios_share,
              tooltip: 'Share',
              onPressed: onShare,
            ),
          ],
        ),
      ),
    );
  }
}

/// A plain-text reader: the decrypted bytes as UTF-8 in a scrollable card.
class _TextView extends StatelessWidget {
  const _TextView({required this.bytes, super.key});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final text = utf8.decode(bytes, allowMalformed: true);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.lg,
        AppSpacing.screenHorizontal,
        AppSpacing.bottomSafe,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: SettingsGroup.decoration(context),
        child: SelectableText(
          text.isEmpty ? '(This file is empty.)' : text,
          style: context.type.body.copyWith(
            fontFamily: 'monospace',
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

/// Shown for Word documents (no in-app renderer) and for any other format.
class _UnsupportedView extends StatelessWidget {
  const _UnsupportedView({
    required this.document,
    required this.onShare,
    super.key,
  });

  final VaultDocument document;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final isWord = document.type == VaultDocumentType.word;
    return EmptyState(
      iconWidget: VaultDocumentTypeTile(type: document.type, dimension: 56),
      iconSize: AppIconSize.illustration,
      title: isWord ? 'Preview not available' : 'Cannot preview this file',
      message: isWord
          ? 'Word documents open in another app. Share this file to view or edit '
                'it.'
          : 'This file type has no in-app viewer. Share it to open it in another '
                'app.',
      action: FilledButton.icon(
        onPressed: onShare,
        icon: const Icon(Icons.ios_share),
        label: const Text('Share'),
      ),
    );
  }
}

/// Shown when a document's bytes are gone or cannot be decrypted.
class _UnavailableView extends StatelessWidget {
  const _UnavailableView({required this.onShare});

  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      title: 'Cannot open this document',
      message: 'Its stored copy is missing or unreadable.',
      action: FilledButton.icon(
        onPressed: onShare,
        icon: const Icon(Icons.ios_share),
        label: const Text('Share'),
      ),
    );
  }
}
