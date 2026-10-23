import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/repositories/contact_repository.dart';
import '../../../core/repositories/reminder_repository.dart';
import '../../../core/repositories/todo_repository.dart';
import '../../../core/services/app_log.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sb_widgets.dart';
import '../../../core/utils/ethiopian_date.dart';
import '../../../core/utils/reminder_time.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../core/widgets/past_reminder_dialog.dart';
import '../../../models/contact.dart';
import '../../../models/reminder.dart';
import '../../../models/todo_item.dart';

/// The calendar, opened from Today's date and built to the "Espresso ·
/// final" Calendar board: the month (with the Ethiopian month under it),
/// a week strip with both calendars' day numbers, then the chosen day's calls
/// with "now" and free time marked. Tap the month for the whole month.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, this.clock});

  /// Fixed "now" for tests.
  final DateTime Function()? clock;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _reminderRepo = ReminderRepository();

  late DateTime _selected = _day(_now);
  List<Reminder> _reminders = [];
  Map<String, Contact> _contacts = {};
  List<TodoItem> _owed = [];
  bool _loading = true;
  bool _failed = false;

  DateTime get _now => widget.clock?.call() ?? DateTime.now();

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final reminders = await _reminderRepo.getAll();
      final contacts = await ContactRepository().getAll();
      final todos = await TodoRepository().getPending();
      if (!mounted) return;
      setState(() {
        _reminders = reminders;
        _contacts = {for (final c in contacts) c.id: c};
        _owed = todos.where((t) => t.owedBy == OwedBy.me && t.dueAt != null).toList();
        _loading = false;
        _failed = false;
      });
    } catch (e, st) {
      AppLog.e('Calendar', 'could not load the calendar', e, st);
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  List<Reminder> _on(DateTime day) =>
      _reminders.where((r) => isSameDay(r.dateTime, day)).toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  /// Monday of the week the chosen day is in.
  DateTime get _weekStart => _selected.subtract(Duration(days: _selected.weekday - DateTime.monday));

  void _moveWeek(int weeks) => setState(() => _selected = _day(_selected.add(Duration(days: 7 * weeks))));

  Future<void> _pickFromMonth() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: context.sb.canvas,
      builder: (_) => _MonthSheet(selected: _selected, now: _now, hasEvents: (d) => _on(d).isNotEmpty),
    );
    if (picked != null) setState(() => _selected = _day(picked));
  }

  Future<void> _add() async {
    if (_contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a person first')));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final people = _contacts.values.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final reminder = await showModalBottomSheet<Reminder>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.sb.canvas,
      builder: (_) => _AddReminderSheet(contacts: people, initialDate: _selected),
    );
    if (reminder == null) return;
    final id = await _reminderRepo.insert(reminder);
    final saved = await _reminderRepo.getById(id);
    final scheduled = saved != null && await NotificationService().scheduleReminder(saved);
    if (!scheduled) {
      messenger.showSnackBar(const SnackBar(content: Text('Saved. No alert, because that time has passed.')));
    }
    _load();
  }

  Future<void> _open(Reminder reminder) async {
    await Navigator.pushNamed(context, AppRoutes.reminderDetail, arguments: reminder.id);
    if (mounted) _load();
  }

  Future<void> _actions(Reminder reminder) async {
    final sb = context.sb;
    final messenger = ScaffoldMessenger.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: sb.canvas,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text(
                reminder.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            SbCard(
              child: Column(
                children: [
                  for (final (i, a) in [
                    (
                      'done',
                      reminder.completed ? LucideIcons.rotateCcw : LucideIcons.check,
                      reminder.completed ? 'Not done yet' : 'Done',
                      false,
                    ),
                    ('delete', LucideIcons.trash2, 'Delete', true),
                  ].indexed)
                    InkWell(
                      onTap: () => Navigator.pop(ctx, a.$1),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 56),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: i == 0
                            ? null
                            : BoxDecoration(
                                border: Border(top: BorderSide(color: sb.fill)),
                              ),
                        child: Row(
                          children: [
                            Icon(a.$2, size: 20, color: a.$4 ? sb.late : sb.text),
                            const SizedBox(width: 14),
                            Text(
                              a.$3,
                              style: TextStyle(
                                fontSize: 16,
                                height: 22 / 16,
                                fontWeight: FontWeight.w600,
                                color: a.$4 ? sb.late : sb.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    if (action == 'done') {
      final toggled = reminder.copyWith(completed: !reminder.completed);
      await _reminderRepo.update(toggled);
      // No alert for a done reminder; reopening one schedules it again.
      if (toggled.completed) {
        await NotificationService().cancelReminder(toggled.id);
      } else {
        await NotificationService().scheduleReminder(toggled);
      }
    } else {
      await _reminderRepo.delete(reminder.id);
      await NotificationService().cancelReminder(reminder.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Reminder deleted'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await _reminderRepo.insert(reminder);
                if (!reminder.completed) await NotificationService().scheduleReminder(reminder);
                if (mounted) _load();
              },
            ),
          ),
        );
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_failed) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: FilledButton(onPressed: _load, child: const Text('Try again')),
        ),
      );
    }
    final sb = context.sb;
    final now = _now;
    final ethiopian = EthiopianDate.fromGregorian(_selected);
    final dayItems = _on(_selected);
    final due = _owed.where((t) => isSameDay(t.dueAt, _selected)).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ConstrainedLayout(
          child: RefreshIndicator(
            color: sb.primary,
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              children: [
                Row(
                  children: [
                    SbCircleButton(
                      icon: LucideIcons.chevronLeft,
                      tooltip: 'Back to Today',
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'Show the whole month, ${DateFormat('MMMM').format(_selected)}',
                        excludeSemantics: true,
                        child: InkWell(
                          onTap: _pickFromMonth,
                          borderRadius: BorderRadius.circular(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      DateFormat('MMMM').format(_selected),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontSize: 26,
                                        height: 30 / 26,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(LucideIcons.chevronDown, size: 18, color: sb.text),
                                ],
                              ),
                              Text(
                                ethiopian.monthYearLabel,
                                style: TextStyle(fontSize: 13, height: 18 / 13, color: sb.text2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SbCircleButton(icon: LucideIcons.plus, tooltip: 'Add to calendar', onPressed: _add, filled: true),
                  ],
                ),
                const SizedBox(height: 18),
                SbRise(
                  child: _WeekStrip(
                    start: _weekStart,
                    selected: _selected,
                    countOn: (d) => _on(d).length,
                    onSelect: (d) => setState(() => _selected = d),
                    onSwipe: _moveWeek,
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${DateFormat('EEEE').format(_selected)} · ${ethiopian.shortLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      if (due.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 28),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: sb.oweBg, borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              'Due: ${due.first.title}${due.length > 1 ? ' +${due.length - 1}' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                height: 18 / 13,
                                fontWeight: FontWeight.w700,
                                color: sb.oweFg,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SbRise(
                  delay: const Duration(milliseconds: 80),
                  child: dayItems.isEmpty
                      ? _NothingPlanned(onAdd: _add)
                      : _DayList(
                          items: dayItems,
                          contacts: _contacts,
                          now: isSameDay(_selected, now) ? now : null,
                          onTap: _open,
                          onLongPress: _actions,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Seven days in a card: weekday, day, the Ethiopian day under it, and a
/// dot per call (up to three). Swipe sideways for the next or last week.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.start,
    required this.selected,
    required this.countOn,
    required this.onSelect,
    required this.onSwipe,
  });

  final DateTime start;
  final DateTime selected;
  final int Function(DateTime day) countOn;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<int> onSwipe;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < 200) return;
        onSwipe(v < 0 ? 1 : -1);
      },
      child: SbCard(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            for (var i = 0; i < 7; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final day = DateTime(start.year, start.month, start.day + i);
                    final on = isSameDay(day, selected);
                    final count = countOn(day).clamp(0, 3);
                    final fg = on ? sb.onPrimary : sb.text;
                    final small = on ? sb.onPrimary.withValues(alpha: 0.72) : sb.text2;
                    return Semantics(
                      button: true,
                      selected: on,
                      label: '${DateFormat('EEE d MMMM').format(day)}, ${countOn(day)} planned',
                      excludeSemantics: true,
                      child: SbPressable(
                        onTap: () => onSelect(day),
                        child: Container(
                          height: 76,
                          decoration: BoxDecoration(
                            color: on ? sb.primary : null,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('EEE').format(day),
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 14 / 11,
                                  fontWeight: FontWeight.w700,
                                  color: small,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${day.day}',
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  fontSize: 19,
                                  height: 24 / 19,
                                  fontWeight: FontWeight.w700,
                                  color: fg,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${EthiopianDate.fromGregorian(day).day}',
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(fontSize: 10, height: 12 / 10, color: small),
                              ),
                              const SizedBox(height: 3),
                              SizedBox(
                                height: 6,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    for (var j = 0; j < count; j++) ...[
                                      if (j > 0) const SizedBox(width: 3),
                                      Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: on ? sb.onPrimary : sb.accent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The chosen day in time order: done calls dimmed, a "now" line today,
/// and "Free for 2 hours" where the day opens up.
class _DayList extends StatelessWidget {
  const _DayList({
    required this.items,
    required this.contacts,
    required this.now,
    required this.onTap,
    required this.onLongPress,
  });

  final List<Reminder> items;
  final Map<String, Contact> contacts;

  /// Set when the chosen day is today.
  final DateTime? now;
  final ValueChanged<Reminder> onTap;
  final ValueChanged<Reminder> onLongPress;

  /// Calls are taken to last about an hour when working out free time.
  static const _slot = Duration(hours: 1);

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    final time = use24h ? DateFormat('H:mm') : DateFormat('h:mm');
    final rows = <Widget>[];
    var nowShown = now == null;
    var divider = false;

    void add(Widget row, {bool line = true}) {
      rows.add(
        Container(
          decoration: divider && line
              ? BoxDecoration(
                  border: Border(top: BorderSide(color: sb.fill)),
                )
              : null,
          child: row,
        ),
      );
      divider = true;
    }

    for (var i = 0; i < items.length; i++) {
      final r = items[i];
      if (!nowShown && !r.dateTime.isBefore(now!)) {
        // The now line sits between the past and what's next, without a rule.
        rows.add(_NowRow(label: time.format(now!)));
        nowShown = true;
        divider = false;
      }
      add(
        _ItemRow(
          reminder: r,
          contact: contacts[r.contactId],
          time: time.format(r.dateTime),
          onTap: () => onTap(r),
          onLongPress: () => onLongPress(r),
        ),
      );
      if (i + 1 < items.length) {
        final freeFrom = r.dateTime.add(_slot);
        final gap = items[i + 1].dateTime.difference(freeFrom);
        if (gap >= const Duration(hours: 2)) {
          final hours = gap.inMinutes / 60;
          final label = hours == hours.roundToDouble() ? '${hours.round()} hours' : '${hours.toStringAsFixed(1)} hours';
          add(_FreeRow(time: time.format(freeFrom), label: 'Free for $label'));
        }
      }
    }
    if (!nowShown) rows.add(_NowRow(label: time.format(now!)));

    return SbCard(child: Column(children: rows));
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.reminder,
    required this.contact,
    required this.time,
    required this.onTap,
    required this.onLongPress,
  });

  final Reminder reminder;
  final Contact? contact;
  final String time;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final done = reminder.completed;
    final name = contact?.name ?? reminder.title;
    // "Call · office lease", unless the title already says it's a call.
    final title = reminder.title.trim();
    final String detail;
    if (done) {
      detail = 'Call · done';
    } else {
      detail = title.toLowerCase().startsWith('call') ? title : 'Call · $title';
    }
    return Opacity(
      opacity: done ? 0.5 : 1,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: _timeColumnWidth(context),
                child: Text(
                  time,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 15,
                    height: 20 / 15,
                    fontWeight: FontWeight.w700,
                    color: sb.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SbFace(name: name, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600, color: sb.text),
                    ),
                    Row(
                      children: [
                        Icon(LucideIcons.phone, size: 13, color: sb.text2),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, height: 18 / 13, color: sb.text2),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NowRow extends StatelessWidget {
  const _NowRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final accent = context.sb.accent;
    return SizedBox(
      height: 18,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SizedBox(
              width: _timeColumnWidth(context),
              child: Text(
                label,
                style: TextStyle(fontSize: 11, height: 14 / 11, fontWeight: FontWeight.w700, color: accent),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            Expanded(child: Container(height: 1.5, color: accent.withValues(alpha: 0.35))),
          ],
        ),
      ),
    );
  }
}

class _FreeRow extends StatelessWidget {
  const _FreeRow({required this.time, required this.label});

  final String time;
  final String label;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final style = TextStyle(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w600, color: sb.text2);
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: _timeColumnWidth(context),
            child: Text(time, maxLines: 1, softWrap: false, style: style),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: style)),
        ],
      ),
    );
  }
}

class _NothingPlanned extends StatelessWidget {
  const _NothingPlanned({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final text = Theme.of(context).textTheme;
    return SbCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: sb.fill, borderRadius: BorderRadius.circular(12)),
            child: Icon(LucideIcons.calendar, size: 20, color: sb.text2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nothing planned', style: text.titleSmall?.copyWith(fontSize: 16)),
                Text('Add a call or a meeting', style: text.bodySmall),
              ],
            ),
          ),
          TextButton(onPressed: onAdd, child: const Text('Add')),
        ],
      ),
    );
  }
}

/// The whole month, to jump to any day.
/// The time column on the left of the day list. It grows with the text
/// size so "11:21" stays on one line with large text. (Scaled as the 15 sp
/// time is: Android scales large sizes less than small ones.)
double _timeColumnWidth(BuildContext context) => 50 * MediaQuery.textScalerOf(context).scale(15) / 15;

class _MonthSheet extends StatefulWidget {
  const _MonthSheet({required this.selected, required this.now, required this.hasEvents});

  final DateTime selected;
  final DateTime now;
  final bool Function(DateTime day) hasEvents;

  @override
  State<_MonthSheet> createState() => _MonthSheetState();
}

class _MonthSheetState extends State<_MonthSheet> {
  late DateTime _focused = widget.selected;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    // TableCalendar fills the height it is given; unbounded, it takes just
    // the month, so the sheet fits the month (and scrolls with huge text).
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 16 + MediaQuery.paddingOf(context).bottom),
      child: TableCalendar<bool>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2100, 12, 31),
        focusedDay: _focused,
        currentDay: widget.now,
        startingDayOfWeek: StartingDayOfWeek.monday,
        availableCalendarFormats: const {CalendarFormat.month: 'Month'},
        selectedDayPredicate: (d) => isSameDay(d, widget.selected),
        eventLoader: (d) => widget.hasEvents(d) ? const [true] : const [],
        daysOfWeekHeight: MediaQuery.textScalerOf(context).scale(20),
        onDaySelected: (day, _) => Navigator.pop(context, day),
        onPageChanged: (d) => _focused = d,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: Theme.of(context).textTheme.titleMedium!,
          leftChevronIcon: Icon(LucideIcons.chevronLeft, size: 20, color: sb.text2),
          rightChevronIcon: Icon(LucideIcons.chevronRight, size: 20, color: sb.text2),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: Theme.of(context).textTheme.labelMedium!,
          weekendStyle: Theme.of(context).textTheme.labelMedium!.copyWith(color: sb.text3),
        ),
        calendarStyle: CalendarStyle(
          selectedDecoration: BoxDecoration(color: sb.primary, shape: BoxShape.circle),
          selectedTextStyle: TextStyle(color: sb.onPrimary, fontWeight: FontWeight.w700),
          todayDecoration: BoxDecoration(
            border: Border.all(color: sb.primary),
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(color: sb.text, fontWeight: FontWeight.w700),
          markerDecoration: BoxDecoration(color: sb.accent, shape: BoxShape.circle),
          markersMaxCount: 1,
          markerSize: 4,
          outsideDaysVisible: false,
        ),
      ),
    );
  }
}

/// A new calendar entry: what, when, and with whom.
class _AddReminderSheet extends StatefulWidget {
  const _AddReminderSheet({required this.contacts, required this.initialDate});

  final List<Contact> contacts;
  final DateTime initialDate;

  @override
  State<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<_AddReminderSheet> {
  final _titleController = TextEditingController();
  late DateTime _date = widget.initialDate;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  String? _contactId;

  @override
  void initState() {
    super.initState();
    // For today, default to the next full hour so the reminder can still fire.
    if (isSameCalendarDay(widget.initialDate, DateTime.now())) {
      final suggested = nextFullHour();
      _date = DateTime(suggested.year, suggested.month, suggested.day);
      _time = TimeOfDay.fromDateTime(suggested);
    }
    // Ask who it's with rather than guess (unless there's only one person).
    if (widget.contacts.length == 1) _contactId = widget.contacts.first.id;
    _titleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty || _contactId == null) return;
    final at = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    if (!isSchedulable(at) && !await confirmPastReminder(context)) return;
    if (!mounted) return;
    Navigator.pop(
      context,
      Reminder(
        id: '',
        contactId: _contactId!,
        title: _titleController.text.trim(),
        dateTime: at,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    Widget pickerTile(String label, String value, VoidCallback onTap) => Expanded(
      child: SbCard(
        onTap: onTap,
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600, color: sb.text),
            ),
          ],
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New reminder', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(fontSize: 17, height: 24 / 17, fontWeight: FontWeight.w600, color: sb.text),
              decoration: const InputDecoration(hintText: 'Call about…'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                pickerTile('Day', DateFormat('EEE d MMM').format(_date), () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null && mounted) setState(() => _date = date);
                }),
                const SizedBox(width: 10),
                pickerTile('Time', _time.format(context), () async {
                  final time = await showTimePicker(context: context, initialTime: _time);
                  if (time != null && mounted) setState(() => _time = time);
                }),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _contactId,
              isExpanded: true,
              decoration: const InputDecoration(hintText: 'Who with?'),
              items: [
                for (final c in widget.contacts)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (id) => setState(() => _contactId = id),
            ),
            const SizedBox(height: 24),
            SbPrimaryButton(
              label: 'Save',
              onPressed: _titleController.text.trim().isEmpty || _contactId == null ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
