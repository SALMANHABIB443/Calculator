import 'dart:convert';

import 'package:calculator/core/design/app_colors.dart';
import 'package:calculator/core/design/app_spacing.dart';
import 'package:calculator/features/secret/images/data/shared_preferences_vault_image_repository.dart';
import 'package:calculator/features/secret/images/domain/vault_image.dart';
import 'package:calculator/features/secret/images/presentation/vault_gallery_widgets.dart';
import 'package:calculator/features/secret/images/presentation/vault_images_screen.dart';
import 'package:calculator/features/secret/presentation/vault_place.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Metadata for [count] vault images, written through the real model so the
/// seed matches the bytes the app itself would have stored.
List<Map<String, dynamic>> _seedImages(int count) {
  final base = DateTime(2026, 1, 1);
  return <Map<String, dynamic>>[
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
  ];
}

void _seedGallery(int count) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    SharedPreferencesVaultImageRepository.imagesKey: jsonEncode(
      _seedImages(count),
    ),
  });
}

Widget _gallery({TextScaler? textScaler}) {
  return ProviderScope(
    child: MaterialApp(
      builder: textScaler == null
          ? null
          : (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: child!,
              ),
      home: const VaultPlaceScreen(placeId: 'images'),
    ),
  );
}

double _navHeight(WidgetTester tester) =>
    tester.getSize(find.byKey(const Key('vault-bottom-tabs'))).height;

double _selectionHeight(WidgetTester tester) =>
    tester.getSize(find.byKey(const Key('vault-selection-bar'))).height;

/// Long-presses the first tile so the screen enters selection mode.
Future<void> _enterSelection(WidgetTester tester) async {
  await tester.longPress(find.byType(VaultGridTile).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('selection bar matches the nav bar and clears the header', (
    tester,
  ) async {
    _seedGallery(6);
    await tester.pumpWidget(_gallery());
    await tester.pumpAndSettle();

    final navHeight = _navHeight(tester);

    await _enterSelection(tester);

    expect(find.byKey(const Key('vault-selection-bar')), findsOneWidget);

    // The selection bar replaces the tabs in place, so the two must be the
    // same height — a shorter bar pulls the screen's bottom edge upward.
    final selectionHeight = _selectionHeight(tester);
    expect(
      (navHeight - selectionHeight).abs(),
      lessThanOrEqualTo(0.5),
      reason: 'selection bar ($selectionHeight) must match nav bar ($navHeight)',
    );

    // The X button must not sit on top of the first photo.
    final cancelBottom = tester.getBottomLeft(find.byIcon(Icons.close)).dy;
    final firstTileTop = tester
        .getTopLeft(find.byType(VaultGridTile).first)
        .dy;
    expect(
      firstTileTop - cancelBottom,
      greaterThanOrEqualTo(AppSpacing.md),
      reason: 'X button and first tile are crowding each other',
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('selection layout holds on a short 320x568 surface at 1.3x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    _seedGallery(6);
    await tester.pumpWidget(
      _gallery(textScaler: const TextScaler.linear(1.3)),
    );
    await tester.pumpAndSettle();

    final navHeight = _navHeight(tester);

    await _enterSelection(tester);

    expect(
      (navHeight - _selectionHeight(tester)).abs(),
      lessThanOrEqualTo(0.5),
    );

    final cancelBottom = tester.getBottomLeft(find.byIcon(Icons.close)).dy;
    final firstTileTop = tester
        .getTopLeft(find.byType(VaultGridTile).first)
        .dy;
    expect(firstTileTop - cancelBottom, greaterThanOrEqualTo(AppSpacing.md));

    expect(tester.takeException(), isNull);
  });

  testWidgets('the add button is a themed circle that hides on select', (
    tester,
  ) async {
    _seedGallery(6);
    await tester.pumpWidget(_gallery());
    await tester.pumpAndSettle();

    final fab = tester.widget<FloatingActionButton>(
      find.byKey(VaultImagesScreen.addButtonKey),
    );
    expect(fab.shape, isA<CircleBorder>());
    // Inverted contrast: a white disc with a dark plus in the dark theme.
    expect(fab.backgroundColor, AppColors.textPrimary);
    expect(fab.foregroundColor, AppColors.background);

    await _enterSelection(tester);

    // It stays mounted so it can grow back, but is inert while selecting.
    expect(find.byKey(VaultImagesScreen.addButtonKey), findsOneWidget);
    final ignoring = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byKey(VaultImagesScreen.addButtonKey),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(ignoring.ignoring, isTrue);

    expect(tester.takeException(), isNull);
  });
}
