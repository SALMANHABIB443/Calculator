/// Real device storage figures behind the Vault's Storage section.
///
/// The section used to carry two hardcoded strings, which is fine for a page
/// that says "Nothing stored yet" underneath but is a lie on a row that reads
/// "28.35 GB / 32.00 GB". This file is the seam that replaces the lie: a
/// `MethodChannel` to the host activity, a value type, and the one formatter
/// the subtitle is built from.
///
/// **No new dependency (D-01).** `path_provider` cannot report totals — only
/// paths — and every pub package that can would be the app's first dependency
/// since Phase 1. `StatFs` is three lines of Kotlin behind a channel, so the
/// lockdown holds and the figures come from the same syscall `df` would use.
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One volume's usage, in bytes.
///
/// A value type with no methods beyond formatting: the platform returns two
/// longs, this holds them, and the subtitle is derived at the edge. `used` is
/// computed rather than reported because the kernel does not track it — what
/// it knows is total blocks and blocks still available, and the difference is
/// the honest reading of "how much of the phone is full".
class DeviceStorage {
  const DeviceStorage({required this.totalBytes, required this.freeBytes});

  final int totalBytes;
  final int freeBytes;

  int get usedBytes => totalBytes - freeBytes;

  @override
  bool operator ==(Object other) =>
      other is DeviceStorage &&
      other.totalBytes == totalBytes &&
      other.freeBytes == freeBytes;

  @override
  int get hashCode => Object.hash(totalBytes, freeBytes);
}

/// The channel this file speaks over. A seam so tests can register a mock
/// handler on the same name without importing `MainActivity`.
const MethodChannel storageChannel = MethodChannel('calculator/storage');

/// Asks the platform for the phone's internal partition.
///
/// Never throws: a missing channel (widget tests, non-Android hosts) answers
/// `null`, which the section renders as `Unavailable` rather than as a number
/// it did not get. The honesty rule the Vault's empty states already follow —
/// no figure is better than a made-up one.
Future<DeviceStorage?> readInternalStorage() =>
    _read('getInternalStorage');

/// Asks the platform whether an SD card is mounted, and how big it is.
///
/// `null` means no card in the slot, which is what the row's subtitle says.
Future<DeviceStorage?> readSdCard() => _read('getSdCard');

Future<DeviceStorage?> _read(String method) async {
  try {
    final raw = await storageChannel.invokeMapMethod<String, int>(method);
    if (raw == null) return null;
    final total = raw['totalBytes'];
    final free = raw['freeBytes'];
    if (total == null || free == null) return null;
    return DeviceStorage(totalBytes: total, freeBytes: free);
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}

/// Formats [bytes] the way the Vault's subtitle reads: two decimals and a
/// unit, dropping to MB below a gigabyte so a 400 MB partition never renders
/// as `0.40 GB`.
String formatBytes(int bytes) {
  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(2)} MB';
  return '${(bytes / 1024).toStringAsFixed(2)} KB';
}

/// The Internal storage row's subtitle: `used / total · free free`.
///
/// `Unavailable` when the platform did not answer — deliberately not the old
/// hardcoded figures, which would still be a lie after the channel exists.
String formatStorageSubtitle(DeviceStorage? storage) {
  if (storage == null) return 'Unavailable';
  return '${formatBytes(storage.usedBytes)} / '
      '${formatBytes(storage.totalBytes)} · '
      '${formatBytes(storage.freeBytes)} free';
}

/// Both rows, fetched together because they are one section and a failure of
/// either must not take down the other — the two reads are independent and
/// each answers `null` on its own.
class VaultStorage {
  const VaultStorage({required this.internal, required this.sdCard});

  final DeviceStorage? internal;
  final DeviceStorage? sdCard;
}

/// The Storage section's data source.
///
/// A `FutureProvider` so the screen watches one value and the rows derive
/// their subtitles from it; tests override this with a fixed [VaultStorage]
/// instead of mocking the channel, which keeps them off platform details.
final vaultStorageProvider = FutureProvider<VaultStorage>((ref) async {
  final internal = await readInternalStorage();
  final sdCard = await readSdCard();
  return VaultStorage(internal: internal, sdCard: sdCard);
});
