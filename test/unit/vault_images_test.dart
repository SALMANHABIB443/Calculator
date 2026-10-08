import 'package:calculator/features/secret/images/data/shared_preferences_vault_image_repository.dart';
import 'package:calculator/features/secret/images/domain/vault_image.dart';
import 'package:calculator/features/secret/images/presentation/vault_images_state.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
