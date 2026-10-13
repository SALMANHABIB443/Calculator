import 'dart:convert';

import 'package:calculator/core/design/app_spacing.dart';
import 'package:calculator/features/secret/images/data/shared_preferences_vault_image_repository.dart';
import 'package:calculator/features/secret/images/domain/vault_image.dart';
import 'package:calculator/features/secret/images/presentation/vault_gallery_widgets.dart';
import 'package:calculator/features/secret/presentation/vault_place.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bug 2 — **opening an album must push a page of its own.**
///
/// The old Albums landing rows did `setState(() => _albumId = id)`, swapping
/// the grid into the *same* `VaultImagesScreen`. Nothing was pushed, so Back
/// popped the whole `/secret/browse/images` route and a user returning from an
/// album left the Gallery entirely.
///
/// These tests drive the real tap on a real album row and assert what is on top
/// afterwards, because an inline swap and a pushed page can look identical at
/// the moment of the tap — the difference is only visible after Back.

/// Seeds three pictures, two of them in an album named "Trip".
///
/// Written through the real model and the repository's own keys, so the screen
/// starts from the bytes the app itself would have written.
void _seedAlbumGallery() {
  final base = DateTime(2026, 1, 1);
  final images = <VaultImage>[
    for (var i = 0; i < 3; i++)
      VaultImage(
        id: 'img-$i',
        fileName: 'photo-$i.jpg',
        vaultFileName: 'photo-$i.jpg',
        mimeType: 'image/jpeg',
        fileSize: 1024,
        dateAdded: base.add(Duration(days: i)),
        dateModified: base.add(Duration(days: i)),
        albumIds: i < 2 ? const <String>['album-trip'] : const <String>[],
      ),
  ];
  final albums = <VaultAlbum>[
    VaultAlbum(id: 'album-trip', name: 'Trip', createdAt: base),
  ];
  SharedPreferences.setMockInitialValues(<String, Object>{
    SharedPreferencesVaultImageRepository.imagesKey: jsonEncode(
      [for (final image in images) image.toJson()],
    ),
    SharedPreferencesVaultImageRepository.albumsKey: jsonEncode(
      [for (final album in albums) album.toJson()],
    ),
  });
}

Widget _gallery() => const ProviderScope(
  child: MaterialApp(home: VaultPlaceScreen(placeId: 'images')),
);

/// Taps the Albums tab and waits for the landing page.
Future<void> _openAlbumsTab(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(const Key('vault-bottom-tabs')),
      matching: find.text('Albums'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tapping an album opens its own page, and Back returns', (
    tester,
  ) async {
    _seedAlbumGallery();
    await tester.pumpWidget(_gallery());
    await tester.pumpAndSettle();

    await _openAlbumsTab(tester);

    // The landing page lists the album and its count.
    expect(find.text('MY ALBUMS'), findsOneWidget);
    expect(find.text('Trip'), findsOneWidget);
    expect(find.text('2 photos'), findsOneWidget);

    await tester.tap(find.text('Trip'));
    await tester.pumpAndSettle();

    // A dedicated page: the album title heads it, the landing list is gone,
    // and only the album's own two pictures are shown.
    expect(find.text('Trip'), findsOneWidget);
    expect(find.text('MY ALBUMS'), findsNothing);
    expect(find.byType(VaultGridTile), findsNWidgets(2));
    // The gallery's tab chrome belongs to the gallery, not the album page.
    expect(find.byKey(const Key('vault-bottom-tabs')), findsNothing);

    // Back pops the album page only — the Albums list is still there, still on
    // the Albums tab, inside the same VaultPlaceScreen (the Gallery was not
    // exited).
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byType(VaultPlaceScreen), findsOneWidget);
    expect(find.text('MY ALBUMS'), findsOneWidget);
    expect(find.text('Trip'), findsOneWidget);
    expect(find.byKey(const Key('vault-bottom-tabs')), findsOneWidget);
    expect(find.byType(VaultGridTile), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a Quick Access row opens its own page too', (tester) async {
    _seedAlbumGallery();
    await tester.pumpWidget(_gallery());
    await tester.pumpAndSettle();

    await _openAlbumsTab(tester);
    await tester.tap(find.text('All Photos'));
    await tester.pumpAndSettle();

    // "All Photos" is a virtual collection, but it still gets a page: all
    // three pictures, no landing list, no bottom tabs.
    expect(find.text('All Photos'), findsOneWidget);
    expect(find.text('MY ALBUMS'), findsNothing);
    expect(find.byType(VaultGridTile), findsNWidgets(3));
    expect(find.byKey(const Key('vault-bottom-tabs')), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('MY ALBUMS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the system Back gesture leaves the album the same way', (
    tester,
  ) async {
    _seedAlbumGallery();
    await tester.pumpWidget(_gallery());
    await tester.pumpAndSettle();

    await _openAlbumsTab(tester);
    await tester.tap(find.text('Trip'));
    await tester.pumpAndSettle();
    expect(find.byType(VaultGridTile), findsNWidgets(2));

    // Android's Back is a Navigator pop, not a tap on the header arrow. A page
    // that had grown a route of its own — or replaced the gallery instead of
    // covering it — would pop to the wrong entry (or exit the Gallery) here
    // while the arrow test above still passed.
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    expect(navigator.canPop(), isTrue);

    navigator.pop();
    await tester.pumpAndSettle();

    // Back lands on the Albums list inside the same VaultPlaceScreen, so the
    // Gallery was not exited.
    expect(find.byType(VaultPlaceScreen), findsOneWidget);
    expect(find.text('MY ALBUMS'), findsOneWidget);
    expect(find.text('Trip'), findsOneWidget);
    expect(find.byKey(const Key('vault-bottom-tabs')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('album photos clear the header like the Pictures selection view', (
    tester,
  ) async {
    _seedAlbumGallery();
    await tester.pumpWidget(_gallery());
    await tester.pumpAndSettle();

    await _openAlbumsTab(tester);
    await tester.tap(find.text('Trip'));
    await tester.pumpAndSettle();

    // The album page has no tab row between its header and the grid, so it
    // must supply the same gap the Pictures selection view uses — otherwise
    // the first photo sits almost flush against the header icons.
    final headerBottom = tester
        .getBottomLeft(find.byType(VaultGalleryHeader))
        .dy;
    final firstTileTop = tester
        .getTopLeft(find.byType(VaultGridTile).first)
        .dy;
    expect(
      firstTileTop - headerBottom,
      greaterThanOrEqualTo(AppSpacing.lg),
      reason: 'album photos are crowding the header',
    );

    expect(tester.takeException(), isNull);
  });
}
