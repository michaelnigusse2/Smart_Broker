/// Time helpers for reminders and their notifications.
library;

/// The next full hour after [now] (14:20 → 15:00, 23:30 → 00:00 next day).
DateTime nextFullHour([DateTime? now]) {
  final t = now ?? DateTime.now();
  return DateTime(t.year, t.month, t.day, t.hour + 1);
}

/// Whether a notification scheduled for [dateTime] would still fire.
bool isSchedulable(DateTime dateTime, [DateTime? now]) =>
    dateTime.isAfter(now ?? DateTime.now());

bool isSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Deterministic 31-bit notification id for a string id (32-bit FNV-1a).
///
/// `String.hashCode` is not guaranteed to be stable across Dart versions, so a
/// scheduled alarm could become impossible to cancel after an app update.
int stableNotificationId(String id) {
  var hash = 0x811c9dc5;
  for (final unit in id.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}

/// The id scheme used by builds before [stableNotificationId]. Only used to
/// cancel alarms those builds may have scheduled.
int legacyNotificationId(String id) => id.hashCode.abs();
