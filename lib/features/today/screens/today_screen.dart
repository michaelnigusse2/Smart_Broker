import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/repositories/contact_repository.dart';
import '../../../core/repositories/note_repository.dart';
import '../../../core/repositories/reminder_repository.dart';
import '../../../core/repositories/todo_repository.dart';
import '../../../core/services/app_log.dart';
import '../../../core/services/phone_dialer.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sb_widgets.dart';
import '../../../core/utils/ethiopian_date.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../models/contact.dart';
import '../../../models/reminder.dart';
import '../../../models/todo_item.dart';
import '../../home/screens/main_shell.dart';

/// The first tab: what's on today, who's next, and who's waiting on you.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, this.clock});

  /// Fixed "now" for tests.
  final DateTime Function()? clock;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> with WidgetsBindingObserver {
  Map<String, Contact> _contacts = {};
  List<Reminder> _today = [];
  List<Reminder> _late = [];
  List<TodoItem> _pending = [];
  int _notesToFinish = 0;
  bool _loading = true;
  bool _failed = false;

  DateTime get _now => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MainShell.currentTab.addListener(_onTabChanged);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    MainShell.currentTab.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  void _onTabChanged() {
    if (MainShell.currentTab.value == MainShell.homeTab) _load();
  }

  Future<void> _load() async {
    try {
      final contacts = await ContactRepository().getAll();
      final reminders = await ReminderRepository().getOpen();
      final todos = await TodoRepository().getPending();
      final notes = await NoteRepository().counts();
      final now = _now;
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      if (!mounted) return;
      setState(() {
        _contacts = {for (final c in contacts) c.id: c};
        _today = reminders.where((r) => !r.dateTime.isBefore(startOfDay) && r.dateTime.isBefore(endOfDay)).toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
        _late = reminders.where((r) => r.dateTime.isBefore(startOfDay)).toList();
        _pending = todos;
        _notesToFinish = notes.unprocessed;
        _loading = false;
        _failed = false;
      });
    } catch (e, st) {
      AppLog.e('Today', 'could not load today', e, st);
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _open(String route, {Object? arguments}) async {
    await Navigator.of(context).pushNamed(route, arguments: arguments);
    if (mounted) _load();
  }

  Future<void> _call(Contact contact) async {
    final opened = await PhoneDialer.dial(contact.phoneNumber);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't open the phone's dialer")));
    }
  }

  // ── Derived data ───────────────────────────────────────────────

  DateTime get _endOfToday {
    final now = _now;
    return DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  }

  /// Promises (open tasks) due by the end of today, late ones included.
  int get _dueCount => _pending.where((t) => t.dueAt != null && t.dueAt!.isBefore(_endOfToday)).length;

  /// The first open promise for a person, soonest due first.
  TodoItem? _promiseFor(String contactId) {
    final mine = _pending.where((t) => t.contactId == contactId).toList()
      ..sort((a, b) => (a.dueAt ?? DateTime(9999)).compareTo(b.dueAt ?? DateTime(9999)));
    return mine.isEmpty ? null : mine.first;
  }

  /// People with open promises, the ones running late first.
  List<({Contact contact, bool late})> get _waiting {
    final now = _now;
    final byContact = <String, List<TodoItem>>{};
    for (final todo in _pending) {
      if (_contacts.containsKey(todo.contactId)) byContact.putIfAbsent(todo.contactId, () => []).add(todo);
    }
    final rows = [
      for (final entry in byContact.entries)
        (contact: _contacts[entry.key]!, late: entry.value.any((t) => t.dueAt != null && t.dueAt!.isBefore(now))),
    ];
    rows.sort((a, b) {
      if (a.late != b.late) return a.late ? -1 : 1;
      return b.contact.lastInteraction.compareTo(a.contact.lastInteraction);
    });
    return rows;
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_failed) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Couldn't load today", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    final waiting = _waiting;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ConstrainedLayout(
          child: RefreshIndicator(
            color: sb.primary,
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 128),
              children: [
                _Header(
                  now: _now,
                  onCalendar: () => _open(AppRoutes.calendar),
                  onSettings: () => _open(AppRoutes.settings),
                ),
                const SizedBox(height: 20),
                SbRise(
                  child: _Headline(things: _today.length + _late.length, due: _dueCount),
                ),
                if (_notesToFinish > 0) ...[
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _WrapUpTag(count: _notesToFinish, onTap: () => _open(AppRoutes.notesList)),
                  ),
                ],
                const SizedBox(height: 24),
                SbRise(
                  delay: const Duration(milliseconds: 80),
                  child: _today.isEmpty && _late.isEmpty
                      ? _EmptyDay(onAdd: () => _open(AppRoutes.calendar))
                      : _Agenda(
                          now: _now,
                          late: _late,
                          today: _today,
                          contacts: _contacts,
                          promiseFor: _promiseFor,
                          onOpenReminder: (r) => _open(AppRoutes.reminderDetail, arguments: r.id),
                          onCall: _call,
                        ),
                ),
                if (waiting.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SbRise(
                    delay: const Duration(milliseconds: 160),
                    child: _WaitingOnYou(
                      people: waiting,
                      onTap: () => MainShell.selectTab(context, MainShell.promisesTab),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.now, required this.onCalendar, required this.onSettings});

  final DateTime now;
  final VoidCallback onCalendar;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final date = DateFormat('EEE d MMM').format(now);
    final ethiopian = EthiopianDate.fromGregorian(now).shortLabel;
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: 'Open calendar, $date',
              excludeSemantics: true,
              child: SbPressable(
                onTap: onCalendar,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.calendar, size: 16, color: sb.text2),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '$date · $ethiopian',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: sb.text2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<String>(
          valueListenable: ProfileService.name,
          builder: (context, name, _) => Semantics(
            button: true,
            label: 'Settings',
            excludeSemantics: true,
            child: SbPressable(
              onTap: onSettings,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: sb.honey, shape: BoxShape.circle),
                  child: Text(
                    name.isEmpty ? '·' : SbFace.letterFor(name),
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF2A1C15)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.things, required this.due});

  final int things;
  final int due;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final first = things == 0 ? 'A clear day.' : '$things ${things == 1 ? 'thing' : 'things'} today.';
    final second = due == 0 ? 'Nothing due.' : '$due ${due == 1 ? 'promise' : 'promises'} due.';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$first\n'),
            TextSpan(
              text: second,
              style: TextStyle(color: sb.text3),
            ),
          ],
        ),
        style: Theme.of(context).textTheme.displaySmall,
      ),
    );
  }
}

class _WrapUpTag extends StatelessWidget {
  const _WrapUpTag({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final label = '$count ${count == 1 ? 'note' : 'notes'} to finish';
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: SbPressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
          decoration: BoxDecoration(
            color: sb.surface,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: sb.hairline),
            boxShadow: [BoxShadow(color: sb.shadow, blurRadius: 2, offset: const Offset(0, 1))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.mic, size: 16, color: sb.accent),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: sb.accent),
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 16, color: sb.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.onAdd});

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

/// Today's reminders in time order with a "Now" line. The first one still to
/// come is opened up: who, what you owe them, and a Call button.
class _Agenda extends StatelessWidget {
  const _Agenda({
    required this.now,
    required this.late,
    required this.today,
    required this.contacts,
    required this.promiseFor,
    required this.onOpenReminder,
    required this.onCall,
  });

  final DateTime now;
  final List<Reminder> late;
  final List<Reminder> today;
  final Map<String, Contact> contacts;
  final TodoItem? Function(String contactId) promiseFor;
  final ValueChanged<Reminder> onOpenReminder;
  final ValueChanged<Contact> onCall;

  @override
  Widget build(BuildContext context) {
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    final time = use24h ? DateFormat.Hm() : DateFormat.jm();
    // Anything that started in the last five minutes still counts as "next".
    final nextIndex = today.indexWhere((r) => !r.dateTime.isBefore(now.subtract(const Duration(minutes: 5))));
    final rows = <Widget>[];

    for (final r in late) {
      rows.add(
        _AgendaRow(
          reminder: r,
          contact: contacts[r.contactId],
          timeLabel: 'Late',
          late: true,
          onTap: () => onOpenReminder(r),
        ),
      );
    }
    for (var i = 0; i < today.length; i++) {
      final r = today[i];
      if (i == nextIndex) rows.add(const _NowLine());
      final past = nextIndex == -1 || i < nextIndex;
      if (i == nextIndex) {
        final contact = contacts[r.contactId];
        rows.add(
          _NextUp(
            reminder: r,
            contact: contact,
            time: time.format(r.dateTime),
            relative: _relative(r.dateTime.difference(now)),
            promise: contact == null ? null : promiseFor(contact.id),
            onOpen: () => onOpenReminder(r),
            onCall: contact == null || contact.phoneNumber.trim().isEmpty ? null : () => onCall(contact),
          ),
        );
      } else {
        rows.add(
          _AgendaRow(
            reminder: r,
            contact: contacts[r.contactId],
            timeLabel: time.format(r.dateTime),
            faded: past,
            onTap: () => onOpenReminder(r),
          ),
        );
      }
    }
    if (nextIndex == -1) rows.add(const _NowLine());

    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final previous = i == 0 ? null : rows[i - 1];
      final divide = i > 0 && row is! _NowLine && previous is! _NowLine;
      children.add(
        divide
            ? DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: context.sb.fill)),
                ),
                child: row,
              )
            : row,
      );
    }
    return SbCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  static String _relative(Duration d) {
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return 'in ${d.inMinutes} min';
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    return minutes == 0 ? 'in $hours h' : 'in $hours h $minutes';
  }
}

class _NowLine extends StatelessWidget {
  const _NowLine();

  @override
  Widget build(BuildContext context) {
    final accent = context.sb.accent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              'Now',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent),
            ),
          ),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          Expanded(child: Container(height: 1.5, color: accent.withValues(alpha: 0.3))),
        ],
      ),
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({
    required this.reminder,
    required this.contact,
    required this.timeLabel,
    required this.onTap,
    this.faded = false,
    this.late = false,
  });

  final Reminder reminder;
  final Contact? contact;
  final String timeLabel;
  final VoidCallback onTap;
  final bool faded;
  final bool late;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final text = Theme.of(context).textTheme;
    final name = contact?.name ?? reminder.title;
    final detail = contact == null ? '' : reminder.title;
    return Opacity(
      opacity: faded ? 0.5 : 1,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: late ? sb.late : sb.text2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
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
                        style: text.titleSmall?.copyWith(fontSize: 16),
                      ),
                      if (detail.isNotEmpty)
                        Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall),
                    ],
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

class _NextUp extends StatelessWidget {
  const _NextUp({
    required this.reminder,
    required this.contact,
    required this.time,
    required this.relative,
    required this.promise,
    required this.onOpen,
    required this.onCall,
  });

  final Reminder reminder;
  final Contact? contact;
  final String time;
  final String relative;
  final TodoItem? promise;
  final VoidCallback onOpen;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final text = Theme.of(context).textTheme;
    final name = contact?.name ?? reminder.title;
    final detail = contact == null ? '' : reminder.title;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(relative, style: TextStyle(fontSize: 12, color: sb.text2)),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      SbFace(name: name, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleMedium?.copyWith(fontSize: 18),
                            ),
                            if (detail.isNotEmpty)
                              Text(
                                detail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall?.copyWith(fontSize: 14),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (promise != null || onCall != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      if (promise != null)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 200),
                          child: SbTag.owe(context, promise!.title),
                        ),
                      if (onCall != null)
                        FilledButton.icon(
                          onPressed: onCall,
                          icon: const Icon(LucideIcons.phone, size: 16),
                          label: const Text('Call'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(88, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingOnYou extends StatelessWidget {
  const _WaitingOnYou({required this.people, required this.onTap});

  final List<({Contact contact, bool late})> people;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final text = Theme.of(context).textTheme;
    final lateCount = people.where((p) => p.late).length;
    final shown = people.take(3).toList();
    final extra = people.length - shown.length;
    return Semantics(
      button: true,
      label: '${people.length} waiting on you${lateCount > 0 ? ', $lateCount late' : ''}',
      excludeSemantics: true,
      child: SbCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Waiting on you', style: text.titleSmall?.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(
                    lateCount > 0 ? '$lateCount late' : '${people.length} ${people.length == 1 ? 'person' : 'people'}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: lateCount > 0 ? sb.late : sb.text2,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 46,
              width: 40.0 + 32.0 * (shown.length - 1 + (extra > 0 ? 1 : 0)) + 6,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < shown.length; i++)
                    Positioned(
                      left: 32.0 * i,
                      top: 3,
                      child: SbFace(name: shown[i].contact.name, size: 40, late: shown[i].late, ring: sb.surface),
                    ),
                  if (extra > 0)
                    Positioned(
                      left: 32.0 * shown.length,
                      top: 3,
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: sb.fill,
                          shape: BoxShape.circle,
                          border: Border.all(color: sb.surface, width: 3, strokeAlign: BorderSide.strokeAlignOutside),
                        ),
                        child: Text(
                          '+$extra',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sb.text),
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
  }
}
