import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../models/unified_contact.dart';
import '../theme/app_theme.dart';
import '../utils/reminder_time.dart';
import 'info_chip.dart';

class ContactCard extends StatelessWidget {
  final UnifiedContact contact;
  final VoidCallback onTap;

  const ContactCard({
    super.key,
    required this.contact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTasks = contact.pendingTasksCount > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          child: Opacity(
            opacity: (!contact.isSmartBrokerContact && contact.isPhoneContact) ? 0.6 : 1.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  // Avatar with subtle accent border if has tasks
                  Container(
                    decoration: hasTasks
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: context.sb.primary, width: 1.5),
                          )
                        : null,
                    child: CircleAvatar(
                      backgroundColor: context.sb.fill,
                      foregroundColor: context.sb.text,
                      radius: 20,
                      child: Text(
                        contact.initials,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // Name + phone
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                contact.name,
                                style: theme.textTheme.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!contact.isSmartBrokerContact && contact.isPhoneContact) ...[
                              const SizedBox(width: 4),
                              Icon(LucideIcons.smartphone, size: 12, color: context.sb.text3),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          contact.phoneNumber.trim(),
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  // Right side: date + task indicator
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatDate(contact.lastInteraction),
                        style: theme.textTheme.labelSmall,
                      ),
                      if (hasTasks) ...[
                        const SizedBox(height: 4),
                        InfoChip(
                          label: '${contact.pendingTasksCount} ${contact.pendingTasksCount == 1 ? 'task' : 'tasks'}',
                          color: context.sb.primary,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    // Guard against epoch zero (phone-only contacts with no interaction)
    if (date.millisecondsSinceEpoch == 0) return '—';
    final now = DateTime.now();
    final difference = now.difference(date);
    if (isSameCalendarDay(date, now)) return DateFormat.jm().format(date);
    if (difference.inDays < 7) return DateFormat.E().format(date);
    return DateFormat.MMMd().format(date);
  }
}
