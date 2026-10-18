import '../domain/vault_audio.dart';

/// Persistence boundary for the private audio vault.
///
/// Metadata only — the bytes live as encrypted blobs in the app-private vault
/// directory. Never throws: a missing or corrupt store degrades to an empty
/// list, so the screen shows its empty state rather than crashing.
abstract class VaultAudioRepository {
  Future<List<VaultAudio>> loadAudios();

  Future<void> saveAudios(List<VaultAudio> audios);

  Future<VaultAudioSort> loadSort();

  Future<void> saveSort(VaultAudioSort sort);
}
