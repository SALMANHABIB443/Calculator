import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/uuid.dart';
import '../data/vault_image_repository.dart';
import '../domain/vault_image.dart';
import 'vault_images_providers.dart';
import 'vault_images_state.dart';

/// Reads, imports, deletes, favorites, and organises vault images (D-116).
///
/// Follows the `HistoryNotifier` pattern: the repository is awaited per call,
/// every mutation re-saves the whole metadata list, then `invalidateSelf()` so
/// the gallery rebuilds from disk rather than from a stale in-memory copy.
class VaultImagesNotifier extends AsyncNotifier<VaultImagesState> {
  static const Duration trashRetention = Duration(days: 30);

  @override
  Future<VaultImagesState> build() async {
    final repository = await ref.watch(vaultImageRepositoryProvider.future);
    final images = await repository.loadImages();
    final albums = await repository.loadAlbums();
    final sort = await repository.loadSort();
    await _purgeExpiredTrash(images, repository);
    return VaultImagesState(images: images, albums: albums, sort: sort);
  }

  Future<VaultImageRepository> get _repository =>
      ref.read(vaultImageRepositoryProvider.future);

  Future<void> _purgeExpiredTrash(
    List<VaultImage> images,
    VaultImageRepository repository,
  ) async {
    final store = ref.read(vaultImageStoreProvider);
    final now = DateTime.now();
    var changed = false;
    final kept = <VaultImage>[];
    for (final image in images) {
      final trashedAt = image.trashedAt;
      if (trashedAt != null && now.difference(trashedAt) > trashRetention) {
        await store.deletePermanently(image.vaultFileName);
        changed = true;
      } else {
        kept.add(image);
      }
    }
    if (changed) await repository.saveImages(kept);
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '.jpg';
    final ext = path.substring(dot).toLowerCase();
    if (ext.length > 5 || ext.length < 2) return '.jpg';
    return ext;
  }

  String _mimeOf(String ext) {
    switch (ext) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.bmp':
        return 'image/bmp';
      case '.heic':
      case '.heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  /// Copies picked files into the private vault.
  ///
  /// Each file is verified after copy; a failed copy never reaches metadata.
  Future<VaultImportResult> importPickedFiles(List<XFile> picked) async {
    final repository = await _repository;
    final store = ref.read(vaultImageStoreProvider);
    final existing = await repository.loadImages();
    var imported = 0;
    var failed = 0;
    for (final pick in picked) {
      try {
        final source = File(pick.path);
        if (!await source.exists()) {
          failed++;
          continue;
        }
        final ext = _extensionOf(
          pick.name.isEmpty ? pick.path : pick.name,
        );
        final vaultName = '${uuidV4()}$ext';
        final dest = await store.importFile(source, vaultName);
        if (!await dest.exists()) {
          failed++;
          continue;
        }
        final stat = await dest.stat();
        if (stat.size <= 0) {
          await store.deletePermanently(vaultName);
          failed++;
          continue;
        }
        final originalName = pick.name.isEmpty ? 'photo$ext' : pick.name;
        final now = DateTime.now();
        existing.insert(
          0,
          VaultImage(
            id: uuidV4(),
            fileName: originalName,
            vaultFileName: vaultName,
            mimeType: pick.mimeType ?? _mimeOf(ext),
            fileSize: stat.size,
            dateAdded: now,
            dateModified: stat.modified,
          ),
        );
        imported++;
      } catch (_) {
        failed++;
      }
    }
    await repository.saveImages(existing);
    ref.invalidateSelf();
    await future;
    return VaultImportResult(imported: imported, failed: failed);
  }

  Future<void> toggleFavorite(String id) async {
    final repository = await _repository;
    final images = await repository.loadImages();
    await repository.saveImages(<VaultImage>[
      for (final image in images)
        if (image.id == id)
          image.copyWith(isFavorite: !image.isFavorite)
        else
          image,
    ]);
    ref.invalidateSelf();
    await future;
  }

  Future<void> moveToTrash(Set<String> ids) async {
    if (ids.isEmpty) return;
    final repository = await _repository;
    final store = ref.read(vaultImageStoreProvider);
    final images = await repository.loadImages();
    final now = DateTime.now();
    final next = <VaultImage>[];
    for (final image in images) {
      if (!ids.contains(image.id)) {
        next.add(image);
        continue;
      }
      await store.moveToTrash(image.vaultFileName);
      next.add(image.copyWith(trashedAt: now));
    }
    await repository.saveImages(next);
    ref.invalidateSelf();
    await future;
  }

  Future<void> restoreFromTrash(Set<String> ids) async {
    if (ids.isEmpty) return;
    final repository = await _repository;
    final store = ref.read(vaultImageStoreProvider);
    final images = await repository.loadImages();
    final next = <VaultImage>[];
    for (final image in images) {
      if (!ids.contains(image.id)) {
        next.add(image);
        continue;
      }
      await store.restoreFromTrash(image.vaultFileName);
      next.add(image.copyWith(clearTrash: true));
    }
    await repository.saveImages(next);
    ref.invalidateSelf();
    await future;
  }

  Future<void> deletePermanently(Set<String> ids) async {
    if (ids.isEmpty) return;
    final repository = await _repository;
    final store = ref.read(vaultImageStoreProvider);
    final images = await repository.loadImages();
    final next = <VaultImage>[];
    for (final image in images) {
      if (!ids.contains(image.id)) {
        next.add(image);
        continue;
      }
      await store.deletePermanently(image.vaultFileName);
    }
    await repository.saveImages(next);
    ref.invalidateSelf();
    await future;
  }

  Future<void> setSort(VaultImageSort sort) async {
    final repository = await _repository;
    await repository.saveSort(sort);
    ref.invalidateSelf();
    await future;
  }

  Future<VaultAlbum> createAlbum(String name) async {
    final repository = await _repository;
    final albums = await repository.loadAlbums();
    final album = VaultAlbum(
      id: uuidV4(),
      name: name.trim(),
      createdAt: DateTime.now(),
    );
    await repository.saveAlbums(<VaultAlbum>[...albums, album]);
    ref.invalidateSelf();
    await future;
    return album;
  }

  Future<void> addToAlbum(String albumId, Set<String> imageIds) async {
    if (imageIds.isEmpty) return;
    final repository = await _repository;
    final images = await repository.loadImages();
    await repository.saveImages(<VaultImage>[
      for (final image in images)
        if (imageIds.contains(image.id) &&
            !image.albumIds.contains(albumId))
          image.copyWith(albumIds: <String>[...image.albumIds, albumId])
        else
          image,
    ]);
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteAlbum(String albumId) async {
    final repository = await _repository;
    final albums = await repository.loadAlbums();
    await repository.saveAlbums(<VaultAlbum>[
      for (final album in albums)
        if (album.id != albumId) album,
    ]);
    final images = await repository.loadImages();
    await repository.saveImages(<VaultImage>[
      for (final image in images)
        if (image.albumIds.contains(albumId))
          image.copyWith(
            albumIds: <String>[
              for (final id in image.albumIds)
                if (id != albumId) id,
            ],
          )
        else
          image,
    ]);
    ref.invalidateSelf();
    await future;
  }
}

final vaultImagesProvider =
    AsyncNotifierProvider<VaultImagesNotifier, VaultImagesState>(
      VaultImagesNotifier.new,
    );

