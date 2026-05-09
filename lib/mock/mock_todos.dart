import '../models/todo_item.dart';

final mockTodos = [
  TodoItem(
    id: 't1',
    contactId: 'c1',
    title: 'Send AWS cost breakdown for Q3 upgrade',
    isCompleted: false,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  TodoItem(
    id: 't2',
    contactId: 'c1',
    title: 'Schedule coffee meeting for next Tuesday',
    isCompleted: false,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  TodoItem(
    id: 't3',
    contactId: 'c1',
    title: 'Send initial contract draft',
    isCompleted: true,
    createdAt: DateTime.now().subtract(const Duration(days: 20)),
  ),
  TodoItem(
    id: 't4',
    contactId: 'c3',
    title: 'Prepare enterprise tier pitch deck',
    isCompleted: false,
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
  ),
  TodoItem(
    id: 't5',
    contactId: 'c4',
    title: 'Follow up on Q2 renewal',
    isCompleted: false,
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
  ),
  TodoItem(
    id: 't6',
    contactId: 'c4',
    title: 'Review legal terms with team',
    isCompleted: false,
    createdAt: DateTime.now().subtract(const Duration(days: 6)),
  ),
  TodoItem(
    id: 't7',
    contactId: 'c4',
    title: 'Send onboarding packet',
    isCompleted: true,
    createdAt: DateTime.now().subtract(const Duration(days: 10)),
  ),
];
