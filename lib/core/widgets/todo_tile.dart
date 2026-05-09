import 'package:flutter/material.dart';
import '../../models/todo_item.dart';
import '../theme/app_theme.dart';

class TodoTile extends StatelessWidget {
  final TodoItem todo;
  final ValueChanged<bool?>? onChanged;

  const TodoTile({
    super.key,
    required this.todo,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      // Flat list item, no borders or background for minimal density
      child: CheckboxListTile(
        value: todo.isCompleted,
        onChanged: onChanged,
        title: Text(
          todo.title,
          style: theme.textTheme.bodyMedium?.copyWith(
            decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
            color: todo.isCompleted ? AppColors.textTertiary : AppColors.textPrimary,
          ),
        ),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppColors.primary,
        contentPadding: EdgeInsets.zero, // Minimal spacing
        visualDensity: VisualDensity.compact,
        checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
