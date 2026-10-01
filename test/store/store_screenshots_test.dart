/// Renders the Play Store listing screenshots from the real app (**D-67**).
///
/// Run it explicitly:
///
/// ```sh
/// flutter test test/store/store_screenshots_test.dart \
///   --update-goldens --dart-define=GENERATE_STORE_ASSETS=true
/// ```
///
/// ## Why this is not an ordinary test
///
/// The file is skipped unless `GENERATE_STORE_ASSETS` is defined, because the
/// output is a *build artifact* for the store listing, not an assertion. Had
/// this been a normal golden test, `flutter test` on another machine or after
/// a font-rendering change would compare the committed PNGs against a
/// locally-rendered one and fail on sub-pixel differences nobody cares about
/// — the screenshots are not a regression suite. Nothing in the shipping
/// pipeline should depend on them; they are regenerated from scratch at
/// release time instead. See `store/README.md`.
///
/// ## Why the goldens are written outside `test/`
///
/// `matchesGoldenFile` resolves its path relative to this file, so the `../..`
/// prefix puts the PNGs in `store/play/screenshots/` where the listing expects
/// them. Keeping them out of `test/` means an ordinary `flutter test` run never
/// picks them up as a comparison target.
///
/// ## Fonts
///
/// `flutter test` renders every glyph as a filled box using its own test font,
/// so a screenshot taken naively would show the real UI with unreadable
/// placeholder text. Roboto is loaded from the Flutter SDK cache and injected
/// into the theme via an `appThemeProvider` override, because the design
/// system sets no explicit `fontFamily` — inheriting it from the theme is the
/// only way the whole widget tree picks it up.
library;

import 'dart:io';

import 'package:calculator/core/design/app_theme.dart';
import 'package:calculator/core/design/app_theme_provider.dart';
import 'package:calculator/features/history/domain/history_entry.dart';
import 'package:calculator/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keypad_session.dart';
import '../support/pump_app.dart';

/// Store screenshots are generated, not asserted — see the library docs.
const bool _generating = bool.fromEnvironment('GENERATE_STORE_ASSETS');

/// 1080x1920 is exactly 9:16, the aspect ratio Play requires, and 1080px is
/// well inside its 320-3840px range. `devicePixelRatio` 3 makes the logical
/// surface 360x640dp, a realistic phone size, so the layout in the PNG is the
/// layout a user would actually get rather than an unconstrained test surface.
const Size _surfaceSize = Size(1080, 1920);
const double _devicePixelRatio = 3.0;

const String _fontDir = r'C:\flutter\bin\cache\artifacts\material_fonts';

/// The Roboto faces the app renders with, and the family each is registered
/// under. Weight distinctions matter: the design system uses Medium for display
/// text, so registering only Regular would silently render headings lighter
/// than the shipped app.
const Map<String, List<String>> _robotoFaces = {
  'Roboto': ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf'],
};

/// The history shown in the History screenshot.
///
/// Written as real entries with plausible values rather than a placeholder, so
/// the listing shows the grouping by day, the time stamps, and the expression
/// and result columns the feature actually has.
List<HistoryEntry> _sampleHistory(DateTime now) => <HistoryEntry>[
  HistoryEntry(
    id: '1',
    expression: '1,250.50 x 4',
    result: '5,002.00',
    resultValue: 5002,
    timestamp: now.subtract(const Duration(minutes: 2)),
  ),
  HistoryEntry(
    id: '2',
    expression: '18% of 340',
    result: '61.20',
    resultValue: 61.2,
    timestamp: now.subtract(const Duration(hours: 3)),
  ),
  HistoryEntry(
    id: '3',
    expression: '96 / 7',
    result: '13.71',
    resultValue: 13.71,
    timestamp: now.subtract(const Duration(days: 1, hours: 2)),
  ),
  HistoryEntry(
    id: '4',
    expression: '345.6 + 0.44',
    result: '346.04',
    resultValue: 346.04,
    timestamp: now.subtract(const Duration(days: 1, hours: 5)),
  ),
];

/// Keys to press so the Calculator screenshot shows a real calculation rather
/// than an empty display.
///
/// `keysFor` matches the exact codepoints the keypad uses, which are not their
/// ASCII lookalikes: multiply is U+00D7 and subtract is U+2212, matching
/// `lib/features/legal/data/legal_content.dart` and the icon generator. ASCII
/// `*` and `-` throw rather than silently computing something else.
///
/// 1250.5 x 4 = 5,002 — a calculation with a decimal and a regrouped result,
/// which is what makes the listing shot worth having.
const String _calculation = '1250.5×4=';

Future<void> _loadRoboto() async {
  for (final family in _robotoFaces.keys) {
    final loader = FontLoader(family);
    for (final file in _robotoFaces[family]!) {
      final path = '$_fontDir\\$file';
      if (!File(path).existsSync()) {
        throw StateError(
          'Roboto face not found at $path. This test needs the Flutter SDK '
          'material_fonts cache; set FLUTTER_ROOT or run it on a machine with '
          'the SDK installed.',
        );
      }
      final bytes = File(path).readAsBytesSync();
      loader.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
}

/// The app's real dark theme with Roboto forced onto every text style.
///
/// Overriding the provider rather than wrapping the app in a `Theme` is what
/// makes this work: `MaterialApp.router` builds its own `Theme` from the
/// provider, so an ancestor `Theme` would be discarded.
ThemeData _robotoTheme(ThemeData base) {
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Roboto'),
  );
}

void main() {
  setUpAll(_loadRoboto);

  late DateTime now;

  setUp(() {
    // A fixed clock so the day/time grouping in the History screenshot is
    // stable and re-running the generator produces the same image.
    now = DateTime(2026, 9, 30, 14, 30);
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views
        .first;
    view
      ..physicalSize = _surfaceSize
      ..devicePixelRatio = _devicePixelRatio;
    addTearDown(view.reset);
  });

  group('store screenshots', () {

  testWidgets('01 calculator', (tester) async {
    await pumpApp(
      tester,
      overrides: [
        appThemeProvider.overrideWithValue(_robotoTheme(AppTheme.dark)),
      ],
    );

    for (final key in keysFor(_calculation)) {
      await tester.tap(find.byKey(ValueKey('key-${key.name}')));
      await tester.pumpAndSettle();
    }
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../store/play/screenshots/01-calculator.png'),
    );
  });

  testWidgets('02 history', (tester) async {
    await pumpApp(
      tester,
      history: _sampleHistory(now),
      settings: AppSettings.defaults.copyWith(decimalPlaces: 2),
      overrides: [
        appThemeProvider.overrideWithValue(_robotoTheme(AppTheme.dark)),
      ],
    );

    await openHistory(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../store/play/screenshots/02-history.png'),
    );
  });

  testWidgets('03 settings', (tester) async {
    await pumpApp(
      tester,
      settings: AppSettings.defaults.copyWith(
        decimalPlaces: 2,
        soundEnabled: true,
      ),
      overrides: [
        appThemeProvider.overrideWithValue(_robotoTheme(AppTheme.dark)),
      ],
    );

    await openSettings(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../store/play/screenshots/03-settings.png'),
    );
  });

  testWidgets('04 privacy policy', (tester) async {
    await pumpApp(
      tester,
      overrides: [
        appThemeProvider.overrideWithValue(_robotoTheme(AppTheme.dark)),
      ],
    );

    // Navigated the way a user does, through Settings, so the screenshot shows
    // the real route rather than a screen pushed on top of the router.
    await openSettings(tester);
    await tapSettingsRow(tester, 'Privacy Policy');

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../store/play/screenshots/04-privacy-policy.png'),
    );
  });
  }, skip: !_generating ? 'set GENERATE_STORE_ASSETS to generate' : false);
}
