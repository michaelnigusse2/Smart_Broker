import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../../models/todo_item.dart';

import '../../models/todo_with_contact.dart';

/// Which tasks [TodoRepository.getAll] returns.
enum TaskFilter {
  all,
  pending,
  completed,

  /// Open and created more than 7 days ago (until tasks get due dates).
  overdue,
}

/// Order of [TodoRepository.getAll].
enum TaskSort { createdAt, contact }

class TodoRepository {
  final DatabaseHelper _db = DatabaseHelper();
  final _uuid = const Uuid();

  Future<List<TodoWithContact>> getAll({
    TaskFilter filter = TaskFilter.all,
    TaskSort sortBy = TaskSort.createdAt,
  }) async {
    final db = await _db.database;

    final whereArgs = <Object?>[];
    final where = switch (filter) {
      TaskFilter.all => '',
      TaskFilter.pending => 't.isCompleted = 0',
      TaskFilter.completed => 't.isCompleted = 1',
      TaskFilter.overdue => 't.isCompleted = 0 AND t.createdAt < ?',
    };
    if (filter == TaskFilter.overdue) {
      whereArgs.add(DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch);
    }

    final orderBy = switch (sortBy) {
      TaskSort.createdAt => 't.createdAt DESC',
      TaskSort.contact => 'contactName COLLATE NOCASE ASC, t.createdAt DESC',
    };

    final query =
        '''
      SELECT t.*, c.name AS contactName
      FROM todos t
      INNER JOIN contacts c ON t.contactId = c.id
      ${where.isNotEmpty ? 'WHERE $where' : ''}
      ORDER BY $orderBy
    ''';

    final maps = await db.rawQuery(query, whereArgs);
    return maps.map((m) {
      final mapCopy = Map<String, dynamic>.from(m);
      final contactName = mapCopy.remove('contactName') as String;
      return TodoWithContact(
        todo: TodoItem.fromMap(mapCopy),
        contactName: contactName,
      );
    }).toList();
  }

  Future<List<TodoItem>> getByContactId(String contactId) async {
    final db = await _db.database;
    final maps = await db.query(
      'todos',
      where: 'contactId = ?',
      whereArgs: [contactId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => TodoItem.fromMap(m)).toList();
  }

  Future<List<TodoItem>> getByNoteId(String noteId) async {
    final db = await _db.database;
    final maps = await db.query(
      'todos',
      where: 'noteId = ?',
      whereArgs: [noteId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => TodoItem.fromMap(m)).toList();
  }

  Future<List<TodoItem>> getPending() async {
    final db = await _db.database;
    final maps = await db.query(
      'todos',
      where: 'isCompleted = 0',
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => TodoItem.fromMap(m)).toList();
  }

  Future<void> _updateContactTasksCount(DatabaseExecutor db, String contactId) => recountForContact(db, contactId);

  /// Recomputes `contacts.pendingTasksCount`. Takes an executor so it can run
  /// inside a transaction.
  static Future<void> recountForContact(DatabaseExecutor db, String contactId) async {
    final countMaps = await db.query(
      'todos',
      columns: ['COUNT(*)'],
      where: 'contactId = ? AND isCompleted = 0',
      whereArgs: [contactId],
    );
    final count = Sqflite.firstIntValue(countMaps) ?? 0;

    await db.update(
      'contacts',
      {'pendingTasksCount': count},
      where: 'id = ?',
      whereArgs: [contactId],
    );
  }

  Future<String> insert(TodoItem todo) async {
    final db = await _db.database;
    final id = todo.id.isEmpty ? _uuid.v4() : todo.id;
    await db.insert('todos', todo.copyWith(id: id).toMap());
    await _updateContactTasksCount(db, todo.contactId);
    return id;
  }

  Future<void> update(TodoItem todo) async {
    final db = await _db.database;
    await db.update('todos', todo.toMap(), where: 'id = ?', whereArgs: [todo.id]);
    await _updateContactTasksCount(db, todo.contactId);
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    final maps = await db.query('todos', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      final contactId = maps.first['contactId'] as String;
      await db.delete('todos', where: 'id = ?', whereArgs: [id]);
      await _updateContactTasksCount(db, contactId);
    }
  }

  /// Sets a task's completion explicitly (used by bulk actions).
  Future<void> setCompleted(String id, bool completed) async {
    final db = await _db.database;
    final maps = await db.query('todos', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return;
    final todo = TodoItem.fromMap(maps.first);
    if (todo.isCompleted == completed) return;
    final updated = todo.copyWith(
      isCompleted: completed,
      completedAt: completed ? DateTime.now() : null,
      clearCompletedAt: !completed,
    );
    await db.update('todos', updated.toMap(), where: 'id = ?', whereArgs: [id]);
    await _updateContactTasksCount(db, todo.contactId);
  }

  Future<void> toggleCompleted(String id) async {
    final db = await _db.database;
    final maps = await db.query('todos', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return;
    final todo = TodoItem.fromMap(maps.first);
    final updated = todo.copyWith(
      isCompleted: !todo.isCompleted,
      completedAt: !todo.isCompleted ? DateTime.now() : null,
      clearCompletedAt: todo.isCompleted,
    );
    await db.update('todos', updated.toMap(), where: 'id = ?', whereArgs: [id]);
    await _updateContactTasksCount(db, todo.contactId);
  }
}
