/// Shipped legal copy for the in-app Privacy Policy and Terms of Service
/// (D-07, D-68).
///
/// This is a data file, not a widget file. The screens in
/// `presentation/legal_screens.dart` render whatever it holds, which keeps the
/// legal text reviewable on its own — a reviewer can diff this file and see
/// exactly what shipped without wading through widget code.
///
/// ## Why these documents exist as constants
///
/// Google Play requires a privacy-policy URL for every app listing, and the
/// in-app pages exist so the policy is reachable from Settings even when the
/// app is installed from a sideloaded APK with no store listing at all. The
/// text lives in the binary rather than being fetched, because the app has no
/// network permission and could not fetch it even if it wanted to.
///
/// ## Every claim below is checkable against the code
///
/// This is the reason the text is this specific. These are not aspirational
/// promises; each one names the mechanism that makes it true, and a reviewer
/// can go verify it:
///
/// * **"makes no network requests"** — the release APK ships with no
///   `INTERNET` permission at all (verified with `aapt2 dump badging`). Not
///   "we choose not to call the network" — the app *cannot*. Adding a
///   dependency that requests `INTERNET` would falsify this line.
/// * **"never leaves your device"** — `android:allowBackup="false"` plus
///   `data_extraction_rules.xml` excluding cloud backup *and* device transfer
///   (D-65). Without those, Android would upload the history to the user's
///   Google account behind the app's back, which is the single easiest way for
///   this app's central promise to become false.
/// * **"no analytics"** — `pubspec.yaml` has no analytics, crash-reporting, or
///   attribution dependency. There is no code path that could report anything.
///
/// ## What a reviewer still has to check
///
/// The one claim that cannot be verified from the source is the developer's
/// identity and contact address. [AppInfo.developer] is a name, not an email
/// address, so both documents reference a support contact that has to be
/// filled in before publishing. That is the Phase 10 external gate, not a code
/// change; see `store/listing.md`.
library;

import '../../../core/config/app_info.dart';

/// The contact shown for support and privacy requests.
///
/// **Placeholder — replace before publishing.** Play requires a working contact
/// address on the listing, and a privacy policy that names no reachable
/// address is one of the most common reasons a listing gets rejected.
///
/// The value uses `example.com`, which IANA reserves for documentation and
/// which cannot route to anyone's inbox, so shipping it by mistake fails
/// loudly instead of sending real people's privacy questions to a stranger.
/// It is still address-shaped so that the surrounding copy reads as finished
/// and the release-gate test in `test/unit/legal_content_test.dart` can check
/// for a contact without special-casing the shape.
const String legalContactEmail = 'TODO-replace-with-your-address@example.com';

/// Privacy Policy sections, in display order (D-07).
const List<({String heading, String body})> privacyPolicySections = [
  (
    heading: 'What this app does',
    body: 'Calculator is a calculator. It evaluates arithmetic on your device '
        'and keeps a short history of what you calculated so you can recall '
        'it. It does nothing else.',
  ),
  (
    heading: 'No network access',
    body: 'This app makes no network requests. The Android version is '
        'released without the internet permission entirely, so it is '
        'technically incapable of sending your data anywhere — not to us, not '
        'to an analytics service, and not to an advertiser. There is no code '
        'in the app that opens a network connection.',
  ),
  (
    heading: 'What is stored on your device',
    body: 'Two things, both kept in the Android app\'s private storage, which '
        'other apps cannot read:\n\n'
        '• Calculation history — the expressions and results you have '
        'calculated, capped at the most recent 200 entries. Older entries are '
        'discarded automatically.\n'
        '• Your preferences — the number of decimal places to show, your '
        'choice of colour theme, the haptic-feedback setting, the keep-screen-'
        'on setting, and whether you have seen the review prompt.\n\n'
        'This data is never transmitted and is not shared with anyone.',
  ),
  (
    heading: 'Backups are disabled',
    body: 'Automatic Android backup is switched off for this app, and '
        'device-to-device transfer is excluded as well. Your history and '
        'settings therefore stay on the device you created them on: they are '
        'not uploaded to your Google account, and they do not follow you to a '
        'new phone. To move your history across devices, reinstall the app and '
        're-enter it.',
  ),
  (
    heading: 'What we do not collect',
    body: 'Nothing. No personal information, no usage analytics, no crash '
        'logs, no advertising identifiers, no device identifiers, no location, '
        'no contacts, no files. The app contains no analytics or advertising '
        'code of any kind, so there is nothing in it that could collect your '
        'data even by accident.',
  ),
  (
    heading: 'How to delete your data',
    body: 'Completely, at any time, from inside the app: the History screen '
        'clears your calculation history, and Settings switches history '
        'saving on or off. Uninstalling the app removes everything it stored, '
        'because that data exists nowhere else.',
  ),
  (
    heading: 'Children',
    body: 'This app is a calculator and collects no data from anyone, so it is '
        'suitable for all ages. Because it stores nothing and sends nothing, '
        'it cannot gather information about children.',
  ),
  (
    heading: 'Changes to this policy',
    body: 'If a future release changes what the app stores or whether it '
        'connects to the network, this policy will be updated in the same '
        'release. The date of the most recent change is shown at the end of '
        'this document.',
  ),
  (
    heading: 'Last updated',
    body: 'September 2026, for version ${AppInfo.version}.',
  ),
  (
    heading: 'Contact',
    body: 'Questions about this policy can be sent to $legalContactEmail. '
        'Because nothing is collected, we will not have any data about you to '
        'look up — please include your question in the email itself.',
  ),
];

/// Terms of Service sections, in display order (D-07).
const List<({String heading, String body})> termsOfServiceSections = [
  (
    heading: 'Agreement',
    body: 'By using ${AppInfo.name} you agree to these terms. If you do not '
        'agree, please uninstall the app.',
  ),
  (
    heading: 'The licence',
    body: 'You are granted a personal, non-exclusive, non-transferable licence '
        'to use this app on devices you own or control. You may not '
        'redistribute, resell, sublicense, or modify the app, and you may not '
        'remove or alter any branding or attribution.',
  ),
  (
    heading: 'What the app is for',
    body: 'The app is a general-purpose calculator. It is provided for '
        'everyday arithmetic convenience. It is not a certified instrument and '
        'is not suitable for engineering, medical, financial, or legal '
        'calculation, where an error could cause harm.',
  ),
  (
    heading: 'Verify important results',
    body: 'You are responsible for checking any result before relying on it, '
        'especially where a mistake would be costly. No arithmetic tool is '
        'perfect; do not use this one as the only check on a calculation that '
        'matters.',
  ),
  (
    heading: 'No warranty',
    body: 'The app is provided "as is", without warranty of any kind, express '
        'or implied, including but not limited to the warranties of '
        'merchantability, fitness for a particular purpose, and '
        'non-infringement. We do not warrant that the app will be '
        'uninterrupted, error-free, or free of defects.',
  ),
  (
    heading: 'Limitation of liability',
    body: 'To the maximum extent permitted by law, in no event shall the '
        'developer be liable for any claim, damages, or other liability — '
        'whether in contract, tort, or otherwise — arising from, out of, or '
        'in connection with the app or its use, or for any calculation result '
        'obtained through it.',
  ),
  (
    heading: 'Your data stays yours',
    body: 'The app stores your history and preferences only on your device and '
        'transmits nothing. We have no access to your data, cannot retrieve it, '
        'and cannot recover it for you. Clearing your history or uninstalling '
        'deletes it permanently.',
  ),
  (
    heading: 'Changes and availability',
    body: 'The app may be updated, changed, or withdrawn at any time, and any '
        'update may alter these terms; continued use after an update means you '
        'accept the revised terms. We may stop distributing the app on some '
        'storefronts or in some regions.',
  ),
  (
    heading: 'Last updated',
    body: 'September 2026, for version ${AppInfo.version}.',
  ),
  (
    heading: 'Contact',
    body: 'Questions about these terms can be sent to $legalContactEmail.',
  ),
];