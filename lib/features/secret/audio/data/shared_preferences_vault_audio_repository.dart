import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/vault_audio.dart';
import 'vault_audio_repository.dart';

/// [VaultAudioRepository] over `shared_preferences`.
///
/// One key, one JSON list, capped like the history and image repositories. Only
/// *metadata* lives here — names, sizes, dates, a content digest, and the trash
/// timestamp. The audio contents are encrypted blobs in the vault directory,
/// so a leaked preferences file exposes a file index, never a file.
class SharedPreferencesVaultAudioRepository implements VaultAudioRepository {
  const SharedPreferencesVaultAudioRepository(this._preferences);

  final SharedPreferences _preferences;

  static const String audiosKey = 'vaultAudios';
  static const String sortKey = 'vaultAudioSort';

  @override
  Future<List<VaultAudio>> loadAudios() async {
    try {
      final stored = _preferences.getString(audiosKey);
      if (stored == null) return <VaultAudio>[];
      final decoded = jsonDecode(stored);
      if (decoded is! List) return <VaultAudio>[];
      final audios = <VaultAudio>[];
      for (final record in decoded) {
        if (record is! Map<String, dynamic>) continue;
        final audio = VaultAudio.fromJson(record);
        if (audio != null) audios.add(audio);
      }
      return audios;
    } on FormatException {
      return <VaultAudio>[];
    } on TypeError {
      return <VaultAudio>[];
    }
  }

  @override
  Future<void> saveAudios(List<VaultAudio> audios) async {
    await _preferences.setString(
      audiosKey,
      jsonEncode(<Map<String, dynamic>>[
        for (final audio in audios) audio.toJson(),
      ]),
    );
  }

  @override
  Future<VaultAudioSort> loadSort() async {
    try {
      return VaultAudioSort.fromStorageKey(_preferences.getString(sortKey));
    } on TypeError {
      return VaultAudioSort.newestFirst;
    }
  }

  @override
  Future<void> saveSort(VaultAudioSort sort) async {
    await _preferences.setString(sortKey, sort.storageKey);
  }
}

/// In-memory fake for tests and as the app's fallback when the plugin is
/// unavailable: same contract, no platform needed.
class InMemoryVaultAudioRepository implements VaultAudioRepository {
  List<VaultAudio> audios;
  VaultAudioSort sort;

  InMemoryVaultAudioRepository({
    List<VaultAudio>? audios,
    this.sort = VaultAudioSort.newestFirst,
  }) : audios = audios ?? <VaultAudio>[];

  @override
  Future<List<VaultAudio>> loadAudios() async =>
      List<VaultAudio>.unmodifiable(audios);

  @override
  Future<void> saveAudios(List<VaultAudio> value) async {
    audios = List<VaultAudio>.from(value);
  }

  @override
  Future<VaultAudioSort> loadSort() async => sort;

  @override
  Future<void> saveSort(VaultAudioSort value) async {
    sort = value;
  }
}
