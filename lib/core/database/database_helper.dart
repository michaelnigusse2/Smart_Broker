import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'migrations.dart';
import 'schema.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static const _fileName = 'smart_broker.db';
  static Database? _database;

  /// Tests point this at [inMemoryDatabasePath] (with the ffi factory).
  @visibleForTesting
  static String? pathOverride;

  static Future<String> _path() async => pathOverride ?? join(await getDatabasesPath(), _fileName);

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    return await openDatabase(
      await _path(),
      version: schemaVersion,
      // Before onCreate/onUpgrade, so foreign keys are enforced everywhere.
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) => runMigrations(db, oldVersion, newVersion),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    for (final statement in createSchema) {
      await db.execute(statement);
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Closes and deletes the local database file. Used by "Reset local data"
  /// and by tests. The next access to [database] creates a fresh one.
  static Future<void> deleteLocalDatabase() async {
    await _database?.close();
    _database = null;
    final path = await _path();
    if (path != inMemoryDatabasePath) await deleteDatabase(path);
  }
}
