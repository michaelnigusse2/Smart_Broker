import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/reminder.dart';
import '../theme/app_theme.dart';

class ReminderCard extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;

  const ReminderCard({
    super.key,
    required this.reminder,
    this.onTap,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = reminder.dateTime.isBefore(DateTime.now()) && !reminder.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.sb.surface,
        borderRadius: AppRadius.card,
        boxShadow: [
          BoxShadow(
            color: context.sb.shadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              GestureDetector(
                onTap: onComplete,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: reminder.completed ? context.sb.goodFg : (isOverdue ? context.sb.late : context.sb.track),
                      width: 2,
                    ),
                    color: reminder.completed ? context.sb.goodFg : Colors.transparent,
                  ),
                  child: reminder.completed ? Icon(LucideIcons.check, size: 14, color: context.sb.surface) : null,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: reminder.completed ? context.sb.text3 : (isOverdue ? context.sb.late : context.sb.text),
                        fontWeight: FontWeight.w500,
                        decoration: reminder.completed ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat.MMMd().add_jm().format(reminder.dateTime),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: reminder.completed ? context.sb.text3 : (isOverdue ? context.sb.late : context.sb.text2),
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(LucideIcons.chevronRight, size: 16, color: context.sb.text3),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
