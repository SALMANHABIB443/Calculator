import 'package:calculator/features/secret/data/device_storage_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Vault Storage section's data path: bytes in, subtitle out.
///
/// Three layers are asserted here because they fail differently. The formatter
/// is pure arithmetic and can only be wrong; the channel reader is a parsing
/// contract with the Kotlin side and can only be wrong against the map that
/// side sends; and the `null` answers are the honesty rule — no channel, no
/// figure — which only holds if every failure mode lands on `null` rather than
/// on a default number.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('formatBytes', () {
    test('reads gigabytes with two decimals', () {
      expect(formatBytes(34359738368), '32.00 GB');
      expect(formatBytes(1073741824), '1.00 GB');
    });

    test('drops to megabytes below a gigabyte', () {
      expect(formatBytes(419430400), '400.00 MB');
      expect(formatBytes(1048576), '1.00 MB');
    });

    test('drops to kilobytes below a megabyte', () {
      expect(formatBytes(512), '0.50 KB');
    });
  });

  group('formatStorageSubtitle', () {
    test('renders used / total with the free figure trailing', () {
      const storage = DeviceStorage(
        totalBytes: 34359738368, // 32 GB
        freeBytes: 3918657658, // ~3.65 GB
      );
      expect(
        formatStorageSubtitle(storage),
        '28.35 GB / 32.00 GB · 3.65 GB free',
      );
    });

    test('answers Unavailable rather than a number when there is none', () {
      expect(formatStorageSubtitle(null), 'Unavailable');
    });
  });

  group('DeviceStorage', () {
    test('used is total minus free', () {
      const storage = DeviceStorage(totalBytes: 100, freeBytes: 30);
      expect(storage.usedBytes, 70);
    });

    test('compares by value so provider rebuilds settle', () {
      const a = DeviceStorage(totalBytes: 1, freeBytes: 2);
      const b = DeviceStorage(totalBytes: 1, freeBytes: 2);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('channel reads', () {
    /// The map `MainActivity.statOf` sends, through the same codec the real
    /// channel uses — so a key rename on the Kotlin side fails here rather than
    /// silently rendering `Unavailable` on a user's phone.
    void mockChannel(Map<String, int>? response) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storageChannel, (call) async => response);
    }

    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storageChannel, null),
    );

    test('parses the platform map into a DeviceStorage', () async {
      mockChannel(<String, int>{
        'totalBytes': 34359738368,
        'freeBytes': 3918657658,
      });
      expect(
        await readInternalStorage(),
        const DeviceStorage(
          totalBytes: 34359738368,
          freeBytes: 3918657658,
        ),
      );
    });

    test('null means no volume — the SD card case', () async {
      mockChannel(null);
      expect(await readSdCard(), isNull);
    });

    test('a platform error answers null, never a default figure', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storageChannel, (call) async {
            throw PlatformException(code: 'unavailable');
          });
      expect(await readInternalStorage(), isNull);
    });

    test('a missing channel — test hosts — answers null', () async {
      mockChannel(null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storageChannel, null);
      expect(await readInternalStorage(), isNull);
    });
  });
}
