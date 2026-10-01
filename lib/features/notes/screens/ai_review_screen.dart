import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/info_chip.dart';
import '../../../models/todo_item.dart';
import '../../../models/note.dart';
import '../../../models/reminder.dart';
import '../../../core/repositories/note_repository.dart';
import '../../../core/repositories/todo_repository.dart';
import '../../../core/repositories/reminder_repository.dart';
import '../../../core/repositories/contact_repository.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/overlay_draft_service.dart';
import '../../../core/utils/reminder_time.dart';
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
  final ReminderRepository _reminderRepo = ReminderRepository();
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
    final aiService = await AiService.fromSettings();
    if (aiService == null) {
      if (!mounted) return;
      _showNoKeyDialog();
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

      final previousNotes = await _noteRepo.getByContactId(_contactId!);
      final previousSummaries = previousNotes.take(3).map((n) => n.aiSummary).join('\n');

      final pendingTodosList = await _todoRepo.getByContactId(_contactId!);
      final pendingTodos = pendingTodosList.where((t) => !t.isCompleted).map((t) => t.title).join('\n');

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
              Navigator.pop(context); // Go back to note screen
            },
            child: const Text('Skip for now'),
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
    if (time == null) return;

    setState(() {
      _reminderDateTime = DateTime(
        date.year, date.month, date.day, time.hour, time.minute
      );
    });
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

    // Show summary confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save to Profile?'),
        content: Text('This will create 1 note, ${_taskControllers.length} tasks, and ${_includeReminder ? "1 reminder" : "0 reminders"}.'),
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
      String finalNoteId;

      if (_noteId == null) {
        final note = Note(
          id: '',
          contactId: _contactId!,
          rawText: _rawText!,
          aiSummary: _summaryController.text.trim(),
          createdAt: DateTime.now(),
        );
        finalNoteId = await _noteRepo.insert(note);
      } else {
        finalNoteId = _noteId!;
        final existingNote = await _noteRepo.getById(finalNoteId);
        if (existingNote != null) {
          await _noteRepo.update(existingNote.copyWith(
            rawText: _rawText!,
            aiSummary: _summaryController.text.trim(),
          ));
        }

        final oldTodos = await _todoRepo.getByNoteId(finalNoteId);
        for (final t in oldTodos) {
          await _todoRepo.delete(t.id);
        }
        final oldReminders = await _reminderRepo.getByNoteId(finalNoteId);
        for (final r in oldReminders) {
          await NotificationService().cancelReminder(r.id);
          await _reminderRepo.delete(r.id);
        }
      }

      for (final controller in _taskControllers) {
        final title = controller.text.trim();
        if (title.isNotEmpty) {
          final todo = TodoItem(
            id: '',
            contactId: _contactId!,
            noteId: finalNoteId,
            title: title,
            createdAt: DateTime.now(),
          );
          await _todoRepo.insert(todo);
        }
      }

      if (_includeReminder) {
        final typedTitle = _reminderTitleController.text.trim();
        final title = typedTitle.isNotEmpty
            ? typedTitle
            : _summaryController.text.isNotEmpty
                ? 'Follow up: ${_summaryController.text.split('.').first}'
                : 'Follow up reminder';
        
        final reminder = Reminder(
          id: '',
          contactId: _contactId!,
          noteId: finalNoteId,
          title: title,
          dateTime: _reminderDateTime,
          createdAt: DateTime.now(),
        );
        final reminderId = await _reminderRepo.insert(reminder);
        await NotificationService().scheduleReminder(reminder.copyWith(id: reminderId));
      }

      // Mark the contact as recently active and clear any saved call draft.
      final contact = await _contactRepo.getById(_contactId!);
      if (contact != null) {
        await _contactRepo.update(contact.copyWith(lastInteraction: DateTime.now()));
      }
      await OverlayDraftService().clearDraft(_contactId!);

      if (mounted) {
        // Return to wherever the note was started from (contact, note, or home).
        Navigator.popUntil(context, (route) {
          final name = route.settings.name;
          return name != AppRoutes.aiReview && name != AppRoutes.addNote;
        });
      }
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
