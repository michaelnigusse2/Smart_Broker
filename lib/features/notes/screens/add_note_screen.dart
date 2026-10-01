import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../models/note.dart';
import '../../../core/services/overlay_draft_service.dart';

class AddNoteScreen extends StatefulWidget {
  const AddNoteScreen({super.key});

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  final TextEditingController _noteController = TextEditingController();
  String? _contactId;
  Note? _note;
  bool _isPostCall = false;
  String? _durationStr;
  bool _isDraftRestored = false;
  final _draftService = OverlayDraftService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_contactId == null && _note == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        _contactId = args;
      } else if (args is Map<String, dynamic>) {
        _contactId = args['contactId'] as String?;
        _isPostCall = args['isPostCall'] as bool? ?? false;
        _durationStr = args['duration'] as String?;
      } else if (args is Note) {
        _note = args;
        _contactId = args.contactId;
        _noteController.text = args.rawText;
      }
      
      _loadDraftIfNeeded();
    }
  }

  Future<void> _loadDraftIfNeeded() async {
    // Restore anything typed in the call overlay (also after a post-call prompt).
    if (_contactId != null && _note == null) {
      final draft = await _draftService.loadDraft(_contactId!);
      if (draft != null && draft.isNotEmpty && _noteController.text.isEmpty) {
        if (mounted) {
          setState(() {
            _noteController.text = draft;
            _isDraftRestored = true;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_contactId == null) {
      return const Scaffold(
        body: Center(child: Text('Error: No contact ID provided')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface, // Distraction free pure white
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              if (_noteController.text.trim().isEmpty) return;
              
              if (_contactId != null) {
                await _draftService.clearDraft(_contactId!);
              }

              if (!context.mounted) return;
              
              Navigator.pushNamed(
                context, 
                AppRoutes.aiReview,
                arguments: {
                  'contactId': _contactId,
                  'rawText': _noteController.text.trim(),
                  'noteId': _note?.id,
                },
              );
            },
            icon: const Icon(LucideIcons.sparkles, size: 16),
            label: const Text('AI Review'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: ConstrainedLayout(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isPostCall)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.phone, size: 16, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Auto-detected call — $_durationStr',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_isDraftRestored)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.fileClock, color: AppColors.primary, size: 16),
                      const SizedBox(width: AppSpacing.sm),
                      const Expanded(
                        child: Text(
                          'Draft from your last call restored',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, color: AppColors.primary, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => setState(() => _isDraftRestored = false),
                      ),
                    ],
                  ),
                ),
              Text(
                'Meeting Notes',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.textTertiary),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: _noteController,
                  maxLines: null,
                  expands: true,
                  autofocus: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18, height: 1.6),
                  decoration: InputDecoration(
                    hintText: 'Start typing...',
                    hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18, color: AppColors.textTertiary),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
