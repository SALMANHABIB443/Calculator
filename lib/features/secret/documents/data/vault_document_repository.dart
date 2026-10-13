import '../domain/vault_document.dart';

/// Persistence boundary for the private document vault (FEAT-SEC-009).
///
/// Metadata only — the bytes live as encrypted blobs in the app-private vault
/// directory. Never throws: a missing or corrupt store degrades to an empty
/// list, so the screen shows its empty state rather than crashing.
abstract class VaultDocumentRepository {
  Future<List<VaultDocument>> loadDocuments();

  Future<void> saveDocuments(List<VaultDocument> documents);

  Future<VaultDocumentSort> loadSort();

  Future<void> saveSort(VaultDocumentSort sort);
}
