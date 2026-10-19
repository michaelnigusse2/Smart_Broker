import 'package:uuid/uuid.dart';

import '../../models/reminder.dart';
import '../../models/todo_item.dart';
import '../database/database_helper.dart';
import 'notification_service.dart';

/// What the user approved on the AI Review screen.
class ReviewedNote {
  final String noteId;
  final String contactId;
  final String rawText;
  final String summary;
  final List<String> taskTitles;

  /// Null when the reminder switch is off.
  final ({String title, DateTime dateTime})? reminder;

  const ReviewedNote({
    required this.noteId,
    required this.contactId,
    required this.rawText,
    required this.summary,
    required this.taskTitles,
    this.reminder,
  });
}

/// Applies an AI review to an existing note without losing work.
///
/// Running AI Review again on a note used to delete every task and reminder
/// that came from it — including completed ones — and re-create them, outside
/// a transaction. Now:
/// - completed tasks are always kept;
/// - open tasks are kept when the new review still lists them (same title,
///   ignoring case/spaces), otherwise removed;
/// - the note's reminder is updated in place, or removed if switched off;
/// - everything happens in one transaction.
class NoteSaveService {
  final _uuid = const Uuid();
  final Future<void> Function(String reminderId) _cancelReminder;
  final Future<bool> Function(Reminder reminder) _scheduleReminder;

  /// The notification hooks are injectable so tests don't need the plugin.
  NoteSaveService({
    Future<void> Function(String reminderId)? cancelReminder,
    Future<bool> Function(Reminder reminder)? scheduleReminder,
  }) : _cancelReminder = cancelReminder ?? NotificationService().cancelReminder,
       _scheduleReminder = scheduleReminder ?? NotificationService().scheduleReminder;

  static String _normalise(String title) => title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Open tasks from an earlier review of [noteId] that saving
  /// [newTaskTitles] would remove. Used to warn before saving.
  Future<List<TodoItem>> openTasksThatWouldBeRemoved(String noteId, List<String> newTaskTitles) async {
    final db = await DatabaseHelper().database;
    final rows = await db.query('todos', where: 'noteId = ? AND isCompleted = 0', whereArgs: [noteId]);
    final keep = newTaskTitles.map(_normalise).toSet();
    return rows.map(TodoItem.fromMap).where((t) => !keep.contains(_normalise(t.title))).toList();
  }

  Future<void> apply(ReviewedNote review) async {
    final db = await DatabaseHelper().database;
    final now = DateTime.now();
    final remindersToCancel = <String>[];
    Reminder? reminderToSchedule;

    await db.transaction((txn) async {
      await txn.update(
        'notes',
        {'rawText': review.rawText, 'aiSummary': review.summary},
        where: 'id = ?',
        whereArgs: [review.noteId],
      );

      // ── Tasks ────────────────────────────────────────────────────
      final existing = (await txn.query(
        'todos',
        where: 'noteId = ?',
        whereArgs: [review.noteId],
      )).map(TodoItem.fromMap).toList();
      final alreadyThere = <String>{};
      for (final todo in existing) {
        final key = _normalise(todo.title);
        if (todo.isCompleted) {
          alreadyThere.add(key);
          continue;
        }
        final stillWanted = review.taskTitles.any((t) => _normalise(t) == key);
        if (stillWanted) {
          alreadyThere.add(key);
        } else {
          await txn.delete('todos', where: 'id = ?', whereArgs: [todo.id]);
        }
      }
      for (final title in review.taskTitles) {
        final trimmed = title.trim();
        final key = _normalise(trimmed);
        if (trimmed.isEmpty || alreadyThere.contains(key)) continue;
        alreadyThere.add(key);
        await txn.insert(
          'todos',
          TodoItem(
            id: _uuid.v4(),
            contactId: review.contactId,
            noteId: review.noteId,
            title: trimmed,
            createdAt: now,
          ).toMap(),
        );
      }

      // ── Reminder ────────────────────────────────────────────────
      final reminders = (await txn.query(
        'reminders',
        where: 'noteId = ?',
        whereArgs: [review.noteId],
        orderBy: 'createdAt ASC',
      )).map(Reminder.fromMap).toList();
      final wanted = review.reminder;
      if (wanted == null) {
        for (final r in reminders) {
          remindersToCancel.add(r.id);
          await txn.delete('reminders', where: 'id = ?', whereArgs: [r.id]);
        }
      } else {
        if (reminders.isEmpty) {
          reminderToSchedule = Reminder(
            id: _uuid.v4(),
            contactId: review.contactId,
            noteId: review.noteId,
            title: wanted.title,
            dateTime: wanted.dateTime,
            createdAt: now,
          );
          await txn.insert('reminders', reminderToSchedule!.toMap());
        } else {
          final first = reminders.first;
          final moved = first.dateTime != wanted.dateTime;
          reminderToSchedule = first.copyWith(
            title: wanted.title,
            dateTime: wanted.dateTime,
            // A rescheduled reminder is open again.
            completed: moved ? false : first.completed,
          );
          remindersToCancel.add(first.id);
          await txn.update('reminders', reminderToSchedule!.toMap(), where: 'id = ?', whereArgs: [first.id]);
          for (final extra in reminders.skip(1)) {
            remindersToCancel.add(extra.id);
            await txn.delete('reminders', where: 'id = ?', whereArgs: [extra.id]);
          }
        }
      }

      await txn.update(
        'contacts',
        {'lastInteraction': now.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [review.contactId],
      );
    });

    // Notifications only after the data is committed.
    for (final id in remindersToCancel) {
      await _cancelReminder(id);
    }
    final toSchedule = reminderToSchedule;
    if (toSchedule != null) await _scheduleReminder(toSchedule);
  }
}
