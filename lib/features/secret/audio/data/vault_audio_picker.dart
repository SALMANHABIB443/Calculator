import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// One audio file the user handed to the vault, already read into memory.
///
/// A plain value type rather than a `PlatformFile` so the controller and its
/// tests never touch the plugin, and so the bytes exist exactly once — the
/// picker's job is to produce them, the vault's is to encrypt and store them.
class PickedAudio {
  const PickedAudio({required this.name, required this.bytes, this.mimeType});

  /// The original filename, extension included.
  final String name;

  final Uint8List bytes;

  final String? mimeType;
}

/// The seam over Android's Storage Access Framework.
///
/// Abstract so a widget test can return a fixed list of [PickedAudio]s
/// without a native dialog. The only production implementation is
/// [FilePickerAudioPicker].
abstract class VaultAudioPicker {
  /// Returns the chosen files, or an empty list when the user dismissed the
  /// picker. Never throws for a cancellation; a genuine platform failure is
  /// allowed to throw so the caller can report it.
  Future<List<PickedAudio>> pickAudios();
}

/// SAF-backed picker over `file_picker` (no manifest permission required).
///
/// `FilePicker.pickFiles` already opens a multi-select chooser on Android, so
/// a user can bring several tracks in at once. `FileType.audio` restricts the
/// chooser to what the platform calls audio; the category is still decided
/// from the filename once the file is in. An empty list means the user
/// dismissed the picker (v13 returns a list, never `null`); a file whose
/// bytes cannot be read becomes an empty pick that the controller counts as a
/// failed import rather than dropping the rest of the multi-select.
///
/// The browser pick has no filesystem path, so the bytes come through
/// `PlatformFile.readAsBytes`, which the web implementation serves from the
/// `File` object the user chose (the web picker loads them on selection by
/// default). On Android the same call reads the SAF content URI the picker
/// resolved.
class FilePickerAudioPicker implements VaultAudioPicker {
  const FilePickerAudioPicker();

  @override
  Future<List<PickedAudio>> pickAudios() async {
    final files = await FilePicker.pickFiles(type: FileType.audio);
    final picked = <PickedAudio>[];
    for (final file in files) {
      Uint8List bytes;
      try {
        bytes = await file.readAsBytes();
      } catch (_) {
        bytes = Uint8List(0);
      }
      picked.add(
        PickedAudio(
          name: file.name,
          bytes: bytes,
          mimeType: _mimeTypeOf(file.name),
        ),
      );
    }
    return picked;
  }

  /// A best-effort MIME type from the extension.
  ///
  /// The picker does not report one, and the app only ever needs it for the
  /// share/export step, so a guess that is right for the common cases and
  /// `application/octet-stream` otherwise is enough.
  static String _mimeTypeOf(String name) {
    final dot = name.lastIndexOf('.');
    final extension = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    return switch (extension) {
      'mp3' => 'audio/mpeg',
      'wav' => 'audio/wav',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'flac' => 'audio/flac',
      'ogg' => 'audio/ogg',
      'opus' => 'audio/opus',
      'amr' => 'audio/amr',
      '3gp' => 'audio/3gpp',
      'wma' => 'audio/x-ms-wma',
      'aiff' || 'aif' => 'audio/aiff',
      _ => 'application/octet-stream',
    };
  }
}
