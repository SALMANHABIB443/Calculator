/// Shared widget-test harness for driving the real app.
///
/// The navigation helpers live here rather than in `navigation_test.dart` so the
/// History tests use exactly the same entry points the Phase 2 navigation tests
/// do, and so the one non-obvious requirement below is stated once.
library;

import 'dart:convert';

import 'package:calculator/app.dart';
import 'package:calculator/core/widgets/core_widgets.dart';
import 'package:calculator/features/history/data/history_repository.dart';
import 'package:calculator/features/history/data/shared_preferences_history_repository.dart';
import 'package:calculator/features/history/domain/history_entry.dart';
import 'package:calculator/features/history/presentation/history_controller.dart';
import 'package:calculator/features/history/presentation/history_screen.dart';
import 'package:calculator/features/secret/data/device_storage_repository.dart';
import 'package:calculator/features/secret/data/shared_preferences_secret_repository.dart';
import 'package:calculator/features/secret/domain/secret_code.dart';
import 'package:calculator/features/settings/data/shared_preferences_settings_repository.dart';
import 'package:calculator/features/settings/domain/app_settings.dart';
import 'package:calculator/features/settings/presentation/decimal_places_sheet.dart';
import 'package:calculator/features/settings/presentation/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Empties the history store a test starts from.
///
/// The History screen reads through `shared_preferences` (D-02), so a test that
/// renders it must give the plugin a store. Without this the pending channel call
/// **never completes** — it does not throw, so the repository's own error
/// handling cannot catch it and the screen sits on its progress indicator
/// forever, which surfaces as `pumpAndSettle timed out`. Mocking here is
/// therefore mandatory rather than a convenience, and it is why the app degrades
/// to `InMemoryHistoryRepository` in production but tests still need a store.
void mockEmptyHistory() => mockHistoryStore(const <HistoryEntry>[]);

/// Seeds the history store with [entries].
///
/// Written through the real repository's key and JSON shape rather than a stub,
/// so a seeded screen starts from the same bytes the app would have written.
/// Pass [settings] to seed the preferences at the same time — the two live in
/// one store, so they are installed together.
///
/// Pass [entries] oldest-first, the way the calculations happened; they are
/// reversed on the way in. Newest-first is a *storage* invariant the repository
/// maintains by inserting each new entry at index 0 and never re-sorting, so a
/// seed written in the wrong order would put the screen in a state the app
/// itself can never produce.
void mockHistoryStore(
  List<HistoryEntry> entries, {
  AppSettings? settings,
  SecretCode? secretPin,
}) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    SharedPreferencesHistoryRepository.storageKey: jsonEncode([
      for (final entry in entries.reversed) entry.toJson(),
    ]),
    if (settings != null) ...settingsStoreValues(settings),
    // Seeded through the real repository's key so a Secret Mode test starts
    // from the same bytes the app would have written (D-83).
    if (secretPin != null)
      SharedPreferencesSecretRepository.pinKey: secretPin.value,
  });
}

/// The settings a store holds, keyed exactly as the real repository keys them.
///
/// Shared with the persistence tests so a seed goes in through the real schema
/// rather than a parallel copy of it that could drift.
Map<String, Object> settingsStoreValues(AppSettings settings) {
  return <String, Object>{
    SharedPreferencesSettingsRepository.soundEnabledKey: settings.soundEnabled,
    SharedPreferencesSettingsRepository.vibrationEnabledKey:
        settings.vibrationEnabled,
    SharedPreferencesSettingsRepository.decimalPlacesKey: settings.decimalPlaces,
    SharedPreferencesSettingsRepository.historyEnabledKey:
        settings.historyEnabled,
    SharedPreferencesSettingsRepository.themeKey: settings.theme,
  };
}

/// The store's current contents, as `setMockInitialValues` would take them.
///
/// This is what makes a genuine **AC-006** restart test possible. Re-seeding with
/// this map does two things: it replaces the backing store, and — because
/// `setMockInitialValues` nulls the plugin's cached `_completer`
/// (`shared_preferences_legacy.dart:290`) — the next `getInstance()` re-reads
/// from disk instead of handing back the same in-memory instance. Building a
/// second `ProviderContainer` *without* this would prove nothing, because both
/// containers would share one cached instance.
Future<Map<String, Object>> snapshotStore() async {
  final preferences = await SharedPreferences.getInstance();
  return <String, Object>{
    for (final key in preferences.getKeys()) key: preferences.get(key)!,
  };
}

/// Replaces the backing store with [values] verbatim.
///
/// [mockHistoryStore] is the usual way in, but it takes history entries and
/// settings and writes them through the real schema — which is the wrong tool
/// for a restart, where the point is to put back the *exact* bytes
/// [snapshotStore] captured, including anything a future version adds. Seeding
/// the raw map also drops keys the previous run did not have, so a preference
/// deleted in run one cannot linger into run two.
void seedStore(Map<String, Object> values) {
  SharedPreferences.setMockInitialValues(values);
}

/// Builds an entry for [mockHistoryStore], newest-day-first, without repeating
/// the storage schema in every test.
HistoryEntry seededEntry({
  required String expression,
  required String result,
  required double resultValue,
  required DateTime timestamp,
  String id = 'seed',
}) => HistoryEntry(
  id: id,
  expression: expression,
  result: result,
  resultValue: resultValue,
  timestamp: timestamp,
);

/// The storage figures every pumped app reports unless a test says otherwise.
///
/// Chosen so the formatted subtitle reads `28.35 GB / 32.00 GB · 3.65 GB free`
/// — the same numbers the row carried when they were hardcoded, now produced by
/// the real formatter from bytes. Keeping the display identical means the
/// harness change is visible only to a test that asserts the *format*, not to
/// every assertion that merely reads the row.
///
/// No SD card: `sdCard: null` is what the platform answers for an empty slot,
/// so the default state of the row stays the state the suite already asserts.
const VaultStorage harnessVaultStorage = VaultStorage(
  internal: DeviceStorage(
    totalBytes: 34359738368, // 32 GB
    freeBytes: 3918657658, // 3.65 GB
  ),
  sdCard: null,
);

/// Pump the whole app and settles, starting from an empty history unless
/// [history] says otherwise.
///
/// [fakeStorage] replaces [vaultStorageProvider] with [harnessVaultStorage].
/// It is on by default because the real provider reaches a `MethodChannel`
/// that no test host answers: the read fails fast and the Vault renders
/// `Unavailable`, which is honest but makes every storage assertion about the
/// failure path rather than the figures. A test that *wants* that path — or
/// wants to drive the channel itself — passes `fakeStorage: false` and owns
/// the provider (or the channel mock) in its own [overrides].
Future<void> pumpApp(
  WidgetTester tester, {
  List<Override> overrides = const <Override>[],
  List<HistoryEntry> history = const <HistoryEntry>[],
  AppSettings? settings,
  SecretCode? secretPin,
  bool fakeStorage = true,
}) async {
  mockHistoryStore(history, settings: settings, secretPin: secretPin);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        if (fakeStorage)
          vaultStorageProvider.overrideWith((ref) async => harnessVaultStorage),
        ...overrides,
      ],
      child: const CalculatorApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// How long History's bottom Clear History button must be held before Secret
/// Mode opens (D-82).
///
/// Re-exported from [HistoryScreen] rather than re-declared here so the test
/// harness holds the *shipped* duration. The alternative — a shorter constant
/// for tests — would let the production five seconds go unpumped, and the value
/// is the decision (D-82), not an implementation detail.
const Duration secretHoldDuration = HistoryScreen.secretHoldDuration;

/// Opens the Calculator screen's history clock (D-20).
Future<void> openHistory(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.history));
  await tester.pumpAndSettle();
}

/// Opens the Calculator screen's gear button, which is the only entry point to
/// Settings (D-20, D-117).
Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings));
  await tester.pumpAndSettle();
}

/// Scrolls a row on the Settings list into view and taps it. `ListView` builds
/// lazily, so rows below the fold do not exist in the tree until scrolled to.
///
/// The `ensureVisible` is not redundant with `scrollUntilVisible`: on a short
/// surface (e.g. 320x568) a row can be *built* while its box is still partly
/// off-screen, and a tap on a partially off-screen row lands on nothing. That
/// failure is silent — the test stays on Settings and the next assertion
/// reports a confusing "0 widgets" instead of "the tap missed".
Future<void> tapSettingsRow(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    120,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// Pops the current screen and returns to the one beneath it.
Future<void> goBack(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.arrow_back));
  await tester.pumpAndSettle();
}

/// The history the screen is currently showing, flattened newest first.
///
/// Reads the provider rather than the widgets so a test can assert the whole
/// list, including entries scrolled out of view.
List<String> historyExpressions(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(Scaffold).first),
  );
  final groups =
      container.read(historyControllerProvider).valueOrNull ??
      const <HistoryDayGroup>[];
  return [
    for (final group in groups)
      for (final entry in group.entries) entry.expression,
  ];
}

/// The preferences the app is currently acting on.
///
/// Reads the same synchronous provider production does, so a test asserts what
/// the calculator, the feedback flags, and the history gate will actually see
/// rather than what a widget happens to be painting.
AppSettings currentSettings(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(Scaffold).first),
  ).read(settingsProvider);
}

/// Flips the toggle on the Settings row titled [title].
///
/// Taps the row rather than the switch so the test drives the gesture a user
/// would make, and so `ToggleRow`'s whole-row target is exercised on the way.
Future<void> toggleSettingsRow(WidgetTester tester, String title) async {
  final row = find.widgetWithText(ToggleRow, title);
  await tester.scrollUntilVisible(
    row,
    120,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(row);
  await tester.pumpAndSettle();
}

/// The position of the switch on the Settings row titled [title].
///
/// Reads the rendered `Switch`, not the stored preference, so a test can tell a
/// control that visibly failed to move from one that moved and was not
/// persisted.
bool switchPosition(WidgetTester tester, String title) {
  return tester
      .widget<Switch>(
        find.descendant(
          of: find.widgetWithText(ToggleRow, title),
          matching: find.byType(Switch),
        ),
      )
      .value;
}

/// Opens the Decimal Places sheet and picks [places].
///
/// Finds the option by the key the sheet publishes rather than by its label: the
/// label is also the Settings row's own subtitle, so a text finder would match
/// two widgets at once with the sheet open.
Future<void> chooseDecimalPlaces(WidgetTester tester, int places) async {
  await tapSettingsRow(tester, 'Decimal Places');

  final option = find.byKey(DecimalPlacesSheet.optionKey(places));
  expect(option, findsOneWidget, reason: 'the picker offers no "$places" row');
  await tester.tap(option);
  await tester.pumpAndSettle();
}

/// Dismisses the Decimal Places sheet without choosing, by tapping the barrier.
Future<void> dismissDecimalPlaces(WidgetTester tester) async {
  await tapSettingsRow(tester, 'Decimal Places');
  await tester.tapAt(const Offset(10, 10));
  await tester.pumpAndSettle();
}

