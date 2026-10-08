import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'vault_image_repository.dart';
import '../domain/vault_image.dart';

/// `VaultImageRepository` over `shared_preferences` (D-02, D-116).
///
/// The same one-key-one-JSON-list design the history repository uses: small,
/// flat, and capped. Only metadata is stored — bytes live as files in the
/// app-private vault directory. Every read degrades to empty rather than
/// throwing, so a corrupt record costs one row, never the gallery.
class SharedPreferencesVaultImageRepository implements VaultImageRepository {
  const SharedPreferencesVaultImageRepository(this._preferences);

  final SharedPreferences _preferences;

  static const String imagesKey = 'vaultImages';
  static const String albumsKey = 'vaultAlbums';
  static const String sortKey = 'vaultImageSort';

  @override
  Future<List<VaultImage>> loadImages() async {
    try {
      final stored = _preferences.getString(imagesKey);
      if (stored == null) return <VaultImage>[];
      final decoded = jsonDecode(stored);
      if (decoded is! List) return <VaultImage>[];
      final images = <VaultImage>[];
      for (final record in decoded) {
        if (record is! Map<String, dynamic>) continue;
        final image = VaultImage.fromJson(record);
        if (image != null) images.add(image);
      }
      return images;
    } on FormatException {
      return <VaultImage>[];
    } on TypeError {
      return <VaultImage>[];
    }
  }

  @override
  Future<void> saveImages(List<VaultImage> images) async {
    await _preferences.setString(
      imagesKey,
      jsonEncode(<Map<String, dynamic>>[
        for (final image in images) image.toJson(),
      ]),
    );
  }

  @override
  Future<List<VaultAlbum>> loadAlbums() async {
    try {
      final stored = _preferences.getString(albumsKey);
      if (stored == null) return <VaultAlbum>[];
      final decoded = jsonDecode(stored);
      if (decoded is! List) return <VaultAlbum>[];
      final albums = <VaultAlbum>[];
      for (final record in decoded) {
        if (record is! Map<String, dynamic>) continue;
        final album = VaultAlbum.fromJson(record);
        if (album != null) albums.add(album);
      }
      return albums;
    } on FormatException {
      return <VaultAlbum>[];
    } on TypeError {
      return <VaultAlbum>[];
    }
  }

  @override
  Future<void> saveAlbums(List<VaultAlbum> albums) async {
    await _preferences.setString(
      albumsKey,
      jsonEncode(<Map<String, dynamic>>[
        for (final album in albums) album.toJson(),
      ]),
    );
  }

  @override
  Future<VaultImageSort> loadSort() async {
    try {
      return VaultImageSort.fromStorageKey(_preferences.getString(sortKey));
    } on TypeError {
      return VaultImageSort.newestFirst;
    }
  }

  @override
  Future<void> saveSort(VaultImageSort sort) async {
    await _preferences.setString(sortKey, sort.storageKey);
  }
}

/// In-memory fake for tests: same contract, no platform needed.
class InMemoryVaultImageRepository implements VaultImageRepository {
  List<VaultImage> images;
  List<VaultAlbum> albums;
  VaultImageSort sort;

  InMemoryVaultImageRepository({
    List<VaultImage>? images,
    List<VaultAlbum>? albums,
    this.sort = VaultImageSort.newestFirst,
  })  : images = images ?? <VaultImage>[],
        albums = albums ?? <VaultAlbum>[];

  @override
  Future<List<VaultImage>> loadImages() async =>
      List<VaultImage>.unmodifiable(images);

  @override
  Future<void> saveImages(List<VaultImage> value) async {
    images = List<VaultImage>.from(value);
  }

  @override
  Future<List<VaultAlbum>> loadAlbums() async =>
      List<VaultAlbum>.unmodifiable(albums);

  @override
  Future<void> saveAlbums(List<VaultAlbum> value) async {
    albums = List<VaultAlbum>.from(value);
  }

  @override
  Future<VaultImageSort> loadSort() async => sort;

  @override
  Future<void> saveSort(VaultImageSort value) async {
    sort = value;
  }
}
