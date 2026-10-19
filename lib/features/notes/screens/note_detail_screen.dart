import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../core/widgets/todo_tile.dart';
import '../../../core/widgets/reminder_card.dart';

import '../../../core/repositories/note_repository.dart';
import '../../../core/repositories/contact_repository.dart';
import '../../../core/repositories/todo_repository.dart';
import '../../../core/repositories/reminder_repository.dart';

import '../../../models/note.dart';
import '../../../models/contact.dart';
import '../../../models/todo_item.dart';
import '../../../models/reminder.dart';

class NoteDetailScreen extends StatefulWidget {
  const NoteDetailScreen({super.key});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  final NoteRepository _noteRepo = NoteRepository();
  final ContactRepository _contactRepo = ContactRepository();
  final TodoRepository _todoRepo = TodoRepository();
  final ReminderRepository _reminderRepo = ReminderRepository();

  String? _noteId;
  Note? _note;
  Contact? _contact;
  List<TodoItem> _todos = [];
  List<Reminder> _reminders = [];

  bool _isLoading = true;
  String? _error;
  bool _initialized = false;

  bool _isEditing = false;
  late TextEditingController _rawTextController;
  late TextEditingController _aiSummaryController;

  @override
  void initState() {
    super.initState();
    _rawTextController = TextEditingController();
    _aiSummaryController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        _noteId = args;
        _initialized = true;
        _loadData();
      } else {
        setState(() {
          _error = 'No note ID provided.';
          _isLoading = false;
        });
        _initialized = true;
      }
    }
  }

  @override
  void dispose() {
    _rawTextController.dispose();
    _aiSummaryController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_noteId == null) return;
    try {
      final note = await _noteRepo.getById(_noteId!);
      if (note == null) throw Exception('Note not found');

      final contact = await _contactRepo.getById(note.contactId);
      final todos = await _todoRepo.getByNoteId(note.id);
      final reminders = await _reminderRepo.getByNoteId(note.id);

      if (mounted) {
        setState(() {
          _note = note;
          _contact = contact;
          _todos = todos;
          _reminders = reminders;
          _isLoading = false;

          if (!_isEditing) {
            _rawTextController.text = note.rawText;
            _aiSummaryController.text = note.aiSummary;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveEdits() async {
    if (_note == null) return;
    final updatedNote = _note!.copyWith(
      rawText: _rawTextController.text.trim(),
      aiSummary: _aiSummaryController.text.trim(),
    );
    await _noteRepo.update(updatedNote);
    if (!mounted) return;
    setState(() {
      _note = updatedNote;
      _isEditing = false;
    });
    // Do not reload full data as we only updated the note
  }

  Future<void> _runAiReview() async {
    if (_note == null) return;
    await Navigator.pushNamed(
      context,
      AppRoutes.aiReview,
      arguments: {
        'contactId': _note!.contactId,
        'rawText': _note!.rawText,
        'noteId': _note!.id,
      },
    );
    if (mounted) _loadData();
  }

  Future<void> _deleteNote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text(
          'This will permanently delete this note. Linked todos and reminders will not be deleted but will no longer be associated with this note.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && _noteId != null && mounted) {
      await _noteRepo.delete(_noteId!);
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _note == null || _contact == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(_error ?? 'Unknown error')),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Note' : 'Note'),
        actions: [
          if (_isEditing) ...[
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _rawTextController.text = _note!.rawText;
                  _aiSummaryController.text = _note!.aiSummary;
                });
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _saveEdits,
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(LucideIcons.sparkles),
              tooltip: 'AI Review',
              onPressed: _runAiReview,
            ),
            IconButton(
              icon: const Icon(LucideIcons.edit2),
              onPressed: () {
                setState(() => _isEditing = true);
              },
            ),
            IconButton(
              icon: const Icon(LucideIcons.trash2, color: AppColors.error),
              onPressed: _deleteNote,
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: ConstrainedLayout(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contact Chip
              InkWell(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.contactDetail,
                    arguments: _contact!.id,
                  ).then((_) => _loadData());
                },
                borderRadius: AppRadius.button,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: AppRadius.button,
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        foregroundColor: AppColors.primary,
                        child: Text(
                          _contact!.initials,
                          style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          'From: ${_contact!.name}',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      const Icon(LucideIcons.chevronRight, size: 14, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Date
              Text(
                DateFormat.yMMMMd().add_jm().format(_note!.createdAt),
                style: theme.textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),

              // AI Summary Section
              Row(
                children: [
                  const Icon(LucideIcons.sparkles, size: 16, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text('AI Summary', style: theme.textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_isEditing)
                TextField(
                  controller: _aiSummaryController,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: 'Edit summary...',
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.card,
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(AppSpacing.md),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: AppRadius.card,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: _note!.aiSummary.isEmpty
                      ? Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Not processed by AI yet.',
                                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                            TextButton(onPressed: _runAiReview, child: const Text('Run AI Review')),
                          ],
                        )
                      : Text(
                          _note!.aiSummary,
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                        ),
                ),
              const SizedBox(height: AppSpacing.xxl),

              // Original Note Section
              Row(
                children: [
                  const Icon(LucideIcons.fileText, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Original Note', style: theme.textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_isEditing)
                TextField(
                  controller: _rawTextController,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: 'Edit raw text...',
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.card,
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(AppSpacing.md),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: AppRadius.card,
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Text(
                    '"${_note!.rawText}"',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),

              if (_todos.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  children: [
                    const Icon(LucideIcons.checkSquare, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Action Items', style: theme.textTheme.titleSmall),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ..._todos.map(
                  (todo) => TodoTile(
                    todo: todo,
                    onChanged: (val) async {
                      await _todoRepo.toggleCompleted(todo.id);
                      _loadData();
                    },
                  ),
                ),
              ],

              if (_reminders.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  children: [
                    const Icon(LucideIcons.bell, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Reminders', style: theme.textTheme.titleSmall),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ..._reminders.map(
                  (r) => ReminderCard(
                    reminder: r,
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.reminderDetail,
                      arguments: r.id,
                    ).then((_) => _loadData()),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }
}
