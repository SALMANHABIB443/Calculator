import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/preferences_provider.dart';
import '../data/shared_preferences_vault_audio_repository.dart';
import '../data/vault_audio_cipher.dart';
import '../data/vault_audio_crypto_factory.dart';
import '../data/vault_audio_picker.dart';
import '../data/vault_audio_repository.dart';
import '../data/vault_audio_store.dart';
import '../data/vault_audio_store_factory.dart';

/// The AES-256-GCM cipher, over the platform keystore key.
///
/// A seam as much as a value: a widget test overrides this with a cipher over
/// a `FixedVaultKeySource`, so no test touches a real keystore. The type is
/// the document vault's cipher — audio shares the one key on purpose.
final vaultAudioCipherProvider = Provider<VaultDocumentCipher>(
  (ref) => createVaultAudioCipher(),
);

/// Where encrypted audio bytes live.
///
/// Depends on the cipher rather than building its own, so overriding the
/// cipher also changes what the store encrypts with.
final vaultAudioStoreProvider = Provider<VaultAudioStore>(
  (ref) => createVaultAudioStore(ref.watch(vaultAudioCipherProvider)),
);

/// Where audio metadata comes from: `shared_preferences`, in-memory fallback.
final vaultAudioRepositoryProvider = FutureProvider<VaultAudioRepository>((
  ref,
) async {
  try {
    final preferences = await ref.watch(preferencesProvider);
    return SharedPreferencesVaultAudioRepository(preferences);
  } catch (_) {
    return InMemoryVaultAudioRepository();
  }
});

/// Opens Android's Storage Access Framework picker (no manifest permission).
///
/// Overridden in tests with a fake that returns fixed bytes, so no native
/// dialog is ever raised.
final vaultAudioPickerProvider = Provider<VaultAudioPicker>(
  (ref) => const FilePickerAudioPicker(),
);
