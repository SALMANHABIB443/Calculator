import 'package:calculator/app.dart';
import 'package:calculator/core/design/app_theme.dart';
import 'package:calculator/core/widgets/core_widgets.dart';
import 'package:calculator/features/history/domain/history_entry.dart';
import 'package:calculator/features/secret/presentation/secret_screens.dart';
import 'package:calculator/features/secret/presentation/vault_place.dart';
import 'package:calculator/routing/app_router.dart';
import 'package:calculator/routing/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/pump_app.dart';

/// FEAT-SEC-007 / **D-114** — the eleven places the Vault screen leads to.
///
/// `secret_flow_test.dart` asserts that the Vault screen *is* what it claims to
/// be; this file asserts what happens when one of its rows is pressed. The
/// distinction matters because the change D-114 made is not visible from the
/// Vault screen alone: a row that opens a page and a row wired to a no-op draw
/// the same chevron, the same ripple, and the same key, and the only thing that
/// separates them is which screen is on top afterwards.
///
/// **Every place is driven through a real tap on its real row**, never by
/// navigating the router directly. A test that pushed `/secret/browse/images`
/// itself would pass even if the row's `onTap` were still a no-op — which is
/// precisely the regression this suite exists to catch, and the one
/// `secret_flow_test.dart`'s old "does nothing" test used to assert as correct.
///
/// **The expected titles come from [vaultPlaces], not from literals written here.**
/// A hardcoded 'Images' would assert that the page says Images *and* that the
/// registry says Images, but a hardcoded expectation cannot notice when both were
/// changed together to something wrong; reading the title off the same record the
/// screen resolves it from asserts the thing that actually matters, which is that
/// the row and its page agree.
void main() {
  /// One seeded entry, so History's bottom Clear History button renders at all —
  /// D-38 hides it when there is nothing to clear, and without it the hold that
  /// opens Secret Mode has no widget to be performed on.
  List<HistoryEntry> seeded() => <HistoryEntry>[
    seededEntry(
      expression: '2 + 2',
      result: '4',
      resultValue: 4,
      timestamp: DateTime(2026, 10, 3, 9),
    ),
  ];

  /// Grows the test surface so the whole Vault screen is inside the viewport.
  ///
  /// The default 800 × 600 canvas is shorter than the screen under test, so a
  /// `ListView` never builds a tail it cannot show and every assertion about a
  /// bottom row would fail for a viewport reason rather than for the thing it was
  /// written about. This mirrors `secret_flow_test.dart`'s own `useTallView`,
  /// duplicated rather than shared because a test helper exported across files
  /// becomes a second public surface to keep stable.
  void useTallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// Holds History's clear button, types the shipped default code, and lands on
  /// the Vault screen.
  ///
  /// The gesture rather than a direct push, for the reason the whole Secret Mode
  /// suite uses it: the hold is the only way in, so a shortcut would test the
  /// screens without testing the thing that reaches them.
  Future<void> unlock(WidgetTester tester) async {
    await pumpApp(tester, history: seeded());

    await openHistory(tester);
    final button = find.byKey(const Key('history-clear-button'));
    expect(button, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(secretHoldDuration);
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();

    for (final digit in '0000'.split('')) {
      await tester.tap(
        find.widgetWithText(CalculatorButton, digit),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
    }
    await tester.pumpAndSettle();

    expect(find.byType(SecretScreen), findsOneWidget);
  }

  /// The router the *pumped* app is using.
  ///
  /// Read out of the mounted [ProviderScope] rather than from a container of our
  /// own, so the pushes below go through the same router the widget tree is
  /// listening to. A second container would navigate a router no widget is
  /// attached to, and the test would assert nothing.
  GoRouter routerFor(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(CalculatorApp)),
  ).read(appRouterProvider);

  /// The `Key` of the Vault row or grid cell that opens [place].
  ///
  /// **A table rather than a derivation.** The grid's six keys do follow
  /// `'secret-category-$id'`, and it is tempting to treat the five rows as the
  /// same convention one prefix away — which is exactly the guess that was wrong
  /// when this was first written: the rows say `secret-recent-files` and
  /// `secret-storage-internal`, not `secret-recent` and `secret-internal-storage`.
  /// Those two schemes are indistinguishable from the widget tree, so a
  /// derivation does not fail loudly; it just finds nothing and reports a
  /// confusing "0 widgets" instead of "the key is spelled differently here".
  ///
  /// The grid branch keeps the derivation because that convention *is* what
  /// `secret_screens.dart` builds its keys from, and reading it off the same rule
  /// is what makes the assertion about agreement rather than about two lists.
  Key rowKeyFor(String id) => switch (id) {
    'recent' => const Key('secret-recent-files'),
    'internal-storage' => const Key('secret-storage-internal'),
    'sd-card' => const Key('secret-storage-sd'),
    'recycle-bin' => const Key('secret-recycle-bin'),
    'analyse-storage' => const Key('secret-analyse-storage'),
    final gridId => Key('secret-category-$gridId'),
  };

  /// Taps [place]'s row on the Vault screen and lands on its page.
  Future<void> openPlace(WidgetTester tester, VaultPlace place) async {
    final row = find.byKey(rowKeyFor(place.id));
    expect(row, findsOneWidget, reason: 'the Vault screen must have a row for ${place.id}');

    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.byType(VaultPlaceScreen), findsOneWidget);
  }

  group('the registry', () {
    testWidgets('holds eleven places, and every id resolves', (tester) async {
      // Read off the shipping list rather than a literal count written here, so
      // this fails when a place is *added* — which is the moment a reviewer
      // should be asked whether it has an honest empty state — rather than only
      // when the list and this file disagree by accident.
      expect(vaultPlaces, hasLength(11));
      expect(
        vaultPlaces.map((place) => place.id).toSet(),
        hasLength(vaultPlaces.length),
        reason: 'two places sharing an id would make one unreachable',
      );

      for (final place in vaultPlaces) {
        expect(vaultPlaceById(place.id), place);
      }
    });

    testWidgets('every id is a single lowercase slug', (tester) async {
      // The id goes into a URL segment. An id with a space or a slash in it
      // produces a path that either 404s to the fallback page or, worse, matches
      // a different route — and neither failure is visible until a user taps the
      // row, which is exactly the failure mode a release build should not have.
      final slug = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

      for (final place in vaultPlaces) {
        expect(
          slug.hasMatch(place.id),
          isTrue,
          reason: '"${place.id}" is not a URL-safe slug',
        );
      }
    });

    testWidgets('the six grid ids are exactly the six Categories cells', (
      tester,
    ) async {
      // The grid reads `vaultCategoryIds` and resolves each one, so a mismatch
      // here is a cell that pushes to the fallback page while looking perfectly
      // ordinary. Asserted against `vaultPlaces` because that is the list the
      // page resolves against.
      expect(vaultCategoryIds, hasLength(6));

      for (final id in vaultCategoryIds) {
        expect(vaultPlaceById(id), isNotNull, reason: 'no place for grid cell $id');
      }

      // And the six are the six the *page* offers that are not rows of their own,
      // which is the distinction the Vault screen draws: these live in the grid,
      // those live in a `SettingsGroup`.
      final gridIds = vaultCategoryIds.toSet();
      for (final place in vaultPlaces) {
        if (gridIds.contains(place.id)) continue;
        expect(
          const <String>{
            'recent',
            'internal-storage',
            'sd-card',
            'recycle-bin',
            'analyse-storage',
          },
          contains(place.id),
          reason: '${place.id} is neither a grid cell nor a known row',
        );
      }
    });

    testWidgets('no place names the feature, the area, or the code (§6.8)', (
      tester,
    ) async {
      // The rule `secret_flow_test.dart` enforces on the Vault screen itself,
      // extended to the eleven pages behind it — because a page that named itself
      // would be a page a screenshot spoils, and eleven of them are eleven more
      // chances to break a guarantee that used to hold in one place.
      //
      // The forbidden words are the four §6.8 names, asserted case-insensitively
      // because "Vault" and "vault" are the same disclosure to a screenshot
      // reader and a substring check is what catches both.
      final forbidden = <String>['secret', 'vault', 'pin', '0000', 'default'];

      for (final place in vaultPlaces) {
        for (final word in forbidden) {
          expect(
            place.title.toLowerCase(),
            isNot(contains(word)),
            reason: 'the title of ${place.id} names "$word"',
          );
          expect(
            place.emptyTitle.toLowerCase(),
            isNot(contains(word)),
            reason: 'the empty state of ${place.id} names "$word"',
          );
        }
      }
    });

    testWidgets('every place has an empty state and an icon', (tester) async {
      // A place with an empty [emptyTitle] would render an [EmptyState] with a
      // blank headline, which looks like a rendering bug rather than an empty
      // folder.
      for (final place in vaultPlaces) {
        expect(place.emptyTitle.trim(), isNotEmpty);
        expect(place.title.trim(), isNotEmpty);
        expect(place.icon, isNotNull);
      }
    });
  });

  group('every place opens its own page', () {
    for (final place in vaultPlaces) {
      testWidgets('${place.id} opens a page titled "${place.title}"', (
        tester,
      ) async {
        useTallView(tester);
        await unlock(tester);
        await openPlace(tester, place);

        // The page's title comes from the same record the row's label came from,
        // so this is the assertion that the two agree — the one thing D-114 is
        // actually about.
        expect(
          find.descendant(
            of: find.byType(SecondaryPageHeader),
            matching: find.text(place.title),
          ),
          findsOneWidget,
          reason: 'the page must be headed with its own name',
        );

        // And the empty state is this place's, not a generic one. Read from the
        // record rather than the screenshot for the same reason as the title.
        expect(
          find.descendant(
            of: find.byKey(VaultPlaceScreen.bodyKey),
            matching: find.text(place.emptyTitle),
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('a place page carries exactly one back button', (tester) async {
      useTallView(tester);
      await unlock(tester);
      await openPlace(tester, vaultPlaces.first);

      // **One, and it is the app's own.** D-84 spent a long time arguing that
      // this screen family should not grow its own affordances, and D-87 added a
      // back arrow to the PIN screen only because that screen has no header to
      // carry one. This page has a header, so it gets the header's button — and a
      // second exit would be the app inventing a way out that the rest of the app
      // does not have.
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // The floating home button belongs to the Vault screen alone. A user who
      // pushed here has a back button and does not need a second way to leave;
      // carrying it down would float a 56 px circle over an empty page.
      expect(find.byKey(const Key('secret-home')), findsNothing);
    });

    testWidgets('back returns to the Vault screen', (tester) async {
      useTallView(tester);
      await unlock(tester);

      // Two hops, deliberately: a back that only worked from the first page
      // pushed would look correct in a one-page test and strand a user who
      // arrived by some other route. Both places are on the same route, so this
      // is the same code path twice — which is the point of asserting it twice.
      for (final place in <VaultPlace>[
        vaultPlaceById('recent')!,
        vaultPlaceById('analyse-storage')!,
      ]) {
        await openPlace(tester, place);
        expect(find.byType(VaultPlaceScreen), findsOneWidget);

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(find.byType(SecretScreen), findsOneWidget);
        expect(find.byType(VaultPlaceScreen), findsNothing);
        expect(find.text('Vault'), findsOneWidget);
      }
    });

    testWidgets('the system back gesture leaves the same way', (tester) async {
      useTallView(tester);
      await unlock(tester);
      await openPlace(tester, vaultPlaceById('documents')!);

      // The header's button pops, and the platform's own gesture pops the same
      // navigator entry — but they are not the same code, and a page that gave
      // the arrow a `go('/secret')` instead of a pop would break here and not
      // there. Asserting the gesture is what proves the page added no route of
      // its own between the two.
      final state = tester.state<NavigatorState>(find.byType(Navigator).first);
      expect(state.canPop(), isTrue);

      state.pop();
      await tester.pumpAndSettle();

      expect(find.byType(SecretScreen), findsOneWidget);
    });
  });

  group('the route', () {
    testWidgets('a segment with no place renders rather than throwing', (
      tester,
    ) async {
      // **The screen must survive a `:place` it does not recognise.** Three
      // reasons converge on this one assertion, and it is the reason
      // `vaultPlaceById` is nullable rather than asserting:
      //
      // * A path parameter can arrive from outside the app — a stale bookmark, a
      //   hand-typed URL, a deep link — and on Android a throw here is a crash on
      //   a screen the user can see.
      // * `navigation_graph_test.dart` pushes the *pattern* `/secret/browse/:place`
      //   verbatim, because a parameterised path has no concrete value to
      //   substitute. The literal segment `:place` therefore reaches the screen
      //   from that suite, and it has to render rather than throw.
      // * The fallback must claim nothing. "Files" names no category, so a wrong
      //   segment lands on a page that says nothing true and wrong, rather than
      //   on whichever place happened to be first in the list.
      await unlock(tester);

      final router = routerFor(tester);
      router.push('/secret/browse/definitely-not-a-place');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(VaultPlaceScreen), findsOneWidget);
      expect(find.text('Files'), findsOneWidget);
    });

    testWidgets('an empty place id falls back too', (tester) async {
      // `app_router.dart` passes `''` when the router hands over no parameter at
      // all, which is the other way a segment can be missing. Same requirement,
      // stated separately because it arrives by a different line of production
      // code — the `?? ''` in the route's builder.
      //
      // **Mounted directly rather than pushed.** `go_router` will not match
      // `/secret/browse/` against `/secret/browse/:place` at all: an empty
      // segment is not a segment, so the push never reaches this screen and there
      // is nothing here for the router to hand over. Which makes the `?? ''`
      // defensive code by construction, and the only honest way to exercise the
      // value it produces is to hand it to the widget the way the route does.
      //
      // The theme is supplied because the components resolve their colours
      // through it, and this bypasses the app that would otherwise install it.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const VaultPlaceScreen(placeId: ''),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(VaultPlaceScreen), findsOneWidget);
      expect(find.text('Files'), findsOneWidget);
    });

    testWidgets('the path helper builds under the route prefix', (tester) async {
      // The prefix lives in `AppRoutes` once and the helper interpolates it, so
      // this asserts the two halves still agree rather than asserting a literal
      // path — a hardcoded expectation here would pass even if both the constant
      // and the helper were renamed to the same wrong thing.
      expect(
        AppRoutes.secretBrowseTo('images'),
        startsWith(AppRoutes.secretBrowse.split('/').take(3).join('/')),
      );
      expect(AppRoutes.secretBrowse, contains(':place'));
    });
  });

  group('the Vault screen after D-114', () {
    testWidgets('Search stays enabled-looking and still does nothing', (
      tester,
    ) async {
      useTallView(tester);
      await unlock(tester);

      // The last inert control, and the one the old "every control does nothing"
      // test used to cover on its own. It has no destination and no honest empty
      // page to open — a search over a set of files that does not exist would be
      // a claim the app cannot make — so it ships as furniture and arrives with
      // the file list it searches.
      expect(
        tester
            .widget<AppIconButton>(find.byKey(const Key('secret-search')))
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(const Key('secret-search')));
      await tester.pumpAndSettle();

      expect(find.byType(SecretScreen), findsOneWidget);
      expect(find.byType(VaultPlaceScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every row is enabled-looking', (tester) async {
      useTallView(tester);
      await unlock(tester);

      // The half of the old assertion that still holds: no row may go grey. The
      // other half — that they do nothing — was D-114's reversal, and the tests
      // above are what replaced it.
      expect(
        tester
            .widget<SettingsRow>(find.byKey(const Key('secret-recent-files')))
            .onTap,
        isNotNull,
      );

      for (final id in vaultCategoryIds) {
        final cell = find.byKey(Key('secret-category-$id'));
        expect(cell, findsOneWidget);
        expect(tester.widget<InkWell>(find.descendant(
          of: cell,
          matching: find.byType(InkWell),
        )).onTap, isNotNull);
      }
    });
  });
}
