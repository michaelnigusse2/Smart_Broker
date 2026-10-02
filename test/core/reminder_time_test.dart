import 'package:flutter_test/flutter_test.dart';
import 'package:smart_broker/core/utils/reminder_time.dart';

void main() {
  group('nextFullHour', () {
    test('rounds up to the next hour', () {
      expect(nextFullHour(DateTime(2026, 10, 1, 14, 20)), DateTime(2026, 10, 1, 15));
      expect(nextFullHour(DateTime(2026, 10, 1, 14)), DateTime(2026, 10, 1, 15));
    });

    test('rolls over midnight and month end', () {
      expect(nextFullHour(DateTime(2026, 10, 31, 23, 30)), DateTime(2026, 11, 1));
    });
  });

  test('isSchedulable only accepts future times', () {
    final now = DateTime(2026, 10, 1, 12);
    expect(isSchedulable(DateTime(2026, 10, 1, 12, 1), now), isTrue);
    expect(isSchedulable(now, now), isFalse);
    expect(isSchedulable(DateTime(2026, 10, 1, 11, 59), now), isFalse);
  });

  test('isSameCalendarDay ignores the time', () {
    expect(isSameCalendarDay(DateTime(2026, 10, 1, 0, 1), DateTime(2026, 10, 1, 23, 59)), isTrue);
    expect(isSameCalendarDay(DateTime(2026, 10, 1, 23, 59), DateTime(2026, 10, 2)), isFalse);
  });

  group('stableNotificationId', () {
    test('is 32-bit FNV-1a, masked to a positive 31-bit int', () {
      // Fixed values: if these change, alarms from older builds can no longer be cancelled.
      expect(stableNotificationId(''), 0x011c9dc5);
      expect(stableNotificationId('a'), 0x640c292c);
      expect(stableNotificationId('call:abc'), 846691607);
    });

    test('stays in Android\'s int range for long ids', () {
      final id = stableNotificationId('8f14e45f-ceea-467f-a8f5-0e4b6b3c5d21' * 4);
      expect(id, inInclusiveRange(0, 0x7FFFFFFF));
    });
  });
}
