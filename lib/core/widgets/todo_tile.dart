import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/todo_item.dart';
import '../theme/app_theme.dart';
import 'text_prompt.dart';

class TodoTile extends StatelessWidget {
  final TodoItem todo;
  final ValueChanged<bool?>? onChanged;
  final Function(String)? onEdit;
  final VoidCallback? onDelete;
  final bool isBulkMode;
  final bool isSelected;
  final String? subtitleText;
  final VoidCallback? onTapSubtitle;
  final bool showChevron;

  /// Tapping the row. Defaults to toggling the checkbox; screens that show a
  /// chevron should open something instead.
  final VoidCallback? onTap;

  const TodoTile({
    super.key,
    required this.todo,
    this.onChanged,
    this.onEdit,
    this.onDelete,
    this.isBulkMode = false,
    this.isSelected = false,
    this.subtitleText,
    this.onTapSubtitle,
    this.showChevron = false,
    this.onTap,
  });

  bool get isOverdue {
    if (todo.isCompleted) return false;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return todo.createdAt.isBefore(cutoff);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: AppRadius.card,
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        leading: Checkbox(
          value: isBulkMode ? isSelected : todo.isCompleted,
          onChanged: onChanged,
          activeColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        title: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: isBulkMode ? null : () => _showEditDialog(context),
                child: Text(
                  todo.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                    color: todo.isCompleted ? AppColors.textTertiary : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            if (isOverdue && !isBulkMode)
              Container(
                margin: const EdgeInsets.only(left: AppSpacing.sm),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: subtitleText != null
            ? GestureDetector(
                onTap: onTapSubtitle,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitleText!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
            : null,
        trailing: isBulkMode
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showChevron) const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textTertiary),
                  if (onDelete != null || onEdit != null)
                    PopupMenuButton<String>(
                      icon: const Icon(LucideIcons.moreVertical, size: 16, color: AppColors.textTertiary),
                      onSelected: (value) {
                        if (value == 'edit') _showEditDialog(context);
                        if (value == 'delete') _confirmDelete(context);
                      },
                      itemBuilder: (context) => [
                        if (onEdit != null)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(LucideIcons.edit2, size: 16),
                                SizedBox(width: AppSpacing.sm),
                                Text('Edit'),
                              ],
                            ),
                          ),
                        if (onDelete != null)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(LucideIcons.trash2, size: 16, color: AppColors.error),
                                SizedBox(width: AppSpacing.sm),
                                Text('Delete', style: TextStyle(color: AppColors.error)),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
        onTap: () {
          if (isBulkMode) {
            onChanged?.call(!isSelected);
          } else if (onTap != null) {
            onTap!();
          } else {
            onChanged?.call(!todo.isCompleted);
          }
        },
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context) async {
    if (onEdit == null) return;
    final title = await showTextPromptDialog(
      context,
      title: 'Edit Task',
      initialText: todo.title,
      hint: 'Task title',
    );
    if (title != null) onEdit!(title);
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete?.call();
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
