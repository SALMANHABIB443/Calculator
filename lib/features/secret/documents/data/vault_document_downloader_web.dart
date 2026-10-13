import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Browser download of one decrypted document (FEAT-SEC-009, web).
///
/// The bytes are a Blob the page creates, clicks once, and lets the browser
/// take away; nothing is written to disk by the app, and the anchor is
/// removed again so the click target does not outlive the download. Returns
/// `true` because the browser always accepted the anchor click; a genuine
/// failure (a zero-byte blob) throws so the caller can report it.
Future<bool> downloadDocument(
  String fileName,
  Uint8List bytes,
  String? mimeType,
) async {
  if (bytes.isEmpty) {
    throw StateError('Cannot download an empty document: $fileName');
  }
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(
      type: mimeType ?? 'application/octet-stream',
    ),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return true;
}
