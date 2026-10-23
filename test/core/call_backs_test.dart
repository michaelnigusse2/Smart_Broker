import 'package:flutter_test/flutter_test.dart';
import 'package:smart_broker/core/utils/call_backs.dart';
import 'package:smart_broker/models/call_entry.dart';
import 'package:smart_broker/models/contact.dart';
import 'package:smart_broker/models/reminder.dart';

void main() {
  final now = DateTime(2026, 10, 21, 12);
  Contact person(String id, {DateTime? cleared}) =>
      Contact(id: id, name: id, phoneNumber: '0911$id', lastInteraction: now, callBackClearedAt: cleared);
  var n = 0;
  CallEntry call(String who, CallType type, DateTime at, [int seconds = 0]) => CallEntry(
    id: '${n++}',
    contactId: who,
    type: type,
    duration: Duration(seconds: seconds),
    timestamp: at,
  );
  DateTime ago(int minutes) => now.subtract(Duration(minutes: minutes));

  List<CallBack> run(List<CallEntry> calls, {List<Contact>? people, List<Reminder> reminders = const []}) => callBacks(
    calls: calls,
    contacts: {
      for (final c in people ?? [person('selam'), person('hirut')]) c.id: c,
    },
    reminders: reminders,
    now: now,
  );

  test('a missed call asks for a call back', () {
    final out = run([call('selam', CallType.missed, ago(30))]);
    expect(out.single.contact.id, 'selam');
    expect(out.single.missed, 1);
    expect(out.single.triedAt, isNull);
    expect(out.single.isLate(now), isFalse);
  });

  test('two misses merge into one line', () {
    final out = run([call('selam', CallType.missed, ago(90)), call('selam', CallType.missed, ago(30))]);
    expect(out.single.missed, 2);
    expect(out.single.firstMissedAt, ago(90));
    expect(out.single.lastMissedAt, ago(30));
  });

  test('it clears when you talk: they call again or you call and they answer', () {
    expect(run([call('selam', CallType.missed, ago(30)), call('selam', CallType.incoming, ago(10), 60)]), isEmpty);
    expect(run([call('selam', CallType.missed, ago(30)), call('selam', CallType.outgoing, ago(10), 45)]), isEmpty);
  });

  test('calling back without an answer keeps it, marked as tried', () {
    final out = run([call('selam', CallType.missed, ago(30)), call('selam', CallType.outgoing, ago(10))]);
    expect(out.single.triedAt, ago(10));
  });

  test('a missed call after you talked opens a new one', () {
    final out = run([
      call('selam', CallType.missed, ago(120)),
      call('selam', CallType.incoming, ago(90), 30),
      call('selam', CallType.missed, ago(20)),
    ]);
    expect(out.single.missed, 1);
    expect(out.single.firstMissedAt, ago(20));
  });

  test('"Not needed" hides it until their next missed call', () {
    final cleared = person('selam', cleared: ago(15));
    expect(run([call('selam', CallType.missed, ago(30))], people: [cleared]), isEmpty);
    final out = run(
      [call('selam', CallType.missed, ago(30)), call('selam', CallType.missed, ago(5))],
      people: [cleared],
    );
    expect(out.single.missed, 1);
  });

  test('not returned by the next day it is late; older than two weeks it drops off', () {
    final yesterday = now.subtract(const Duration(days: 1));
    expect(run([call('hirut', CallType.missed, yesterday)]).single.isLate(now), isTrue);
    expect(run([call('hirut', CallType.missed, now.subtract(const Duration(days: 15)))]), isEmpty);
  });

  test('a call-back reminder is attached; newest missed call first; strangers skipped', () {
    final reminder = Reminder(
      id: 'r',
      contactId: 'hirut',
      title: 'Call back',
      dateTime: now.add(const Duration(hours: 6)),
      createdAt: now,
      kind: Reminder.callBack,
    );
    final out = run(
      [
        call('hirut', CallType.missed, ago(300)),
        call('selam', CallType.missed, ago(30)),
        call('nobody', CallType.missed, ago(10)),
      ],
      reminders: [reminder],
    );
    expect([for (final c in out) c.contact.id], ['selam', 'hirut']);
    expect(out.last.reminder?.id, 'r');
    expect(out.first.reminder, isNull);
  });
}
