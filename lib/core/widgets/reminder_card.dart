import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/reminder.dart';
import '../theme/app_theme.dart';

class ReminderCard extends StatelessWidget {
  final Reminder reminder;

  const ReminderCard({
    super.key,
    required this.reminder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = reminder.dateTime.isBefore(DateTime.now());
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.calendarClock,
            color: isOverdue ? AppColors.error : AppColors.textTertiary,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              reminder.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isOverdue ? AppColors.error : AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            DateFormat.MMMd().add_jm().format(reminder.dateTime),
            style: theme.textTheme.labelSmall?.copyWith(
              color: isOverdue ? AppColors.error : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
