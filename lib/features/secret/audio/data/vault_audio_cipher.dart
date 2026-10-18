library;

/// The audio vault's cipher is the document vault's cipher.
///
/// One key, one guarantee: audio blobs are encrypted with the same
/// AES-256-GCM cipher as documents, so there is a single place where the
/// at-rest promise can be broken. Import the cipher from this path to keep
/// audio code decoupled from the documents path.
export '../../documents/data/vault_document_cipher.dart';
