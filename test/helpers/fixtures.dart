import 'package:smart_broker/core/repositories/call_repository.dart';
import 'package:smart_broker/core/repositories/contact_repository.dart';
import 'package:smart_broker/core/repositories/reminder_repository.dart';
import 'package:smart_broker/core/repositories/todo_repository.dart';
import 'package:smart_broker/models/call_entry.dart';
import 'package:smart_broker/models/contact.dart';
import 'package:smart_broker/models/reminder.dart';
import 'package:smart_broker/models/todo_item.dart';

// Fictional people and numbers only — never real client data in tests.

Future<Contact> insertContact({
  String id = 'contact-1',
  String name = 'Test Client One',
  String phone = '+251 911 000 001',
  String company = '',
  DateTime? lastInteraction,
}) async {
  final contact = Contact(
    id: id,
    name: name,
    phoneNumber: phone,
    company: company,
    lastInteraction: lastInteraction ?? DateTime(2026, 1, 1),
  );
  await ContactRepository().insert(contact);
  return contact;
}

Future<TodoItem> insertTodo({
  required String contactId,
  String? id,
  String? noteId,
  String title = 'Send the floor plan',
  bool completed = false,
  DateTime? createdAt,
}) async {
  final todo = TodoItem(
    id: id ?? '',
    contactId: contactId,
    noteId: noteId,
    title: title,
    isCompleted: completed,
    createdAt: createdAt ?? DateTime.now(),
    completedAt: completed ? DateTime.now() : null,
  );
  final newId = await TodoRepository().insert(todo);
  return todo.copyWith(id: newId);
}

Future<Reminder> insertReminder({
  required String contactId,
  required DateTime at,
  String? id,
  String? noteId,
  String title = 'Follow up',
  bool completed = false,
  String kind = '',
}) async {
  final reminder = Reminder(
    id: id ?? '',
    contactId: contactId,
    noteId: noteId,
    title: title,
    dateTime: at,
    completed: completed,
    createdAt: DateTime.now(),
    kind: kind,
  );
  final newId = await ReminderRepository().insert(reminder);
  return reminder.copyWith(id: newId);
}

Future<CallEntry> insertCall({
  required String contactId,
  required CallType type,
  required DateTime at,
  Duration duration = Duration.zero,
}) async {
  final call = CallEntry(id: '', contactId: contactId, type: type, duration: duration, timestamp: at);
  final id = await CallRepository().insert(call);
  return CallEntry(id: id, contactId: contactId, type: type, duration: duration, timestamp: at);
}
