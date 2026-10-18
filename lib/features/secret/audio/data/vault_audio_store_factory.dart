import 'vault_audio_cipher.dart';
import 'vault_audio_store.dart';
import 'vault_audio_store_web.dart'
    if (dart.library.io) 'vault_audio_store_io.dart'
    as impl;

/// The platform's default audio store, bound to [cipher].
VaultAudioStore createVaultAudioStore(VaultDocumentCipher cipher) =>
    impl.createVaultAudioStore(cipher);
