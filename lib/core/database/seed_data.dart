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
  static Future<void> seedIfNeeded() async {
    final db = await DatabaseHelper().database;
    
    // Check if data already exists
    final contactCount = await db.rawQuery('SELECT COUNT(*) FROM contacts');
    if ((contactCount.first.values.first as int) > 0) return;

    final contactRepo = ContactRepository();
    final noteRepo = NoteRepository();
    final todoRepo = TodoRepository();
    final reminderRepo = ReminderRepository();
    final callRepo = CallRepository();

    // Insert all mock data
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
  }
}
