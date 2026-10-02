import 'todo_item.dart';

class TodoWithContact {
  final TodoItem todo;
  final String contactName;

  TodoWithContact({required this.todo, required this.contactName});

  // Forward commonly used fields for convenience
  String get id => todo.id;
  String get contactId => todo.contactId;
  String get title => todo.title;
  bool get isCompleted => todo.isCompleted;
  DateTime get createdAt => todo.createdAt;
  DateTime? get completedAt => todo.completedAt;
  String? get noteId => todo.noteId;
}
