/// UUID version 4 generation, without a package.
///
/// [D-01] locks the dependency set, and `uuid` is not in it. A history entry's
/// `id` is the only place this app needs one, so a dependency for it would cost
/// more than the twenty lines below.
///
/// Pure Dart with no Flutter import, so it unit-tests in isolation.
library;

import 'dart:math';

/// A random RFC 4122 version 4 UUID, e.g.
/// `3f2b9c1e-7a44-4d0b-8c3e-1f9a5b6d2e07`.
///
/// 122 of the 128 bits are random; bits 48–51 are forced to `0100` (version 4)
/// and bits 64–65 to `10` (the RFC 4122 variant), which is what makes the string
/// a well-formed v4 UUID rather than 128 arbitrary bits. The dashes are the
/// 8-4-4-4-12 grouping RFC 4122 specifies.
///
/// Backed by [Random.secure], which is the right source for an identifier: the
/// only requirement is that two calls do not collide, and this avoids the
/// shared, seeded [Random] instance a non-secure generator would share with
/// everything else in the process.
///
/// The value is opaque to the app. Nothing parses it or orders by it — history
/// is ordered by [HistoryEntry.timestamp] — so a malformed id coming back from
/// disk would be harmless rather than corrupting.
String uuidV4([Random? random]) {
  final rng = random ?? Random.secure();

  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0F) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3F) | 0x80; // variant 10xx

  final buffer = StringBuffer();
  for (var i = 0; i < bytes.length; i++) {
    if (i == 4 || i == 6 || i == 8 || i == 10) buffer.write('-');
    buffer.write(bytes[i].toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}