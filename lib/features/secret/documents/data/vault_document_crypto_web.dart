import 'vault_document_cipher.dart';

/// Builds the browser cipher over a key held only for this process.
///
/// The web has no keystore `path_provider` can reach, so the honest choice is a
/// random session key rather than a half-secure one persisted in
/// `localStorage`. The cost is documented: a full page refresh starts a new key
/// and previously stored blobs are undecryptable, which the controller heals by
/// dropping the rows.
VaultDocumentCipher createDefaultVaultDocumentCipher() =>
    AesGcmVaultDocumentCipher(InMemoryVaultKeySource());
