import 'dart:typed_data';

import 'vault_document_cipher.dart';
import 'vault_document_store.dart';

/// In-memory [VaultDocumentStore] for the browser (FEAT-SEC-009).
///
/// Web has no private filesystem `dart:io` can reach, so the *encrypted* blobs
/// live only in this process. They are still encrypted — the cipher is the same
/// one the device uses — but the key is a session key, so a full page refresh
/// makes them undecryptable and the controller drops the orphaned rows.
class VaultDocumentWebStore extends VaultDocumentStore {
  VaultDocumentWebStore(this._cipher);

  final VaultDocumentCipher _cipher;

  final Map<String, Uint8List> _documents = <String, Uint8List>{};
  final Map<String, Uint8List> _trash = <String, Uint8List>{};

  Map<String, Uint8List> _bucket(bool trashed) =>
      trashed ? _trash : _documents;

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
    _documents[vaultFileName] = await _cipher.encrypt(bytes);
  }

  @override
  Future<void> moveToTrash(String vaultFileName) async {
    final bytes = _documents.remove(vaultFileName);
    if (bytes != null) _trash[vaultFileName] = bytes;
  }

  @override
  Future<void> restoreFromTrash(String vaultFileName) async {
    final bytes = _trash.remove(vaultFileName);
    if (bytes != null) _documents[vaultFileName] = bytes;
  }

  @override
  Future<void> deletePermanently(String vaultFileName) async {
    _documents.remove(vaultFileName);
    _trash.remove(vaultFileName);
  }

  @override
  Future<bool> get isEmpty async => _documents.isEmpty && _trash.isEmpty;
}

VaultDocumentStore createVaultDocumentStore(VaultDocumentCipher cipher) =>
    VaultDocumentWebStore(cipher);
