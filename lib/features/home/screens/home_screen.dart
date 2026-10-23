import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/todo_tile.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/repositories/contact_repository.dart';
import '../../../core/repositories/note_repository.dart';
import '../../../core/repositories/todo_repository.dart';
import '../../../core/repositories/reminder_repository.dart';
import '../../../models/contact.dart';
import '../../../models/todo_item.dart';
import '../../../models/reminder.dart';
import 'main_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ContactRepository _contactRepo = ContactRepository();
  final TodoRepository _todoRepo = TodoRepository();
  final ReminderRepository _reminderRepo = ReminderRepository();

  List<Contact> _contacts = [];
  List<TodoItem> _pendingTodos = [];
  List<Reminder> _upcomingReminders = [];
  int _noteCount = 0;
  int _unprocessedNoteCount = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final contacts = await _contactRepo.getAll();
      final todos = await _todoRepo.getPending();
      // Include overdue reminders so they don't silently disappear.
      final reminders = await _reminderRepo.getOpen();
      final noteCounts = await NoteRepository().counts();

      if (mounted) {
        setState(() {
          _contacts = contacts;
          _pendingTodos = todos;
          _upcomingReminders = reminders;
          _noteCount = noteCounts.total;
          _unprocessedNoteCount = noteCounts.unprocessed;
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

  void _openNotes() => Navigator.pushNamed(context, AppRoutes.notesList).then((_) => _loadData());

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(child: Text('Error: $_error')),
      );
    }

    final recentContacts = List.of(_contacts)..sort((a, b) => b.lastInteraction.compareTo(a.lastInteraction));
    final displayTodos = _pendingTodos.take(3).toList();
    final displayReminders = _upcomingReminders.take(2).toList();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ConstrainedLayout(
          child: CustomScrollView(
            slivers: [
              // ─── Header ───────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xxl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: context.sb.text2,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Michael',
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Stat pills row
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _StatPill(
                            label: '${_contacts.length} Contacts',
                            icon: LucideIcons.users,
                          ),
                          _StatPill(
                            label: '${_pendingTodos.length} Tasks',
                            icon: LucideIcons.checkSquare,
                          ),
                          _StatPill(
                            label: '${_upcomingReminders.length} Reminders',
                            icon: LucideIcons.bell,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Body ─────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: 'Upcoming Reminders',
                        actionLabel: 'See all',
                        onActionTap: () => MainShell.selectTab(context, MainShell.calendarTab),
                      ),
                      ...displayReminders.map(
                        (r) => _ReminderRow(
                          id: r.id,
                          title: r.title,
                          dateTime: r.dateTime,
                          onReload: _loadData,
                        ),
                      ),

                      SectionHeader(
                        title: 'Recent Contacts',
                        actionLabel: 'See all',
                        onActionTap: () => MainShell.selectTab(context, MainShell.contactsTab),
                      ),
                      ...recentContacts.take(3).map(
                        (contact) {
                          final hasOverdue = _pendingTodos.any(
                            (t) =>
                                t.contactId == contact.id &&
                                t.createdAt.isBefore(DateTime.now().subtract(const Duration(days: 7))),
                          );
                          return _ContactRow(
                            name: contact.name,
                            phone: contact.phoneNumber,
                            lastSeen: contact.lastInteraction,
                            hasTasks: contact.pendingTasksCount > 0,
                            hasOverdueTasks: hasOverdue,
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.contactDetail,
                              arguments: contact.id, // Pass ID
                            ).then((_) => _loadData()), // Reload when popping back
                          );
                        },
                      ),

                      SectionHeader(
                        title: 'Pending Tasks',
                        actionLabel: 'See all',
                        onActionTap: () => Navigator.pushNamed(context, AppRoutes.tasks).then((_) => _loadData()),
                      ),
                      ...displayTodos.map(
                        (todo) => TodoTile(
                          todo: todo,
                          showChevron: true,
                          // The row opens the contact; only the checkbox completes the task.
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.contactDetail,
                            arguments: todo.contactId,
                          ).then((_) => _loadData()),
                          onChanged: (val) async {
                            await _todoRepo.toggleCompleted(todo.id);
                            _loadData(); // Refresh UI
                          },
                        ),
                      ),

                      SectionHeader(
                        title: 'Notes',
                        actionLabel: 'See all',
                        onActionTap: _openNotes,
                      ),
                      _NotesSummary(
                        total: _noteCount,
                        unprocessed: _unprocessedNoteCount,
                        onTap: _openNotes,
                      ),

                      // Space for floating nav bar
                      const SizedBox(height: 100),
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

// ─── Notes summary ───────────────────────────────────────────────────────────
class _NotesSummary extends StatelessWidget {
  final int total;
  final int unprocessed;
  final VoidCallback onTap;

  const _NotesSummary({required this.total, required this.unprocessed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = total == 0
        ? 'No notes yet'
        : unprocessed == 0
        ? '$total ${total == 1 ? 'note' : 'notes'}'
        : '$total ${total == 1 ? 'note' : 'notes'} · $unprocessed waiting for AI Review';
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.card,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.sb.surface,
          borderRadius: AppRadius.card,
          border: Border.all(color: context.sb.track),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.fileText, color: unprocessed > 0 ? context.sb.primary : context.sb.text2),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(subtitle, style: theme.textTheme.bodyMedium)),
            Icon(LucideIcons.chevronRight, size: 18, color: context.sb.text3),
          ],
        ),
      ),
    );
  }
}

// ─── Stat Pill ───────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final String label;
  final IconData icon;

  const _StatPill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: context.sb.fill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: context.sb.text2),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.sb.text2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reminder Row ─────────────────────────────────────────────────────────────
class _ReminderRow extends StatelessWidget {
  final String id;
  final String title;
  final DateTime dateTime;
  final VoidCallback onReload;

  const _ReminderRow({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = dateTime.isBefore(DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.reminderDetail, arguments: id).then((_) => onReload());
        },
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 36,
                decoration: BoxDecoration(
                  color: isOverdue ? context.sb.late : context.sb.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat.MMMd().add_jm().format(dateTime),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: context.sb.text2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(LucideIcons.chevronRight, size: 16, color: context.sb.text3),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Contact Row ──────────────────────────────────────────────────────────────
class _ContactRow extends StatelessWidget {
  final String name;
  final String phone;
  final DateTime lastSeen;
  final bool hasTasks;
  final bool hasOverdueTasks;
  final VoidCallback onTap;

  const _ContactRow({
    required this.name,
    required this.phone,
    required this.lastSeen,
    required this.hasTasks,
    this.hasOverdueTasks = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            // Initials avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: context.sb.fill,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.sb.text,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 1),
                  Text(phone, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateFormat.MMMd().format(lastSeen),
                  style: theme.textTheme.labelSmall,
                ),
                if (hasTasks) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: hasOverdueTasks ? Colors.orange : context.sb.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
