import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../core/design/app_palette.dart';
import '../../../../core/design/app_typography.dart';
import '../data/vault_document_downloader.dart';

/// Renders decrypted PDF bytes with `pdfx` (FEAT-SEC-009).
///
/// The bytes arrive already decrypted from the vault store and live only in
/// this widget's memory — nothing is written to a temporary file, so a PDF's
/// plaintext never touches the filesystem. `pdfx` needs the whole document up
/// front, so a very large PDF is held in RAM for as long as the viewer is open;
/// that is a documented limitation rather than a hidden one.
///
/// **Guarded by platform.** `pdfx`'s pinch viewer throws on Windows, and the
/// plugin has no host implementation in a widget test; both fall through to an
/// honest "can't preview here" body instead of a crash. The web build is in
/// the same group on purpose: `pdfx`'s web host is not what production
/// Android/iOS ship, and an exception in its platform channel takes the whole
/// viewer down with it — the fallback hands the user a Download instead.
/// Production Android/iOS take the real path.
class VaultPdfPreview extends StatefulWidget {
  const VaultPdfPreview({
    required this.bytes,
    super.key,
    this.fileName,
    this.mimeType,
  });

  final Uint8List bytes;

  /// The original filename, used by the fallback's Download action.
  final String? fileName;

  final String? mimeType;

  @override
  State<VaultPdfPreview> createState() => _VaultPdfPreviewState();
}

class _VaultPdfPreviewState extends State<VaultPdfPreview> {
  PdfControllerPinch? _controller;

  @override
  void initState() {
    super.initState();
    if (_canRenderPdf) {
      _controller = PdfControllerPinch(
        document: PdfDocument.openData(Future<Uint8List>.value(widget.bytes)),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Whether this platform's `pdfx` build can actually mount the viewer.
  static bool get _canRenderPdf =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return _PdfUnavailable(
        bytes: widget.bytes,
        fileName: widget.fileName,
        mimeType: widget.mimeType,
      );
    }

    return PdfViewPinch(
      controller: controller,
      backgroundDecoration: BoxDecoration(color: context.appColors.background),
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(
          loaderSwitchDuration: Duration(milliseconds: 200),
        ),
        documentLoaderBuilder: (context) => const Center(
          child: SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
        ),
        pageLoaderBuilder: (context) => const ColoredBox(color: Colors.white),
        errorBuilder: (context, error) => _PdfUnavailable(
          bytes: widget.bytes,
          fileName: widget.fileName,
          mimeType: widget.mimeType,
        ),
      ),
    );
  }
}

/// Shown when the PDF cannot be rendered on this platform.
///
/// On the web (and in a widget test) there is no renderer, so the body
/// offers a Download of the decrypted bytes rather than leaving the user
/// with a dead screen; elsewhere the message still points at Share, which
/// the viewer's header already offers.
class _PdfUnavailable extends StatelessWidget {
  const _PdfUnavailable({
    required this.bytes,
    this.fileName,
    this.mimeType,
  });

  final Uint8List bytes;
  final String? fileName;
  final String? mimeType;

  Future<void> _download() async {
    final name = fileName;
    if (name == null) return;
    await downloadDocument(name, bytes, mimeType);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Preview is not available on this device. Use Share to open the file '
              'in another app.',
              textAlign: TextAlign.center,
              style: context.type.body,
            ),
            if (fileName != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _download,
                icon: const Icon(Icons.download),
                label: const Text('Download'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
