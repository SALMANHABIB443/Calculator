import 'dart:typed_data';

import 'vault_audio_cipher.dart';
import 'vault_audio_store.dart';

/// In-memory [VaultAudioStore] for the browser.
///
/// Web has no private filesystem `dart:io` can reach, so the *encrypted* blobs
/// live only in this process. They are still encrypted — the cipher is the same
/// one the device uses — but the key is a session key, so a full page refresh
/// makes them undecryptable and the controller drops the orphaned rows.
class VaultAudioWebStore extends VaultAudioStore {
  VaultAudioWebStore(this._cipher);

  final VaultDocumentCipher _cipher;

  final Map<String, Uint8List> _audios = <String, Uint8List>{};
  final Map<String, Uint8List> _trash = <String, Uint8List>{};

  Map<String, Uint8List> _bucket(bool trashed) => trashed ? _trash : _audios;

  @override
  Future<Uint8List?> readBytes(
    String vaultFileName, {
    bool trashed = false,
  }) async {
    final stored = _bucket(trashed)[vaultFileName];
    if (stored == null) return null;
    return _cipher.decrypt(stored);
  }

  @override
  Future<void> importBytes(Uint8List bytes, String vaultFileName) async {
    _audios[vaultFileName] = await _cipher.encrypt(bytes);
  }

  @override
  Future<void> moveToTrash(String vaultFileName) async {
    final bytes = _audios.remove(vaultFileName);
    if (bytes != null) _trash[vaultFileName] = bytes;
  }

  @override
  Future<void> restoreFromTrash(String vaultFileName) async {
    final bytes = _trash.remove(vaultFileName);
    if (bytes != null) _audios[vaultFileName] = bytes;
  }

  @override
  Future<void> deletePermanently(String vaultFileName) async {
    _audios.remove(vaultFileName);
    _trash.remove(vaultFileName);
  }

  @override
  Future<bool> get isEmpty async => _audios.isEmpty && _trash.isEmpty;
}

VaultAudioStore createVaultAudioStore(VaultDocumentCipher cipher) =>
    VaultAudioWebStore(cipher);
