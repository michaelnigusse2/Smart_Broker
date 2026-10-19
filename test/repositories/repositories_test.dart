import 'package:flutter_test/flutter_test.dart';
import 'package:smart_broker/core/database/database_helper.dart';
import 'package:smart_broker/core/repositories/call_repository.dart';
import 'package:smart_broker/core/repositories/contact_repository.dart';
import 'package:smart_broker/core/repositories/note_repository.dart';
import 'package:smart_broker/core/repositories/reminder_repository.dart';
import 'package:smart_broker/core/repositories/todo_repository.dart';
import 'package:smart_broker/models/call_entry.dart';
import 'package:smart_broker/models/contact.dart';
import 'package:smart_broker/models/todo_item.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_db.dart';

Future<int> _count(String table) async {
  final db = await DatabaseHelper().database;
  final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM $table');
  return rows.first['n'] as int;
}

Future<int> _pendingCount(String contactId) async => (await ContactRepository().getById(contactId))!.pendingTasksCount;

void main() {
  setUp(useFreshTestDatabase);
  tearDown(closeTestDatabase);

  group('ContactRepository', () {
    test('deleting a contact removes its notes, tasks, reminders and calls', () async {
      final keep = await insertContact(id: 'keep', name: 'Test Client Two', phone: '+251911000002');
      final gone = await insertContact(id: 'gone');
      final noteId = await NoteRepository().saveNote(contactId: gone.id, rawText: 'Viewing on Friday');
      await insertTodo(contactId: gone.id, noteId: noteId);
      await insertTodo(contactId: keep.id, title: 'Unrelated task');
      await insertReminder(contactId: gone.id, noteId: noteId, at: DateTime.now().add(const Duration(days: 1)));
      await CallRepository().insert(
        CallEntry(
          id: 'call-1',
          contactId: gone.id,
          type: CallType.incoming,
          duration: const Duration(minutes: 3),
          timestamp: DateTime.now(),
        ),
      );

      await ContactRepository().delete(gone.id);

      expect(await ContactRepository().getById(gone.id), isNull);
      expect(await _count('notes'), 0);
      expect(await _count('todos'), 1, reason: 'only the other contact\'s task is left');
      expect(await _count('reminders'), 0);
      expect(await _count('calls'), 0);
    });

    test('search matches name and phone number', () async {
      await insertContact(id: 'a', name: 'Test Client Alpha', phone: '+251911000010');
      await insertContact(id: 'b', name: 'Test Client Beta', phone: '+251911000020');

      expect((await ContactRepository().search('alpha')).map((c) => c.id), ['a']);
      expect((await ContactRepository().search('000020')).map((c) => c.id), ['b']);
    });
  });

  group('one contact per number', () {
    test('saving a known number again returns the existing contact', () async {
      final first = await insertContact(id: 'first', phone: '+251 911 000 001');
      final id = await ContactRepository().insert(
        Contact(id: 'second', name: 'Same Person', phoneNumber: '0911-000-001', lastInteraction: DateTime(2026)),
      );

      expect(id, first.id);
      expect(await ContactRepository().getAll(), hasLength(1));
    });

    test('findByPhone matches any formatting and ignores numbers without digits', () async {
      await insertContact(id: 'a', phone: '+251911000001');

      expect((await ContactRepository().findByPhone('0911 000 001'))?.id, 'a');
      expect(await ContactRepository().findByPhone('0911000002'), isNull);
      expect(await ContactRepository().findByPhone(''), isNull);
    });

    test("changing a number to another contact's number fails", () async {
      await insertContact(id: 'a', phone: '+251911000001');
      final b = await insertContact(id: 'b', name: 'Test Client Two', phone: '+251911000002');

      await expectLater(
        ContactRepository().update(b.copyWith(phoneNumber: '0911000001')),
        throwsA(anything),
      );
    });

    test('touch only moves lastInteraction forward', () async {
      final c = await insertContact(lastInteraction: DateTime(2026, 5, 1));

      await ContactRepository().touch(c.id, DateTime(2026, 4, 1));
      expect((await ContactRepository().getById(c.id))!.lastInteraction, DateTime(2026, 5, 1));

      await ContactRepository().touch(c.id, DateTime(2026, 6, 1));
      expect((await ContactRepository().getById(c.id))!.lastInteraction, DateTime(2026, 6, 1));
    });

    test('the open-task count is always live', () async {
      final c = await insertContact();
      await insertTodo(contactId: c.id, title: 'A');
      await insertTodo(contactId: c.id, title: 'B');
      expect(await _pendingCount(c.id), 2);

      // Even when tasks change outside TodoRepository.
      final db = await DatabaseHelper().database;
      await db.update('todos', {'isCompleted': 1}, where: 'title = ?', whereArgs: ['A']);
      expect(await _pendingCount(c.id), 1);
    });
  });

  group('CallRepository', () {
    test('the same call is stored once', () async {
      final c = await insertContact();
      final call = CallEntry(
        id: '',
        contactId: c.id,
        type: CallType.outgoing,
        duration: const Duration(seconds: 40),
        timestamp: DateTime(2026, 10, 1, 9, 30),
      );

      final first = await CallRepository().insert(call);
      final second = await CallRepository().insert(call);

      expect(second, first);
      expect(await _count('calls'), 1);
      expect(await CallRepository().exists(c.id, call.timestamp), isTrue);
      expect(await CallRepository().exists(c.id, DateTime(2026, 10, 1, 9, 31)), isFalse);
    });
  });

  group('search', () {
    test('% and _ typed by the user are matched literally', () async {
      await insertContact(id: 'pct', name: '100% Homes', phone: '+251911000011');
      await insertContact(id: 'plain', name: '1000 Homes', phone: '+251911000012');
      await insertContact(id: 'under', name: 'Bole_Office', phone: '+251911000013');
      await insertContact(id: 'other', name: 'Bole Office', phone: '+251911000014');

      expect((await ContactRepository().search('0%')).map((c) => c.id), ['pct']);
      expect((await ContactRepository().search('e_O')).map((c) => c.id), ['under']);
    });

    test('note counts include notes waiting for AI Review', () async {
      final c = await insertContact();
      final first = await NoteRepository().saveNote(contactId: c.id, rawText: 'one');
      await NoteRepository().saveNote(contactId: c.id, rawText: 'two');
      final note = await NoteRepository().getById(first);
      await NoteRepository().update(note!.copyWith(aiSummary: 'Summary'));

      final counts = await NoteRepository().counts();
      expect(counts.total, 2);
      expect(counts.unprocessed, 1);
    });

    test('a task keeps its due date', () async {
      final c = await insertContact();
      final due = DateTime(2026, 11, 2, 9);
      final id = await TodoRepository().insert(
        TodoItem(id: '', contactId: c.id, title: 'Send offer', createdAt: DateTime(2026, 10, 1), dueAt: due),
      );

      final saved = (await TodoRepository().getByContactId(c.id)).single;
      expect(saved.id, id);
      expect(saved.dueAt, due);
      expect(saved.copyWith(clearDueAt: true).dueAt, isNull);
    });
  });

  group('NoteRepository.saveNote', () {
    test('saves a new note without an AI summary and bumps lastInteraction', () async {
      final contact = await insertContact(lastInteraction: DateTime(2020));

      final id = await NoteRepository().saveNote(contactId: contact.id, rawText: 'Call back Monday');

      final note = await NoteRepository().getById(id);
      expect(note!.rawText, 'Call back Monday');
      expect(note.aiSummary, isEmpty);
      final updated = await ContactRepository().getById(contact.id);
      expect(updated!.lastInteraction.isAfter(DateTime(2025)), isTrue);
    });

    test('updating keeps the existing summary', () async {
      final contact = await insertContact();
      final id = await NoteRepository().saveNote(contactId: contact.id, rawText: 'v1');
      final note = await NoteRepository().getById(id);
      await NoteRepository().update(note!.copyWith(aiSummary: 'Summary of v1'));

      final sameId = await NoteRepository().saveNote(contactId: contact.id, rawText: 'v2', existingNoteId: id);

      expect(sameId, id);
      final saved = await NoteRepository().getById(id);
      expect(saved!.rawText, 'v2');
      expect(saved.aiSummary, 'Summary of v1');
      expect(await _count('notes'), 1);
    });

    test('deleting a note keeps its tasks, unlinked', () async {
      final contact = await insertContact();
      final noteId = await NoteRepository().saveNote(contactId: contact.id, rawText: 'x');
      final todo = await insertTodo(contactId: contact.id, noteId: noteId);

      await NoteRepository().delete(noteId);

      final tasks = await TodoRepository().getByContactId(contact.id);
      expect(tasks.single.id, todo.id);
      expect(tasks.single.noteId, isNull);
    });
  });

  group('TodoRepository keeps pendingTasksCount in sync', () {
    test('insert, complete, reopen, toggle and delete', () async {
      final contact = await insertContact();
      final a = await insertTodo(contactId: contact.id, title: 'A');
      await insertTodo(contactId: contact.id, title: 'B');
      expect(await _pendingCount(contact.id), 2);

      await TodoRepository().setCompleted(a.id, true);
      expect(await _pendingCount(contact.id), 1);
      final completed = (await TodoRepository().getByContactId(contact.id)).firstWhere((t) => t.id == a.id);
      expect(completed.isCompleted, isTrue);
      expect(completed.completedAt, isNotNull);

      await TodoRepository().setCompleted(a.id, true); // no-op
      expect(await _pendingCount(contact.id), 1);

      await TodoRepository().setCompleted(a.id, false);
      expect(await _pendingCount(contact.id), 2);
      final reopened = (await TodoRepository().getByContactId(contact.id)).firstWhere((t) => t.id == a.id);
      expect(reopened.completedAt, isNull);

      await TodoRepository().toggleCompleted(a.id);
      expect(await _pendingCount(contact.id), 1);

      await TodoRepository().delete(a.id);
      expect(await _pendingCount(contact.id), 1);
    });

    test('getAll filters pending, completed and overdue (open > 7 days)', () async {
      final contact = await insertContact();
      await insertTodo(contactId: contact.id, title: 'fresh');
      await insertTodo(
        contactId: contact.id,
        title: 'old',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      );
      await insertTodo(contactId: contact.id, title: 'done', completed: true);

      Future<List<String>> titles(TaskFilter filter) async =>
          (await TodoRepository().getAll(filter: filter)).map((t) => t.todo.title).toList()..sort();

      expect(await titles(TaskFilter.all), ['done', 'fresh', 'old']);
      expect(await titles(TaskFilter.pending), ['fresh', 'old']);
      expect(await titles(TaskFilter.completed), ['done']);
      expect(await titles(TaskFilter.overdue), ['old']);
    });

    test('getAll sorts by contact name, ignoring case', () async {
      final b = await insertContact(id: 'b', name: 'beta Client', phone: '+251911000002');
      final a = await insertContact(id: 'a', name: 'Alpha Client', phone: '+251911000001');
      await insertTodo(contactId: b.id, title: 'for beta');
      await insertTodo(contactId: a.id, title: 'for alpha');

      final sorted = await TodoRepository().getAll(sortBy: TaskSort.contact);

      expect(sorted.map((t) => t.contactName), ['Alpha Client', 'beta Client']);
    });
  });

  group('ReminderRepository', () {
    test('upcoming, overdue and open', () async {
      final contact = await insertContact();
      final now = DateTime.now();
      await insertReminder(contactId: contact.id, id: 'past', at: now.subtract(const Duration(hours: 2)));
      await insertReminder(contactId: contact.id, id: 'future', at: now.add(const Duration(hours: 2)));
      await insertReminder(
        contactId: contact.id,
        id: 'past-done',
        at: now.subtract(const Duration(days: 1)),
        completed: true,
      );
      await insertReminder(
        contactId: contact.id,
        id: 'future-done',
        at: now.add(const Duration(days: 1)),
        completed: true,
      );

      expect((await ReminderRepository().getUpcoming()).map((r) => r.id), ['future']);
      expect((await ReminderRepository().getOverdue()).map((r) => r.id), ['past']);
      expect((await ReminderRepository().getOpen()).map((r) => r.id), ['past', 'future']);
      expect((await ReminderRepository().getAll()).length, 4);
    });
  });
}
