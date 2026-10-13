import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Encrypts and decrypts document bytes at rest (FEAT-SEC-009).
///
/// The one promise this holds: bytes handed to [encrypt] never reach disk in a
/// readable form, and only [decrypt] turns them back. Every caller below the
/// controller deals in plaintext and never sees the cipher, so there is a
/// single place where the guarantee can be broken.
abstract class VaultDocumentCipher {
  Future<Uint8List> encrypt(Uint8List plaintext);

  Future<Uint8List> decrypt(Uint8List stored);
}

/// Where the 256-bit vault key comes from.
///
/// On Android/iOS it is the platform keystore (see the IO key source); on the
/// web, and in tests, it is a random key held only for this process.
abstract class VaultKeySource {
  Future<Uint8List> readKey();
}

/// A random 256-bit key held only for this process.
///
/// The honest answer for a browser, which has no keystore `path_provider` can
/// reach: documents survive navigation and hot reload, but a full page refresh
/// starts a new key and the previously stored blobs are undecryptable. The
/// controller heals that by dropping rows whose bytes no longer decrypt.
class InMemoryVaultKeySource implements VaultKeySource {
  InMemoryVaultKeySource([Uint8List? key]) : _key = key ?? randomVaultKey();

  final Uint8List _key;

  @override
  Future<Uint8List> readKey() async => _key;
}

/// 32 bytes from [Random.secure].
Uint8List randomVaultKey() {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(32, (_) => random.nextInt(256), growable: false),
  );
}

/// AES-256-GCM with a random nonce per write (FEAT-SEC-009).
///
/// On-disk layout is `nonce(12) ‖ tag(16) ‖ ciphertext`. The nonce is fresh for
/// every [encrypt] call — reusing one under a fixed key is the classic GCM
/// failure, so it is generated here and never carried in from a caller. The tag
/// is what makes a tampered or truncated blob fail closed: a wrong key or a
/// flipped byte throws [VaultDecryptionException] instead of returning garbage.
class AesGcmVaultDocumentCipher implements VaultDocumentCipher {
  AesGcmVaultDocumentCipher(this._keySource, {AesGcm? algorithm})
    : _algorithm = algorithm ?? AesGcm.with256bits();

  final VaultKeySource _keySource;
  final AesGcm _algorithm;

  static const int nonceLength = 12;
  static const int tagLength = 16;
  static const int keyLength = 32;

  /// Resolved once and shared by every concurrent caller.
  ///
  /// A cached `Future` rather than a cached key so two imports racing on the
  /// first ever call cannot both read an absent key and both generate one —
  /// which would leave the earlier blob undecryptable.
  Future<SecretKey>? _key;

  Future<SecretKey> _resolveKey() async {
    final bytes = await _keySource.readKey();
    if (bytes.length != keyLength) {
      throw ArgumentError(
        'The vault key must be $keyLength bytes, got ${bytes.length}.',
      );
    }
    return SecretKey(bytes);
  }

  Future<SecretKey> get _secretKey => _key ??= _resolveKey();

  @override
  Future<Uint8List> encrypt(Uint8List plaintext) async {
    final key = await _secretKey;
    final nonce = _algorithm.newNonce();
    final box = await _algorithm.encrypt(
      plaintext,
      secretKey: key,
      nonce: nonce,
    );
    final mac = box.mac.bytes;
    final cipherText = box.cipherText;
    final out = Uint8List(nonceLength + tagLength + cipherText.length);
    out.setRange(0, nonceLength, box.nonce);
    out.setRange(nonceLength, nonceLength + tagLength, mac);
    out.setRange(nonceLength + tagLength, out.length, cipherText);
    return out;
  }

  @override
  Future<Uint8List> decrypt(Uint8List stored) async {
    if (stored.length < nonceLength + tagLength) {
      throw const VaultDecryptionException(
        'The stored document is too short to be valid.',
      );
    }
    final key = await _secretKey;
    final nonce = stored.sublist(0, nonceLength);
    final mac = stored.sublist(nonceLength, nonceLength + tagLength);
    final cipherText = stored.sublist(nonceLength + tagLength);
    try {
      final clear = await _algorithm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const VaultDecryptionException(
        'The stored document could not be decrypted.',
      );
    }
  }
}

/// Raised when encrypted bytes cannot be turned back into plaintext — a wrong
/// key, a truncated blob, or a tampered one. Callers treat it as "this file is
/// unreadable", never as a crash.
class VaultDecryptionException implements Exception {
  const VaultDecryptionException(this.message);

  final String message;

  @override
  String toString() => 'VaultDecryptionException: $message';
}
