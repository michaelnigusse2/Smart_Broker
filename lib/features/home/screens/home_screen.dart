import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/todo_tile.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/repositories/contact_repository.dart';
import '../../../core/repositories/todo_repository.dart';
import '../../../core/repositories/reminder_repository.dart';
import '../../../models/contact.dart';
import '../../../models/todo_item.dart';
import '../../../models/reminder.dart';

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
      final reminders = await _reminderRepo.getUpcoming();

      if (mounted) {
        setState(() {
          _contacts = contacts;
          _pendingTodos = todos;
          _upcomingReminders = reminders;
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

    final recentContacts = List.of(_contacts)
      ..sort((a, b) => b.lastInteraction.compareTo(a.lastInteraction));
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
                          color: AppColors.textSecondary,
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
                      Row(
                        children: [
                          _StatPill(
                            label: '${_contacts.length} Contacts',
                            icon: LucideIcons.users,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _StatPill(
                            label: '${_pendingTodos.length} Tasks',
                            icon: LucideIcons.checkSquare,
                          ),
                          const SizedBox(width: AppSpacing.sm),
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
                      const SectionHeader(
                        title: 'Upcoming Reminders',
                        actionLabel: 'See all',
                      ),
                      ...displayReminders.map(
                        (r) => _ReminderRow(
                          title: r.title,
                          dateTime: r.dateTime,
                        ),
                      ),

                      const SectionHeader(
                        title: 'Recent Contacts',
                        actionLabel: 'See all',
                      ),
                      ...recentContacts.take(3).map(
                            (contact) => _ContactRow(
                              name: contact.name,
                              phone: contact.phoneNumber,
                              lastSeen: contact.lastInteraction,
                              hasTasks: contact.pendingTasksCount > 0,
                              onTap: () => Navigator.pushNamed(
                                context,
                                AppRoutes.contactDetail,
                                arguments: contact.id, // Pass ID
                              ).then((_) => _loadData()), // Reload when popping back
                            ),
                          ),

                      const SectionHeader(
                        title: 'Pending Tasks',
                        actionLabel: 'See all',
                      ),
                      ...displayTodos.map(
                        (todo) => TodoTile(
                          todo: todo, 
                          onChanged: (val) async {
                            await _todoRepo.toggleCompleted(todo.id);
                            _loadData(); // Refresh UI
                          },
                        ),
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
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
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
  final String title;
  final DateTime dateTime;

  const _ReminderRow({required this.title, required this.dateTime});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = dateTime.isBefore(DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: isOverdue ? AppColors.error : AppColors.primary,
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
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            LucideIcons.chevronRight,
            size: 16,
            color: AppColors.textTertiary,
          ),
        ],
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
  final VoidCallback onTap;

  const _ContactRow({
    required this.name,
    required this.phone,
    required this.lastSeen,
    required this.hasTasks,
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
              backgroundColor: AppColors.surfaceElevated,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
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
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
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
