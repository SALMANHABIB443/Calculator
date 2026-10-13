import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/uuid.dart';
import '../data/vault_image_repository.dart';
import '../domain/vault_image.dart';
import 'vault_images_providers.dart';
import 'vault_images_state.dart';

/// A new album's name cannot be used: empty after trimming, or already taken.
///
/// Thrown by [VaultImagesNotifier.createAlbum] so the presentation layer can
/// show a specific reason rather than a generic "could not create the album".
/// The message is user-facing and safe to drop straight into a snackbar.
class AlbumNameException implements Exception {
  const AlbumNameException(this.message);

  /// Why the name was rejected, phrased for the person who typed it.
  final String message;

  @override
  String toString() => 'AlbumNameException: $message';
}

/// Reads, imports, deletes, favorites, and organises vault images (D-116).
///
/// Follows the `HistoryNotifier` pattern: the repository is awaited per call,
/// every mutation re-saves the whole metadata list, then `invalidateSelf()` so
/// the gallery rebuilds from disk rather than from a stale in-memory copy.
class VaultImagesNotifier extends AsyncNotifier<VaultImagesState> {
  static const Duration trashRetention = Duration(days: 30);

  /// Tail of the mutation chain — see [_serialize].
  Future<void> _mutations = Future<void>.value();

  @override
  Future<VaultImagesState> build() async {
    final repository = await ref.watch(vaultImageRepositoryProvider.future);
    var images = await repository.loadImages();
    final albums = await repository.loadAlbums();
    final sort = await repository.loadSort();
    if (kIsWeb && await ref.read(vaultImageStoreProvider).isEmpty) {
      // A browser refresh drops the in-memory byte store but keeps the
      // localStorage metadata. Heal the rows that no longer have pixels behind
      // them — the gallery would otherwise list broken tiles.
      //
      // **Albums are never cleared here.** An album is metadata-only: it owns
      // no bytes by design, and an empty album is a perfectly valid state a
      // user just asked for. Treating "store is empty" as "the album is stale"
      // deleted every album created before the first photo was imported, which
      // is exactly what happened on a fresh Chrome session: create an album,
      // `invalidateSelf()` re-runs this method, and the album was wiped before
      // the list ever rendered it.
      final healed = healMetadataForEmptyStore(
        images,
        albums,
        storeIsEmpty: true,
      );
      if (healed.images.length != images.length) {
        images = healed.images;
        await repository.saveImages(images);
      }
    }
    await _purgeExpiredTrash(images, repository);
    return VaultImagesState(images: images, albums: albums, sort: sort);
  }

  /// The metadata that survives a web refresh, once the byte store has come
  /// back empty.
  ///
  /// **The images go; the albums stay.** An image is a row *plus* bytes, so an
  /// empty store means every row is a broken tile. An album is metadata only —
  /// it owns no bytes — so an empty store says nothing about it, and an empty
  /// album is a state the user just asked for.
  ///
  /// **A pure function of the store's emptiness, not of `kIsWeb`.** `kIsWeb` is
  /// a compile-time constant, so a test running on the VM can never reach the
  /// browser branch in [build]; pulling the decision out here makes the rule —
  /// "empty store drops the images, and nothing else" — unit-testable. The
  /// albums are carried through the result on purpose: clearing them here was
  /// the bug (see [build]), and a result that carries them is something a test
  /// can pin down.
  @visibleForTesting
  static ({List<VaultImage> images, List<VaultAlbum> albums})
  healMetadataForEmptyStore(
    List<VaultImage> images,
    List<VaultAlbum> albums, {
    required bool storeIsEmpty,
  }) {
    if (!storeIsEmpty) return (images: images, albums: albums);
    return (images: const <VaultImage>[], albums: albums);
  }

  /// Runs [action] after every mutation queued before it has finished.
  ///
  /// Every mutation is a read-modify-write over the same `shared_preferences`
  /// keys, so two overlapping calls — a double-tapped **Create**, an import
  /// racing a delete — would each read the old list and the last write would
  /// win, silently dropping the other's change. That is why album creation
  /// appeared to "work sometimes": the album was written and then overwritten
  /// by a sibling call that had read the list before it landed.
  ///
  /// Chaining them makes each mutation observe the previous one's result. The
  /// gate future always completes *normally*, even when [action] throws, so one
  /// failed mutation cannot wedge the queue; the caller still receives
  /// [action]'s own result or error.
  Future<T> _serialize<T>(Future<T> Function() action) {
    final gate = Completer<void>();
    final previous = _mutations;
    _mutations = gate.future;
    return previous
        .then((_) => action())
        .whenComplete(() {
          if (!gate.isCompleted) gate.complete();
        });
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
  /// Reads bytes straight off the picker (a `blob:` URL on web), so the same
  /// code path feeds both the on-device files and the web store. A file whose
  /// bytes come back empty never reaches metadata.
  ///
  /// When [albumId] names an existing album, every imported picture is tagged
  /// with it in the same save, so the picture lands in both Pictures and that
  /// album. An unknown id (a virtual row such as `all`, or an album deleted
  /// concurrently) is ignored: a general import must never leak into an
  /// arbitrary album.
  Future<VaultImportResult> importPickedFiles(
    List<XFile> picked, {
    String? albumId,
  }) {
    return _serialize(() async {
      final repository = await _repository;
      final store = ref.read(vaultImageStoreProvider);
      final existing = await repository.loadImages();
      String? targetAlbumId;
      if (albumId != null) {
        final albums = await repository.loadAlbums();
        if (albums.any((album) => album.id == albumId)) {
          targetAlbumId = albumId;
        }
      }
      var imported = 0;
      var failed = 0;
      for (final pick in picked) {
        try {
          final bytes = await pick.readAsBytes();
          if (bytes.isEmpty) {
            failed++;
            continue;
          }
          final ext = _extensionOf(
            pick.name.isEmpty ? pick.path : pick.name,
          );
          final vaultName = '${uuidV4()}$ext';
          await store.importBytes(bytes, vaultName);
          final originalName = pick.name.isEmpty ? 'photo$ext' : pick.name;
          final now = DateTime.now();
          DateTime modified;
          try {
            modified = await pick.lastModified();
          } catch (_) {
            modified = now;
          }
          existing.insert(
            0,
            VaultImage(
              id: uuidV4(),
              fileName: originalName,
              vaultFileName: vaultName,
              mimeType: pick.mimeType ?? _mimeOf(ext),
              fileSize: bytes.length,
              dateAdded: now,
              dateModified: modified,
              albumIds: targetAlbumId == null
                  ? const <String>[]
                  : <String>[targetAlbumId],
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
    });
  }

  Future<void> toggleFavorite(String id) {
    return _serialize(() async {
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
    });
  }

  Future<void> moveToTrash(Set<String> ids) {
    if (ids.isEmpty) return Future<void>.value();
    return _serialize(() async {
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
    });
  }

  Future<void> restoreFromTrash(Set<String> ids) {
    if (ids.isEmpty) return Future<void>.value();
    return _serialize(() async {
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
    });
  }

  Future<void> deletePermanently(Set<String> ids) {
    if (ids.isEmpty) return Future<void>.value();
    return _serialize(() async {
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
    });
  }

  Future<void> setSort(VaultImageSort sort) {
    return _serialize(() async {
      final repository = await _repository;
      await repository.saveSort(sort);
      ref.invalidateSelf();
      await future;
    });
  }

  /// Creates and stores a new album, returning it.
  ///
  /// The name is trimmed and must be non-empty and not a case-insensitive
  /// duplicate of an existing album; either failure throws an
  /// [AlbumNameException] carrying a message the caller can show. Duplicates
  /// are refused because the Albums list has no other identity to tell two
  /// same-named rows apart, so a second one reads as the first one failing to
  /// save.
  Future<VaultAlbum> createAlbum(String name) {
    return _serialize(() async {
      final trimmed = name.trim();
      if (trimmed.isEmpty) {
        throw const AlbumNameException('Enter an album name.');
      }
      final repository = await _repository;
      final albums = await repository.loadAlbums();
      final taken = albums.any(
        (album) => album.name.trim().toLowerCase() == trimmed.toLowerCase(),
      );
      if (taken) {
        throw AlbumNameException('An album named "$trimmed" already exists.');
      }
      final album = VaultAlbum(
        id: uuidV4(),
        name: trimmed,
        createdAt: DateTime.now(),
      );
      await repository.saveAlbums(<VaultAlbum>[...albums, album]);
      ref.invalidateSelf();
      await future;
      return album;
    });
  }

  Future<void> addToAlbum(String albumId, Set<String> imageIds) {
    if (imageIds.isEmpty) return Future<void>.value();
    return _serialize(() async {
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
    });
  }

  Future<void> deleteAlbum(String albumId) {
    return _serialize(() async {
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
    });
  }
}

final vaultImagesProvider =
    AsyncNotifierProvider<VaultImagesNotifier, VaultImagesState>(
      VaultImagesNotifier.new,
    );
