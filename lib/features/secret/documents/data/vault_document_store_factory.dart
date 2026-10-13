import 'vault_document_cipher.dart';
import 'vault_document_store.dart';
import 'vault_document_store_web.dart'
    if (dart.library.io) 'vault_document_store_io.dart' as impl;

/// The platform's default document store, bound to [cipher].
VaultDocumentStore createVaultDocumentStore(VaultDocumentCipher cipher) =>
    impl.createVaultDocumentStore(cipher);
