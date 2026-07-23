import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../../models/todo_item.dart';

class TodoRepository {
  final DatabaseHelper _db = DatabaseHelper();
  final _uuid = const Uuid();

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

  Future<List<TodoItem>> getPending() async {
    final db = await _db.database;
    final maps = await db.query(
      'todos',
      where: 'isCompleted = 0',
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => TodoItem.fromMap(m)).toList();
  }

  Future<String> insert(TodoItem todo) async {
    final db = await _db.database;
    final id = todo.id.isEmpty ? _uuid.v4() : todo.id;
    await db.insert('todos', todo.copyWith(id: id).toMap());
    return id;
  }

  Future<void> update(TodoItem todo) async {
    final db = await _db.database;
    await db.update('todos', todo.toMap(), where: 'id = ?', whereArgs: [todo.id]);
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('todos', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> toggleCompleted(String id) async {
    final db = await _db.database;
    final maps = await db.query('todos', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return;
    final todo = TodoItem.fromMap(maps.first);
    final updated = todo.copyWith(
      isCompleted: !todo.isCompleted,
      completedAt: !todo.isCompleted ? DateTime.now() : null,
    );
    await db.update('todos', updated.toMap(), where: 'id = ?', whereArgs: [id]);
  }
}
