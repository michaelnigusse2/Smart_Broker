import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../core/widgets/todo_tile.dart';
import '../../../core/widgets/reminder_card.dart';
import '../../../core/widgets/info_chip.dart';
import '../../../mock/mock_contacts.dart';
import '../../../mock/mock_notes.dart';
import '../../../mock/mock_todos.dart';
import '../../../mock/mock_reminders.dart';
import '../../../mock/mock_calls.dart';
import '../../../models/call_entry.dart';

class ContactDetailScreen extends StatelessWidget {
  const ContactDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // For mock purposes, pick the first contact
    final contact = mockContacts.first;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Details'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.moreHorizontal),
            onPressed: () {},
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
                            Text(
                              contact.phoneNumber,
                              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
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
                child: _NotesList(contactId: contact.id),
              ),
              const Divider(height: 1),
              _CollapsibleSection(
                title: 'Tasks',
                icon: LucideIcons.checkSquare,
                isExpanded: true,
                child: _TodosList(contactId: contact.id),
              ),
              const Divider(height: 1),
              _CollapsibleSection(
                title: 'Call History',
                icon: LucideIcons.phoneCall,
                isExpanded: false,
                child: _CallsList(contactId: contact.id),
              ),
              const Divider(height: 1),
              _CollapsibleSection(
                title: 'Reminders',
                icon: LucideIcons.bell,
                isExpanded: false,
                child: _RemindersList(contactId: contact.id),
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
          Navigator.pushNamed(context, AppRoutes.addNote);
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
    if (difference.inDays == 0) return 'Today at ${DateFormat.jm().format(date)}';
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
  final String contactId;

  const _NotesList({required this.contactId});

  @override
  Widget build(BuildContext context) {
    final notes = mockNotes.where((n) => n.contactId == contactId).toList();
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
        return Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xxl, right: AppSpacing.lg, bottom: AppSpacing.xl),
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
                    Row(
                      children: [
                        const InfoChip(label: 'AI Summary', color: AppColors.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          DateFormat.yMMMd().format(note.createdAt),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TodosList extends StatelessWidget {
  final String contactId;

  const _TodosList({required this.contactId});

  @override
  Widget build(BuildContext context) {
    final todos = mockTodos.where((t) => t.contactId == contactId).toList();

    if (todos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Text('No tasks.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: todos.map((todo) => TodoTile(
          todo: todo,
          onChanged: (val) {},
        )).toList(),
      ),
    );
  }
}

class _CallsList extends StatelessWidget {
  final String contactId;

  const _CallsList({required this.contactId});

  @override
  Widget build(BuildContext context) {
    final calls = mockCalls.where((c) => c.contactId == contactId).toList();
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
                Expanded(
                  child: Text(
                    call.type.name.capitalize(),
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                  ),
                ),
                Text(
                  DateFormat.yMMMd().add_jm().format(call.timestamp),
                  style: theme.textTheme.labelSmall,
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 50,
                  child: Text(
                    call.duration.inSeconds > 0 
                      ? '${call.duration.inMinutes}m'
                      : '0s',
                    style: theme.textTheme.labelMedium,
                    textAlign: TextAlign.end,
                  ),
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
  final String contactId;

  const _RemindersList({required this.contactId});

  @override
  Widget build(BuildContext context) {
    final reminders = mockReminders.where((r) => r.contactId == contactId).toList();

    if (reminders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Text('No reminders.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: reminders.map((r) => ReminderCard(reminder: r)).toList(),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
