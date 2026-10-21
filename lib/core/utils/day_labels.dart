import 'package:intl/intl.dart';

/// Short labels for when something is due or last happened, as the boards
/// write them: "Today", "Fri", "28 Oct", "2d late", "1w".
class DayLabels {
  DayLabels._();

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Whole calendar days from [from] to [to] (negative when [to] is earlier).
  static int daysBetween(DateTime from, DateTime to) => (_day(to).difference(_day(from)).inHours / 24).round();

  /// When something is due: "Today", then the weekday ("Thu") within the
  /// week, otherwise "28 Oct".
  static String due(DateTime due, DateTime now) {
    final days = daysBetween(now, due);
    if (days == 0) return 'Today';
    if (days > 0 && days < 7) return DateFormat('EEE').format(due);
    return DateFormat('d MMM').format(due);
  }

  /// How late something is: "Late" on the day, then "2d late", "3w late".
  static String late(DateTime due, DateTime now) {
    final days = daysBetween(due, now);
    if (days <= 0) return 'Late';
    if (days < 14) return '${days}d late';
    return '${days ~/ 7}w late';
  }

  /// How long ago something happened: "Today", "1d", "2w", "3mo", "1y".
  /// Empty when it never happened (the epoch).
  static String ago(DateTime when, DateTime now) {
    if (when.millisecondsSinceEpoch <= 0) return '';
    final days = daysBetween(when, now);
    if (days <= 0) return 'Today';
    if (days < 7) return '${days}d';
    if (days < 35) return '${days ~/ 7}w';
    if (days < 365) return '${days ~/ 30}mo';
    return '${days ~/ 365}y';
  }
}
