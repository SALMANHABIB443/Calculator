import 'dart:typed_data';

/// Where encrypted document bytes live (FEAT-SEC-009).
///
/// The contract is byte-shaped and *plaintext-facing*: [importBytes] receives
/// what the user picked and [readBytes] hands back what the viewer draws. The
/// encryption happens inside the implementation, so no caller above this line
/// can accidentally write a readable file. Each platform supplies its own store
/// through `createVaultDocumentStore` — private files for Android/iOS, an
/// in-memory map for the browser.
abstract class VaultDocumentStore {
  const VaultDocumentStore();

  /// The document's decrypted bytes, or `null` when nothing is stored under
  /// [vaultFileName].
  Future<Uint8List?> readBytes(String vaultFileName, {bool trashed = false});

  /// Encrypts [bytes] and writes them under [vaultFileName].
  Future<void> importBytes(Uint8List bytes, String vaultFileName);

  Future<void> moveToTrash(String vaultFileName);

  Future<void> restoreFromTrash(String vaultFileName);

  Future<void> deletePermanently(String vaultFileName);

  /// True when no document remains anywhere in the vault.
  Future<bool> get isEmpty;
}
