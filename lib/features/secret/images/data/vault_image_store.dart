import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// File layout of the private image vault (D-116).
///
/// Everything lives under the app-private documents directory, which Android
/// never scans into the public gallery. Private originals sit in one folder,
/// recently deleted in another, with a `.nomedia` marker at the vault root.
/// No vault file is ever written to DCIM/Pictures/Downloads. Share sheets get
/// a copy under the app cache, deleted right after sharing. Paths are never
/// shown in UI — callers get [File] handles, the user sees friendly names.
class VaultImageStore {
  const VaultImageStore();

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

  Future<Directory> shareScratch() async {
    final cache = await getTemporaryDirectory();
    final dir = Directory('${cache.path}/vault-share');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
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

  Future<File> fileFor(String vaultFileName, {bool trashed = false}) async {
    final root = trashed ? await trashRoot() : await vaultRoot();
    return File('${root.path}/$vaultFileName');
  }

  /// Copies [source] into the vault under [vaultFileName]. Returns the new file.
  Future<File> importFile(File source, String vaultFileName) async {
    final dest = await fileFor(vaultFileName);
    await source.copy(dest.path);
    return dest;
  }

  Future<void> moveToTrash(String vaultFileName) async {
    final src = await fileFor(vaultFileName);
    if (!await src.exists()) return;
    final dest = File('${(await trashRoot()).path}/$vaultFileName');
    try {
      await src.rename(dest.path);
    } catch (_) {
      await src.copy(dest.path);
      try {
        await src.delete();
      } catch (_) {}
    }
  }

  Future<void> restoreFromTrash(String vaultFileName) async {
    final src = File('${(await trashRoot()).path}/$vaultFileName');
    if (!await src.exists()) return;
    final dest = await fileFor(vaultFileName);
    try {
      await src.rename(dest.path);
    } catch (_) {
      await src.copy(dest.path);
      try {
        await src.delete();
      } catch (_) {}
    }
  }

  Future<void> deletePermanently(String vaultFileName) async {
    for (final trashed in <bool>[false, true]) {
      try {
        final file = await fileFor(vaultFileName, trashed: trashed);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  /// Removes share-scratch copies older than a day; best-effort.
  Future<void> cleanShareScratch() async {
    try {
      final dir = await shareScratch();
      await for (final entity in dir.list()) {
        try {
          final stat = await entity.stat();
          if (DateTime.now().difference(stat.modified).inHours >= 24) {
            await entity.delete(recursive: true);
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Purges trash entries older than [retention]. Returns surviving file names.
  Future<Set<String>> purgeExpiredTrash(
    Set<String> knownNames,
    Duration retention,
  ) async {
    try {
      final dir = await trashRoot();
      if (!await dir.exists()) return knownNames;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.path.split(RegExp(r'[/\\]')).last;
        try {
          final stat = await entity.stat();
          if (DateTime.now().difference(stat.modified) > retention) {
            await entity.delete();
            knownNames.remove(name);
          }
        } catch (_) {}
      }
    } catch (_) {}
    return knownNames;
  }
}
