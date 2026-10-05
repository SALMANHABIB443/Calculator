/// Day-grouping helper for the History screen (desing.md §6.2, D-10).
///
/// Pure Dart with no Flutter and no `intl` dependency — the dependency set is
/// fixed at D-01 and does not include a date library, so the month names are
/// spelled out here. That is the only formatting this app needs: history
/// sections are `Today`, `Yesterday`, or a calendar date.
library;

/// Month abbreviations, index-aligned with [DateTime.month] (1–12).
const List<String> _monthNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Whether two instants fall on the same calendar day, in local time.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The section header for a calculation made at [timestamp].
///
/// Returns `Today`, `Yesterday`, or a `Mon D, YYYY` date such as
/// `Sep 20, 2026`, matching the label carried by `HistoryDayGroup`.
///
/// [now] is injectable so the behaviour is testable without waiting for a day
/// to pass; it defaults to the current time. Comparison is on the local
/// calendar day, so a calculation at 11pm is still "Today" at 1am.
String dayGroupLabel(DateTime timestamp, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  if (isSameDay(timestamp, reference)) return 'Today';

  final yesterday = DateTime(
    reference.year,
    reference.month,
    reference.day,
  ).subtract(const Duration(days: 1));
  if (isSameDay(timestamp, yesterday)) return 'Yesterday';

  return formatCalendarDate(timestamp);
}

/// Formats [date] as `Mon D, YYYY` — the label for history older than
/// yesterday.
String formatCalendarDate(DateTime date) =>
    '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';