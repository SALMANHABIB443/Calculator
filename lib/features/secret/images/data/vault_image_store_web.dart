import 'dart:typed_data';

import 'vault_image_store.dart';

/// In-memory implementation of [VaultImageStore] for the browser.
///
/// Web has no private filesystem that `dart:io` can reach, so picture bytes
/// live only in this process. Photos survive navigation and hot reload within
/// the session but vanish on a full page refresh; the controller then wipes
/// any stale metadata (which persists in `localStorage`) so the gallery never
/// shows broken tiles.
class VaultImageWebStore extends VaultImageStore {
  VaultImageWebStore();

  final Map<String, Uint8List> _images = <String, Uint8List>{};
  final Map<String, Uint8List> _trash = <String, Uint8List>{};

  @override
  Future<Uint8List?> readBytes(
    String vaultFileName, {
    bool trashed = false,
  }) async {
    return (trashed ? _trash : _images)[vaultFileName];
  }

  @override
  Future<void> importBytes(Uint8List bytes, String vaultFileName) async {
    _images[vaultFileName] = bytes;
  }

  @override
  Future<void> moveToTrash(String vaultFileName) async {
    final bytes = _images.remove(vaultFileName);
    if (bytes != null) _trash[vaultFileName] = bytes;
  }

  @override
  Future<void> restoreFromTrash(String vaultFileName) async {
    final bytes = _trash.remove(vaultFileName);
    if (bytes != null) _images[vaultFileName] = bytes;
  }

  @override
  Future<void> deletePermanently(String vaultFileName) async {
    _images.remove(vaultFileName);
    _trash.remove(vaultFileName);
  }

  @override
  Future<bool> get isEmpty async => _images.isEmpty && _trash.isEmpty;
}

VaultImageStore createVaultImageStore() => VaultImageWebStore();