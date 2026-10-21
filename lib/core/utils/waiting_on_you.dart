import '../../models/contact.dart';
import '../../models/reminder.dart';
import '../../models/todo_item.dart';

/// Someone waiting on you: you owe them something or missed calling them.
class WaitingPerson {
  const WaitingPerson({required this.contact, required this.late, required this.due});

  final Contact contact;

  /// Something owed is past due, or a reminder to call them was missed.
  final bool late;

  /// The soonest date among what's owed, or null when nothing has a date.
  final DateTime? due;
}

/// Everyone waiting on you: anyone late first, then whoever is due soonest.
/// [pending] are open promises (only the ones you owe count), [missed] are open reminders whose time has
/// passed. [except] leaves one person out (Today shows them elsewhere).
List<WaitingPerson> waitingOnYou({
  required Iterable<TodoItem> pending,
  required Iterable<Reminder> missed,
  required Map<String, Contact> contacts,
  required DateTime now,
  String? except,
}) {
  final late = <String, bool>{};
  final soonest = <String, DateTime?>{};
  void add(String contactId, DateTime? due, bool overdue) {
    if (contactId == except || !contacts.containsKey(contactId)) return;
    late[contactId] = (late[contactId] ?? false) || overdue;
    final current = soonest[contactId];
    if (!soonest.containsKey(contactId) || (due != null && (current == null || due.isBefore(current)))) {
      soonest[contactId] = due;
    }
  }

  // Only what you owe keeps someone waiting; what they owe you doesn't.
  for (final todo in pending.where((t) => t.owedBy == OwedBy.me)) {
    add(todo.contactId, todo.dueAt, todo.dueAt != null && todo.dueAt!.isBefore(now));
  }
  for (final reminder in missed) {
    add(reminder.contactId, reminder.dateTime, true);
  }
  final people = [
    for (final id in late.keys) WaitingPerson(contact: contacts[id]!, late: late[id]!, due: soonest[id]),
  ];
  people.sort((a, b) {
    if (a.late != b.late) return a.late ? -1 : 1;
    final ad = a.due ?? DateTime(9999);
    final bd = b.due ?? DateTime(9999);
    final byDate = ad.compareTo(bd);
    return byDate != 0 ? byDate : a.contact.name.toLowerCase().compareTo(b.contact.name.toLowerCase());
  });
  return people;
}
