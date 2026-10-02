import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_broker/core/services/app_log.dart';

void main() {
  final originalDebugPrint = debugPrint;
  setUp(() {
    AppLog.clear();
    debugPrint = (String? message, {int? wrapWidth}) {}; // keep test output readable
  });
  tearDown(() => debugPrint = originalDebugPrint);

  test('maskPhone hides the middle of the number', () {
    expect(AppLog.maskPhone('+251911234567'), '+2519****567');
    expect(AppLog.maskPhone('0911 234 567'), '0911****567');
    expect(AppLog.maskPhone('12345'), '***');
  });

  test('keeps only the most recent entries', () {
    for (var i = 0; i < AppLog.capacity + 10; i++) {
      AppLog.d('Test', 'entry $i');
    }

    expect(AppLog.entries, hasLength(AppLog.capacity));
    expect(AppLog.entries.first, endsWith('entry 10'));
    expect(AppLog.entries.last, endsWith('entry ${AppLog.capacity + 9}'));
  });

  test('formats level, tag and error', () {
    AppLog.w('Calls', 'lookup failed', 'timeout');

    expect(AppLog.entries.single, endsWith('W/Calls: lookup failed: timeout'));
  });
}
