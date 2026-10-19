// Verbatim copy of the schema version 1 created by DatabaseHelper._onCreate
// before migrations existed (app builds up to 1.0.0+2). Used to test that
// real v1 databases upgrade correctly. Never edit this file.
const v1Schema = <String>[
  '''
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

  ''',
  '''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        contactId TEXT NOT NULL,
        rawText TEXT NOT NULL,
        aiSummary TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (contactId) REFERENCES contacts(id) ON DELETE CASCADE
      )

  ''',
  '''
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

  ''',
  '''
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

  ''',
  '''
      CREATE TABLE calls (
        id TEXT PRIMARY KEY,
        contactId TEXT NOT NULL,
        type INTEGER NOT NULL,
        duration INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY (contactId) REFERENCES contacts(id) ON DELETE CASCADE
      )

  ''',
];
