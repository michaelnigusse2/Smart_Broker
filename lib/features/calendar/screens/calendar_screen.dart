import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../core/repositories/reminder_repository.dart';
import '../../../core/repositories/contact_repository.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/reminder_time.dart';
import '../../../core/widgets/past_reminder_dialog.dart';
import '../../../models/reminder.dart';
import '../../../models/contact.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final ReminderRepository _reminderRepo = ReminderRepository();
  final ContactRepository _contactRepo = ContactRepository();

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<Reminder> _allReminders = [];
  List<Contact> _contacts = [];
  bool _isLoading = true;
  String? _error;

  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _hideCompleted = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final reminders = await _reminderRepo.getAll();
      final contacts = await _contactRepo.getAll();
      if (mounted) {
        setState(() {
          _allReminders = reminders;
          _contacts = contacts;
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

  List<Reminder> _getEventsForDay(DateTime day) {
    return _allReminders.where((r) {
      if (_hideCompleted && r.completed) return false;
      return isSameDay(r.dateTime, day);
    }).toList();
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

    final theme = Theme.of(context);
    final selectedReminders = _getEventsForDay(_selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddReminderSheet(context),
          backgroundColor: AppColors.textPrimary,
          foregroundColor: Colors.white,
          elevation: 2,
          icon: const Icon(LucideIcons.plus),
          label: const Text('Add Reminder', style: TextStyle(fontWeight: FontWeight.w500)),
        ),
      ),
      body: ConstrainedLayout(
        child: Column(
          children: [
            // ─── Controls ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SegmentedButton<CalendarFormat>(
                    segments: const [
                      ButtonSegment(value: CalendarFormat.month, label: Text('Month')),
                      ButtonSegment(value: CalendarFormat.week, label: Text('Week')),
                    ],
                    selected: {_calendarFormat},
                    onSelectionChanged: (set) {
                      setState(() {
                        _calendarFormat = set.first;
                      });
                    },
                    style: SegmentedButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      selectedBackgroundColor: AppColors.surfaceElevated,
                      foregroundColor: AppColors.textSecondary,
                      selectedForegroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  FilterChip(
                    label: const Text('Hide Completed'),
                    selected: _hideCompleted,
                    onSelected: (val) {
                      setState(() => _hideCompleted = val);
                    },
                  ),
                ],
              ),
            ),

            // ─── Calendar ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: TableCalendar<Reminder>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Month',
                  CalendarFormat.week: 'Week',
                },
                onFormatChanged: (format) {
                  if (_calendarFormat != format) {
                    setState(() => _calendarFormat = format);
                  }
                },
                rowHeight: _calendarFormat == CalendarFormat.week ? 80 : 52,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: _getEventsForDay,
                startingDayOfWeek: StartingDayOfWeek.monday,

                calendarStyle: const CalendarStyle(
                  // Disable all built-in markers — we handle them in calendarBuilders
                  markersMaxCount: 0,
                  isTodayHighlighted: false,
                ),

                // ── Custom cell builders for full control ────────────
                calendarBuilders: CalendarBuilders(
                  // Suppress default markers entirely
                  markerBuilder: (context, day, events) => const SizedBox.shrink(),

                  defaultBuilder: (context, day, focusedDay) {
                    return _DayCell(
                      day: day,
                      events: _getEventsForDay(day),
                      isToday: false,
                      isSelected: false,
                      isOutside: false,
                      isWeekView: _calendarFormat == CalendarFormat.week,
                    );
                  },

                  todayBuilder: (context, day, focusedDay) {
                    return _DayCell(
                      day: day,
                      events: _getEventsForDay(day),
                      isToday: true,
                      isSelected: isSameDay(day, _selectedDay),
                      isOutside: false,
                      isWeekView: _calendarFormat == CalendarFormat.week,
                    );
                  },

                  selectedBuilder: (context, day, focusedDay) {
                    return _DayCell(
                      day: day,
                      events: _getEventsForDay(day),
                      isToday: isSameDay(day, DateTime.now()),
                      isSelected: true,
                      isOutside: false,
                      isWeekView: _calendarFormat == CalendarFormat.week,
                    );
                  },

                  outsideBuilder: (context, day, focusedDay) {
                    return _DayCell(
                      day: day,
                      events: _getEventsForDay(day),
                      isToday: false,
                      isSelected: false,
                      isOutside: true,
                      isWeekView: _calendarFormat == CalendarFormat.week,
                    );
                  },

                  disabledBuilder: (context, day, focusedDay) {
                    return _DayCell(
                      day: day,
                      events: const [],
                      isToday: false,
                      isSelected: false,
                      isOutside: true,
                      isWeekView: _calendarFormat == CalendarFormat.week,
                    );
                  },
                ),

                // ── Header ──────────────────────────────────────────
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: theme.textTheme.titleMedium!,
                  leftChevronIcon: const Icon(
                    LucideIcons.chevronLeft,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  rightChevronIcon: const Icon(
                    LucideIcons.chevronRight,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  headerPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                ),

                // ── Weekday row ──────────────────────────────────────
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: theme.textTheme.labelMedium!,
                  weekendStyle: theme.textTheme.labelMedium!.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),

                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
              ),
            ),

            Container(height: 1, color: AppColors.divider),

            // ─── Events for selected day ───────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md),
                      child: Row(
                        children: [
                          Text(
                            DateFormat.MMMMEEEEd().format(_selectedDay),
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          if (selectedReminders.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${selectedReminders.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: selectedReminders.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    LucideIcons.calendarCheck,
                                    size: 28,
                                    color: AppColors.textTertiary,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    'No events today',
                                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 100),
                              itemCount: selectedReminders.length,
                              itemBuilder: (context, index) {
                                return _EventRow(
                                  reminder: selectedReminders[index],
                                  onReload: _loadData,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddReminderSheet(BuildContext context) {
    if (_contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a contact first.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) {
        return _AddReminderSheet(
          contacts: _contacts,
          initialDate: _selectedDay,
          onSave: (reminder) async {
            final id = await _reminderRepo.insert(reminder);
            // Schedule a notification for the new reminder
            final saved = await _reminderRepo.getById(id);
            final scheduled = saved != null && await NotificationService().scheduleReminder(saved);
            if (!scheduled) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Reminder saved — no notification (the time has passed)'),
                ),
              );
            }
            _loadData();
          },
        );
      },
    );
  }
}

class _AddReminderSheet extends StatefulWidget {
  final List<Contact> contacts;
  final DateTime initialDate;
  final Function(Reminder) onSave;

  const _AddReminderSheet({
    required this.contacts,
    required this.initialDate,
    required this.onSave,
  });

  @override
  State<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<_AddReminderSheet> {
  final _titleController = TextEditingController();
  late DateTime _selectedDate;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  String? _selectedContactId;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    // For today, default to the next full hour so the reminder can still fire.
    if (isSameCalendarDay(widget.initialDate, DateTime.now())) {
      final suggested = nextFullHour();
      _selectedDate = DateTime(suggested.year, suggested.month, suggested.day);
      _selectedTime = TimeOfDay.fromDateTime(suggested);
    }
    if (widget.contacts.isNotEmpty) {
      _selectedContactId = widget.contacts.first.id;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty || _selectedContactId == null) return;

    final finalDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    if (!isSchedulable(finalDateTime) && !await confirmPastReminder(context)) return;
    if (!mounted) return;

    widget.onSave(
      Reminder(
        id: '',
        contactId: _selectedContactId!,
        title: _titleController.text.trim(),
        dateTime: finalDateTime,
        createdAt: DateTime.now(),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add Reminder', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xl),

            TextField(
              controller: _titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null && mounted) setState(() => _selectedDate = date);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()),
                      child: Text(DateFormat.yMMMd().format(_selectedDate)),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime,
                      );
                      if (time != null && mounted) setState(() => _selectedTime = time);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Time', border: OutlineInputBorder()),
                      child: Text(_selectedTime.format(context)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Contact',
                border: OutlineInputBorder(),
              ),
              initialValue: _selectedContactId,
              items: widget.contacts
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedContactId = val);
              },
            ),
            const SizedBox(height: AppSpacing.xl),

            ElevatedButton(
              onPressed: _save,
              child: const Text('Save Reminder'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

// ─── Custom Day Cell ─────────────────────────────────────────────────────────
class _DayCell extends StatelessWidget {
  final DateTime day;
  final List<Reminder> events;
  final bool isToday;
  final bool isSelected;
  final bool isOutside;
  final bool isWeekView;

  const _DayCell({
    required this.day,
    required this.events,
    required this.isToday,
    required this.isSelected,
    required this.isOutside,
    required this.isWeekView,
  });

  @override
  Widget build(BuildContext context) {
    final hasEvents = events.isNotEmpty;

    Color textColor;
    if (isOutside) {
      textColor = AppColors.textTertiary;
    } else if (isSelected) {
      textColor = Colors.white;
    } else if (isToday) {
      textColor = AppColors.primary;
    } else {
      textColor = AppColors.textPrimary;
    }

    BoxDecoration? circleDecoration;
    if (isSelected) {
      circleDecoration = const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      );
    } else if (isToday) {
      circleDecoration = BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      );
    }

    return Container(
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Number in circle
          Container(
            width: 28,
            height: 28,
            decoration: circleDecoration,
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.normal,
                color: textColor,
              ),
            ),
          ),

          if (hasEvents && !isOutside && !isWeekView) ...[
            const SizedBox(height: 2),
            SizedBox(
              height: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  events.length.clamp(0, 3),
                  (i) => Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: events[i].completed
                          ? Colors.green
                          : (events[i].dateTime.isBefore(DateTime.now()) ? AppColors.error : AppColors.primary),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],

          if (hasEvents && !isOutside && isWeekView) ...[
            const SizedBox(height: 2),
            ...events
                .take(2)
                .map(
                  (e) => Container(
                    margin: const EdgeInsets.only(bottom: 2, left: 2, right: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: e.completed ? AppColors.surfaceElevated : AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        color: e.completed
                            ? AppColors.textTertiary
                            : (e.dateTime.isBefore(DateTime.now()) ? AppColors.error : AppColors.primary),
                        decoration: e.completed ? TextDecoration.lineThrough : null,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            if (events.length > 2)
              Text(
                '+${events.length - 2}',
                style: const TextStyle(fontSize: 9, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
          ],
        ],
      ),
    );
  }
}

// ─── Event Row ───────────────────────────────────────────────────────────────
class _EventRow extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback onReload;

  const _EventRow({required this.reminder, required this.onReload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, AppRoutes.reminderDetail, arguments: reminder.id).then((_) => onReload());
      },
      onLongPress: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Reminder Actions'),
            content: Text(reminder.title),
            actions: [
              TextButton(
                onPressed: () async {
                  final toggled = reminder.copyWith(completed: !reminder.completed);
                  await ReminderRepository().update(toggled);
                  // Cancel notification if completing, reschedule if reopening
                  if (toggled.completed) {
                    await NotificationService().cancelReminder(toggled.id);
                  } else {
                    await NotificationService().scheduleReminder(toggled);
                  }
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  onReload();
                },
                child: Text(reminder.completed ? 'Reopen' : 'Mark Complete'),
              ),
              TextButton(
                onPressed: () async {
                  await ReminderRepository().delete(reminder.id);
                  await NotificationService().cancelReminder(reminder.id);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  onReload();
                },
                child: const Text('Delete', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        );
      },
      borderRadius: AppRadius.card,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time
            SizedBox(
              width: 56,
              child: Text(
                DateFormat.jm().format(reminder.dateTime),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: reminder.completed ? AppColors.textTertiary : AppColors.textSecondary,
                  height: 1.4,
                  decoration: reminder.completed ? TextDecoration.lineThrough : null,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Dot aligned to first line of text
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: reminder.completed
                      ? Colors.green
                      : (reminder.dateTime.isBefore(DateTime.now()) ? AppColors.error : AppColors.primary),
                  shape: BoxShape.circle,
                ),
                child: reminder.completed ? const Icon(LucideIcons.check, size: 6, color: Colors.white) : null,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Title
            Expanded(
              child: Text(
                reminder.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: reminder.completed ? AppColors.textTertiary : AppColors.textPrimary,
                  decoration: reminder.completed ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
