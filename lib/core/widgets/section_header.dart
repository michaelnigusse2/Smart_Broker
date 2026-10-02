import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final EdgeInsetsGeometry? padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onActionTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: padding ?? const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (actionLabel != null && onActionTap != null)
            InkWell(
              onTap: onActionTap,
              borderRadius: AppRadius.button,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel!,
                      style: theme.textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(LucideIcons.chevronRight, size: 14, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
