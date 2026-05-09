import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/constrained_layout.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ConstrainedLayout(
        child: ListView(
          children: [
            const SizedBox(height: AppSpacing.md),
            _buildSectionHeader(context, 'Appearance'),
            ListTile(
              leading: const Icon(LucideIcons.moon),
              title: const Text('Theme'),
              subtitle: const Text('Light (Default)'),
              trailing: const Icon(LucideIcons.chevronRight, size: 20),
              onTap: () {},
            ),
            const Divider(height: 1),
            
            _buildSectionHeader(context, 'AI Integration'),
            ListTile(
              leading: const Icon(LucideIcons.sparkles),
              title: const Text('AI Status'),
              subtitle: const Text('Connected (Mock Mode)'),
              trailing: const Icon(LucideIcons.checkCircle2, color: AppColors.primary, size: 20),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(LucideIcons.history),
              title: const Text('Clear AI Cache'),
              trailing: const Icon(LucideIcons.chevronRight, size: 20),
              onTap: () {},
            ),
            const Divider(height: 1),

            _buildSectionHeader(context, 'Developer Tools'),
            ListTile(
              leading: const Icon(LucideIcons.bug),
              title: const Text('Debug Menu'),
              trailing: const Icon(LucideIcons.chevronRight, size: 20),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(LucideIcons.trash2),
              title: const Text('Reset Mock Data'),
              trailing: const Icon(LucideIcons.chevronRight, size: 20),
              onTap: () {},
            ),
            
            const SizedBox(height: AppSpacing.xxl),
            const Center(
              child: Text(
                'SmartBroker v1.0.0-mock\nPhase 1 UI Skeleton',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.lg, top: AppSpacing.xl, bottom: AppSpacing.sm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
