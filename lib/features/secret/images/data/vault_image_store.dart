import 'dart:typed_data';

/// Where vault picture bytes live (D-116).
///
/// The old implementation was shaped around `dart:io File` handles and
/// `path_provider` paths, which the browser cannot reach. This contract is
/// byte-shaped instead, and each platform supplies its own store through
/// [createVaultImageStore] (on-device files for Android/iOS, an in-memory map
/// for the web so the gallery can be exercised in Chrome).
abstract class VaultImageStore {
  const VaultImageStore();

  /// The picture's raw bytes, or `null` when the entry has no data behind it.
  Future<Uint8List?> readBytes(String vaultFileName, {bool trashed = false});

  Future<void> importBytes(Uint8List bytes, String vaultFileName);

  Future<void> moveToTrash(String vaultFileName);

  Future<void> restoreFromTrash(String vaultFileName);

  Future<void> deletePermanently(String vaultFileName);

  /// True when no bytes remain anywhere in the vault.
  Future<bool> get isEmpty;
}