# Play Store listing — Calculator v1.0.0

Copy and asset manifest for the Google Play submission. Everything Play asks
for that can be prepared ahead of time is here; the two items that cannot be
produced in this repository are called out under **Open gates** at the bottom.

- **Package**: `com.hasanmahadi.calculator`
- **Version**: `1.0.0` (`versionCode` 1)
- **Category**: Tools → Calculator (Play's `TOOLS` / `Calculator`)
- **Content rating**: 4+ / Everyone. Nothing objectionable, no user-generated
  content, no ads, no location. This is the honest answer for a calculator that
  collects nothing.
- **Ads**: No. **In-app purchases**: No. **Target audience**: 13+ is the
  conservative default; 4+ is defensible but 13+ avoids the extra Data Safety
  declaration Play requires for the youngest band.
- **Countries**: Worldwide, minus any region you lack distribution rights in.

---

## Short description

Play's limit is 80 characters. This is 69.

```
A fast, private calculator. Works offline. Nothing leaves your phone.
```

## Full description

Play's limit is 4000 characters. This is 1828.

```
A calculator that stays out of the way: it opens instantly, it does the
arithmetic, and it never asks for anything.

No account. No sign-up. No ads. No tracking. No internet permission — the app
is released without it, so it is technically incapable of sending your data
anywhere. Your history never leaves your phone, because your phone is the only
place it exists.

FEATURES

• Everything you expect: addition, subtraction, multiplication, division,
  percent, sign change, and decimals.
• Grouped results, so 1250.50 x 4 reads as 5,002.00 rather than 5002.
• Calculation history, grouped by day, so you can find that total from last
  Tuesday without redoing the arithmetic.
• Share the app with a friend from the About screen.
• Choose how many decimal places to show, from 0 to 6.
• Optional key-press sound and vibration feedback.
• A dark theme designed to be easy on the eyes at night.
• Works entirely offline. On a plane, on the train, in a basement — it never
  needs a connection.

PRIVACY

Calculator collects nothing. Not your history, not your settings, not
analytics, not crash logs, not advertising identifiers. There is no analytics
or advertising code in the app to collect anything even if we wanted to.

Your history and preferences are stored only in this app's private storage on
this device. Android's automatic backup is switched off and device-to-device
transfer is excluded, so your data is not uploaded to your Google account and
does not follow you to a new phone. To erase everything, clear your history on
the History screen or uninstall the app — either removes it permanently,
because there is no copy anywhere else.

The full Privacy Policy and Terms of Service are built into the app, under
Settings. We have no ability to look up anything about you, because we do not
have anything about you.
```

### Re-measuring the field lengths

Both fields are fenced blocks, and the fences are the paste targets, so their
character counts exclude the surrounding prose. Re-check after any edit:

```sh
powershell -NoProfile -ExecutionPolicy Bypass -File tool\measure_store_fields.ps1
```

The script locates each block by its section heading, so adding a fenced block
elsewhere in this file will not change what gets measured, and it exits
non-zero if a field is over its limit. It also measures the release notes, so
run it after editing either file.

### Claim audit

Every claim below was checked against the source during Phase 10. Two were
wrong on the first draft and were corrected, so the table is kept to record
what each claim rests on rather than just asserting the copy:

| Claim | Evidence |
|---|---|
| "no internet permission" | Release manifest has no `INTERNET`; `aapt2 dump badging` on the built APK. |
| "backup is switched off" | `allowBackup="false"`, `fullBackupContent="false"`, plus `data_extraction_rules.xml` excluding every domain. |
| "device-to-device transfer is excluded" | Same `data_extraction_rules.xml`, `disableIfNoEncryptionCapabilities` is not used; all four domains are excluded outright. |
| "Grouped results" | Result formatting groups thousands; `1250.50 x 4 = 5,002.00` is covered by formatter tests. |
| "history, grouped by day" | `history_repository.dart` has one shared day-grouping rule. |
| "Share the app with a friend from the About screen" | `about_screen.dart` has a `Share App` action calling `ShareService`. |
| "0 to 6 decimal places" | `AppSettings.minDecimalPlaces = 0`, `maxDecimalPlaces = 6`. |
| "clear your history on the History screen" | Clearing lives on the History screen, **not** Settings — an earlier draft said Settings and was wrong. Settings only toggles history saving. |
| "a dark theme" | `app_theme.dart` provides the dark theme. |

## Data safety declaration

| Question | Answer | Why |
|---|---|---|
| Does your app collect or share any required user data types? | **No** | The APK ships with no `INTERNET` permission. Verified with `aapt2 dump badging` on the release build. |
| Is all user data encrypted in transit? | N/A | No data is transmitted. |
| Do you provide a way to request data deletion? | N/A | Nothing is collected, so there is nothing to request. The app documents in-app deletion instead. |
| Is the app a "news" app, etc.? | No | Calculator. |

Play's Data Safety form is the one place where an over-claim is dangerous, so
the reasoning is recorded rather than just the answer: the "no" is backed by a
missing platform permission, which is a stronger guarantee than a promise in a
policy document.

## Privacy policy URL

Play requires a public URL, reachable from outside the app, that serves the
policy. **This is an open gate** — see below. The in-app text in
`lib/features/legal/data/legal_content.dart` is the intended content; publish it
verbatim at whatever URL you control, and paste that URL here.

## Store assets

All files are generated. Do not hand-edit the PNGs; re-run the generator.

| Asset | Path | Spec | Status |
|---|---|---|---|
| App icon | `play/icon-512.png` | exactly 512×512, 32-bit PNG with alpha, ≤1024 KB | 25.6 KB, 512×512, alpha present |
| Feature graphic | `play/feature-graphic-1024x500.png` | 1024×500, no alpha | 27.2 KB, 24-bit |
| Screenshot 1 | `play/screenshots/01-calculator.png` | 320–3840 px, 16:9 or 9:16, no alpha | 1080×1920 = 9:16 |
| Screenshot 2 | `play/screenshots/02-history.png` | same | 1080×1920 = 9:16 |
| Screenshot 3 | `play/screenshots/03-settings.png` | same | 1080×1920 = 9:16 |
| Screenshot 4 | `play/screenshots/04-privacy-policy.png` | same | 1080×1920 = 9:16 |

Four screenshots covers Play's minimum of two with room to spare. The set leads
with the calculator itself, then history, then settings, then the privacy page —
the last one is deliberately in the set, because for an app whose entire pitch
is "nothing leaves your phone", showing the actual policy is more persuasive
than another settings screen.

### Regenerating the assets

```sh
# 1. Screenshots — renders the real app with Roboto loaded
flutter test test/store/store_screenshots_test.dart \
  --update-goldens --dart-define=GENERATE_STORE_ASSETS=true

# 2. Icons, feature graphic, and the alpha-flattening pass
powershell -NoProfile -ExecutionPolicy Bypass -File tool/generate_assets.ps1
```

The script is written for Windows PowerShell 5.1, which is what ships with
Windows; it does not need PowerShell 7 (`pwsh`). On a non-Windows machine it
needs `System.Drawing`, so the icon and feature-graphic steps are
Windows-specific as written.

Order matters: the golden test writes screenshots *with* an alpha channel, and
the PowerShell step flattens them, because Play rejects screenshots that carry
transparency.

The screenshot test is skipped unless `GENERATE_STORE_ASSETS` is defined, so a
normal `flutter test` run never compares these PNGs. They are a build artifact
for the listing, not a regression suite, and asserting on them across machines
would only produce false failures from font and rasteriser differences.

---

## Open gates

Two things in this listing cannot be completed from inside the repository. Both
are the developer's to do, and both block publication.

1. **A real contact email.** `legalContactEmail` in
   `lib/features/legal/data/legal_content.dart` is still
   `TODO-replace-with-your-address@example.com`. `example.com` is IANA-reserved
   and cannot receive mail, so this is safe to commit but must not be
   published. `test/unit/legal_content_test.dart` asserts the placeholder is
   still present, so replacing it will fail that one test on purpose — delete or
   invert it in the same commit that adds the address.

2. **A public privacy policy URL.** Play requires one, and it must be
   reachable without the app. Publish the in-app policy text at any URL you
   control and record it here. Until then the listing cannot be submitted.
