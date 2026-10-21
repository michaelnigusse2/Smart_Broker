import 'package:sqflite/sqflite.dart';

import '../../models/phone_contact.dart';
import '../services/app_log.dart';
import 'schema.dart';

/// One forward-only step from `version - 1` to [version].
///
/// Steps run inside the upgrade transaction, so a failing step leaves the
/// database at its old version. Never edit a released migration: add a new one
/// and bump `schemaVersion`.
abstract class Migration {
  const Migration();

  int get version;
  String get description;
  Future<void> up(DatabaseExecutor db);
}

const List<Migration> migrations = [MigrationV2(), MigrationV3()];

/// Runs every migration after [from] up to and including [to], in order.
Future<void> runMigrations(DatabaseExecutor db, int from, int to) async {
  final steps = migrations.where((m) => m.version > from && m.version <= to).toList()
    ..sort((a, b) => a.version.compareTo(b.version));
  for (final step in steps) {
    AppLog.i('Database', 'migrating to v${step.version}: ${step.description}');
    await step.up(db);
  }
}

/// v3: promises can be owed either way. Every existing one is yours to keep
/// ("me"), so nothing changes for data already on the phone.
class MigrationV3 extends Migration {
  const MigrationV3();

  @override
  int get version => 3;

  @override
  String get description => 'who owes each promise';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute("ALTER TABLE todos ADD COLUMN owedBy TEXT NOT NULL DEFAULT 'me'");
  }
}

/// v2: phone keys with duplicate contacts merged, task due dates, the
/// unassigned-calls table, duplicate calls removed, and indexes.
class MigrationV2 extends Migration {
  const MigrationV2();

  @override
  int get version => 2;

  @override
  String get description => 'phone keys, merge duplicate contacts, due dates, unassigned calls, indexes';

  static final _numberOnly = RegExp(r'^[\d\s+()\-.]*$');

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute("ALTER TABLE contacts ADD COLUMN phoneKey TEXT NOT NULL DEFAULT ''");
    await _mergeDuplicateContacts(db);

    await db.execute('ALTER TABLE todos ADD COLUMN dueAt INTEGER');

    // The same call could be logged twice (call log re-read), and merging
    // contacts above can produce more of the same.
    await db.execute(
      'DELETE FROM calls WHERE rowid NOT IN (SELECT MIN(rowid) FROM calls GROUP BY contactId, timestamp)',
    );

    await db.execute(createUnassignedCallsV2);
    for (final statement in indexesV2) {
      await db.execute(statement);
    }
  }

  /// Fills `phoneKey` and merges contacts that share it into one: the one
  /// with a real name (not just the number) wins, then the oldest. Notes,
  /// tasks, reminders and calls move to the kept contact; empty details are
  /// filled from the others and the latest interaction is kept.
  Future<void> _mergeDuplicateContacts(DatabaseExecutor db) async {
    final rows = await db.rawQuery(
      'SELECT rowid AS rowNumber, id, name, phoneNumber, email, company, role, lastInteraction, avatarUrl FROM contacts',
    );
    final groups = <String, List<Map<String, Object?>>>{};
    for (final row in rows) {
      final key = PhoneContact.matchKey(row['phoneNumber'] as String? ?? '');
      await db.update('contacts', {'phoneKey': key}, where: 'id = ?', whereArgs: [row['id']]);
      if (key.isNotEmpty) groups.putIfAbsent(key, () => []).add(row);
    }

    for (final group in groups.values.where((g) => g.length > 1)) {
      group.sort((a, b) {
        final aNumber = _numberOnly.hasMatch((a['name'] as String? ?? '').trim()) ? 1 : 0;
        final bNumber = _numberOnly.hasMatch((b['name'] as String? ?? '').trim()) ? 1 : 0;
        if (aNumber != bNumber) return aNumber - bNumber;
        return (a['rowNumber'] as int).compareTo(b['rowNumber'] as int);
      });
      final keep = group.first;
      final others = group.skip(1).toList();

      String firstNonEmpty(String column) {
        for (final row in group) {
          final value = (row[column] as String? ?? '').trim();
          if (value.isNotEmpty) return value;
        }
        return '';
      }

      final latest = group.map((r) => r['lastInteraction'] as int? ?? 0).reduce((a, b) => a > b ? a : b);
      for (final other in others) {
        for (final table in const ['notes', 'todos', 'reminders', 'calls']) {
          await db.update(table, {'contactId': keep['id']}, where: 'contactId = ?', whereArgs: [other['id']]);
        }
        await db.delete('contacts', where: 'id = ?', whereArgs: [other['id']]);
      }
      await db.update(
        'contacts',
        {
          'email': firstNonEmpty('email'),
          'company': firstNonEmpty('company'),
          'role': firstNonEmpty('role'),
          'avatarUrl': firstNonEmpty('avatarUrl'),
          'lastInteraction': latest,
        },
        where: 'id = ?',
        whereArgs: [keep['id']],
      );
      AppLog.i('Database', 'merged ${others.length} duplicate contact(s) into ${keep['id']}');
    }
  }
}
