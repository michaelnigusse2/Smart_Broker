import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/todo_tile.dart';
import '../../../core/widgets/info_chip.dart';
import '../../../models/todo_item.dart';

class AiReviewScreen extends StatefulWidget {
  const AiReviewScreen({super.key});

  @override
  State<AiReviewScreen> createState() => _AiReviewScreenState();
}

class _AiReviewScreenState extends State<AiReviewScreen> {
  bool _isProcessing = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Review'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ConstrainedLayout(
        child: _isProcessing
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Analyzing notes...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const InfoChip(label: 'AI Generated', color: AppColors.primary),
                    
                    const SectionHeader(
                      title: 'Summary',
                      padding: EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
                    ),
                    TextField(
                      controller: TextEditingController(text: 'Client prefers AWS but requires a cost breakdown. Promised to deliver by Friday. Also suggested coffee next Tuesday.'),
                      maxLines: null,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(AppSpacing.md),
                      ),
                    ),

                    const SectionHeader(
                      title: 'Action Items',
                      padding: EdgeInsets.only(top: AppSpacing.xxl, bottom: AppSpacing.md),
                    ),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.card,
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        children: [
                          TodoTile(
                            todo: TodoItem(
                              id: 'm1',
                              contactId: 'c1',
                              title: 'Send AWS cost breakdown by Friday',
                              createdAt: DateTime.now(),
                            ),
                            onChanged: (val) {},
                          ),
                          TodoTile(
                            todo: TodoItem(
                              id: 'm2',
                              contactId: 'c1',
                              title: 'Schedule coffee next Tuesday',
                              createdAt: DateTime.now(),
                            ),
                            onChanged: (val) {},
                          ),
                        ],
                      ),
                    ),

                    const SectionHeader(
                      title: 'Suggested Reminder',
                      padding: EdgeInsets.only(top: AppSpacing.xxl, bottom: AppSpacing.md),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.card,
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: ListTile(
                        leading: const Icon(LucideIcons.calendarClock, color: AppColors.primary, size: 20),
                        title: Text('Follow up on Cost Breakdown', style: Theme.of(context).textTheme.bodyMedium),
                        subtitle: Text('Tomorrow at 9:00 AM', style: Theme.of(context).textTheme.bodySmall),
                        trailing: Switch(
                          value: true,
                          activeColor: AppColors.primary,
                          onChanged: (val) {},
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxxl * 2),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: !_isProcessing ? SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Save to Profile'),
          ),
        ),
      ) : null,
    );
  }
}
