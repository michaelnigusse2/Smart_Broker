import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import '../../mock/mock_contacts.dart';
import '../../mock/mock_notes.dart';
import '../../mock/mock_todos.dart';
import '../../mock/mock_reminders.dart';
import '../../mock/mock_calls.dart';
import '../repositories/contact_repository.dart';
import '../repositories/note_repository.dart';
import '../repositories/todo_repository.dart';
import '../repositories/reminder_repository.dart';
import '../repositories/call_repository.dart';

class SeedData {
  /// Opens the database (so startup surfaces database errors) and, in debug
  /// builds only, fills an empty database with demo data. Release installs
  /// start empty.
  static Future<void> seedIfNeeded({bool seedDemoData = kDebugMode}) async {
    final db = await DatabaseHelper().database;
    if (!seedDemoData) return;

    final contactCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM contacts')) ?? 0;
    if (contactCount > 0) return;
    await loadDemoData();
  }

  /// Inserts the demo contacts, notes, tasks, reminders and calls.
  /// Returns false (and changes nothing) when the demo data is already there.
  static Future<bool> loadDemoData() async {
    final db = await DatabaseHelper().database;
    final existing = await db.query('contacts', columns: ['id'], where: 'id = ?', whereArgs: [mockContacts.first.id]);
    if (existing.isNotEmpty) return false;

    final contactRepo = ContactRepository();
    final noteRepo = NoteRepository();
    final todoRepo = TodoRepository();
    final reminderRepo = ReminderRepository();
    final callRepo = CallRepository();

    for (final contact in mockContacts) {
      await contactRepo.insert(contact);
    }
    for (final note in mockNotes) {
      await noteRepo.insert(note);
    }
    for (final todo in mockTodos) {
      await todoRepo.insert(todo);
    }
    for (final reminder in mockReminders) {
      await reminderRepo.insert(reminder);
    }
    for (final call in mockCalls) {
      await callRepo.insert(call);
    }
    return true;
  }
}
