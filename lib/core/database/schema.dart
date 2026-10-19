/// The current database schema.
///
/// A fresh install runs [createSchema] directly. Existing installs reach the
/// same schema by running the steps in `migrations.dart`; a test checks that
/// both paths produce identical tables and indexes. Columns added by a
/// migration go at the end of their table here too, matching `ALTER TABLE`.
library;

/// Bump together with a new `Migration` in `migrations.dart`.
const int schemaVersion = 2;

const List<String> createTables = [
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
    avatarUrl TEXT DEFAULT '',
    phoneKey TEXT NOT NULL DEFAULT ''
  )''',
  '''
  CREATE TABLE notes (
    id TEXT PRIMARY KEY,
    contactId TEXT NOT NULL,
    rawText TEXT NOT NULL,
    aiSummary TEXT NOT NULL,
    createdAt INTEGER NOT NULL,
    FOREIGN KEY (contactId) REFERENCES contacts(id) ON DELETE CASCADE
  )''',
  '''
  CREATE TABLE todos (
    id TEXT PRIMARY KEY,
    contactId TEXT NOT NULL,
    noteId TEXT,
    title TEXT NOT NULL,
    isCompleted INTEGER NOT NULL DEFAULT 0,
    createdAt INTEGER NOT NULL,
    completedAt INTEGER,
    dueAt INTEGER,
    FOREIGN KEY (contactId) REFERENCES contacts(id) ON DELETE CASCADE,
    FOREIGN KEY (noteId) REFERENCES notes(id) ON DELETE SET NULL
  )''',
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
  )''',
  '''
  CREATE TABLE calls (
    id TEXT PRIMARY KEY,
    contactId TEXT NOT NULL,
    type INTEGER NOT NULL,
    duration INTEGER NOT NULL,
    timestamp INTEGER NOT NULL,
    FOREIGN KEY (contactId) REFERENCES contacts(id) ON DELETE CASCADE
  )''',
  createUnassignedCallsV2,
];

/// Calls from numbers that aren't contacts yet (used by the unassigned-calls inbox).
const String createUnassignedCallsV2 = '''
  CREATE TABLE unassigned_calls (
    id TEXT PRIMARY KEY,
    phoneNumber TEXT NOT NULL,
    phoneKey TEXT NOT NULL,
    type INTEGER NOT NULL,
    duration INTEGER NOT NULL,
    timestamp INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'new',
    note TEXT NOT NULL DEFAULT '',
    createdAt INTEGER NOT NULL
  )''';

/// Indexes added in version 2. `contacts.phoneKey` is unique so the same
/// number can't be saved twice (empty keys — no digits — are exempt), and a
/// call is stored once per contact and start time.
const List<String> indexesV2 = [
  "CREATE UNIQUE INDEX idx_contacts_phoneKey ON contacts(phoneKey) WHERE phoneKey <> ''",
  'CREATE INDEX idx_notes_contact ON notes(contactId, createdAt)',
  'CREATE INDEX idx_todos_contact ON todos(contactId, isCompleted)',
  'CREATE INDEX idx_todos_note ON todos(noteId)',
  'CREATE INDEX idx_todos_due ON todos(dueAt)',
  'CREATE INDEX idx_reminders_contact ON reminders(contactId, dateTime)',
  'CREATE INDEX idx_reminders_note ON reminders(noteId)',
  'CREATE INDEX idx_reminders_open ON reminders(completed, dateTime)',
  'CREATE UNIQUE INDEX idx_calls_contact_time ON calls(contactId, timestamp)',
  'CREATE INDEX idx_unassigned_status ON unassigned_calls(status, timestamp)',
];

const List<String> createSchema = [...createTables, ...indexesV2];
