import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/info_chip.dart';
import '../../../core/repositories/note_repository.dart';
import '../../../core/repositories/todo_repository.dart';
import '../../../core/repositories/contact_repository.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/app_log.dart';
import '../../../core/services/note_save_service.dart';
import '../../../core/services/overlay_draft_service.dart';
import '../../../core/utils/reminder_time.dart';
import '../../../core/widgets/ai_consent_dialog.dart';
import '../../../core/widgets/past_reminder_dialog.dart';
import '../../../core/constants/app_routes.dart';

class AiReviewScreen extends StatefulWidget {
  const AiReviewScreen({super.key});

  @override
  State<AiReviewScreen> createState() => _AiReviewScreenState();
}

class _AiReviewScreenState extends State<AiReviewScreen> {
  bool _isProcessing = true;
  String? _contactId;
  String? _rawText;
  String? _noteId;

  final NoteRepository _noteRepo = NoteRepository();
  final TodoRepository _todoRepo = TodoRepository();
  final ContactRepository _contactRepo = ContactRepository();
  
  late final TextEditingController _summaryController;
  final List<TextEditingController> _taskControllers = [];
  bool _includeReminder = true;
  final TextEditingController _reminderTitleController = TextEditingController();
  DateTime _reminderDateTime = DateTime.now().add(const Duration(days: 1));
  
  bool _initialized = false;
  bool _isSaving = false;
  String? _saveError;
  String? _aiError;
  String _loadingMessage = 'Reading your notes...';
  Timer? _loadingTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _contactId = args['contactId'] as String?;
        _rawText = args['rawText'] as String?;
        _noteId = args['noteId'] as String?;
      }
      _initialized = true;
      
      _reminderDateTime = DateTime(
        _reminderDateTime.year, 
        _reminderDateTime.month, 
        _reminderDateTime.day, 
        9, 0
      );
      
      _summaryController = TextEditingController();
      _checkApiKeyAndAnalyze();
    }
  }

  void _startLoadingMessages() {
    _loadingTimer?.cancel();
    int step = 0;
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      step++;
      if (step == 1 && mounted) setState(() => _loadingMessage = 'Identifying action items...');
      if (step == 2 && mounted) setState(() => _loadingMessage = 'Generating summary...');
    });
  }

  Future<void> _checkApiKeyAndAnalyze() async {
    // The note is saved before any AI call so it can never be lost.
    if (_noteId == null && _contactId != null && _rawText != null) {
      try {
        _noteId = await _noteRepo.saveNote(contactId: _contactId!, rawText: _rawText!);
        await OverlayDraftService().clearDraft(_contactId!);
      } catch (e, st) {
        AppLog.e('AiReview', 'could not save note', e, st);
        if (!mounted) return;
        setState(() {
          _aiError = 'Could not save the note: $e';
          _isProcessing = false;
        });
        return;
      }
    }
    final aiService = await AiService.fromSettings();
    if (!mounted) return;
    if (aiService == null) {
      _showNoKeyDialog();
      return;
    }
    if (!await ensureAiConsent(context, aiService.provider)) {
      if (!mounted) return;
      _keepWithoutAi('Note saved — AI Review skipped, nothing was sent');
      return;
    }
    _analyzeNote(aiService);
  }

  Future<void> _analyzeNote(AiService aiService) async {
    if (!mounted) return;
    setState(() {
      _isProcessing = true;
      _aiError = null;
      _loadingMessage = 'Reading your notes...';
    });
    
    _startLoadingMessages();

    try {
      if (_contactId == null || _rawText == null) {
        throw Exception('Missing context');
      }

      final contact = await _contactRepo.getById(_contactId!);
      final contactName = contact?.name ?? 'Unknown';

      // Background = other notes only. This note is already saved (and may
      // have an older summary if it's being re-reviewed).
      final previousNotes = await _noteRepo.getByContactId(_contactId!);
      final previousSummaries = previousNotes
          .where((n) => n.id != _noteId && n.aiSummary.isNotEmpty)
          .take(3)
          .map((n) => n.aiSummary)
          .join('\n');

      // Exclude this note's own tasks: the model is told not to repeat
      // existing tasks, and on a re-review it must be free to list them again
      // or they would be treated as dropped.
      final pendingTodosList = await _todoRepo.getByContactId(_contactId!);
      final pendingTodos = pendingTodosList
          .where((t) => !t.isCompleted && t.noteId != _noteId)
          .map((t) => t.title)
          .join('\n');

      final result = await aiService.analyzeNote(
        contactName: contactName,
        rawNote: _rawText!,
        previousNotes: previousSummaries.isEmpty ? 'None' : previousSummaries,
        pendingTodos: pendingTodos.isEmpty ? 'None' : pendingTodos,
      );

      if (!mounted) return;

      setState(() {
        _summaryController.text = result.summary;
        _taskControllers.clear();
        for (final item in result.actionItems) {
          _taskControllers.add(TextEditingController(text: item));
        }
        
        _reminderTitleController.text = result.reminderTitle ?? '';
        if (result.reminderTitle != null) {
          _includeReminder = true;
          if (result.reminderDate != null) {
            _reminderDateTime = result.reminderDate!;
          }
        } else {
          _includeReminder = false;
        }
        
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiError = e.toString();
        _isProcessing = false;
      });
    } finally {
      _loadingTimer?.cancel();
    }
  }

  void _showNoKeyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('API Key Required'),
        content: const Text('To use AI Review, you need to add a free AI API key (e.g. Groq) in Settings.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _keepWithoutAi();
            },
            child: const Text('Keep note without AI'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, AppRoutes.settings).then((_) {
                _checkApiKeyAndAnalyze();
              });
            },
            child: const Text('Enter API Key'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _summaryController.dispose();
    _reminderTitleController.dispose();
    for (final c in _taskControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _reminderDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 1)), // Allow slightly in past for timezone edge cases
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_reminderDateTime),
    );
    if (time == null || !mounted) return;

    setState(() {
      _reminderDateTime = DateTime(
        date.year, date.month, date.day, time.hour, time.minute
      );
    });
  }

  List<String> get _taskTitles => _taskControllers
      .map((c) => c.text.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  /// Leaves AI Review and the note editor, back to where the note was started.
  void _finish() {
    Navigator.popUntil(context, (route) {
      final name = route.settings.name;
      return name != AppRoutes.aiReview && name != AppRoutes.addNote;
    });
  }

  /// The note is already saved; leave without an AI summary.
  void _keepWithoutAi([String message = 'Note saved without an AI summary']) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    _finish();
  }

  Future<void> _saveToProfile() async {
    if (_contactId == null || _rawText == null) return;
    if (_includeReminder && !isSchedulable(_reminderDateTime)) {
      if (!await confirmPastReminder(context)) {
        await _pickDateTime();
        return;
      }
      if (!mounted) return;
    }

    // Show what will change, including tasks an earlier review created that
    // this one no longer lists (completed tasks are always kept).
    final removed = await NoteSaveService().openTasksThatWouldBeRemoved(_noteId!, _taskTitles);
    if (!mounted) return;
    final taskCount = _taskTitles.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save to Profile?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This saves the summary, $taskCount ${taskCount == 1 ? "task" : "tasks"}'
                '${_includeReminder ? " and a reminder" : ""}.'),
            if (removed.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              const Text('These open tasks from the earlier review will be removed:'),
              const SizedBox(height: AppSpacing.xs),
              ...removed.map((t) => Text('•  ${t.title}')),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final typedTitle = _reminderTitleController.text.trim();
      final reminderTitle = typedTitle.isNotEmpty
          ? typedTitle
          : _summaryController.text.isNotEmpty
              ? 'Follow up: ${_summaryController.text.split('.').first}'
              : 'Follow up reminder';

      await NoteSaveService().apply(ReviewedNote(
        noteId: _noteId!,
        contactId: _contactId!,
        rawText: _rawText!,
        summary: _summaryController.text.trim(),
        taskTitles: _taskTitles,
        reminder: _includeReminder ? (title: reminderTitle, dateTime: _reminderDateTime) : null,
      ));
      await OverlayDraftService().clearDraft(_contactId!);

      if (mounted) _finish();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_contactId == null) {
      return const Scaffold(
        body: Center(child: Text('Error: Missing context data')),
      );
    }

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
                      _loadingMessage,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            : _aiError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.alertTriangle, size: 48, color: AppColors.error),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            _aiError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.error),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          ElevatedButton.icon(
                            icon: const Icon(LucideIcons.refreshCw, size: 18),
                            label: const Text('Retry'),
                            onPressed: () => _checkApiKeyAndAnalyze(),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextButton(
                            onPressed: _keepWithoutAi,
                            child: const Text('Keep note without AI'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_saveError != null) ...[
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: AppRadius.card,
                              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.alertCircle, color: AppColors.error, size: 20),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(child: Text(_saveError!, style: TextStyle(color: AppColors.error))),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],

                        const InfoChip(label: 'AI Generated', color: AppColors.primary),
                        
                        const SectionHeader(
                          title: 'Summary',
                          padding: EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
                        ),
                        TextField(
                          controller: _summaryController,
                          maxLines: null,
                          maxLength: 500,
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
                          padding: EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.md),
                        ),
                        ..._taskControllers.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final controller = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.circle, size: 20, color: AppColors.textTertiary),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: TextField(
                                    controller: controller,
                                    maxLength: 200,
                                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                      filled: true,
                                      fillColor: AppColors.surfaceElevated,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(LucideIcons.x, size: 18, color: AppColors.textTertiary),
                                  onPressed: () {
                                    setState(() {
                                      _taskControllers.removeAt(idx).dispose();
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _taskControllers.add(TextEditingController());
                            });
                          },
                          icon: const Icon(LucideIcons.plus, size: 16),
                          label: const Text('Add Task'),
                        ),

                        const SectionHeader(
                          title: 'Suggested Reminder',
                          padding: EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: AppRadius.card,
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: ListTile(
                            leading: const Icon(LucideIcons.calendarClock, color: AppColors.primary, size: 20),
                            title: TextField(
                              controller: _reminderTitleController,
                              decoration: const InputDecoration.collapsed(hintText: 'Reminder title'),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            subtitle: Text(DateFormat.yMMMd().add_jm().format(_reminderDateTime), style: Theme.of(context).textTheme.bodySmall),
                            trailing: Switch(
                              value: _includeReminder,
                              activeThumbColor: AppColors.primary,
                              onChanged: (val) {
                                setState(() {
                                  _includeReminder = val;
                                });
                              },
                            ),
                            onTap: _pickDateTime,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xxxl * 2),
                      ],
                    ),
                  ),
      ),
      bottomNavigationBar: !_isProcessing && _aiError == null ? SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveToProfile,
            child: _isSaving 
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_saveError != null ? 'Retry Save' : 'Save to Profile'),
          ),
        ),
      ) : null,
    );
  }
}
