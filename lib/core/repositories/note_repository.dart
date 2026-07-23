import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../../models/note.dart';

class NoteRepository {
  final DatabaseHelper _db = DatabaseHelper();
  final _uuid = const Uuid();

  Future<List<Note>> getByContactId(String contactId) async {
    final db = await _db.database;
    final maps = await db.query(
      'notes',
      where: 'contactId = ?',
      whereArgs: [contactId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => Note.fromMap(m)).toList();
  }

  Future<String> insert(Note note) async {
    final db = await _db.database;
    final id = note.id.isEmpty ? _uuid.v4() : note.id;
    await db.insert('notes', note.copyWith(id: id).toMap());
    return id;
  }

  Future<void> update(Note note) async {
    final db = await _db.database;
    await db.update('notes', note.toMap(), where: 'id = ?', whereArgs: [note.id]);
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }
}
