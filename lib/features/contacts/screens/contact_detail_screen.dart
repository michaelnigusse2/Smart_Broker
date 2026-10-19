import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../core/widgets/todo_tile.dart';
import '../../../core/widgets/reminder_card.dart';
import '../../../core/widgets/info_chip.dart';
import '../../../core/widgets/text_prompt.dart';
import '../../../core/repositories/contact_repository.dart';
import '../../../core/repositories/note_repository.dart';
import '../../../core/repositories/todo_repository.dart';
import '../../../core/repositories/reminder_repository.dart';
import '../../../core/repositories/call_repository.dart';
import '../../../core/services/call_matching_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/overlay_draft_service.dart';
import '../../../core/utils/reminder_time.dart';
import '../../../models/contact.dart';
import '../../../models/note.dart';
import '../../../models/todo_item.dart';
import '../../../models/reminder.dart';
import '../../../models/call_entry.dart';

class ContactDetailScreen extends StatefulWidget {
  const ContactDetailScreen({super.key});

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  final ContactRepository _contactRepo = ContactRepository();
  final NoteRepository _noteRepo = NoteRepository();
  final TodoRepository _todoRepo = TodoRepository();
  final ReminderRepository _reminderRepo = ReminderRepository();
  final CallRepository _callRepo = CallRepository();

  String? _contactId;
  Contact? _contact;
  List<Note> _notes = [];
  List<TodoItem> _todos = [];
  List<Reminder> _reminders = [];
  List<CallEntry> _calls = [];
  bool _isLoading = true;
  String? _error;

  bool _initialized = false;
  StreamSubscription<CallEntry>? _callLogSubscription;

  @override
  void initState() {
    super.initState();
    _callLogSubscription = CallMatchingService().onCallLogged.listen((call) {
      if (call.contactId == _contactId) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _callLogSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        _contactId = args;
        _initialized = true;
        _loadData();
      } else {
        setState(() {
          _error = 'No contact ID provided.';
          _isLoading = false;
        });
        _initialized = true;
      }
    }
  }

  Future<void> _loadData() async {
    if (_contactId == null) return;
    try {
      final contact = await _contactRepo.getById(_contactId!);
      if (contact == null) {
        throw Exception('Contact not found');
      }
      final notes = await _noteRepo.getByContactId(_contactId!);
      final todos = await _todoRepo.getByContactId(_contactId!);
      final reminders = await _reminderRepo.getByContactId(_contactId!);
      final calls = await _callRepo.getByContactId(_contactId!);

      if (mounted) {
        setState(() {
          _contact = contact;
          _notes = notes;
          _todos = todos;
          _reminders = reminders;
          _calls = calls;
          _isLoading = false;
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

  Future<void> _editContact() async {
    await Navigator.pushNamed(context, AppRoutes.contactForm, arguments: _contact);
    if (mounted) _loadData();
  }

  /// Deletes the contact with everything linked to it, after a confirmation
  /// that says what will be lost.
  Future<void> _deleteContact() async {
    final contact = _contact;
    if (contact == null) return;
    String count(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${contact.name}?'),
        content: Text(
          'This also deletes ${count(_notes.length, 'note')}, ${count(_todos.length, 'task')}, '
          '${count(_reminders.length, 'reminder')} and ${count(_calls.length, 'logged call')}. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      // Reminders are deleted with the contact, so their alarms must go too.
      for (final reminder in _reminders) {
        await NotificationService().cancelReminder(reminder.id);
      }
      await _contactRepo.delete(contact.id);
      await OverlayDraftService().clearDraft(contact.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${contact.name} deleted')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _contact == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(_error ?? 'Unknown error')),
      );
    }

    final contact = _contact!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Details'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.moreHorizontal),
            tooltip: 'More',
            onSelected: (value) => value == 'edit' ? _editContact() : _deleteContact(),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit contact')),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete contact', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: ConstrainedLayout(
        child: Column(
          children: [
            // Minimal Header (Pinned to top)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.surfaceElevated,
                    foregroundColor: AppColors.textPrimary,
                    radius: 36,
                    child: Text(
                      contact.initials,
                      style: theme.textTheme.headlineMedium?.copyWith(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.name,
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Icon(LucideIcons.phone, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: AppSpacing.xs),
                            Flexible(
                              child: Text(
                                contact.phoneNumber.trim(),
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Last seen ${_formatDate(contact.lastInteraction)}',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Collapsible Sections
                    _CollapsibleSection(
                      title: 'Notes',
                      icon: LucideIcons.fileText,
                      isExpanded: true,
                      child: _NotesList(
                        notes: _notes,
                        onTap: (noteId) {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.noteDetail,
                            arguments: noteId,
                          ).then((_) => _loadData());
                        },
                        onDelete: (noteId) async {
                          await _noteRepo.delete(noteId);
                          _loadData();
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    _CollapsibleSection(
                      title: 'Tasks',
                      icon: LucideIcons.checkSquare,
                      isExpanded: true,
                      child: _TodosList(
                        contactId: contact.id,
                        todos: _todos,
                        onToggle: (id) async {
                          await _todoRepo.toggleCompleted(id);
                          _loadData();
                        },
                        onEdit: (todo, newTitle) async {
                          await _todoRepo.update(todo.copyWith(title: newTitle));
                          _loadData();
                        },
                        onDelete: (todo) async {
                          await _todoRepo.delete(todo.id);
                          _loadData();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Task deleted'),
                              duration: const Duration(seconds: 5),
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: () async {
                                  await _todoRepo.insert(todo);
                                  _loadData();
                                },
                              ),
                            ),
                          );
                        },
                        onAdd: (title) async {
                          final todo = TodoItem(
                            id: '',
                            contactId: contact.id,
                            title: title,
                            isCompleted: false,
                            createdAt: DateTime.now(),
                          );
                          await _todoRepo.insert(todo);
                          _loadData();
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    _CollapsibleSection(
                      title: 'Call History',
                      icon: LucideIcons.phoneCall,
                      isExpanded: false,
                      child: _CallsList(calls: _calls),
                    ),
                    const Divider(height: 1),
                    _CollapsibleSection(
                      title: 'Reminders',
                      icon: LucideIcons.bell,
                      isExpanded: false,
                      child: _RemindersList(reminders: _reminders, onChanged: _loadData),
                    ),
                    const SizedBox(height: AppSpacing.xxxl * 2), // FAB spacing
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(
            context,
            AppRoutes.addNote,
            arguments: contact.id,
          ).then((_) => _loadData());
        },
        backgroundColor: AppColors.textPrimary,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(LucideIcons.plus),
        label: const Text('Add Note', style: TextStyle(fontWeight: FontWeight.w500)),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (isSameCalendarDay(date, now)) return 'Today at ${DateFormat.jm().format(date)}';
    if (difference.inDays < 7) return DateFormat.EEEE().format(date);
    return DateFormat.yMMMd().format(date);
  }
}

class _CollapsibleSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final bool isExpanded;

  const _CollapsibleSection({
    required this.title,
    required this.icon,
    required this.child,
    this.isExpanded = false,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _expanded = !_expanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
            child: Row(
              children: [
                Icon(widget.icon, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Icon(
                  _expanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: widget.child,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _NotesList extends StatelessWidget {
  final List<Note> notes;
  final Function(String) onTap;
  final Function(String) onDelete;

  const _NotesList({
    required this.notes,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (notes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Text('No notes yet.', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return InkWell(
          onTap: () => onTap(note.id),
          onLongPress: () {
            showModalBottomSheet(
              context: context,
              builder: (context) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(LucideIcons.fileText),
                      title: const Text('View Details'),
                      onTap: () {
                        Navigator.pop(context);
                        onTap(note.id);
                      },
                    ),
                    ListTile(
                      leading: const Icon(LucideIcons.trash2, color: AppColors.error),
                      title: const Text('Delete Note', style: TextStyle(color: AppColors.error)),
                      onTap: () {
                        Navigator.pop(context);
                        _confirmDelete(context, note.id);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xxl,
              right: AppSpacing.lg,
              bottom: AppSpacing.xl,
              top: AppSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline line visual indicator
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 2,
                  height: 16,
                  color: AppColors.divider,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date drops under the chip when both don't fit on one line.
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          note.aiSummary.isEmpty
                              ? const InfoChip(label: 'Not processed', color: AppColors.textSecondary)
                              : const InfoChip(label: 'AI Summary', color: AppColors.primary),
                          Text(
                            DateFormat.yMMMd().format(note.createdAt),
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (note.aiSummary.isEmpty)
                        // Saved without AI: show the note itself.
                        Text(
                          note.rawText,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        )
                      else ...[
                        Text(
                          note.aiSummary,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '"${note.rawText}"',
                          style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textTertiary),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, String noteId) async {
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

    if (confirmed == true) {
      onDelete(noteId);
    }
  }
}

class _TodosList extends StatefulWidget {
  final String contactId;
  final List<TodoItem> todos;
  final Function(String) onToggle;
  final Function(TodoItem, String) onEdit;
  final Function(TodoItem) onDelete;
  final Function(String) onAdd;

  const _TodosList({
    required this.contactId,
    required this.todos,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });

  @override
  State<_TodosList> createState() => _TodosListState();
}

class _TodosListState extends State<_TodosList> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.todos.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                'No tasks.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
            )
          else
            ...widget.todos.map(
              (todo) => Dismissible(
                key: Key(todo.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  color: AppColors.error,
                  child: const Icon(LucideIcons.trash2, color: Colors.white),
                ),
                onDismissed: (_) => widget.onDelete(todo),
                child: TodoTile(
                  todo: todo,
                  onChanged: (val) => widget.onToggle(todo.id),
                  onEdit: (newTitle) => widget.onEdit(todo, newTitle),
                  onDelete: () => widget.onDelete(todo),
                ),
              ),
            ),

          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _showAddTaskSheet(context),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add Task'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTaskSheet(BuildContext context) async {
    final title = await showTextPromptSheet(
      context,
      title: 'New Task',
      hint: 'What needs to be done?',
      confirmLabel: 'Save Task',
    );
    if (title != null && mounted) widget.onAdd(title);
  }
}

class _CallsList extends StatelessWidget {
  final List<CallEntry> calls;

  const _CallsList({required this.calls});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (calls.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Text('No call history.', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: calls.map((call) {
          IconData callIcon;
          Color callColor;
          switch (call.type) {
            case CallType.incoming:
              callIcon = LucideIcons.phoneIncoming;
              callColor = AppColors.textSecondary;
              break;
            case CallType.outgoing:
              callIcon = LucideIcons.phoneOutgoing;
              callColor = AppColors.textPrimary;
              break;
            case CallType.missed:
              callIcon = LucideIcons.phoneMissed;
              callColor = AppColors.error;
              break;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: [
                Icon(callIcon, color: callColor, size: 16),
                const SizedBox(width: AppSpacing.md),
                // Type above date, so neither has to squeeze into one line.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        call.type.name.capitalize(),
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                      ),
                      Text(
                        DateFormat.yMMMd().add_jm().format(call.timestamp),
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  call.duration.inMinutes > 0 ? '${call.duration.inMinutes}m' : '${call.duration.inSeconds}s',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RemindersList extends StatelessWidget {
  final List<Reminder> reminders;
  final VoidCallback onChanged;

  const _RemindersList({required this.reminders, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Text(
          'No reminders.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: reminders
            .map(
              (r) => ReminderCard(
                reminder: r,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.reminderDetail, arguments: r.id).then((_) => onChanged()),
              ),
            )
            .toList(),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
