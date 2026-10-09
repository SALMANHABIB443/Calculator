import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'vault_image_store.dart';

/// On-device implementation of [VaultImageStore]: bytes live as private files
/// under the app documents directory (D-116).
///
/// Everything lives under the app-private documents directory, which Android
/// never scans into the public gallery. Private originals sit in one folder,
/// recently deleted in another, with a `.nomedia` marker at the vault root.
/// No vault file is ever written to DCIM/Pictures/Downloads. A small byte
/// cache means the 3-column grid never re-reads a file from disk twice in the
/// same session; paths are never shown in UI — callers get bytes.
class VaultImageIoStore extends VaultImageStore {
  VaultImageIoStore() : _cache = <String, Uint8List>{};

  final Map<String, Uint8List> _cache;
  static const int _cacheLimit = 96;

  /// Root of the vault, created on first use.
  Future<Directory> vaultRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory('${docs.path}/vault/images');
    if (!await root.exists()) await root.create(recursive: true);
    await _ensureNoMedia(docs);
    return root;
  }

  Future<Directory> trashRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory('${docs.path}/vault/trash');
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

  String _cacheKey(String vaultFileName, bool trashed) =>
      '${trashed ? 'trash' : 'vault'}/$vaultFileName';

  void _remember(String vaultFileName, bool trashed, Uint8List bytes) {
    _cache[_cacheKey(vaultFileName, trashed)] = bytes;
    if (_cache.length > _cacheLimit) _cache.remove(_cache.keys.first);
  }

  void _forget(String vaultFileName) {
    _cache.remove(_cacheKey(vaultFileName, false));
    _cache.remove(_cacheKey(vaultFileName, true));
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
    final cached = _cache[_cacheKey(vaultFileName, trashed)];
    if (cached != null) return cached;
    final file = await _fileFor(vaultFileName, trashed: trashed);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    _remember(vaultFileName, trashed, bytes);
    return bytes;
  }

  @override
  Future<void> importBytes(Uint8List bytes, String vaultFileName) async {
    final dest = await _fileFor(vaultFileName, trashed: false);
    await dest.writeAsBytes(bytes, flush: true);
    _remember(vaultFileName, false, bytes);
  }

  @override
  Future<void> moveToTrash(String vaultFileName) async {
    final src = await _fileFor(vaultFileName, trashed: false);
    if (!await src.exists()) return;
    final dest = await _fileFor(vaultFileName, trashed: true);
    try {
      await src.rename(dest.path);
    } catch (_) {
      await src.copy(dest.path);
      try {
        await src.delete();
      } catch (_) {}
    }
    _forget(vaultFileName);
  }

  @override
  Future<void> restoreFromTrash(String vaultFileName) async {
    final src = await _fileFor(vaultFileName, trashed: true);
    if (!await src.exists()) return;
    final dest = await _fileFor(vaultFileName, trashed: false);
    try {
      await src.rename(dest.path);
    } catch (_) {
      await src.copy(dest.path);
      try {
        await src.delete();
      } catch (_) {}
    }
    _forget(vaultFileName);
  }

  @override
  Future<void> deletePermanently(String vaultFileName) async {
    for (final trashed in <bool>[false, true]) {
      try {
        final file = await _fileFor(vaultFileName, trashed: trashed);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    _forget(vaultFileName);
  }

  @override
  Future<bool> get isEmpty async {
    try {
      for (final trashed in <bool>[false, true]) {
        final root = trashed ? await trashRoot() : await vaultRoot();
        if (await root.exists()) {
          await for (final _ in root.list()) {
            return false;
          }
        }
      }
    } catch (_) {}
    return true;
  }
}

VaultImageStore createVaultImageStore() => VaultImageIoStore();