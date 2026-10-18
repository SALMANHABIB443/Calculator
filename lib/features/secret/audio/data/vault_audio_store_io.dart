import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'vault_audio_cipher.dart';
import 'vault_audio_store.dart';

/// On-device [VaultAudioStore]: ciphertext files under the app's private
/// documents directory.
///
/// Nothing here is a plaintext write. [importBytes] encrypts before the file is
/// created and [readBytes] decrypts after it is read, so the bytes on disk are
/// always the `nonce ‖ tag ‖ ciphertext` blob the cipher made. The vault sits
/// beside the image and document vaults under `vault/`, with the same
/// `.nomedia` marker, so Android never scans any of them into a public folder.
///
/// **No plaintext cache.** Audio files are played one at a time by the player,
/// so a cache would buy nothing and hold decrypted content in memory for
/// longer than the screen that asked for it.
class VaultAudioIoStore extends VaultAudioStore {
  VaultAudioIoStore(this._cipher);

  final VaultDocumentCipher _cipher;

  /// Root of the vault, created on first use.
  Future<Directory> vaultRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory('${docs.path}/vault/audio');
    if (!await root.exists()) await root.create(recursive: true);
    await _ensureNoMedia(docs);
    return root;
  }

  Future<Directory> trashRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory('${docs.path}/vault/audio-trash');
    if (!await root.exists()) await root.create(recursive: true);
    await _ensureNoMedia(docs);
    return root;
  }

  Future<void> _ensureNoMedia(Directory docs) async {
    try {
      final vault = Directory('${docs.path}/vault');
      if (!await vault.exists()) await vault.create(recursive: true);
      final marker = File('${vault.path}/.nomedia');
      if (!await marker.exists()) await marker.writeAsString('');
    } catch (_) {
      // Best-effort privacy marker; a failure here must not block imports.
    }
  }

  Future<File> _fileFor(String vaultFileName, {required bool trashed}) async {
    final root = trashed ? await trashRoot() : await vaultRoot();
    return File('${root.path}/$vaultFileName');
  }

  @override
  Future<Uint8List?> readBytes(
    String vaultFileName, {
    bool trashed = false,
  }) async {
    final file = await _fileFor(vaultFileName, trashed: trashed);
    if (!await file.exists()) return null;
    final stored = await file.readAsBytes();
    if (stored.isEmpty) return Uint8List(0);
    return _cipher.decrypt(stored);
  }

  @override
  Future<void> importBytes(Uint8List bytes, String vaultFileName) async {
    final encrypted = await _cipher.encrypt(bytes);
    final dest = await _fileFor(vaultFileName, trashed: false);
    await dest.writeAsBytes(encrypted, flush: true);
  }

  @override
  Future<void> moveToTrash(String vaultFileName) async {
    await _move(vaultFileName, fromTrash: false);
  }

  @override
  Future<void> restoreFromTrash(String vaultFileName) async {
    await _move(vaultFileName, fromTrash: true);
  }

  Future<void> _move(String vaultFileName, {required bool fromTrash}) async {
    final src = await _fileFor(vaultFileName, trashed: fromTrash);
    if (!await src.exists()) return;
    final dest = await _fileFor(vaultFileName, trashed: !fromTrash);
    try {
      await src.rename(dest.path);
    } catch (_) {
      await src.copy(dest.path);
      try {
        await src.delete();
      } catch (_) {}
    }
  }

  @override
  Future<void> deletePermanently(String vaultFileName) async {
    for (final trashed in <bool>[false, true]) {
      try {
        final file = await _fileFor(vaultFileName, trashed: trashed);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  @override
  Future<bool> get isEmpty async {
    try {
      for (final trashed in <bool>[false, true]) {
        final root = trashed ? await trashRoot() : await vaultRoot();
        if (await root.exists()) {
          await for (final entity in root.list()) {
            if (entity is File && !entity.path.endsWith('.nomedia')) {
              return false;
            }
          }
        }
      }
    } catch (_) {}
    return true;
  }
}

VaultAudioStore createVaultAudioStore(VaultDocumentCipher cipher) =>
    VaultAudioIoStore(cipher);
