import 'package:uuid/uuid.dart';

import '../../models/call_entry.dart';
import '../../models/new_number.dart';
import '../../models/phone_contact.dart';
import '../database/database_helper.dart';
import 'call_repository.dart';
import 'contact_repository.dart';

/// Calls from numbers that aren't your people yet (`unassigned_calls`):
/// People → New numbers, and the numbers you ignored ("Not a client").
class NewNumberRepository {
  final DatabaseHelper _db = DatabaseHelper();
  final _uuid = const Uuid();

  static const _open = 'new';
  static const _ignored = 'ignored';

  /// Numbers you haven't touched in this long leave the list.
  static const keepFor = Duration(days: 30);

  /// Logs a call from a new number. Returns false when the number is
  /// ignored (the call is kept, quietly, so it stays ignored).
  Future<bool> logCall({
    required String phoneNumber,
    required CallType type,
    required Duration duration,
    required DateTime timestamp,
  }) async {
    final key = PhoneContact.matchKey(phoneNumber);
    if (key.isEmpty) return false;
    final db = await _db.database;
    final ignored = await isIgnored(key);
    final existing = await db.query(
      'unassigned_calls',
      columns: ['id'],
      where: 'phoneKey = ? AND timestamp = ?',
      whereArgs: [key, timestamp.millisecondsSinceEpoch],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert('unassigned_calls', {
        'id': _uuid.v4(),
        'phoneNumber': phoneNumber.trim(),
        'phoneKey': key,
        'type': type.index,
        'duration': duration.inSeconds,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'status': ignored ? _ignored : _open,
        'note': '',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
    return !ignored;
  }

  Future<bool> isIgnored(String phoneKey) async {
    final db = await _db.database;
    final rows = await db.query(
      'unassigned_calls',
      columns: ['id'],
      where: 'phoneKey = ? AND status = ?',
      whereArgs: [phoneKey, _ignored],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// New numbers waiting to be saved, newest first.
  Future<List<NewNumber>> open({DateTime? now}) async {
    final db = await _db.database;
    final since = (now ?? DateTime.now()).subtract(keepFor).millisecondsSinceEpoch;
    final keys = await db.rawQuery(
      'SELECT phoneKey FROM unassigned_calls WHERE status = ? GROUP BY phoneKey HAVING MAX(timestamp) >= ?',
      [_open, since],
    );
    if (keys.isEmpty) return [];
    final rows = await db.query(
      'unassigned_calls',
      where: 'status = ? AND phoneKey IN (${List.filled(keys.length, '?').join(',')})',
      whereArgs: [_open, for (final k in keys) k['phoneKey']],
      orderBy: 'timestamp DESC',
    );
    return groupNewNumbers(rows.map(NewNumberCall.fromMap).toList());
  }

  /// One new number by key, or null when it's no longer waiting.
  Future<NewNumber?> find(String phoneKey) async {
    final db = await _db.database;
    final rows = await db.query(
      'unassigned_calls',
      where: 'status = ? AND phoneKey = ?',
      whereArgs: [_open, phoneKey],
      orderBy: 'timestamp DESC',
    );
    final grouped = groupNewNumbers(rows.map(NewNumberCall.fromMap).toList());
    return grouped.isEmpty ? null : grouped.first;
  }

  /// Keeps what you typed about the number until you save them.
  Future<void> saveNote(String phoneKey, String text) async {
    final db = await _db.database;
    final latest = await db.query(
      'unassigned_calls',
      columns: ['id', 'note'],
      where: 'phoneKey = ? AND status = ?',
      whereArgs: [phoneKey, _open],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (latest.isEmpty) return;
    final existing = (latest.first['note'] as String? ?? '').trim();
    final merged = existing.isEmpty ? text.trim() : '$existing\n${text.trim()}';
    await db.update('unassigned_calls', {'note': merged}, where: 'id = ?', whereArgs: [latest.first['id']]);
  }

  /// "Not a client": no cards, reminders or list for this number.
  Future<void> ignore(String phoneKey) async {
    final db = await _db.database;
    await db.update('unassigned_calls', {'status': _ignored}, where: 'phoneKey = ?', whereArgs: [phoneKey]);
  }

  /// Settings → Ignored numbers → Stop ignoring.
  Future<void> unignore(String phoneKey) async {
    final db = await _db.database;
    await db.update('unassigned_calls', {'status': _open}, where: 'phoneKey = ?', whereArgs: [phoneKey]);
  }

  /// Ignored numbers, newest first.
  Future<List<NewNumber>> ignored() async {
    final db = await _db.database;
    final rows = await db.query(
      'unassigned_calls',
      where: 'status = ?',
      whereArgs: [_ignored],
      orderBy: 'timestamp DESC',
    );
    return groupNewNumbers(rows.map(NewNumberCall.fromMap).toList());
  }

  Future<int> ignoredCount() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(DISTINCT phoneKey) AS n FROM unassigned_calls WHERE status = ?',
      [_ignored],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  /// The number belongs to [contactId] now (a new person, or a second phone
  /// of someone you know): its calls move to them and it leaves the list.
  /// Returns what you'd typed about it, for their notes.
  Future<String> assignTo(String phoneKey, String contactId) async {
    final db = await _db.database;
    final rows = await db.query('unassigned_calls', where: 'phoneKey = ?', whereArgs: [phoneKey]);
    final calls = rows.map(NewNumberCall.fromMap).toList();
    final callRepo = CallRepository();
    DateTime? latest;
    for (final c in calls) {
      await callRepo.insert(
        CallEntry(id: '', contactId: contactId, type: c.type, duration: c.duration, timestamp: c.timestamp),
      );
      if (latest == null || c.timestamp.isAfter(latest)) latest = c.timestamp;
    }
    if (latest != null) await ContactRepository().touch(contactId, latest);
    await db.delete('unassigned_calls', where: 'phoneKey = ?', whereArgs: [phoneKey]);
    return [for (final c in calls) c.note.trim()].where((n) => n.isNotEmpty).join('\n');
  }
}
