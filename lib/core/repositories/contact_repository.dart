import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../../models/contact.dart';

class ContactRepository {
  final DatabaseHelper _db = DatabaseHelper();
  final _uuid = const Uuid();

  Future<List<Contact>> getAll() async {
    final db = await _db.database;
    final maps = await db.query('contacts', orderBy: 'lastInteraction DESC');
    return maps.map((m) => Contact.fromMap(m)).toList();
  }

  Future<Contact?> getById(String id) async {
    final db = await _db.database;
    final maps = await db.query('contacts', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Contact.fromMap(maps.first);
  }

  Future<List<Contact>> search(String query) async {
    final db = await _db.database;
    final maps = await db.query(
      'contacts',
      where: 'name LIKE ? OR phoneNumber LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'lastInteraction DESC',
    );
    return maps.map((m) => Contact.fromMap(m)).toList();
  }

  Future<String> insert(Contact contact) async {
    final db = await _db.database;
    final id = contact.id.isEmpty ? _uuid.v4() : contact.id;
    await db.insert('contacts', contact.copyWith(id: id).toMap());
    return id;
  }

  Future<void> update(Contact contact) async {
    final db = await _db.database;
    await db.update(
      'contacts',
      contact.toMap(),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  }
}
