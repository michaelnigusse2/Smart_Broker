import 'package:uuid/uuid.dart';

import '../../models/contact.dart';
import '../../models/phone_contact.dart';
import '../database/database_helper.dart';
import '../database/sql_like.dart';

class ContactRepository {
  final DatabaseHelper _db = DatabaseHelper();
  final _uuid = const Uuid();

  /// Contacts with their live open-task count, so the number shown is never
  /// stale (it used to be a stored counter that drifted).
  static const _select = '''
    SELECT c.*,
      (SELECT COUNT(*) FROM todos t WHERE t.contactId = c.id AND t.isCompleted = 0) AS openTaskCount
    FROM contacts c''';

  Future<List<Contact>> getAll() async {
    final db = await _db.database;
    final maps = await db.rawQuery('$_select ORDER BY c.lastInteraction DESC');
    return maps.map(Contact.fromMap).toList();
  }

  Future<Contact?> getById(String id) async {
    final db = await _db.database;
    final maps = await db.rawQuery('$_select WHERE c.id = ?', [id]);
    return maps.isEmpty ? null : Contact.fromMap(maps.first);
  }

  Future<List<Contact>> search(String query) async {
    final db = await _db.database;
    final maps = await db.rawQuery(
      "$_select WHERE c.name LIKE ? ESCAPE '\\' OR c.phoneNumber LIKE ? ESCAPE '\\' OR c.otherPhones LIKE ? ESCAPE '\\' "
      'ORDER BY c.lastInteraction DESC',
      [likeContains(query), likeContains(query), likeContains(query)],
    );
    return maps.map(Contact.fromMap).toList();
  }

  /// The contact with the same number (last 9 digits, any formatting), if
  /// any: their main number first, then their other numbers.
  Future<Contact?> findByPhone(String phoneNumber) async {
    final key = PhoneContact.matchKey(phoneNumber);
    if (key.isEmpty) return null;
    final db = await _db.database;
    final maps = await db.rawQuery(
      '$_select WHERE c.phoneKey = ? OR c.otherPhoneKeys LIKE ? ORDER BY c.phoneKey = ? DESC LIMIT 1',
      [key, '%,$key,%', key],
    );
    return maps.isEmpty ? null : Contact.fromMap(maps.first);
  }

  /// Adds [phoneNumber] to [contactId]'s other numbers (a second phone).
  Future<void> addOtherPhone(String contactId, String phoneNumber) async {
    final contact = await getById(contactId);
    if (contact == null) return;
    if (contact.allPhones.any((p) => PhoneContact.numbersMatch(p, phoneNumber))) return;
    await update(contact.copyWith(otherPhones: [...contact.otherPhones, phoneNumber.trim()]));
  }

  /// "Not needed": missed calls before [when] no longer ask for a call back.
  Future<void> clearCallBack(String contactId, DateTime when) async {
    final db = await _db.database;
    await db.update(
      'contacts',
      {'callBackClearedAt': when.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [contactId],
    );
  }

  /// Saves a new contact and returns its id. If a contact with the same
  /// number already exists, nothing is inserted and that contact's id is
  /// returned instead — a number belongs to one contact.
  Future<String> insert(Contact contact) async {
    final existing = await findByPhone(contact.phoneNumber);
    if (existing != null) return existing.id;
    final db = await _db.database;
    final id = contact.id.isEmpty ? _uuid.v4() : contact.id;
    await db.insert('contacts', contact.copyWith(id: id).toMap());
    return id;
  }

  /// Writes the editable fields. Throws if the new number belongs to
  /// another contact.
  Future<void> update(Contact contact) async {
    final db = await _db.database;
    await db.update('contacts', contact.toMap()..remove('id'), where: 'id = ?', whereArgs: [contact.id]);
  }

  /// Moves `lastInteraction` forward to [when] (never backwards).
  Future<void> touch(String id, DateTime when) async {
    final db = await _db.database;
    await db.rawUpdate('UPDATE contacts SET lastInteraction = MAX(lastInteraction, ?) WHERE id = ?', [
      when.millisecondsSinceEpoch,
      id,
    ]);
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  }
}
