import 'dart:typed_data';

import 'vault_document_downloader_web.dart'
    if (dart.library.io) 'vault_document_downloader_io.dart' as impl;

/// Hands one decrypted document to the browser as a download (FEAT-SEC-009,
/// web).
///
/// The browser has no share sheet and no private filesystem to write a temp
/// file to, so a Share on the web becomes a Download: the decrypted bytes
/// live in a Blob and the page clicks a one-shot anchor. On the platforms
/// where the share sheet exists this is a no-op — `shareDocuments` never
/// reaches it.
Future<bool> downloadDocument(
  String fileName,
  Uint8List bytes,
  String? mimeType,
) => impl.downloadDocument(fileName, bytes, mimeType);
