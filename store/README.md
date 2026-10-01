# Store listing materials

Everything needed to fill in the Google Play Console for Calculator v1.0.0,
plus the two things that cannot be produced from inside this repository.

| File | What it is |
|---|---|
| [`listing.md`](listing.md) | Short and full descriptions, Data Safety answers, the asset manifest with measured dimensions, and the claim audit. **The open gates are at the bottom of this file.** |
| [`release-notes-1.0.0.md`](release-notes-1.0.0.md) | The 500-character release-notes field, in a fenced block that is the paste target. |
| `play/` | The generated graphics Play accepts. Do not hand-edit these; see below. |

---

## Generated assets

Nothing under `play/` is drawn by hand. `tool/generate_assets.ps1` produces the
512×512 store icon, the 1024×500 feature graphic, the launcher icons under
`android/app/src/main/res/mipmap-*`, and the alpha-flattening pass over the
screenshots (`D-66`, `D-67`).

The screenshots themselves come from `test/store/store_screenshots_test.dart`,
which renders the real app — real widgets, real theme, real copy — at Play's
1080×1920 rather than mocking the screens. It is skipped unless
`GENERATE_STORE_ASSETS` is defined, so an ordinary `flutter test` run never
compares these PNGs; they are a listing artifact, not a regression suite, and
pinning them across machines would only produce false failures from font and
rasteriser differences.

Regenerate everything, in this order:

```sh
# 1. Screenshots. Writes them with an alpha channel.
flutter test test/store/store_screenshots_test.dart \
  --update-goldens --dart-define=GENERATE_STORE_ASSETS=true

# 2. Icons, feature graphic, and the flattening pass.
powershell -NoProfile -ExecutionPolicy Bypass -File tool\generate_assets.ps1
```

Order matters: the golden test writes screenshots *with* alpha, and step 2
flattens them, because Play rejects screenshots carrying transparency. The
matte colour is sampled from each screenshot's own background rather than
hard-coded, so a theme change does not leave a mismatched border.

`tool/generate_assets.ps1` is written for Windows PowerShell 5.1, which ships
with Windows; it does not need PowerShell 7. On a non-Windows machine the icon
and feature-graphic steps additionally need `System.Drawing`, so those steps
are Windows-specific as written.

## Text field lengths

Play's limits are hard rejections, so they are checked by a script rather than
by eye:

```sh
powershell -NoProfile -ExecutionPolicy Bypass -File tool\measure_store_fields.ps1
```

It measures the fenced block in each field, resolves each block from its section
heading so an unrelated fence elsewhere in the file cannot change what is
measured, and exits non-zero if anything is over. Current lengths:

| Field | Limit | Current |
|---|---|---|
| Short description | 80 | 69 |
| Full description | 4000 | 1828 |
| Release notes | 500 | 482 |

Both documents quote these numbers in prose. If you edit a field, update the
quote too, or the script and the text will disagree.

## Open gates

Neither of these can be completed from inside the repository. Both block
publication, and both are described in more detail at the bottom of
[`listing.md`](listing.md).

1. **A real contact email.** `legalContactEmail` in
   `lib/features/legal/data/legal_content.dart` is
   `TODO-replace-with-your-address@example.com`. `example.com` is IANA-reserved
   and cannot receive mail, so it is safe to commit but must not be published.
   `test/unit/legal_content_test.dart` asserts the placeholder is still there, so
   replacing it fails that one test on purpose — update or delete the assertion in
   the same change that adds the address.
2. **A public privacy policy URL.** Play requires one reachable from outside the
   app. Publish the in-app policy text verbatim at a URL you control.

## Publication checklist

Beyond the two gates above:

- [ ] Upload keystore generated, backed up **outside** the repository, and
      described by a git-ignored `android/key.properties` (`D-62`).
- [ ] `flutter build appbundle --release` produces a signed AAB, and
      `jarsigner -verify` accepts it.
- [ ] Privacy policy URL added to the Play listing and to `listing.md`.
- [ ] Content rating questionnaire completed.
- [ ] Target-audience band chosen — `listing.md` recommends 13+ over 4+.
- [ ] **On a physical device:** install and run, exercise the share sheet and the
      in-app review prompt, walk the screens with TalkBack, and check history
      persistence across a restart. No device or emulator was available in this
      environment, so none of this has been done. Passing builds and passing
      tests do not stand in for it.
