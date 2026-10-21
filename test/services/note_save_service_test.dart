import 'package:flutter_test/flutter_test.dart';
import 'package:smart_broker/core/repositories/contact_repository.dart';
import 'package:smart_broker/core/repositories/note_repository.dart';
import 'package:smart_broker/core/repositories/reminder_repository.dart';
import 'package:smart_broker/core/repositories/todo_repository.dart';
import 'package:smart_broker/core/services/note_save_service.dart';
import 'package:smart_broker/models/reminder.dart';
import 'package:smart_broker/models/todo_item.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_db.dart';

void main() {
  late List<String> cancelled;
  late List<Reminder> scheduled;
  late NoteSaveService service;
  late String contactId;
  late String noteId;
  // Whole minutes: the database stores milliseconds, DateTime.now() has microseconds.
  final today = DateTime.now();
  final followUp = DateTime(today.year, today.month, today.day + 3, 10);

  setUp(() async {
    await useFreshTestDatabase();
    cancelled = [];
    scheduled = [];
    service = NoteSaveService(
      cancelReminder: (id) async => cancelled.add(id),
      scheduleReminder: (r) async {
        scheduled.add(r);
        return true;
      },
    );
    contactId = (await insertContact()).id;
    noteId = await NoteRepository().saveNote(contactId: contactId, rawText: 'Viewing next Monday');
  });
  tearDown(closeTestDatabase);

  ReviewedNote review(List<String> tasks, {DateTime? reminderAt, String summary = 'Summary'}) => ReviewedNote(
    noteId: noteId,
    contactId: contactId,
    rawText: 'Viewing next Monday',
    summary: summary,
    taskTitles: tasks,
    reminder: reminderAt == null ? null : (title: 'Viewing', dateTime: reminderAt),
  );

  Future<List<TodoItem>> tasks() => TodoRepository().getByNoteId(noteId);
  Future<int> pending() async => (await ContactRepository().getById(contactId))!.pendingTasksCount;

  test('first review saves summary, tasks and reminder and schedules it', () async {
    await service.apply(review(['Send floor plan', 'Book viewing'], reminderAt: followUp, summary: 'Wants a viewing'));

    expect((await NoteRepository().getById(noteId))!.aiSummary, 'Wants a viewing');
    expect((await tasks()).map((t) => t.title).toSet(), {'Send floor plan', 'Book viewing'});
    expect(await pending(), 2);
    final reminders = await ReminderRepository().getByNoteId(noteId);
    expect(reminders.single.dateTime, followUp);
    expect(scheduled.single.id, reminders.single.id);
    expect(cancelled, isEmpty);
  });

  test('re-review keeps completed tasks and matching open tasks, removes dropped ones', () async {
    await service.apply(review(['Send floor plan', 'Book viewing', 'Call the bank']));
    final before = {for (final t in await tasks()) t.title: t};
    await TodoRepository().setCompleted(before['Send floor plan']!.id, true);

    final wouldRemove = await service.openTasksThatWouldBeRemoved(noteId, ['book  VIEWING', 'Prepare contract']);
    expect(wouldRemove.map((t) => t.title), ['Call the bank']);

    await service.apply(review(['book  VIEWING', 'Prepare contract']));

    final after = {for (final t in await tasks()) t.title: t};
    expect(after.keys.toSet(), {'Send floor plan', 'Book viewing', 'Prepare contract'});
    expect(after['Send floor plan']!.isCompleted, isTrue, reason: 'completed work is never deleted');
    expect(after['Book viewing']!.id, before['Book viewing']!.id, reason: 'same task, same row');
    expect(await pending(), 2);
  });

  test('ignores blank and duplicate task titles', () async {
    await service.apply(review(['Send floor plan', '  ', 'send floor plan ']));

    expect((await tasks()).map((t) => t.title), ['Send floor plan']);
  });

  test('moving the reminder updates the same row and reopens it', () async {
    await service.apply(review([], reminderAt: followUp));
    final original = (await ReminderRepository().getByNoteId(noteId)).single;
    await ReminderRepository().update(original.copyWith(completed: true));

    final later = followUp.add(const Duration(days: 1));
    await service.apply(review([], reminderAt: later));

    final updated = (await ReminderRepository().getByNoteId(noteId)).single;
    expect(updated.id, original.id);
    expect(updated.dateTime, later);
    expect(updated.completed, isFalse);
    expect(cancelled, [original.id]);
    expect(scheduled.last.id, original.id);
  });

  test('switching the reminder off deletes it and cancels the notification', () async {
    await service.apply(review([], reminderAt: followUp));
    final id = (await ReminderRepository().getByNoteId(noteId)).single.id;
    scheduled.clear();

    await service.apply(review([]));

    expect(await ReminderRepository().getByNoteId(noteId), isEmpty);
    expect(cancelled, [id]);
    expect(scheduled, isEmpty);
  });

  test('what they owe is saved on their side, and kept apart from yours', () async {
    await service.apply(
      ReviewedNote(
        noteId: noteId,
        contactId: contactId,
        rawText: 'Viewing next Monday',
        summary: 'Summary',
        taskTitles: ['Send floor plan'],
        theirTitles: ['Signed offer', 'Send floor plan'],
      ),
    );
    final saved = {for (final t in await tasks()) '${t.owedBy.name}:${t.title}'};
    expect(saved, {'me:Send floor plan', 'them:Signed offer', 'them:Send floor plan'});

    // A re-review that drops "Signed offer" removes only that one.
    expect(
      (await service.openTasksThatWouldBeRemoved(
        noteId,
        ['Send floor plan'],
        newTheirTitles: ['Send floor plan'],
      )).map((t) => t.title),
      ['Signed offer'],
    );
  });
}
