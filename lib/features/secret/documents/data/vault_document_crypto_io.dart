import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'vault_document_cipher.dart';

/// The vault key, held in the platform keystore (FEAT-SEC-009).
///
/// Generated once, on first use, as 32 bytes from [randomVaultKey] and stored
/// base64-encoded in `flutter_secure_storage` — Android's EncryptedSharedPrefs
/// over the Keystore, iOS's Keychain. The key never touches `shared_preferences`
/// and never appears in a log line.
class SecureStorageVaultKeySource implements VaultKeySource {
  SecureStorageVaultKeySource({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// The single key this source owns.
  ///
  /// Distinct from the metadata keys in `shared_preferences` on purpose: a
  /// clear-data on ordinary preferences must not be able to orphan the key
  /// while the blobs survive.
  static const String keyName = 'vaultDocumentKey';

  @override
  Future<Uint8List> readKey() async {
    final existing = await _storage.read(key: keyName);
    if (existing != null) {
      final decoded = base64Decode(existing);
      if (decoded.length == AesGcmVaultDocumentCipher.keyLength) {
        return Uint8List.fromList(decoded);
      }
    }
    final generated = randomVaultKey();
    await _storage.write(key: keyName, value: base64Encode(generated));
    return generated;
  }
}

/// Builds the on-device cipher over the keystore-backed key.
VaultDocumentCipher createDefaultVaultDocumentCipher() =>
    AesGcmVaultDocumentCipher(SecureStorageVaultKeySource());
