import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../../models/note.dart';
import '../../models/note_with_contact.dart';

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

  Future<Note?> getById(String id) async {
    final db = await _db.database;
    final maps = await db.query('notes', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Note.fromMap(maps.first);
  }

  Future<List<NoteWithContact>> getAll() async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT notes.*, contacts.name AS contactName, contacts.avatarUrl AS contactAvatarUrl
      FROM notes
      INNER JOIN contacts ON notes.contactId = contacts.id
      ORDER BY notes.createdAt DESC
    ''');
    return maps.map((m) => NoteWithContact(
      note: Note.fromMap(m),
      contactName: m['contactName'] as String,
      contactAvatarUrl: m['contactAvatarUrl'] as String? ?? '',
    )).toList();
  }

  Future<List<NoteWithContact>> search(String query) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT notes.*, contacts.name AS contactName, contacts.avatarUrl AS contactAvatarUrl
      FROM notes
      INNER JOIN contacts ON notes.contactId = contacts.id
      WHERE notes.rawText LIKE ? OR notes.aiSummary LIKE ?
      ORDER BY notes.createdAt DESC
    ''', ['%$query%', '%$query%']);
    return maps.map((m) => NoteWithContact(
      note: Note.fromMap(m),
      contactName: m['contactName'] as String,
      contactAvatarUrl: m['contactAvatarUrl'] as String? ?? '',
    )).toList();
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
