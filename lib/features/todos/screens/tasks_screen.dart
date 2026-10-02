import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/repositories/todo_repository.dart';
import '../../../core/repositories/contact_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/todo_tile.dart';
import '../../../models/todo_item.dart';
import '../../../models/todo_with_contact.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final TodoRepository _todoRepo = TodoRepository();
  final ContactRepository _contactRepo = ContactRepository();

  List<TodoWithContact> _todos = [];
  bool _isLoading = true;

  TaskFilter _activeFilter = TaskFilter.all;
  TaskSort _activeSort = TaskSort.createdAt;

  bool _isBulkMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  Future<void> _loadTodos() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final filter = _activeFilter;
    final sort = _activeSort;
    final todos = await _todoRepo.getAll(filter: filter, sortBy: sort);
    // Ignore results of a query that the user has already switched away from.
    if (mounted && filter == _activeFilter && sort == _activeSort) {
      setState(() {
        _todos = todos;
        _isLoading = false;
      });
    }
  }

  void _toggleFilter(TaskFilter filter) {
    if (_activeFilter == filter) return;
    setState(() {
      _activeFilter = filter;
      _isBulkMode = false;
      _selectedIds.clear();
    });
    _loadTodos();
  }

  void _toggleSort() {
    setState(() {
      _activeSort = _activeSort == TaskSort.createdAt ? TaskSort.contact : TaskSort.createdAt;
    });
    _loadTodos();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isBulkMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _bulkDelete() async {
    final ids = _selectedIds.toList();
    setState(() {
      _isBulkMode = false;
      _selectedIds.clear();
    });
    for (var id in ids) {
      await _todoRepo.delete(id);
    }
    _loadTodos();
  }

  Future<void> _bulkComplete() async {
    final ids = _selectedIds.toList();
    setState(() {
      _isBulkMode = false;
      _selectedIds.clear();
    });
    for (var id in ids) {
      await _todoRepo.setCompleted(id, true);
    }
    _loadTodos();
  }

  Future<void> _handleDelete(TodoWithContact item) async {
    final todoItem = item.todo;
    await _todoRepo.delete(todoItem.id);
    if (!mounted) return;

    // Optimistic UI update
    setState(() {
      _todos.removeWhere((t) => t.id == todoItem.id);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Task deleted'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              // Re-insert with the original ID
              await _todoRepo.insert(todoItem);
              _loadTodos();
            },
          ),
        ),
      );
    }
  }

  void _showAddTaskSheet() async {
    final contacts = await _contactRepo.getAll();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) {
        return _AddTaskSheet(
          contacts: contacts,
          onSave: (todo) async {
            await _todoRepo.insert(todo);
            _loadTodos();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isBulkMode ? _buildBulkAppBar() : _buildNormalAppBar(),
      body: Column(
        children: [
          _buildFilterBar(),
          _buildSortBar(),
          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildList(),
          ),
        ],
      ),
      floatingActionButton: _isBulkMode
          ? null
          : FloatingActionButton(
              onPressed: _showAddTaskSheet,
              backgroundColor: AppColors.primary,
              child: const Icon(LucideIcons.plus, color: Colors.white),
            ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
      title: const Text('Tasks'),
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: AppColors.border, height: 1),
      ),
    );
  }

  PreferredSizeWidget _buildBulkAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(LucideIcons.x),
        onPressed: () {
          setState(() {
            _isBulkMode = false;
            _selectedIds.clear();
          });
        },
      ),
      title: Text('${_selectedIds.length} selected'),
      actions: [
        IconButton(
          icon: const Icon(LucideIcons.checkSquare),
          onPressed: _bulkComplete,
          tooltip: 'Toggle Status',
        ),
        IconButton(
          icon: const Icon(LucideIcons.trash2),
          onPressed: _bulkDelete,
          tooltip: 'Delete',
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        children: [
          _buildFilterChip('All', TaskFilter.all),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip('Pending', TaskFilter.pending),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip('Completed', TaskFilter.completed),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip('Overdue', TaskFilter.overdue),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, TaskFilter filterValue) {
    final isActive = _activeFilter == filterValue;
    return ChoiceChip(
      label: Text(label),
      selected: isActive,
      onSelected: (selected) {
        if (selected) _toggleFilter(filterValue);
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.1),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isActive ? AppColors.primary : AppColors.textSecondary,
        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isActive ? AppColors.primary : AppColors.border,
      ),
    );
  }

  Widget _buildSortBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_todos.length} Tasks',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          TextButton.icon(
            onPressed: _toggleSort,
            icon: const Icon(LucideIcons.arrowDownWideNarrow, size: 16, color: AppColors.textSecondary),
            label: Text(
              'Sort: ${_activeSort == TaskSort.createdAt ? 'Newest' : 'Contact'}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_todos.isEmpty) {
      return Center(
        child: Text(
          'No tasks found.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    if (_activeFilter == TaskFilter.all) {
      final pending = _todos.where((t) => !t.isCompleted).toList();
      final completed = _todos.where((t) => t.isCompleted).toList();

      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (pending.isNotEmpty) ...[
            _buildSectionHeader('${pending.length} Pending'),
            ...pending.map((t) => _buildTodoTile(t)),
          ],
          if (completed.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _buildSectionHeader('${completed.length} Completed'),
            ...completed.map((t) => _buildTodoTile(t)),
          ],
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _todos.length,
      itemBuilder: (context, index) {
        return _buildTodoTile(_todos[index]);
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTodoTile(TodoWithContact item) {
    final todo = item.todo;

    // Relative time logic (simplistic for now)
    final diff = DateTime.now().difference(todo.createdAt);
    String timeStr;
    if (diff.inDays > 0) {
      timeStr = '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      timeStr = '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      timeStr = '${diff.inMinutes}m ago';
    } else {
      timeStr = 'Just now';
    }

    final tile = TodoTile(
      todo: todo,
      subtitleText: '${item.contactName} • $timeStr',
      isBulkMode: _isBulkMode,
      isSelected: _selectedIds.contains(todo.id),
      onTapSubtitle: () async {
        await Navigator.pushNamed(
          context,
          AppRoutes.contactDetail,
          arguments: todo.contactId,
        );
        _loadTodos(); // reload on return
      },
      onChanged: (val) {
        if (_isBulkMode) {
          _toggleSelection(todo.id);
        } else {
          _todoRepo.toggleCompleted(todo.id).then((_) => _loadTodos());
        }
      },
      onEdit: (newTitle) {
        _todoRepo.update(todo.copyWith(title: newTitle)).then((_) => _loadTodos());
      },
      onDelete: () => _handleDelete(item),
    );

    return GestureDetector(
      onLongPress: () {
        if (!_isBulkMode) {
          setState(() {
            _isBulkMode = true;
            _selectedIds.add(todo.id);
          });
        }
      },
      child: Dismissible(
        key: Key(todo.id),
        direction: _isBulkMode ? DismissDirection.none : DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppSpacing.md),
          color: AppColors.error,
          child: const Icon(LucideIcons.trash2, color: Colors.white),
        ),
        onDismissed: (direction) {
          _handleDelete(item);
        },
        child: tile,
      ),
    );
  }
}

class _AddTaskSheet extends StatefulWidget {
  final List<dynamic> contacts; // Actually List<Contact> but keeping dynamic for fast typing since we know the model
  final Function(TodoItem) onSave;

  const _AddTaskSheet({required this.contacts, required this.onSave});

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _controller = TextEditingController();
  String? _selectedContactId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New Task', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'What needs to be done?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Contact',
                border: OutlineInputBorder(),
              ),
              initialValue: _selectedContactId,
              items: widget.contacts.map((c) {
                return DropdownMenuItem<String>(
                  value: c.id,
                  child: Text(c.name),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedContactId = val),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: _selectedContactId == null
                  ? null
                  : () {
                      if (_controller.text.trim().isEmpty) return;

                      final todo = TodoItem(
                        id: '',
                        contactId: _selectedContactId!,
                        title: _controller.text.trim(),
                        isCompleted: false,
                        createdAt: DateTime.now(),
                      );
                      widget.onSave(todo);
                      Navigator.pop(context);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
              child: const Text('Save Task'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
