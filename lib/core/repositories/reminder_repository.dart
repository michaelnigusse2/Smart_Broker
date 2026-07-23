import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../../models/reminder.dart';

class ReminderRepository {
  final DatabaseHelper _db = DatabaseHelper();
  final _uuid = const Uuid();

  Future<List<Reminder>> getByContactId(String contactId) async {
    final db = await _db.database;
    final maps = await db.query(
      'reminders',
      where: 'contactId = ?',
      whereArgs: [contactId],
      orderBy: 'dateTime ASC',
    );
    return maps.map((m) => Reminder.fromMap(m)).toList();
  }

  Future<List<Reminder>> getUpcoming() async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final maps = await db.query(
      'reminders',
      where: 'completed = 0',
      orderBy: 'dateTime ASC',
    );
    return maps.map((m) => Reminder.fromMap(m)).toList();
  }

  Future<String> insert(Reminder reminder) async {
    final db = await _db.database;
    final id = reminder.id.isEmpty ? _uuid.v4() : reminder.id;
    await db.insert('reminders', reminder.copyWith(id: id).toMap());
    return id;
  }

  Future<void> update(Reminder reminder) async {
    final db = await _db.database;
    await db.update('reminders', reminder.toMap(), where: 'id = ?', whereArgs: [reminder.id]);
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }
}
