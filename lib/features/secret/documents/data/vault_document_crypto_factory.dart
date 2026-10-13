import 'vault_document_cipher.dart';
import 'vault_document_crypto_web.dart'
    if (dart.library.io) 'vault_document_crypto_io.dart' as impl;

/// The platform's default document cipher.
///
/// Keystore-backed on Android/iOS, an in-memory session key on the web. The
/// seam exists so a widget test can install a `FixedVaultKeySource` cipher
/// without touching a real keystore.
VaultDocumentCipher createVaultDocumentCipher() =>
    impl.createDefaultVaultDocumentCipher();
