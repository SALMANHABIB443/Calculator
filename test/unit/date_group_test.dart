import 'package:calculator/core/utils/date_group.dart';
import 'package:flutter_test/flutter_test.dart';

/// The History screen groups entries under `Today`, `Yesterday`, or a calendar
/// date (desing.md §6.2). `now` is injected everywhere so these cases do not
/// depend on when the suite runs — including across a midnight rollover.
void main() {
  // A fixed Tuesday, chosen so a day either side is unambiguous.
  final now = DateTime(2026, 9, 28, 14, 30);

  group('isSameDay', () {
    test('ignores the time of day', () {
      expect(isSameDay(DateTime(2026, 9, 28, 0, 1), now), isTrue);
      expect(isSameDay(DateTime(2026, 9, 28, 23, 59), now), isTrue);
    });

    test('separates adjacent days', () {
      expect(isSameDay(DateTime(2026, 9, 27, 14, 30), now), isFalse);
      expect(isSameDay(DateTime(2026, 9, 29), now), isFalse);
    });

    test('separates the same date in a different month or year', () {
      expect(isSameDay(DateTime(2026, 8, 28), now), isFalse);
      expect(isSameDay(DateTime(2025, 9, 28), now), isFalse);
    });
  });

  group('dayGroupLabel', () {
    test('labels a calculation made today', () {
      expect(dayGroupLabel(DateTime(2026, 9, 28, 0, 1), now: now), 'Today');
      expect(dayGroupLabel(DateTime(2026, 9, 28, 23, 59), now: now), 'Today');
    });

    test('labels a calculation made yesterday', () {
      expect(dayGroupLabel(DateTime(2026, 9, 27, 23, 59), now: now), 'Yesterday');
      expect(dayGroupLabel(DateTime(2026, 9, 27, 0, 0), now: now), 'Yesterday');
    });

    test('labels anything older as a calendar date', () {
      expect(dayGroupLabel(DateTime(2026, 9, 26), now: now), 'Sep 26, 2026');
      expect(dayGroupLabel(DateTime(2026, 9, 20), now: now), 'Sep 20, 2026');
    });

    test('crosses a month boundary into Yesterday', () {
      final firstOfMonth = DateTime(2026, 10, 1, 9);
      expect(
        dayGroupLabel(DateTime(2026, 9, 30, 22), now: firstOfMonth),
        'Yesterday',
      );
      expect(dayGroupLabel(DateTime(2026, 9, 29), now: firstOfMonth),
          'Sep 29, 2026');
    });

    test('crosses a year boundary into Yesterday', () {
      final newYear = DateTime(2027, 1, 1, 9);
      expect(
        dayGroupLabel(DateTime(2026, 12, 31, 23), now: newYear),
        'Yesterday',
      );
      expect(
        dayGroupLabel(DateTime(2026, 12, 30), now: newYear),
        'Dec 30, 2026',
      );
    });

    test('handles a leap day', () {
      final leapDay = DateTime(2028, 2, 29, 12);
      expect(
        dayGroupLabel(DateTime(2028, 2, 28), now: leapDay),
        'Yesterday',
      );
      expect(
        dayGroupLabel(DateTime(2028, 2, 27), now: leapDay),
        'Feb 27, 2028',
      );
    });

    test('names every month, in order', () {
      const expected = [
        'Jan 5, 2026',
        'Feb 5, 2026',
        'Mar 5, 2026',
        'Apr 5, 2026',
        'May 5, 2026',
        'Jun 5, 2026',
        'Jul 5, 2026',
        'Aug 5, 2026',
        'Sep 5, 2026',
        'Oct 5, 2026',
        'Nov 5, 2026',
        'Dec 5, 2026',
      ];
      for (var month = 1; month <= 12; month++) {
        expect(
          formatCalendarDate(DateTime(2026, month, 5)),
          expected[month - 1],
        );
      }
    });

    test('defaults now to the current time', () {
      expect(dayGroupLabel(DateTime.now()), 'Today');
    });
  });
}
