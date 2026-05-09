import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../models/reminder.dart';
import '../../../mock/mock_reminders.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  List<Reminder> _getEventsForDay(DateTime day) {
    return mockReminders.where((r) {
      return isSameDay(r.dateTime, day);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedReminders = _getEventsForDay(_selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
      ),
      body: ConstrainedLayout(
        child: Column(
          children: [
            // ─── Calendar ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: TableCalendar<Reminder>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
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
                  markerBuilder: (context, day, events) =>
                      const SizedBox.shrink(),

                  defaultBuilder: (context, day, focusedDay) {
                    final events = _getEventsForDay(day);
                    return _DayCell(
                      day: day,
                      events: events,
                      isToday: false,
                      isSelected: false,
                      isOutside: false,
                    );
                  },

                  todayBuilder: (context, day, focusedDay) {
                    final events = _getEventsForDay(day);
                    return _DayCell(
                      day: day,
                      events: events,
                      isToday: true,
                      isSelected: isSameDay(day, _selectedDay),
                      isOutside: false,
                    );
                  },

                  selectedBuilder: (context, day, focusedDay) {
                    final events = _getEventsForDay(day);
                    return _DayCell(
                      day: day,
                      events: events,
                      isToday: isSameDay(day, DateTime.now()),
                      isSelected: true,
                      isOutside: false,
                    );
                  },

                  outsideBuilder: (context, day, focusedDay) {
                    final events = _getEventsForDay(day);
                    return _DayCell(
                      day: day,
                      events: events,
                      isToday: false,
                      isSelected: false,
                      isOutside: true,
                    );
                  },

                  disabledBuilder: (context, day, focusedDay) {
                    return _DayCell(
                      day: day,
                      events: const [],
                      isToday: false,
                      isSelected: false,
                      isOutside: true,
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
                      padding: const EdgeInsets.only(
                          top: AppSpacing.xl, bottom: AppSpacing.md),
                      child: Row(
                        children: [
                          Text(
                            DateFormat.MMMMEEEEd().format(_selectedDay),
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          if (selectedReminders.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
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
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 100),
                              itemCount: selectedReminders.length,
                              itemBuilder: (context, index) {
                                return _EventRow(
                                    reminder: selectedReminders[index]);
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
}

// ─── Custom Day Cell ─────────────────────────────────────────────────────────
//
// Vertical layout: [number in circle] then [dot row] — always separated.
class _DayCell extends StatelessWidget {
  final DateTime day;
  final List<Reminder> events;
  final bool isToday;
  final bool isSelected;
  final bool isOutside;

  const _DayCell({
    required this.day,
    required this.events,
    required this.isToday,
    required this.isSelected,
    required this.isOutside,
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

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Number in circle
          Container(
            width: 32,
            height: 32,
            decoration: circleDecoration,
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday || isSelected
                    ? FontWeight.w700
                    : FontWeight.normal,
                color: textColor,
              ),
            ),
          ),

          // Event dots — always outside the circle
          const SizedBox(height: 3),
          SizedBox(
            height: 6,
            child: hasEvents && !isOutside
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      events.length.clamp(0, 3),
                      (i) => Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

// ─── Event Row ───────────────────────────────────────────────────────────────
class _EventRow extends StatelessWidget {
  final Reminder reminder;

  const _EventRow({required this.reminder});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time
          SizedBox(
            width: 52,
            child: Text(
              DateFormat.jm().format(reminder.dateTime),
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textTertiary,
                height: 1.4,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Dot aligned to first line of text
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Title
          Expanded(
            child: Text(
              reminder.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
