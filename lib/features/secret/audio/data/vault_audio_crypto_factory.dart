import '../../documents/data/vault_document_cipher.dart';
import '../../documents/data/vault_document_crypto_factory.dart' as docs;

/// The platform's default audio cipher.
///
/// Delegates to the document vault's factory: keystore-backed on Android/iOS,
/// an in-memory session key on the web. Same key, same guarantee — audio needs
/// no second key source to lose.
VaultDocumentCipher createVaultAudioCipher() =>
    docs.createVaultDocumentCipher();
