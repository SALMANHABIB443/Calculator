import 'package:calculator/features/secret/images/presentation/vault_images_screen.dart';
import 'package:calculator/features/secret/presentation/vault_place.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  group('image gallery empty state', () {
    testWidgets('shows premium empty state with Add Photos', (tester) async {
      mockEmptyHistory();
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp(home: VaultPlaceScreen(placeId: 'images'))),
      );
      await tester.pumpAndSettle();

      // Gallery chrome: Pictures header + bottom tabs.
      expect(find.text('Pictures'), findsWidgets);
      expect(find.text('Albums'), findsWidgets);
      expect(find.text('Favorites'), findsWidgets);
      expect(find.text('Trash'), findsWidgets);
      // Premium empty state with a working entry point.
      expect(find.text('No private photos yet'), findsOneWidget);
      expect(
        find.byKey(VaultImagesScreen.addButtonKey),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
