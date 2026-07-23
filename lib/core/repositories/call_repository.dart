import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../../models/call_entry.dart';

class CallRepository {
  final DatabaseHelper _db = DatabaseHelper();
  final _uuid = const Uuid();

  Future<List<CallEntry>> getByContactId(String contactId) async {
    final db = await _db.database;
    final maps = await db.query(
      'calls',
      where: 'contactId = ?',
      whereArgs: [contactId],
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => CallEntry.fromMap(m)).toList();
  }

  Future<String> insert(CallEntry call) async {
    final db = await _db.database;
    final id = call.id.isEmpty ? _uuid.v4() : call.id;
    await db.insert('calls', call.copyWith(id: id).toMap());
    return id;
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('calls', where: 'id = ?', whereArgs: [id]);
  }
}
