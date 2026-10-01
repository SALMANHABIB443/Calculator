# Calculator 1.0.0 — release notes

First public release. The Play Console release-notes field accepts 500
characters. Copy everything inside the fence below — that fenced block is the
paste target, and its character count is stated at the end of this file.

---

```
• Full arithmetic: add, subtract, multiply, divide, percent, sign change,
  and decimals.
• Grouped results, so 1250.50 x 4 reads as 5,002.00.
• History grouped by day, and a Clear button that asks before it deletes.
• Precision from 0 to 6 decimal places, and optional key sound and haptics.
• Dark theme, adaptive icon, font sizes up to 130%.
• Works fully offline, and ships without internet permission, so it cannot
  send your data anywhere.
• No ads, no analytics, no account.
```

To re-measure after editing, run this from the repository root:

```sh
powershell -NoProfile -ExecutionPolicy Bypass -File tool\measure_store_fields.ps1
```

Current length: **482 / 500**.

Every claim in the block is checkable against the code. The three that are
easiest to get wrong, and where they were verified:

| Claim | Where it is true |
|---|---|
| "without internet permission" | The release manifest has no `INTERNET` permission; verified with `aapt2 dump badging`. |
| "a Clear button that asks before it deletes" | `history_screen.dart` routes both clear entry points through `_confirmClear` (D-05, AC-008). It is *not* one-tap. |
| "font sizes up to 130%" | `app.dart` clamps `maxTextScaleFactor = 1.3`. |
