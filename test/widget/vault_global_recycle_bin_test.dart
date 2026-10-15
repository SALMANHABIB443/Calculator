import 'dart:convert';
import 'dart:typed_data';

import 'package:calculator/core/design/app_theme.dart';
import 'package:calculator/features/secret/documents/documents.dart';
import 'package:calculator/features/secret/images/data/shared_preferences_vault_image_repository.dart';
import 'package:calculator/features/secret/images/data/vault_image_store.dart';
import 'package:calculator/features/secret/images/domain/vault_image.dart';
import 'package:calculator/features/secret/images/presentation/vault_images_controller.dart';
import 'package:calculator/features/secret/images/presentation/vault_images_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/vault_documents.dart';

/// The Vault's recycle bin is the vault's **one** bin (FEAT-SEC-009, D-116).
///
/// Nothing else asserts the thing this file exists for: that a picture deleted
/// from the Gallery and a document deleted from Documents land in the *same*
/// list, and that restoring from here flips the very flag the gallery's own
/// Trash tab reads — so the two views can never disagree about one item.
///
/// The documents suite already covers the bin as a documents-only list; these
/// tests only pin the two additions that make it global.
void main() {
  group('the global recycle bin', () {
    testWidgets('a photo and a document deleted in the vault both land here', (
      tester,
    ) async {
      _useTallView(tester);
      await _pumpBin(
        tester,
        documents: <VaultDocument>[
          seededDocument(id: 'doc-1', fileName: 'report.pdf'),
        ],
        images: <VaultImage>[_liveImage(id: 'img-1', fileName: 'sunset.jpg')],
      );

      // Both are still live, so an empty bin is the honest answer.
      expect(find.text('Recycle bin is empty'), findsOneWidget);

      final container = _binContainer(tester);
      await container
          .read(vaultImagesProvider.notifier)
          .moveToTrash(<String>{'img-1'});
      await container
          .read(vaultDocumentsProvider.notifier)
          .moveToTrash(<String>{'doc-1'});
      await tester.pumpAndSettle();

      // One list, both kinds, each wearing its own row.
      expect(find.byKey(const Key('vault-image-trash-img-1')), findsOneWidget);
      expect(
        find.byKey(const Key('vault-document-trash-doc-1')),
        findsOneWidget,
      );
      expect(find.text('sunset.jpg'), findsOneWidget);
      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.text('Recycle bin is empty'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the newest deletion sits on top of the shared list', (
      tester,
    ) async {
      _useTallView(tester);
      await _pumpBin(
        tester,
        documents: <VaultDocument>[
          seededDocument(
            id: 'doc-1',
            fileName: 'report.pdf',
            trashedAt: DateTime.now().subtract(const Duration(days: 5)),
          ),
        ],
        images: <VaultImage>[
          _liveImage(
            id: 'img-1',
            fileName: 'sunset.jpg',
            trashedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ],
      );

      expect(find.byKey(VaultDocumentsTrashScreen.listKey), findsOneWidget);

      final photoY = tester
          .getTopLeft(find.byKey(const Key('vault-image-trash-img-1')))
          .dy;
      final documentY = tester
          .getTopLeft(find.byKey(const Key('vault-document-trash-doc-1')))
          .dy;
      expect(
        photoY,
        lessThan(documentY),
        reason: 'the photo went three days later, so it sorts first',
      );
    });

    testWidgets('restoring a photo here clears the gallery Trash flag', (
      tester,
    ) async {
      _useTallView(tester);
      await _pumpBin(
        tester,
        images: <VaultImage>[
          _liveImage(
            id: 'img-1',
            fileName: 'sunset.jpg',
            trashedAt: DateTime(2026, 2, 5),
          ),
        ],
      );
      expect(find.text('sunset.jpg'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('vault-image-trash-img-1')),
          matching: find.byIcon(Icons.more_vert),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();

      final images = _binContainer(tester)
          .read(vaultImagesProvider)
          .requireValue
          .images;
      expect(images.single.isTrashed, isFalse);
      expect(find.text('Recycle bin is empty'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Grows the surface so every row lands inside the viewport — a `ListView` never
/// builds a tail it cannot show, and a bottom-row failure would then be a
/// viewport failure rather than the one under test.
void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// The provider container the bin itself is attached to, so a test can drive a
/// deletion through the same notifiers the real pages do.
ProviderContainer _binContainer(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(VaultDocumentsTrashScreen)),
  );
}

/// Renders the bin over [documents] and [images], with every seam it touches
/// replaced by an in-memory double: no filesystem, no plugin, no cipher.
Future<void> _pumpBin(
  WidgetTester tester, {
  List<VaultDocument> documents = const <VaultDocument>[],
  List<VaultImage> images = const <VaultImage>[],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        ...vaultDocumentOverrides(
          repository: InMemoryVaultDocumentRepository(documents: documents),
        ),
        vaultImageRepositoryProvider.overrideWith(
          (ref) async => InMemoryVaultImageRepository(images: images),
        ),
        vaultImageStoreProvider.overrideWithValue(_PixelStore()),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const VaultDocumentsTrashScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A live gallery picture; hand it [trashedAt] to put it in the bin's state.
VaultImage _liveImage({
  required String id,
  required String fileName,
  DateTime? trashedAt,
}) => VaultImage(
  id: id,
  fileName: fileName,
  vaultFileName: '$id.jpg',
  mimeType: 'image/jpeg',
  fileSize: 1024,
  dateAdded: DateTime(2026, 2, 1),
  dateModified: DateTime(2026, 2, 1),
  trashedAt: trashedAt,
);

/// A byte store that answers every read with one real pixel.
///
/// The bin draws a thumbnail straight from the gallery store, and a test host
/// has no app-private directory to read a genuine one from. The pixels are a
/// valid 1×1 PNG rather than a placeholder so `Image.memory` decodes instead of
/// reporting a codec error through the test framework.
class _PixelStore extends VaultImageStore {
  static final Uint8List _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
    'AAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  );

  @override
  Future<Uint8List?> readBytes(
    String vaultFileName, {
    bool trashed = false,
  }) async => _png;

  @override
  Future<void> importBytes(Uint8List bytes, String vaultFileName) async {}

  @override
  Future<void> moveToTrash(String vaultFileName) async {}

  @override
  Future<void> restoreFromTrash(String vaultFileName) async {}

  @override
  Future<void> deletePermanently(String vaultFileName) async {}

  @override
  Future<bool> get isEmpty async => false;
}
