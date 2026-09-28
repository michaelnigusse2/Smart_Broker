import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/repositories/reminder_repository.dart';
import '../../../core/repositories/contact_repository.dart';
import '../../../core/repositories/note_repository.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/notification_service.dart';
import '../../../models/reminder.dart';
import '../../../models/contact.dart';
import '../../../models/note.dart';

class ReminderDetailScreen extends StatefulWidget {
  const ReminderDetailScreen({super.key});

  @override
  State<ReminderDetailScreen> createState() => _ReminderDetailScreenState();
}

class _ReminderDetailScreenState extends State<ReminderDetailScreen> {
  final _reminderRepo = ReminderRepository();
  final _contactRepo = ContactRepository();
  final _noteRepo = NoteRepository();

  String? _reminderId;
  Reminder? _reminder;
  Contact? _contact;
  Note? _note;
  bool _isLoading = true;
  String? _error;

  // Edit Mode state
  bool _isEditing = false;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  DateTime? _editedDateTime;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reminderId == null) {
      _reminderId = ModalRoute.of(context)?.settings.arguments as String?;
      if (_reminderId != null) {
        _loadData();
      } else {
        setState(() {
          _error = 'No reminder ID provided';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    if (_isEditing) {
      _titleController.dispose();
      _descriptionController.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final reminder = await _reminderRepo.getById(_reminderId!);
      if (reminder == null) {
        throw Exception('Reminder not found');
      }

      final contact = await _contactRepo.getById(reminder.contactId);
      Note? note;
      if (reminder.noteId != null) {
        note = await _noteRepo.getById(reminder.noteId!);
      }

      if (mounted) {
        setState(() {
          _reminder = reminder;
          _contact = contact;
          _note = note;
          _isLoading = false;
          _error = null;
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

  void _enterEditMode() {
    _titleController = TextEditingController(text: _reminder!.title);
    _descriptionController = TextEditingController(text: _reminder!.description);
    _editedDateTime = _reminder!.dateTime;
    setState(() {
      _isEditing = true;
    });
  }

  void _cancelEditMode() {
    _titleController.dispose();
    _descriptionController.dispose();
    setState(() {
      _isEditing = false;
    });
  }

  Future<void> _saveChanges() async {
    if (_titleController.text.trim().isEmpty) return;

    final updated = _reminder!.copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      dateTime: _editedDateTime,
    );

    await _reminderRepo.update(updated);
    // Reschedule notification (date/time may have changed)
    await NotificationService().cancelReminder(updated.id);
    await NotificationService().scheduleReminder(updated);
    _cancelEditMode();
    _loadData(); // reload fresh data
  }

  Future<void> _deleteReminder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reminder?'),
        content: const Text('This action cannot be undone.'),
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

    if (confirm == true && mounted) {
      await _reminderRepo.delete(_reminder!.id);
      await NotificationService().cancelReminder(_reminder!.id);
      if (!mounted) return;
      Navigator.pop(context); // pop back
    }
  }

  Future<void> _toggleComplete() async {
    final updated = _reminder!.copyWith(completed: !_reminder!.completed);
    await _reminderRepo.update(updated);
    // Cancel or reschedule notification based on new completion state
    if (updated.completed) {
      await NotificationService().cancelReminder(updated.id);
    } else {
      await NotificationService().scheduleReminder(updated);
    }
    _loadData();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _editedDateTime!,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    if (!mounted) return;
    
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_editedDateTime!),
    );
    if (time == null) return;

    setState(() {
      _editedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Widget _buildStatusPill() {
    if (_reminder!.completed) {
      return _Pill(color: Colors.green, label: 'Completed');
    }
    if (_reminder!.dateTime.isBefore(DateTime.now())) {
      return _Pill(color: AppColors.error, label: 'Overdue');
    }
    return _Pill(color: AppColors.primary, label: 'Upcoming');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _reminder == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reminder')),
        body: Center(child: Text(_error ?? 'Not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Reminder' : 'Reminder'),
        leading: _isEditing
            ? IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: _cancelEditMode,
              )
            : IconButton(
                icon: const Icon(LucideIcons.arrowLeft),
                onPressed: () => Navigator.pop(context),
              ),
        actions: _isEditing
            ? [
                TextButton(
                  onPressed: _saveChanges,
                  child: const Text('Save', style: TextStyle(color: AppColors.primary)),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(LucideIcons.edit2, size: 20),
                  onPressed: _enterEditMode,
                ),
                IconButton(
                  icon: const Icon(LucideIcons.trash2, size: 20, color: AppColors.error),
                  onPressed: _deleteReminder,
                ),
              ],
      ),
      body: SafeArea(
        child: ConstrainedLayout(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusPill(),
                      const SizedBox(height: AppSpacing.xl),
                      
                      // Title
                      if (_isEditing)
                        TextField(
                          controller: _titleController,
                          style: Theme.of(context).textTheme.headlineMedium,
                          decoration: const InputDecoration(
                            hintText: 'Title',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                          maxLines: null,
                        )
                      else
                        Text(
                          _reminder!.title,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            decoration: _reminder!.completed ? TextDecoration.lineThrough : null,
                            color: _reminder!.completed ? AppColors.textSecondary : null,
                          ),
                        ),
                      
                      const SizedBox(height: AppSpacing.lg),
                      
                      // Date/Time
                      InkWell(
                        onTap: _isEditing ? _pickDateTime : null,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          child: Row(
                            children: [
                              Icon(LucideIcons.calendar, size: 20, color: AppColors.primary),
                              const SizedBox(width: AppSpacing.md),
                              Text(
                                DateFormat('EEEE, MMM d, yyyy').add_jm().format(_isEditing ? _editedDateTime! : _reminder!.dateTime),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: AppSpacing.lg),

                      // Description
                      if (_isEditing)
                        TextField(
                          controller: _descriptionController,
                          style: Theme.of(context).textTheme.bodyMedium,
                          decoration: const InputDecoration(
                            hintText: 'Description (optional)',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                          maxLines: null,
                        )
                      else if (_reminder!.description.isNotEmpty)
                        Text(
                          _reminder!.description,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        
                      const SizedBox(height: AppSpacing.xl),
                      const Divider(),
                      const SizedBox(height: AppSpacing.lg),
                      
                      // Links
                      Text('Linked Context', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.md),
                      
                      if (_contact != null)
                        _LinkRow(
                          icon: LucideIcons.user,
                          label: _contact!.name,
                          onTap: () {
                            if (!_isEditing) {
                              Navigator.pushNamed(context, AppRoutes.contactDetail, arguments: _contact!.id);
                            }
                          },
                        ),
                        
                      if (_note != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _LinkRow(
                          icon: LucideIcons.fileText,
                          label: 'Linked Note',
                          onTap: () {
                            if (!_isEditing) {
                              Navigator.pushNamed(context, AppRoutes.noteDetail, arguments: _note!.id);
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              // Bottom Action
              if (!_isEditing)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: ElevatedButton(
                    onPressed: _toggleComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _reminder!.completed ? AppColors.surfaceElevated : AppColors.primary,
                      foregroundColor: _reminder!.completed ? AppColors.textPrimary : Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_reminder!.completed ? LucideIcons.rotateCcw : LucideIcons.check),
                        const SizedBox(width: AppSpacing.sm),
                        Text(_reminder!.completed ? 'Reopen Reminder' : 'Mark Complete'),
                      ],
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

class _Pill extends StatelessWidget {
  final Color color;
  final String label;
  
  const _Pill({required this.color, required this.label});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  
  const _LinkRow({required this.icon, required this.label, required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
