import 'dart:typed_data';

/// No-op stub: the platforms with a real filesystem never reach a browser
/// download, so `shareDocuments` never calls this seam there.
///
/// The seam exists only so the web can share the controller's `shareDocuments`
/// entry point without `dart:js` in the mobile build.
Future<bool> downloadDocument(
  String fileName,
  Uint8List bytes,
  String? mimeType,
) async => false;
