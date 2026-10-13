import 'package:calculator/features/secret/presentation/vault_place.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Creating an album through the dialog must put it in **My Albums**.
///
/// This flow had no UI coverage at all: the controller unit tests prove
/// `createAlbum` persists, but nothing drove the NEW badge → dialog → Create
/// path and checked the list the user actually looks at. That gap is how the
/// web self-heal could delete a just-created album unnoticed.

Widget _gallery() => const ProviderScope(
  child: MaterialApp(home: VaultPlaceScreen(placeId: 'images')),
);

Future<void> _openAlbumsTab(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(const Key('vault-bottom-tabs')),
      matching: find.text('Albums'),
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens the NEW album dialog, types [name], and taps Create.
Future<void> _createAlbum(WidgetTester tester, String name) async {
  await tester.tap(find.text('NEW'));
  await tester.pumpAndSettle();
  expect(find.text('New album'), findsOneWidget);

  await tester.enterText(find.byType(TextField), name);
  await tester.tap(find.text('Create'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an album created in the dialog appears under My Albums', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_gallery());
    await tester.pumpAndSettle();

    await _openAlbumsTab(tester);
    expect(find.text('MY ALBUMS'), findsOneWidget);
    expect(find.text('No albums yet'), findsOneWidget);

    await _createAlbum(tester, 'Trip');

    // The album is in the list, and the "no albums" card is gone.
    expect(find.text('Trip'), findsOneWidget);
    expect(find.text('No albums yet'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a second album is added alongside the first', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_gallery());
    await tester.pumpAndSettle();

    await _openAlbumsTab(tester);
    await _createAlbum(tester, 'Trip');
    await _createAlbum(tester, 'Family');

    expect(find.text('Trip'), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a duplicate name is refused with a message, not a second row', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_gallery());
    await tester.pumpAndSettle();

    await _openAlbumsTab(tester);
    await _createAlbum(tester, 'Trip');
    await _createAlbum(tester, 'trip'); // same name, different case

    expect(find.text('Trip'), findsOneWidget);
    expect(
      find.text('An album named "trip" already exists.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
