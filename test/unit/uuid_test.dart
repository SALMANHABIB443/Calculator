import 'dart:math';

import 'package:calculator/core/utils/uuid.dart';
import 'package:flutter_test/flutter_test.dart';

/// A history entry's `id` is the app's only UUID, and [D-01] rules out the
/// `uuid` package, so the generator is hand-rolled. These tests lock in the two
/// properties the rest of the app relies on: the string is a well-formed v4
/// UUID, and two calls do not collide.
void main() {
  final pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  group('uuidV4', () {
    test('is a well-formed version 4 UUID', () {
      expect(uuidV4(), matches(pattern));
    });

    test('groups the hex digits 8-4-4-4-12', () {
      final id = uuidV4();
      final parts = id.split('-');
      expect(parts, hasLength(5));
      expect(
        parts.map((part) => part.length),
        <int>[8, 4, 4, 4, 12],
      );
    });

    test('lowercases every hex digit and pads each byte to two', () {
      // A seeded generator makes the exact bytes predictable, so this can assert
      // the formatting rather than only the pattern.
      final id = uuidV4(Random(0));
      expect(id, id.toLowerCase());
      expect(id, hasLength(36));
      expect(id.replaceAll('-', ''), hasLength(32));
    });

    test('forces the version and variant nibbles for every draw', () {
      // A single draw could pass by luck; sweeping the generator proves the two
      // masks are applied unconditionally.
      for (var i = 0; i < 200; i++) {
        expect(uuidV4(), matches(pattern));
      }
    });

    test('does not repeat across 1000 draws', () {
      final ids = <String>{for (var i = 0; i < 1000; i++) uuidV4()};
      expect(ids, hasLength(1000));
    });

    test('accepts an injected Random for deterministic tests', () {
      // Same seed, same id — which is what makes the formatting testable at
      // all, since the default source is deliberately non-deterministic.
      expect(uuidV4(Random(42)), uuidV4(Random(42)));
      expect(uuidV4(Random(42)), isNot(uuidV4(Random(43))));
    });
  });
}
