import 'package:uuid/uuid.dart';

import '../../models/call_entry.dart';
import '../database/database_helper.dart';

class CallRepository {
  final DatabaseHelper _db = DatabaseHelper();
  final _uuid = const Uuid();

  Future<List<CallEntry>> getByContactId(String contactId) async {
    final db = await _db.database;
    final maps = await db.query('calls', where: 'contactId = ?', whereArgs: [contactId], orderBy: 'timestamp DESC');
    return maps.map(CallEntry.fromMap).toList();
  }

  /// Whether this call (same contact and start time) is already logged.
  Future<bool> exists(String contactId, DateTime timestamp) async => (await _findId(contactId, timestamp)) != null;

  /// Logs a call and returns its id. A call that is already logged (same
  /// contact and start time) is not stored twice; its existing id is returned.
  Future<String> insert(CallEntry call) async {
    final existing = await _findId(call.contactId, call.timestamp);
    if (existing != null) return existing;
    final db = await _db.database;
    final id = call.id.isEmpty ? _uuid.v4() : call.id;
    await db.insert('calls', call.copyWith(id: id).toMap());
    return id;
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('calls', where: 'id = ?', whereArgs: [id]);
  }

  Future<String?> _findId(String contactId, DateTime timestamp) async {
    final db = await _db.database;
    final rows = await db.query(
      'calls',
      columns: ['id'],
      where: 'contactId = ? AND timestamp = ?',
      whereArgs: [contactId, timestamp.millisecondsSinceEpoch],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'] as String;
  }
}
