import 'package:flutter_test/flutter_test.dart';
import 'package:smart_broker/core/utils/day_labels.dart';
import 'package:smart_broker/core/utils/waiting_on_you.dart';
import 'package:smart_broker/models/contact.dart';
import 'package:smart_broker/models/reminder.dart';
import 'package:smart_broker/models/todo_item.dart';

/// 10:10 on Wednesday 21 October 2026, like the boards.
final _now = DateTime(2026, 10, 21, 10, 10);

void main() {
  test('due dates read as the boards write them', () {
    expect(DayLabels.due(DateTime(2026, 10, 21, 17), _now), 'Today');
    expect(DayLabels.due(DateTime(2026, 10, 22, 9), _now), 'Thu');
    expect(DayLabels.due(DateTime(2026, 10, 23), _now), 'Fri');
    expect(DayLabels.due(DateTime(2026, 10, 26), _now), 'Mon');
    expect(DayLabels.due(DateTime(2026, 10, 28), _now), '28 Oct');
  });

  test('late and ago count calendar days', () {
    expect(DayLabels.late(DateTime(2026, 10, 21, 9), _now), 'Late');
    expect(DayLabels.late(DateTime(2026, 10, 19, 23, 59), _now), '2d late');
    expect(DayLabels.late(DateTime(2026, 9, 30), _now), '3w late');
    expect(DayLabels.ago(DateTime(2026, 10, 21, 8), _now), 'Today');
    expect(DayLabels.ago(DateTime(2026, 10, 20, 23), _now), '1d');
    expect(DayLabels.ago(DateTime(2026, 10, 7), _now), '2w');
    expect(DayLabels.ago(DateTime.fromMillisecondsSinceEpoch(0), _now), '');
  });

  test('waiting on you: late first, then soonest due; only what you owe', () {
    Contact person(String id) => Contact(id: id, name: id, phoneNumber: '', lastInteraction: DateTime(2026));
    final contacts = {
      for (final id in ['hanna', 'selam', 'dawit', 'meron', 'yonas']) id: person(id),
    };
    TodoItem promise(String who, DateTime? due, {OwedBy owedBy = OwedBy.me}) =>
        TodoItem(id: who, contactId: who, title: 'x', createdAt: DateTime(2026, 10, 1), dueAt: due, owedBy: owedBy);
    final people = waitingOnYou(
      pending: [
        promise('dawit', DateTime(2026, 10, 23)),
        promise('selam', DateTime(2026, 10, 21, 17)),
        promise('meron', null),
        promise('hanna', DateTime(2026, 10, 19)),
        // Yonas owes you; that doesn't keep him waiting on you.
        promise('yonas', DateTime(2026, 10, 22), owedBy: OwedBy.them),
      ],
      missed: [
        Reminder(
          id: 'r',
          contactId: 'selam',
          title: 'Call',
          dateTime: DateTime(2026, 10, 21, 9),
          createdAt: DateTime(2026, 10, 1),
        ),
      ],
      contacts: contacts,
      now: _now,
      except: 'dawit',
    );
    expect([for (final p in people) '${p.contact.id}${p.late ? '!' : ''}'], ['hanna!', 'selam!', 'meron']);
  });
}
