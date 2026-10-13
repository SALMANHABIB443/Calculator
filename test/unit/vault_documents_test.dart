import 'dart:convert';
import 'dart:typed_data';

import 'package:calculator/features/secret/documents/documents.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/vault_documents.dart';

/// Naive substring search, so a test can assert a plaintext string does not
/// appear anywhere inside a ciphertext blob.
bool _contains(Uint8List haystack, List<int> needle) {
  if (needle.isEmpty) return true;
  for (var start = 0; start + needle.length <= haystack.length; start++) {
    var matches = true;
    for (var offset = 0; offset < needle.length; offset++) {
      if (haystack[start + offset] != needle[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}

/// A fresh container over the doubles, with an empty preferences mock.
ProviderContainer _container({
  VaultDocumentRepository? repository,
  FakeVaultDocumentPicker? picker,
  InMemoryVaultDocumentStore? store,
}) {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final container = ProviderContainer(
    overrides: vaultDocumentOverrides(
      repository: repository,
      picker: picker,
      store: store,
    ),
  );
  addTearDown(container.dispose);
  return container;
}

Future<VaultDocumentsState> _state(ProviderContainer container) async {
  await container.read(vaultDocumentsProvider.future);
  return container.read(vaultDocumentsProvider).requireValue;
}

/// The notifier, re-read each time: every mutation invalidates the provider, so
/// a reference captured before one is stale for the next.
VaultDocumentsNotifier _notifier(ProviderContainer container) =>
    container.read(vaultDocumentsProvider.notifier);

void main() {
  group('file type detection', () {
    test('extension decides the family, not case', () {
      expect(VaultDocumentType.fromFileName('a.pdf'), VaultDocumentType.pdf);
      expect(VaultDocumentType.fromFileName('A.PDF'), VaultDocumentType.pdf);
      expect(VaultDocumentType.fromFileName('a.doc'), VaultDocumentType.word);
      expect(VaultDocumentType.fromFileName('a.docx'), VaultDocumentType.word);
      expect(VaultDocumentType.fromFileName('a.txt'), VaultDocumentType.text);
      expect(VaultDocumentType.fromFileName('a.md'), VaultDocumentType.text);
      expect(VaultDocumentType.fromFileName('a.log'), VaultDocumentType.text);
      expect(VaultDocumentType.fromFileName('a.zip'), VaultDocumentType.other);
      expect(VaultDocumentType.fromFileName('README'), VaultDocumentType.other);
    });

    test('a leading dot or a trailing dot is not an extension', () {
      // `.gitignore` is a whole name, and `a.` ends in a separator that names
      // nothing — neither should be read as extension "gitignore" or "".
      expect(VaultDocumentType.fromFileName('.gitignore'), VaultDocumentType.other);
      expect(VaultDocumentType.fromFileName('a.'), VaultDocumentType.other);
    });

    test('the label is the uppercase extension, or FILE', () {
      expect(VaultDocumentType.extensionLabel('Report.PDF'), 'PDF');
      expect(VaultDocumentType.extensionLabel('notes.docx'), 'DOCX');
      expect(VaultDocumentType.extensionLabel('no-extension'), 'FILE');
      expect(VaultDocumentType.extensionLabel('.env'), 'FILE');
    });
  });

  group('the cipher', () {
    test('round-trips and stores no plaintext', () async {
      final cipher = harnessVaultCipher();
      final plain = Uint8List.fromList(utf8.encode('the secret report body'));
      final stored = await cipher.encrypt(plain);

      expect(stored, isNot(equals(plain)));
      expect(_contains(stored, plain), isFalse,
          reason: 'the plaintext must not appear in the blob');
      expect(await cipher.decrypt(stored), plain);
    });

    test('a fresh nonce makes two encryptions of one input differ', () async {
      final cipher = harnessVaultCipher();
      final plain = Uint8List.fromList(utf8.encode('same'));
      final first = await cipher.encrypt(plain);
      final second = await cipher.encrypt(plain);
      expect(first, isNot(equals(second)));
    });

    test('a flipped byte fails closed', () async {
      final cipher = harnessVaultCipher();
      final stored = await cipher.encrypt(
        Uint8List.fromList(utf8.encode('tamper me')),
      );
      stored[stored.length - 1] ^= 0xFF;
      await expectLater(
        cipher.decrypt(stored),
        throwsA(isA<VaultDecryptionException>()),
      );
    });

    test('a wrong key fails closed rather than returning garbage', () async {
      final encrypter = AesGcmVaultDocumentCipher(
        InMemoryVaultKeySource(Uint8List.fromList(List<int>.filled(32, 7))),
      );
      final decrypter = AesGcmVaultDocumentCipher(
        InMemoryVaultKeySource(Uint8List.fromList(List<int>.filled(32, 9))),
      );
      final stored = await encrypter.encrypt(
        Uint8List.fromList(utf8.encode('secret')),
      );
      await expectLater(
        decrypter.decrypt(stored),
        throwsA(isA<VaultDecryptionException>()),
      );
    });

    test('a blob too short to hold a nonce and tag is rejected', () async {
      final cipher = harnessVaultCipher();
      await expectLater(
        cipher.decrypt(Uint8List.fromList(<int>[1, 2, 3])),
        throwsA(isA<VaultDecryptionException>()),
      );
    });
  });

  group('the repository', () {
    test('round-trips metadata and sort through shared_preferences', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesVaultDocumentRepository(preferences);

      expect(await repository.loadDocuments(), isEmpty);
      expect(await repository.loadSort(), VaultDocumentSort.newestFirst);

      await repository.saveDocuments(<VaultDocument>[
        seededDocument(id: 'a', fileName: 'Report.pdf', contentHash: 'abc'),
      ]);
      await repository.saveSort(VaultDocumentSort.nameAz);

      final loaded = await repository.loadDocuments();
      expect(loaded.single.fileName, 'Report.pdf');
      expect(loaded.single.contentHash, 'abc');
      expect(await repository.loadSort(), VaultDocumentSort.nameAz);
    });

    test('corrupt metadata degrades to an empty list', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPreferencesVaultDocumentRepository.documentsKey: 'not-json',
      });
      final repository = SharedPreferencesVaultDocumentRepository(
        await SharedPreferences.getInstance(),
      );
      expect(await repository.loadDocuments(), isEmpty);
    });
  });

  group('the import path', () {
    test('a picked file lands in the vault encrypted', () async {
      final store = InMemoryVaultDocumentStore(harnessVaultCipher());
      final picker = FakeVaultDocumentPicker(<PickedDocument>[
        pickedTextFile('Report.txt', 'hello vault'),
      ]);
      final container = _container(store: store, picker: picker);
      await container.read(vaultDocumentsProvider.future);

      final result = await _notifier(container).importDocuments();
      expect(result.imported, 1);
      expect(result.failed, 0);
      expect(picker.calls, 1);

      final state = await _state(container);
      final document = state.visible.single;
      expect(document.fileName, 'Report.txt');
      expect(document.type, VaultDocumentType.text);
      expect(document.fileSize, utf8.encode('hello vault').length);
      expect(document.contentHash, isNotNull);

      final stored = store.ciphertextOf(document.vaultFileName)!;
      expect(_contains(stored, utf8.encode('hello vault')), isFalse,
          reason: 'the vault must not hold the plaintext');
      expect(
        utf8.decode((await store.readBytes(document.vaultFileName))!),
        'hello vault',
        reason: 'the store must decrypt back to what was imported',
      );
    });

    test('cancelling the picker imports nothing', () async {
      final container = _container(picker: FakeVaultDocumentPicker());
      await container.read(vaultDocumentsProvider.future);

      final result = await _notifier(container).importDocuments();
      expect(result.cancelled, isTrue);
      expect((await _state(container)).visible, isEmpty);
    });

    test('the same bytes a second time are reported as a duplicate', () async {
      final picker = FakeVaultDocumentPicker(<PickedDocument>[
        pickedTextFile('a.txt', 'same bytes'),
      ]);
      final container = _container(picker: picker);
      await container.read(vaultDocumentsProvider.future);

      await _notifier(container).importDocuments();
      final second = await _notifier(container).importDocuments();

      expect(second.imported, 0);
      expect(second.duplicates, hasLength(1));
      expect((await _state(container)).visible, hasLength(1));
    });

    test('a forced import disambiguates the name', () async {
      final picker = FakeVaultDocumentPicker(<PickedDocument>[
        pickedTextFile('a.txt', 'same bytes'),
      ]);
      final container = _container(picker: picker);
      await container.read(vaultDocumentsProvider.future);

      await _notifier(container).importDocuments();
      final again = await _notifier(container).importDocuments();
      final forced = await _notifier(container).importDocuments(
        selection: again.duplicates,
        allowDuplicates: true,
      );

      expect(forced.imported, 1);
      final names = (await _state(container)).visible.map((e) => e.fileName);
      expect(names, containsAll(<String>['a.txt', 'a (2).txt']));
    });

    test('identical bytes are a duplicate whatever the file is called', () async {
      final picker = FakeVaultDocumentPicker(<PickedDocument>[
        pickedTextFile('a.txt', 'same bytes'),
      ]);
      final container = _container(picker: picker);
      await container.read(vaultDocumentsProvider.future);
      await _notifier(container).importDocuments();

      picker.picked = <PickedDocument>[pickedTextFile('a.md', 'same bytes')];
      final result = await _notifier(container).importDocuments();

      // The content hash is the real test: a file with identical bytes is the
      // same document, so renaming it is not a way to smuggle in a twin.
      expect(result.imported, 0);
      expect(result.duplicates, hasLength(1));
    });

    test('an empty file is counted as failed, not stored', () async {
      final picker = FakeVaultDocumentPicker(<PickedDocument>[
        PickedDocument(name: 'empty.txt', bytes: Uint8List(0)),
      ]);
      final container = _container(picker: picker);
      await container.read(vaultDocumentsProvider.future);

      final result = await _notifier(container).importDocuments();
      expect(result.imported, 0);
      expect(result.failed, 1);
      expect((await _state(container)).visible, isEmpty);
    });
  });

  group('rename, trash, and sort', () {
    test('rename keeps the extension when the new name omits one', () async {
      final container = _container(
        picker: FakeVaultDocumentPicker(<PickedDocument>[
          pickedTextFile('Report.txt', 'x'),
        ]),
      );
      await container.read(vaultDocumentsProvider.future);
      await _notifier(container).importDocuments();
      final id = (await _state(container)).visible.single.id;

      await _notifier(container).renameDocument(id, 'Notes');
      expect((await _state(container)).visible.single.fileName, 'Notes.txt');
    });

    test('rename rejects an empty name and a name already worn', () async {
      final container = _container(
        repository: InMemoryVaultDocumentRepository(
          documents: <VaultDocument>[
            seededDocument(id: 'a', fileName: 'a.txt'),
            seededDocument(id: 'b', fileName: 'b.txt'),
          ],
        ),
      );
      await container.read(vaultDocumentsProvider.future);

      await expectLater(
        _notifier(container).renameDocument('a', '  '),
        throwsA(isA<VaultDocumentNameException>()),
      );
      await expectLater(
        _notifier(container).renameDocument('a', 'b.txt'),
        throwsA(isA<VaultDocumentNameException>()),
      );
    });

    test('trashing hides a document, restoring brings it back', () async {
      final store = InMemoryVaultDocumentStore(harnessVaultCipher());
      final container = _container(
        store: store,
        picker: FakeVaultDocumentPicker(<PickedDocument>[
          pickedTextFile('Report.txt', 'hello'),
        ]),
      );
      await container.read(vaultDocumentsProvider.future);
      await _notifier(container).importDocuments();
      final document = (await _state(container)).visible.single;

      await _notifier(container).moveToTrash(<String>{document.id});
      var state = await _state(container);
      expect(state.visible, isEmpty);
      expect(state.trash.map((e) => e.id), <String>[document.id]);
      expect(store.trashedCiphertextOf(document.vaultFileName), isNotNull);

      await _notifier(container).restoreFromTrash(<String>{document.id});
      state = await _state(container);
      expect(state.visible.map((e) => e.id), <String>[document.id]);
      expect(state.trash, isEmpty);
    });

    test('deleting permanently removes both the row and the bytes', () async {
      final store = InMemoryVaultDocumentStore(harnessVaultCipher());
      final container = _container(
        store: store,
        picker: FakeVaultDocumentPicker(<PickedDocument>[
          pickedTextFile('Report.txt', 'hello'),
        ]),
      );
      await container.read(vaultDocumentsProvider.future);
      await _notifier(container).importDocuments();
      final document = (await _state(container)).visible.single;

      await _notifier(container).deletePermanently(<String>{document.id});
      expect((await _state(container)).documents, isEmpty);
      expect(store.ciphertextOf(document.vaultFileName), isNull);
      expect(await store.isEmpty, isTrue);
    });

    test('sort reorders the resolved list', () async {
      final container = _container(
        repository: InMemoryVaultDocumentRepository(
          documents: <VaultDocument>[
            seededDocument(
              id: 'a',
              fileName: 'zeta.txt',
              fileSize: 10,
              dateAdded: DateTime(2026, 1, 1),
            ),
            seededDocument(
              id: 'b',
              fileName: 'alpha.txt',
              fileSize: 20,
              dateAdded: DateTime(2026, 1, 3),
            ),
          ],
        ),
      );
      final state = await _state(container);
      const view = VaultDocumentView();

      // Newest first by default: 'b' was added later.
      expect(state.resolve(view).map((e) => e.id), <String>['b', 'a']);

      await _notifier(container).setSort(VaultDocumentSort.nameAz);
      final sorted = await _state(container);
      expect(sorted.sort, VaultDocumentSort.nameAz);
      expect(sorted.resolve(view).map((e) => e.id), <String>['b', 'a']);

      await _notifier(container).setSort(VaultDocumentSort.oldestFirst);
      final oldest = await _state(container);
      expect(oldest.resolve(view).map((e) => e.id), <String>['a', 'b']);
    });

    test('readDocument hands back the bytes, and throws when they are gone',
        () async {
      final container = _container(
        repository: InMemoryVaultDocumentRepository(
          documents: <VaultDocument>[seededDocument(id: 'a', fileName: 'a.txt')],
        ),
      );
      await container.read(vaultDocumentsProvider.future);
      final document = (await _state(container)).visible.single;

      await expectLater(
        _notifier(container).readDocument(document),
        throwsA(isA<VaultDocumentMissingException>()),
      );
    });
  });

  group('the state view', () {
    test('search is case-insensitive and matches the file name', () {
      final state = VaultDocumentsState(
        documents: <VaultDocument>[
          seededDocument(id: 'a', fileName: 'Report.pdf'),
          seededDocument(id: 'b', fileName: 'notes.txt'),
        ],
        sort: VaultDocumentSort.newestFirst,
      );
      expect(
        state.resolve(const VaultDocumentView(query: 'rep')).map((e) => e.id),
        <String>['a'],
      );
      expect(
        state.resolve(const VaultDocumentView(query: 'NOPE')),
        isEmpty,
      );
    });

    test('the type filter narrows to one family', () {
      final state = VaultDocumentsState(
        documents: <VaultDocument>[
          seededDocument(id: 'a', fileName: 'Report.pdf'),
          seededDocument(id: 'b', fileName: 'notes.txt'),
          seededDocument(id: 'c', fileName: 'letter.docx'),
        ],
        sort: VaultDocumentSort.newestFirst,
      );
      expect(
        state
            .resolve(const VaultDocumentView(typeFilter: VaultDocumentFilter.pdf))
            .map((e) => e.id),
        <String>['a'],
      );
      expect(state.countOf(VaultDocumentFilter.word), 1);
      expect(state.countOf(VaultDocumentFilter.all), 3);
      expect(state.countOf(VaultDocumentFilter.text), 1);
    });

    test('counts and total size ignore the recycle bin', () {
      final state = VaultDocumentsState(
        documents: <VaultDocument>[
          seededDocument(id: 'a', fileName: 'a.txt', fileSize: 100),
          seededDocument(id: 'b', fileName: 'b.txt', fileSize: 50),
          seededDocument(
            id: 'c',
            fileName: 'c.txt',
            fileSize: 999,
            trashedAt: DateTime(2026, 2, 1),
          ),
        ],
        sort: VaultDocumentSort.newestFirst,
      );
      expect(state.visible, hasLength(2));
      expect(state.trash, hasLength(1));
      expect(state.totalBytes, 150);
      expect(state.trashBytes, 999);
      expect(state.countOf(VaultDocumentFilter.all), 2);
    });
  });

  group('the record', () {
    test('round-trips through JSON, including the trash timestamp', () {
      final document = seededDocument(
        id: 'a',
        fileName: 'Report.pdf',
        contentHash: 'deadbeef',
        trashedAt: DateTime(2026, 3, 4, 5, 6),
      );
      final restored = VaultDocument.fromJson(document.toJson())!;
      expect(restored.id, 'a');
      expect(restored.fileName, 'Report.pdf');
      expect(restored.contentHash, 'deadbeef');
      expect(restored.trashedAt, DateTime(2026, 3, 4, 5, 6));
      expect(restored.isTrashed, isTrue);
    });

    test('a record missing a required field is refused, not guessed', () {
      expect(VaultDocument.fromJson(<String, dynamic>{'id': 'a'}), isNull);
    });
  });
}
