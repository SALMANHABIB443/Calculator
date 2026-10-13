import 'dart:convert';
import 'dart:typed_data';

import 'package:calculator/core/design/app_theme.dart';
import 'package:calculator/features/secret/documents/documents.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/vault_documents.dart';

/// One way in: the Documents screen, or its trash page, under the app's theme
/// and the document provider overrides, settled.
Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  VaultDocumentRepository? repository,
  FakeVaultDocumentPicker? picker,
  InMemoryVaultDocumentStore? store,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: vaultDocumentOverrides(
        repository: repository,
        picker: picker,
        store: store,
      ),
      child: MaterialApp(theme: AppTheme.dark, home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

/// A repository holding [documents], as the screen's data source.
InMemoryVaultDocumentRepository _repo(List<VaultDocument> documents) =>
    InMemoryVaultDocumentRepository(documents: documents);

/// Grows the surface so the whole landing page is inside the viewport, the way
/// the Secret-mode suites do: a `ListView` never builds a tail it cannot show,
/// so a bottom row would fail for a viewport reason rather than the one under
/// test.
void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder _rowMenu(String id) => find.descendant(
  of: find.byKey(Key('vault-document-$id')),
  matching: find.byIcon(Icons.more_vert),
);

Finder _headerMenu() => find.descendant(
  of: find.byType(VaultDocumentsHeader),
  matching: find.byIcon(Icons.more_vert),
);

Finder _chip(String label) => find.descendant(
  of: find.byType(VaultDocumentFilterBar),
  matching: find.text(label),
);

void main() {
  group('the landing page', () {
    testWidgets('an empty vault shows the full layout with an inline empty message', (
      tester,
    ) async {
      _useTallView(tester);
      await _pump(tester, const VaultDocumentsScreen());

      // The full layout is always visible: filter chips, Recent Documents,
      // Browse by type, All Documents, and the floating Home button.
      expect(find.text('No documents yet. Tap ADD to import.'), findsOneWidget);
      expect(find.text('RECENT DOCUMENTS'), findsOneWidget);
      expect(find.text('BROWSE BY TYPE'), findsOneWidget);
      expect(find.byKey(VaultDocumentsScreen.addButtonKey), findsOneWidget);
      expect(find.byKey(const Key('secret-home')), findsOneWidget);
    });

    testWidgets('Add imports a picked file into the list', (tester) async {
      _useTallView(tester);
      final picker = FakeVaultDocumentPicker(<PickedDocument>[
        pickedTextFile('Report.txt', 'hello vault'),
      ]);
      await _pump(tester, const VaultDocumentsScreen(), picker: picker);

      await tester.tap(find.byKey(VaultDocumentsScreen.addButtonKey));
      await tester.pumpAndSettle();

      expect(picker.calls, 1);
      expect(find.text('Report.txt'), findsOneWidget);
      expect(find.text('BROWSE BY TYPE'), findsOneWidget);
    });

    testWidgets('the collection row totals the visible documents', (
      tester,
    ) async {
      _useTallView(tester);
      await _pump(
        tester,
        const VaultDocumentsScreen(),
        repository: _repo(<VaultDocument>[
          seededDocument(id: 'a', fileName: 'Report.pdf', fileSize: 2048),
          seededDocument(id: 'b', fileName: 'notes.txt', fileSize: 1024),
        ]),
      );

      expect(find.text('Report.pdf'), findsOneWidget);
      expect(find.text('notes.txt'), findsOneWidget);
      // Count and a real size, read off the documents rather than hardcoded.
      expect(find.textContaining('2 files'), findsOneWidget);
      expect(find.textContaining('3.00 KB'), findsOneWidget);
    });

    testWidgets('a type chip filters the list in place', (tester) async {
      _useTallView(tester);
      await _pump(
        tester,
        const VaultDocumentsScreen(),
        repository: _repo(<VaultDocument>[
          seededDocument(id: 'a', fileName: 'Report.pdf'),
          seededDocument(id: 'b', fileName: 'notes.txt'),
        ]),
      );

      await tester.tap(_chip('PDF'));
      await tester.pumpAndSettle();

      expect(find.text('Report.pdf'), findsOneWidget);
      expect(find.text('notes.txt'), findsNothing);
    });

    testWidgets('search is instant and clears back to the full list', (
      tester,
    ) async {
      _useTallView(tester);
      await _pump(
        tester,
        const VaultDocumentsScreen(),
        repository: _repo(<VaultDocument>[
          seededDocument(id: 'a', fileName: 'Report.pdf'),
          seededDocument(id: 'b', fileName: 'notes.txt'),
        ]),
      );

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(VaultDocumentsScreen.searchFieldKey),
        'note',
      );
      await tester.pumpAndSettle();

      expect(find.text('notes.txt'), findsOneWidget);
      expect(find.text('Report.pdf'), findsNothing);

      await tester.enterText(
        find.byKey(VaultDocumentsScreen.searchFieldKey),
        'nothing matches this',
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No documents match the current search or filter'),
        findsOneWidget,
      );
    });

    testWidgets('the overflow sorts by name', (tester) async {
      _useTallView(tester);
      await _pump(
        tester,
        const VaultDocumentsScreen(),
        repository: _repo(<VaultDocument>[
          seededDocument(
            id: 'a',
            fileName: 'zeta.txt',
            dateAdded: DateTime(2026, 1, 2),
          ),
          seededDocument(
            id: 'b',
            fileName: 'alpha.txt',
            dateAdded: DateTime(2026, 1, 1),
          ),
        ]),
      );

      // Newest first by default: zeta (added later) sits above alpha.
      expect(
        tester.getTopLeft(find.text('zeta.txt')).dy,
        lessThan(tester.getTopLeft(find.text('alpha.txt')).dy),
      );

      await tester.tap(_headerMenu());
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(VaultDocumentSort.nameAz.label));
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('alpha.txt')).dy,
        lessThan(tester.getTopLeft(find.text('zeta.txt')).dy),
      );
    });

    testWidgets('a long-press starts a selection with a bottom bar', (
      tester,
    ) async {
      _useTallView(tester);
      await _pump(
        tester,
        const VaultDocumentsScreen(),
        repository: _repo(<VaultDocument>[
          seededDocument(id: 'a', fileName: 'Report.pdf'),
        ]),
      );

      await tester.longPress(find.text('Report.pdf'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
      expect(
        find.byKey(VaultDocumentsScreen.selectionBarKey),
        findsOneWidget,
      );
    });
  });

  group('row actions', () {
    testWidgets('the row menu renames a document', (tester) async {
      _useTallView(tester);
      await _pump(
        tester,
        const VaultDocumentsScreen(),
        repository: _repo(<VaultDocument>[
          seededDocument(id: 'a', fileName: 'Report.txt'),
        ]),
      );

      await tester.tap(_rowMenu('a'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Notes.txt');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Notes.txt'), findsOneWidget);
      expect(find.text('Report.txt'), findsNothing);
    });

    testWidgets('deleting asks first, then moves the row to the recycle bin', (
      tester,
    ) async {
      _useTallView(tester);
      await _pump(
        tester,
        const VaultDocumentsScreen(),
        repository: _repo(<VaultDocument>[
          seededDocument(id: 'a', fileName: 'Report.txt'),
        ]),
      );

      await tester.tap(_rowMenu('a'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Move document to recycle bin?'), findsOneWidget);
      await tester.tap(find.text('Move to recycle bin'));
      await tester.pumpAndSettle();

      expect(find.text('Report.txt'), findsNothing);
      expect(find.text('No documents yet. Tap ADD to import.'), findsOneWidget);
    });

    testWidgets('file info describes the document without leaking a path', (
      tester,
    ) async {
      _useTallView(tester);
      await _pump(
        tester,
        const VaultDocumentsScreen(),
        repository: _repo(<VaultDocument>[
          seededDocument(id: 'a', fileName: 'Report.pdf', fileSize: 2048),
        ]),
      );

      await tester.tap(_rowMenu('a'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('File info'));
      await tester.pumpAndSettle();

      expect(find.text('Encrypted in this app\'s vault'), findsOneWidget);
      // The sheet's own Size row; the list row and the collection subtitle
      // carry the same figure, so scope the finder to the bottom sheet.
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('2.00 KB'),
        ),
        findsOneWidget,
      );
    });
  });

  group('the viewer', () {
    testWidgets('a text document opens, shows its bytes, and Back returns', (
      tester,
    ) async {
      _useTallView(tester);
      final store = InMemoryVaultDocumentStore(harnessVaultCipher());
      await store.importBytes(
        Uint8List.fromList(utf8.encode('the file body')),
        'a.bin',
      );

      await _pump(
        tester,
        const VaultDocumentsScreen(),
        store: store,
        repository: _repo(<VaultDocument>[
          seededDocument(id: 'a', fileName: 'notes.txt'),
        ]),
      );

      await tester.tap(find.text('notes.txt'));
      await tester.pumpAndSettle();

      expect(find.byType(VaultDocumentViewerScreen), findsOneWidget);
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        'the file body',
      );

      await tester.tap(
        find.descendant(
          of: find.byType(VaultDocumentViewerScreen),
          matching: find.byIcon(Icons.arrow_back),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VaultDocumentsScreen), findsOneWidget);
      expect(find.byType(VaultDocumentViewerScreen), findsNothing);
    });

    testWidgets('a PDF renders through the injected viewer', (tester) async {
      _useTallView(tester);
      final store = InMemoryVaultDocumentStore(harnessVaultCipher());
      await store.importBytes(
        Uint8List.fromList(<int>[1, 2, 3, 4]),
        'a.bin',
      );

      await _pump(
        tester,
        const VaultDocumentsScreen(),
        store: store,
        repository: _repo(<VaultDocument>[
          seededDocument(id: 'a', fileName: 'Report.pdf'),
        ]),
      );

      await tester.tap(find.text('Report.pdf'));
      await tester.pumpAndSettle();

      expect(find.text('pdf-stub'), findsOneWidget);
    });

    testWidgets('a Word document says preview is unavailable and offers Share', (
      tester,
    ) async {
      _useTallView(tester);
      final store = InMemoryVaultDocumentStore(harnessVaultCipher());
      await store.importBytes(Uint8List.fromList(<int>[9, 9, 9]), 'a.bin');

      await _pump(
        tester,
        const VaultDocumentsScreen(),
        store: store,
        repository: _repo(<VaultDocument>[
          seededDocument(id: 'a', fileName: 'letter.docx'),
        ]),
      );

      await tester.tap(find.text('letter.docx'));
      await tester.pumpAndSettle();

      expect(find.text('Preview not available'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Share'), findsOneWidget);
    });

    testWidgets('a document whose bytes are gone shows an honest unavailable', (
      tester,
    ) async {
      _useTallView(tester);
      await _pump(
        tester,
        const VaultDocumentsScreen(),
        repository: _repo(<VaultDocument>[
          seededDocument(id: 'a', fileName: 'Report.pdf'),
        ]),
      );

      await tester.tap(find.text('Report.pdf'));
      await tester.pumpAndSettle();

      expect(find.text('Cannot open this document'), findsOneWidget);
    });
  });

  group('the collection page', () {
    testWidgets('a filtered page shows only its family', (tester) async {
      _useTallView(tester);
      await _pump(
        tester,
        const VaultDocumentsScreen(
          initialFilter: VaultDocumentFilter.pdf,
          title: 'PDF',
        ),
        repository: _repo(<VaultDocument>[
          seededDocument(id: 'a', fileName: 'Report.pdf'),
          seededDocument(id: 'b', fileName: 'notes.txt'),
        ]),
      );

      expect(find.text('Report.pdf'), findsOneWidget);
      expect(find.text('notes.txt'), findsNothing);
    });

    testWidgets('a family with nothing in it offers Add', (tester) async {
      _useTallView(tester);
      await _pump(
        tester,
        const VaultDocumentsScreen(
          initialFilter: VaultDocumentFilter.word,
          title: 'Word',
        ),
        repository: _repo(<VaultDocument>[
          seededDocument(id: 'a', fileName: 'Report.pdf'),
        ]),
      );

      expect(find.text('No Word documents in this vault.'), findsOneWidget);
      expect(find.byKey(VaultDocumentsScreen.addButtonKey), findsOneWidget);
    });

    testWidgets('the All-documents row pushes the full list', (tester) async {
      _useTallView(tester);
      await _pump(
        tester,
        const VaultDocumentsScreen(),
        repository: _repo(<VaultDocument>[
          seededDocument(id: 'a', fileName: 'Report.pdf'),
        ]),
      );

      await tester.ensureVisible(
        find.byKey(const Key('vault-documents-collection')),
      );
      await tester.pumpAndSettle();
      // Tap the row's InkWell directly: [SettingsRow] puts its key on the
      // outer column while the gesture area wraps only the label, so the
      // key's centre can miss it after a scroll.
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('vault-documents-collection')),
          matching: find.byType(InkWell),
        ),
      );
      await tester.pumpAndSettle();

      // The pushed collection page covers the landing page (an opaque route
      // keeps the landing offstage, so `byType` still finds one screen):
      // it shows the collection title and Back returns to the landing page.
      expect(find.byType(VaultDocumentsScreen), findsOneWidget);
      expect(find.text('Report.pdf'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('BROWSE BY TYPE'), findsOneWidget);
    });
  });

  group('the recycle bin', () {
    testWidgets('it lists trashed documents and restores one', (tester) async {
      _useTallView(tester);
      final store = InMemoryVaultDocumentStore(harnessVaultCipher());
      await store.importBytes(Uint8List.fromList(<int>[1, 2]), 'a.bin');
      await store.moveToTrash('a.bin');

      await _pump(
        tester,
        const VaultDocumentsTrashScreen(),
        store: store,
        repository: _repo(<VaultDocument>[
          seededDocument(
            id: 'a',
            fileName: 'old.txt',
            trashedAt: DateTime(2026, 2, 1),
          ),
        ]),
      );

      expect(find.text('old.txt'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('vault-document-trash-a')),
          matching: find.byIcon(Icons.more_vert),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();

      expect(find.text('Recycle bin is empty'), findsOneWidget);
    });

    testWidgets('an empty bin shows the place\'s own empty state', (
      tester,
    ) async {
      _useTallView(tester);
      await _pump(tester, const VaultDocumentsTrashScreen());

      expect(find.text('Recycle bin is empty'), findsOneWidget);
    });
  });

  group('duplicate import', () {
    testWidgets('a duplicate offers Import anyway and adds a suffixed copy', (
      tester,
    ) async {
      _useTallView(tester);
      // The vault already holds these exact bytes under the same name and
      // size, so the very first pick is refused as a duplicate — no prior
      // import round (and its queued snackbar) needed.
      // 'same bytes'.length == 10, which is what the name-and-size fallback
      // compares when the seeded record predates content hashes.
      final picker = FakeVaultDocumentPicker(<PickedDocument>[
        pickedTextFile('a.txt', 'same bytes'),
      ]);
      await _pump(
        tester,
        const VaultDocumentsScreen(),
        picker: picker,
        repository: _repo(<VaultDocument>[
          seededDocument(id: 'a', fileName: 'a.txt', fileSize: 10),
        ]),
      );

      await tester.tap(
        find.descendant(
          of: find.byType(VaultDocumentsHeader),
          matching: find.byIcon(Icons.more_vert),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add documents'));
      await tester.pumpAndSettle();

      // The duplicate offer rides as a SnackBarAction, whose label is a
      // property rather than a Text child — match it by predicate.
      final anyway = find.byWidgetPredicate(
        (widget) => widget is SnackBarAction && widget.label == 'Import anyway',
      );
      expect(anyway, findsOneWidget);

      await tester.tap(anyway);
      await tester.pumpAndSettle();

      expect(find.text('a (2).txt'), findsOneWidget);
    });
  });
}
