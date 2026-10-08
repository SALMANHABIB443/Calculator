import '../domain/vault_image.dart';

/// Persistence boundary for the private image vault (D-116).
///
/// Metadata only — the bytes live as files in the app-private vault
/// directory. Never throws: a missing or corrupt store degrades to an empty
/// list, so the gallery shows its empty state rather than crashing.
abstract class VaultImageRepository {
  Future<List<VaultImage>> loadImages();
  Future<void> saveImages(List<VaultImage> images);
  Future<List<VaultAlbum>> loadAlbums();
  Future<void> saveAlbums(List<VaultAlbum> albums);
  Future<VaultImageSort> loadSort();
  Future<void> saveSort(VaultImageSort sort);
}
