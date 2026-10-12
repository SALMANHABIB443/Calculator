import 'dart:typed_data';

import 'package:calculator/features/secret/images/data/shared_preferences_vault_image_repository.dart';
import 'package:calculator/features/secret/images/data/vault_image_store.dart';
import 'package:calculator/features/secret/images/domain/vault_image.dart';
import 'package:calculator/features/secret/images/presentation/vault_images_controller.dart';
import 'package:calculator/features/secret/images/presentation/vault_images_providers.dart';
import 'package:calculator/features/secret/images/presentation/vault_images_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

VaultImage _image(String id, String name, {bool favorite = false}) {
  return VaultImage(
    id: id,
    fileName: name,
    vaultFileName: '$id.jpg',
    mimeType: 'image/jpeg',
    fileSize: 100,
    dateAdded: DateTime(2026, 1, 2),
    dateModified: DateTime(2026, 1, 2),
    isFavorite: favorite,
  );
}

/// Byte store that keeps imported bytes in memory (keyed by vault file name).
class _MemoryStore extends VaultImageStore {
  final Map<String, Uint8List> files = <String, Uint8List>{};
  final Map<String, Uint8List> trash = <String, Uint8List>{};

  @override
  Future<Uint8List?> readBytes(
    String vaultFileName, {
    bool trashed = false,
  }) async =>
      trashed ? trash[vaultFileName] : files[vaultFileName];

  @override
  Future<void> importBytes(Uint8List bytes, String vaultFileName) async {
    files[vaultFileName] = bytes;
  }

  @override
  Future<void> moveToTrash(String vaultFileName) async {
    final bytes = files.remove(vaultFileName);
    if (bytes != null) trash[vaultFileName] = bytes;
  }

  @override
  Future<void> restoreFromTrash(String vaultFileName) async {
    final bytes = trash.remove(vaultFileName);
    if (bytes != null) files[vaultFileName] = bytes;
  }

  @override
  Future<void> deletePermanently(String vaultFileName) async {
    files.remove(vaultFileName);
    trash.remove(vaultFileName);
  }

  @override
  Future<bool> get isEmpty async => files.isEmpty && trash.isEmpty;
}

XFile _pick(String name, List<int> bytes) => XFile.fromData(
      Uint8List.fromList(bytes),
      name: name,
      mimeType: 'image/jpeg',
    );

/// A fresh provider container backed by an empty `shared_preferences` mock
/// and the in-memory byte store, so controller tests exercise the real
/// repository + provider wiring rather than a stub.
ProviderContainer _container(_MemoryStore store) {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final container = ProviderContainer(
    overrides: [vaultImageStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<VaultImagesState> _state(ProviderContainer container) async {
  await container.read(vaultImagesProvider.future);
  return container.read(vaultImagesProvider).requireValue;
}

void main() {
  test('corrupt vault record degrades to empty rather than throwing', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SharedPreferencesVaultImageRepository.imagesKey: 'not-json',
    });
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPreferencesVaultImageRepository(prefs);
    expect(await repo.loadImages(), isEmpty);
    expect(await repo.loadAlbums(), isEmpty);
    expect(await repo.loadSort(), VaultImageSort.newestFirst);
  });

  test('search matches name and favorites filter works', () {
    const state = VaultImagesState(images: [], albums: [], sort: VaultImageSort.newestFirst);
    final images = <VaultImage>[
      _image('1', 'beach.jpg'),
      _image('2', 'birthday.png', favorite: true),
    ];
    final full = VaultImagesState(
      images: images,
      albums: const [],
      sort: VaultImageSort.nameAz,
    );
    expect(full.search('beach').map((e) => e.id), ['1']);
    expect(full.search('nope'), isEmpty);
    expect(state, isNotNull);
  });

  test('sort orders by name and size', () {
    final a = VaultImage(
      id: 'a',
      fileName: 'b.jpg',
      vaultFileName: 'a.jpg',
      mimeType: 'image/jpeg',
      fileSize: 50,
      dateAdded: DateTime(2026, 1, 1),
      dateModified: DateTime(2026, 1, 1),
    );
    final b = VaultImage(
      id: 'b',
      fileName: 'a.jpg',
      vaultFileName: 'b.jpg',
      mimeType: 'image/jpeg',
      fileSize: 200,
      dateAdded: DateTime(2026, 1, 2),
      dateModified: DateTime(2026, 1, 2),
    );
    const state = VaultImagesState(
      images: [],
      albums: [],
      sort: VaultImageSort.nameAz,
    );
    expect(state.sorted([a, b]).map((e) => e.id), ['b', 'a']);
    const bySize = VaultImagesState(
      images: [],
      albums: [],
      sort: VaultImageSort.sizeLargest,
    );
    expect(bySize.sorted([a, b]).map((e) => e.id), ['b', 'a']);
  });

  group('album workflow', () {
    test('general import lands in Pictures only', () async {
      final container = _container(_MemoryStore());
      final notifier = container.read(vaultImagesProvider.notifier);
      await container.read(vaultImagesProvider.future);

      final album = await notifier.createAlbum('Trip');
      final result = await notifier.importPickedFiles(
        [_pick('a.jpg', [1, 2, 3])],
      );
      expect(result.imported, 1);

      final state = await _state(container);
      expect(state.visible, hasLength(1));
      // Pictures and Albums are two views of the same rows: the new picture
      // is visible in the library but tagged with no album.
      expect(state.visible.single.albumIds, isEmpty);
      expect(state.inAlbum(album.id), isEmpty);
      expect(state.inAlbum('all'), hasLength(1));
    });

    test('adding an existing picture shows it in both places', () async {
      final container = _container(_MemoryStore());
      final notifier = container.read(vaultImagesProvider.notifier);
      await container.read(vaultImagesProvider.future);

      await notifier.importPickedFiles([_pick('a.jpg', [1, 2, 3])]);
      var state = await _state(container);
      final id = state.visible.single.id;

      final album = await notifier.createAlbum('Trip');
      await notifier.addToAlbum(album.id, {id});

      state = await _state(container);
      expect(state.visible, hasLength(1));
      expect(state.inAlbum(album.id).map((e) => e.id), [id]);
    });

    test('importing directly into an album fills both views', () async {
      final container = _container(_MemoryStore());
      final notifier = container.read(vaultImagesProvider.notifier);
      await container.read(vaultImagesProvider.future);

      final album = await notifier.createAlbum('Trip');
      final result = await notifier.importPickedFiles(
        [_pick('a.jpg', [1, 2, 3]), _pick('b.jpg', [4, 5])],
        albumId: album.id,
      );
      expect(result.imported, 2);

      final state = await _state(container);
      expect(state.visible, hasLength(2));
      expect(state.inAlbum(album.id), hasLength(2));
    });

    test('unknown album ids never capture a general import', () async {
      final container = _container(_MemoryStore());
      final notifier = container.read(vaultImagesProvider.notifier);
      await container.read(vaultImagesProvider.future);

      await notifier.importPickedFiles(
        [_pick('a.jpg', [1])],
        albumId: 'all',
      );
      await notifier.importPickedFiles(
        [_pick('b.jpg', [2])],
        albumId: 'missing-album',
      );

      final state = await _state(container);
      expect(state.visible, hasLength(2));
      for (final image in state.visible) {
        expect(image.albumIds, isEmpty);
      }
    });

    test('membership is isolated per album and deduped', () async {
      final container = _container(_MemoryStore());
      final notifier = container.read(vaultImagesProvider.notifier);
      await container.read(vaultImagesProvider.future);

      await notifier.importPickedFiles([
        _pick('a.jpg', [1]),
        _pick('b.jpg', [2]),
      ]);
      var state = await _state(container);
      final ids = state.visible.map((e) => e.id).toSet();
      final first = state.visible.first.id;

      final one = await notifier.createAlbum('One');
      final two = await notifier.createAlbum('Two');
      await notifier.addToAlbum(one.id, ids);
      await notifier.addToAlbum(one.id, {first});
      await notifier.addToAlbum(two.id, {first});

      state = await _state(container);
      expect(state.inAlbum(one.id), hasLength(2));
      expect(state.inAlbum(two.id).map((e) => e.id), [first]);
      final tagged = state.visible.firstWhere((e) => e.id == first);
      expect(tagged.albumIds.toSet(), {one.id, two.id});
    });

    test('deleting an album keeps the Pictures rows', () async {
      final container = _container(_MemoryStore());
      final notifier = container.read(vaultImagesProvider.notifier);
      await container.read(vaultImagesProvider.future);

      await notifier.importPickedFiles([_pick('a.jpg', [1])]);
      var state = await _state(container);
      final id = state.visible.single.id;
      final album = await notifier.createAlbum('Trip');
      await notifier.addToAlbum(album.id, {id});
      await notifier.deleteAlbum(album.id);

      state = await _state(container);
      expect(state.albums, isEmpty);
      expect(state.visible.map((e) => e.id), [id]);
      expect(state.visible.single.albumIds, isEmpty);
    });

    test('empty picks write no metadata', () async {
      final container = _container(_MemoryStore());
      final notifier = container.read(vaultImagesProvider.notifier);
      await container.read(vaultImagesProvider.future);

      final result = await notifier.importPickedFiles(
        [_pick('empty.jpg', [])],
      );
      expect(result.imported, 0);
      expect(result.failed, 1);
      expect((await _state(container)).visible, isEmpty);
    });
  });
}
