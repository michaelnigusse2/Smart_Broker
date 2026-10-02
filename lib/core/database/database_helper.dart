import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static const _fileName = 'smart_broker.db';
  static Database? _database;

  /// Tests point this at [inMemoryDatabasePath] (with the ffi factory).
  @visibleForTesting
  static String? pathOverride;

  static Future<String> _path() async =>
      pathOverride ?? join(await getDatabasesPath(), _fileName);

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    return await openDatabase(
      await _path(),
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');

    // Contacts table
    await db.execute('''
      CREATE TABLE contacts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phoneNumber TEXT NOT NULL,
        email TEXT DEFAULT '',
        company TEXT DEFAULT '',
        role TEXT DEFAULT '',
        lastInteraction INTEGER NOT NULL,
        pendingTasksCount INTEGER DEFAULT 0,
        avatarUrl TEXT DEFAULT ''
      )
    ''');

    // Notes table
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        contactId TEXT NOT NULL,
        rawText TEXT NOT NULL,
        aiSummary TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (contactId) REFERENCES contacts(id) ON DELETE CASCADE
      )
    ''');

    // Todos table
    await db.execute('''
      CREATE TABLE todos (
        id TEXT PRIMARY KEY,
        contactId TEXT NOT NULL,
        noteId TEXT,
        title TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL,
        completedAt INTEGER,
        FOREIGN KEY (contactId) REFERENCES contacts(id) ON DELETE CASCADE,
        FOREIGN KEY (noteId) REFERENCES notes(id) ON DELETE SET NULL
      )
    ''');

    // Reminders table
    await db.execute('''
      CREATE TABLE reminders (
        id TEXT PRIMARY KEY,
        contactId TEXT NOT NULL,
        noteId TEXT,
        title TEXT NOT NULL,
        description TEXT DEFAULT '',
        dateTime INTEGER NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (contactId) REFERENCES contacts(id) ON DELETE CASCADE,
        FOREIGN KEY (noteId) REFERENCES notes(id) ON DELETE SET NULL
      )
    ''');

    // Calls table
    await db.execute('''
      CREATE TABLE calls (
        id TEXT PRIMARY KEY,
        contactId TEXT NOT NULL,
        type INTEGER NOT NULL,
        duration INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY (contactId) REFERENCES contacts(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations go here
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
