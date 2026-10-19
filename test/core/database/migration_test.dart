import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:smart_broker/core/database/database_helper.dart';
import 'package:smart_broker/core/database/schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/v1_schema.dart';
import '../../helpers/test_db.dart';

/// Tables (columns, foreign keys) and indexes, in a comparable form.
Future<Map<String, Object?>> describeSchema(Database db) async {
  final out = <String, Object?>{};
  final objects = await db.rawQuery(
    "SELECT type, name, sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY name",
  );
  for (final o in objects) {
    final name = o['name'] as String;
    if (o['type'] == 'table') {
      final columns = await db.rawQuery('PRAGMA table_info($name)');
      out['table $name'] = [
        for (final c in columns)
          '${c['name']} ${c['type']} notnull=${c['notnull']} default=${c['dflt_value']} pk=${c['pk']}',
      ];
      final keys = await db.rawQuery('PRAGMA foreign_key_list($name)');
      out['foreign keys $name'] = [
        for (final k in keys) '${k['from']} -> ${k['table']}.${k['to']} on delete ${k['on_delete']}',
      ]..sort();
    } else if (o['type'] == 'index') {
      out['index $name'] = o['sql'];
    }
  }
  return out;
}

/// Creates a version-1 database file exactly as builds up to 1.0.0+2 did.
Future<void> createV1Database(String path, Future<void> Function(Database db) fill) async {
  final db = await databaseFactory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        for (final statement in v1Schema) {
          await db.execute(statement);
        }
      },
    ),
  );
  await fill(db);
  await db.close();
}

void main() {
  late Directory tempDir;

  setUp(() async {
    await useFreshTestDatabase();
    tempDir = await Directory.systemTemp.createTemp('smart_broker_migration');
  });

  tearDown(() async {
    await closeTestDatabase();
    await tempDir.delete(recursive: true);
  });

  test('a fresh install is created at the current version with all indexes', () async {
    final db = await DatabaseHelper().database;

    expect(await db.getVersion(), schemaVersion);
    final schema = await describeSchema(db);
    for (final name in [
      'idx_contacts_phoneKey',
      'idx_notes_contact',
      'idx_todos_contact',
      'idx_todos_note',
      'idx_todos_due',
      'idx_reminders_contact',
      'idx_reminders_note',
      'idx_reminders_open',
      'idx_calls_contact_time',
      'idx_unassigned_status',
    ]) {
      expect(schema.containsKey('index $name'), isTrue, reason: name);
    }
  });

  test('upgrading a v1 database gives exactly the fresh-install schema', () async {
    final fresh = await describeSchema(await DatabaseHelper().database);
    await closeTestDatabase();

    final path = p.join(tempDir.path, 'v1.db');
    await createV1Database(path, (_) async {});
    DatabaseHelper.pathOverride = path;
    final db = await DatabaseHelper().database;

    expect(await db.getVersion(), schemaVersion);
    expect(await describeSchema(db), fresh);
  });

  group('v1 → v2 data', () {
    late Database db;

    setUp(() async {
      final path = p.join(tempDir.path, 'v1.db');
      await createV1Database(path, (db) async {
        Future<void> contact(
          String id,
          String name,
          String phone, {
          String email = '',
          String company = '',
          int at = 1000,
        }) => db.insert('contacts', {
          'id': id,
          'name': name,
          'phoneNumber': phone,
          'email': email,
          'company': company,
          'lastInteraction': at,
        });
        // An unknown caller auto-created as a contact, later saved again with a real name.
        await contact('auto', '0911000001', '0911000001', email: 'hanna@example.com', at: 5000);
        await contact('real', 'Hanna Bekele', '+251 911 000 001', company: 'Bole Homes');
        await contact('other', 'Dawit Alemu', '+251911000002');
        await contact('no-number-1', 'No Number', '');
        await contact('no-number-2', 'Also No Number', 'n/a');

        await db.insert('notes', {'id': 'n1', 'contactId': 'auto', 'rawText': 'a', 'aiSummary': '', 'createdAt': 1});
        await db.insert('notes', {'id': 'n2', 'contactId': 'real', 'rawText': 'b', 'aiSummary': '', 'createdAt': 2});
        await db.insert('todos', {
          'id': 't1',
          'contactId': 'auto',
          'title': 'Send plan',
          'isCompleted': 0,
          'createdAt': 1,
        });
        await db.insert('todos', {
          'id': 't2',
          'contactId': 'real',
          'title': 'Call bank',
          'isCompleted': 1,
          'createdAt': 2,
        });
        await db.insert('reminders', {
          'id': 'r1',
          'contactId': 'auto',
          'title': 'Viewing',
          'dateTime': 9,
          'createdAt': 1,
        });

        Future<void> call(String id, String contactId, int at) => db.insert('calls', {
          'id': id,
          'contactId': contactId,
          'type': 0,
          'duration': 30,
          'timestamp': at,
        });
        await call('c1', 'auto', 100); // the same call, logged under both duplicates
        await call('c2', 'real', 100);
        await call('c3', 'other', 200); // logged twice for the same contact
        await call('c4', 'other', 200);
        await call('c5', 'real', 300);
      });
      DatabaseHelper.pathOverride = path;
      db = await DatabaseHelper().database;
    });

    Future<List<String>> ids(String table, {String? contactId}) async => [
      for (final row in await db.query(
        table,
        columns: ['id'],
        where: contactId == null ? null : 'contactId = ?',
        whereArgs: contactId == null ? null : [contactId],
        orderBy: 'id',
      ))
        row['id'] as String,
    ];

    test('duplicate numbers are merged into the contact with a real name', () async {
      expect(await ids('contacts'), ['no-number-1', 'no-number-2', 'other', 'real']);

      final kept = (await db.query('contacts', where: 'id = ?', whereArgs: ['real'])).single;
      expect(kept['name'], 'Hanna Bekele');
      expect(kept['email'], 'hanna@example.com', reason: 'blank details are filled from the duplicate');
      expect(kept['company'], 'Bole Homes');
      expect(kept['lastInteraction'], 5000, reason: 'latest interaction wins');
      expect(kept['phoneKey'], '911000001');
    });

    test('notes, tasks, reminders and calls move to the kept contact', () async {
      expect(await ids('notes', contactId: 'real'), ['n1', 'n2']);
      expect(await ids('todos', contactId: 'real'), ['t1', 't2']);
      expect(await ids('reminders', contactId: 'real'), ['r1']);
    });

    test('duplicate calls are removed', () async {
      final calls = await db.query('calls', orderBy: 'timestamp');
      expect([for (final c in calls) '${c['contactId']}@${c['timestamp']}'], ['real@100', 'other@200', 'real@300']);
    });

    test('phone keys are filled; contacts without digits keep an empty key', () async {
      final keys = {
        for (final row in await db.query('contacts')) row['id']: row['phoneKey'],
      };
      expect(keys, {'real': '911000001', 'other': '911000002', 'no-number-1': '', 'no-number-2': ''});
    });

    test('new columns and tables exist and constraints hold', () async {
      final todo = (await db.query('todos', where: 'id = ?', whereArgs: ['t1'])).single;
      expect(todo.containsKey('dueAt'), isTrue);
      expect(todo['dueAt'], isNull);
      expect(await db.query('unassigned_calls'), isEmpty);

      await expectLater(
        db.insert('contacts', {
          'id': 'dup',
          'name': 'Dup',
          'phoneNumber': '0911000002',
          'phoneKey': '911000002',
          'lastInteraction': 1,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
