import 'dart:convert';

import 'package:calculator/core/design/app_theme.dart';
import 'package:calculator/core/widgets/core_widgets.dart';
import 'package:calculator/features/history/domain/history_entry.dart';
import 'package:calculator/features/secret/documents/documents.dart';
import 'package:calculator/features/secret/images/data/shared_preferences_vault_image_repository.dart';
import 'package:calculator/features/secret/images/domain/vault_image.dart';
import 'package:calculator/features/secret/images/presentation/vault_gallery_widgets.dart';
import 'package:calculator/features/secret/images/presentation/vault_images_screen.dart';
import 'package:calculator/features/secret/presentation/vault_place.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/pump_app.dart';
import '../support/vault_documents.dart';

/// Drives the long-press-then-drag gesture that paints a selection (D-120).
///
/// Presses and holds [from] until the long-press fires, then moves through
/// [path] and lifts. [path] is read *after* the hold rather than before,
/// because a press can swap the body underneath the finger — the documents
/// landing page hands over to its selection list — and the points a test aims
/// at have to be the ones on screen while the drag is happening.
Future<void> longPressPaint(
  WidgetTester tester, {
  required Finder from,
  required List<Offset> Function() path,
}) async {
  final gesture = await tester.startGesture(tester.getCenter(from));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  for (final point in path()) {
    await gesture.moveTo(point);
    await tester.pump();
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// History
// ---------------------------------------------------------------------------

HistoryEntry _entry(String expression, String result, double value) =>
    HistoryEntry(
      id: 'id-$expression',
      expression: expression,
      result: result,
      resultValue: value,
      timestamp: DateTime.now(),
    );

/// Three entries, oldest first — the order `mockHistoryStore` wants. On screen
/// they read newest first, so the top card is `3 + 3`.
List<HistoryEntry> _history() => [
  _entry('1 + 1', '2', 2),
  _entry('2 + 2', '4', 4),
  _entry('3 + 3', '6', 6),
];

// ---------------------------------------------------------------------------
// Images
// ---------------------------------------------------------------------------

void _seedGallery(int count) {
  final base = DateTime(2026, 1, 1);
  SharedPreferences.setMockInitialValues(<String, Object>{
    SharedPreferencesVaultImageRepository.imagesKey: jsonEncode(<Map<String, dynamic>>[
      for (var i = 0; i < count; i++)
        VaultImage(
          id: 'img-$i',
          fileName: 'photo-$i.jpg',
          vaultFileName: 'photo-$i.jpg',
          mimeType: 'image/jpeg',
          fileSize: 1024,
          dateAdded: base.add(Duration(days: i)),
          dateModified: base.add(Duration(days: i)),
        ).toJson(),
    ]),
  });
}

Widget _gallery() => const ProviderScope(
  child: MaterialApp(home: VaultPlaceScreen(placeId: 'images')),
);

// ---------------------------------------------------------------------------
// Documents
// ---------------------------------------------------------------------------

void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpDocuments(
  WidgetTester tester,
  List<VaultDocument> documents,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: vaultDocumentOverrides(
        repository: InMemoryVaultDocumentRepository(documents: documents),
      ),
      child: MaterialApp(theme: AppTheme.dark, home: const VaultDocumentsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('History (D-120)', () {
    testWidgets('a hold and drag paints every row the finger crosses', (
      tester,
    ) async {
      await pumpApp(tester, history: _history());
      await openHistory(tester);

      expect(find.byType(AppSelectionHeader), findsNothing);

      await longPressPaint(
        tester,
        from: find.text('3 + 3'),
        path: () => [
          tester.getCenter(find.text('2 + 2')),
          tester.getCenter(find.text('1 + 1')),
        ],
      );

      // All three, including the row in the middle that the finger only passed
      // over: the drag paints what it crosses, not just where it started and
      // stopped.
      expect(find.text('3 selected'), findsOneWidget);
      expect(find.byType(AppSelectionHeader), findsOneWidget);
    });

    testWidgets('a drag that starts on a chosen row removes the rows it crosses', (
      tester,
    ) async {
      await pumpApp(tester, history: _history());
      await openHistory(tester);

      // Choose everything first, so the second gesture has something to take
      // away and a survivor to leave behind.
      await longPressPaint(
        tester,
        from: find.text('3 + 3'),
        path: () => [
          tester.getCenter(find.text('2 + 2')),
          tester.getCenter(find.text('1 + 1')),
        ],
      );
      expect(find.text('3 selected'), findsOneWidget);

      await longPressPaint(
        tester,
        from: find.text('3 + 3'),
        path: () => [
          tester.getCenter(find.text('2 + 2')),
        ],
      );

      // The press landed on a chosen row, so the drag removed rather than
      // added: `1 + 1` is the one the finger never touched.
      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('an ordinary quick drag scrolls without selecting', (
      tester,
    ) async {
      await pumpApp(tester, history: _history());
      await openHistory(tester);

      await tester.drag(
        find.byKey(const Key('history-list')),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();

      // No hold, so the list's own drag won and the selection never began.
      expect(find.byType(AppSelectionHeader), findsNothing);
      expect(find.text('History'), findsOneWidget);
    });

    testWidgets('the drag does not leave the screen wedged (regression guard)', (
      tester,
    ) async {
      await pumpApp(tester, history: _history());
      await openHistory(tester);

      await longPressPaint(
        tester,
        from: find.text('3 + 3'),
        path: () => [tester.getCenter(find.text('2 + 2'))],
      );
      expect(find.text('2 selected'), findsOneWidget);

      // A plain tap after the drag still toggles the row it lands on, which
      // proves the region released its pointer and is not still painting.
      await tester.tap(find.text('1 + 1'));
      await tester.pumpAndSettle();
      expect(find.text('3 selected'), findsOneWidget);

      await tester.tap(find.text('1 + 1'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });

  group('the image grid (D-120)', () {
    testWidgets('a hold and drag paints every tile the finger crosses', (
      tester,
    ) async {
      _seedGallery(6);
      await tester.pumpWidget(_gallery());
      await tester.pumpAndSettle();

      final tiles = find.byType(VaultGridTile);
      expect(tiles, findsNWidgets(6));

      await longPressPaint(
        tester,
        from: tiles.at(0),
        path: () => [tester.getCenter(tiles.at(1)), tester.getCenter(tiles.at(2))],
      );

      expect(find.text('3 selected'), findsOneWidget);
    });

    testWidgets('an ordinary quick drag scrolls without selecting', (
      tester,
    ) async {
      _seedGallery(6);
      await tester.pumpWidget(_gallery());
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(VaultImagesScreen.gridKey),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 selected'), findsNothing);
      expect(find.byKey(const Key('vault-selection-bar')), findsNothing);
    });
  });

  group('the documents list (D-120)', () {
    testWidgets('a hold and drag paints across the body swap it triggers', (
      tester,
    ) async {
      _useTallView(tester);
      await _pumpDocuments(tester, <VaultDocument>[
        seededDocument(id: 'a', fileName: 'Report.pdf'),
        seededDocument(id: 'b', fileName: 'Notes.pdf'),
        seededDocument(id: 'c', fileName: 'Letter.pdf'),
      ]);

      expect(find.text('RECENT DOCUMENTS'), findsOneWidget);

      await longPressPaint(
        tester,
        from: find.byKey(const Key('vault-document-a')),
        path: () => [
          tester.getCenter(find.byKey(const Key('vault-document-b'))),
          tester.getCenter(find.byKey(const Key('vault-document-c'))),
        ],
      );

      // The press swapped the landing page for the selection list, and the drag
      // kept going across it — the region outlived the body it wrapped.
      expect(find.text('3 selected'), findsOneWidget);
    });

    testWidgets('an ordinary quick drag scrolls without selecting', (
      tester,
    ) async {
      _useTallView(tester);
      await _pumpDocuments(tester, <VaultDocument>[
        seededDocument(id: 'a', fileName: 'Report.pdf'),
        seededDocument(id: 'b', fileName: 'Notes.pdf'),
      ]);

      await tester.drag(
        find.byKey(const Key('vault-documents-landing')),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(VaultDocumentsScreen.selectionBarKey), findsNothing);
    });
  });
}
