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

/// The first tab, built to the "Espresso · final" Today board: the headline,
/// the rest of the day from "Now" on (the next item opened up), and the
/// people waiting on you.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, this.clock});

  /// Fixed "now" for tests.
  final DateTime Function()? clock;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> with WidgetsBindingObserver {
  Map<String, Contact> _contacts = {};

  /// Today's reminders from now on, in time order.
  List<Reminder> _upcoming = [];

  /// Open reminders whose time has passed (today or earlier).
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
      // Anything that started in the last five minutes still counts as next.
      final cutoff = now.subtract(const Duration(minutes: 5));
      final endOfDay = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      if (!mounted) return;
      setState(() {
        _contacts = {for (final c in contacts) c.id: c};
        _upcoming = reminders.where((r) => !r.dateTime.isBefore(cutoff) && r.dateTime.isBefore(endOfDay)).toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
        _late = reminders.where((r) => r.dateTime.isBefore(cutoff)).toList();
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

  /// Promises (open tasks) due today. Ones from earlier days show as late
  /// under "Waiting on you" instead, as on the board.
  int get _dueCount {
    final now = _now;
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return _pending.where((t) => t.dueAt != null && !t.dueAt!.isBefore(start) && t.dueAt!.isBefore(end)).length;
  }

  /// The first open promise for a person, soonest due first.
  TodoItem? _promiseFor(String contactId) {
    final mine = _pending.where((t) => t.contactId == contactId).toList()
      ..sort((a, b) => (a.dueAt ?? DateTime(9999)).compareTo(b.dueAt ?? DateTime(9999)));
    return mine.isEmpty ? null : mine.first;
  }

  /// People with open promises or missed reminders: anyone late first, then
  /// whoever is due soonest. The person opened up at the top of the agenda is
  /// left out, since what you owe them is already shown there.
  List<({Contact contact, bool late})> get _waiting {
    final now = _now;
    final nextUp = _upcoming.isEmpty ? null : _upcoming.first.contactId;
    final late = <String, bool>{};
    final soonest = <String, DateTime>{};
    void note(String contactId, DateTime? due, bool overdue) {
      if (contactId == nextUp || !_contacts.containsKey(contactId)) return;
      late[contactId] = (late[contactId] ?? false) || overdue;
      final when = due ?? DateTime(9999);
      final current = soonest[contactId];
      if (current == null || when.isBefore(current)) soonest[contactId] = when;
    }

    for (final todo in _pending) {
      note(todo.contactId, todo.dueAt, todo.dueAt != null && todo.dueAt!.isBefore(now));
    }
    for (final reminder in _late) {
      note(reminder.contactId, reminder.dateTime, true);
    }
    final rows = [for (final entry in late.entries) (contact: _contacts[entry.key]!, late: entry.value)];
    rows.sort((a, b) {
      if (a.late != b.late) return a.late ? -1 : 1;
      return soonest[a.contact.id]!.compareTo(soonest[b.contact.id]!);
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
              children: [
                _Header(
                  now: _now,
                  onCalendar: () => _open(AppRoutes.calendar),
                  onSettings: () => _open(AppRoutes.settings),
                ),
                const SizedBox(height: 22),
                SbRise(
                  child: _Headline(things: _upcoming.length, due: _dueCount),
                ),
                if (_notesToFinish > 0) ...[
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _WrapUpTag(count: _notesToFinish, onTap: () => _open(AppRoutes.notesList)),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SbRise(
                  delay: const Duration(milliseconds: 80),
                  child: _upcoming.isEmpty
                      ? _EmptyDay(onAdd: () => _open(AppRoutes.calendar))
                      : _Agenda(
                          now: _now,
                          upcoming: _upcoming,
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

/// "📅 Wed 21 Oct · ጥቅምት 11" on the left (opens the calendar), the
/// person's initial on the right (opens Settings).
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
                            style: TextStyle(
                              fontSize: 14,
                              height: 20 / 14,
                              fontWeight: FontWeight.w600,
                              color: sb.text2,
                            ),
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

/// "3 calls today. / 1 promise due." in Bricolage 36/40, second line lighter.
class _Headline extends StatelessWidget {
  const _Headline({required this.things, required this.due});

  final int things;
  final int due;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final first = things == 0 ? 'A clear day.' : '$things ${things == 1 ? 'call' : 'calls'} today.';
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

/// The caramel pill under the headline: 36 high, mic, label, chevron.
class _WrapUpTag extends StatelessWidget {
  const _WrapUpTag({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final label = '$count ${count == 1 ? 'note' : 'notes'} to wrap up';
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: SbPressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.fromLTRB(14, 6, 12, 6),
          decoration: BoxDecoration(
            color: sb.surface,
            borderRadius: BorderRadius.circular(99),
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
                  style: TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w700, color: sb.accent),
                ),
              ),
              const SizedBox(width: 8),
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
      radius: 28,
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

/// The rest of the day: the "Now" line at the top, then the next item opened
/// up (face, name, what you owe them, Call), then the ones after it.
/// Layout follows the board: a 52 dp time column, 8 dp gap, 28 dp corners.
class _Agenda extends StatelessWidget {
  const _Agenda({
    required this.now,
    required this.upcoming,
    required this.contacts,
    required this.promiseFor,
    required this.onOpenReminder,
    required this.onCall,
  });

  final DateTime now;
  final List<Reminder> upcoming;
  final Map<String, Contact> contacts;
  final TodoItem? Function(String contactId) promiseFor;
  final ValueChanged<Reminder> onOpenReminder;
  final ValueChanged<Contact> onCall;

  static const timeColumn = 52.0;
  static const gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    final time = use24h ? DateFormat.Hm() : DateFormat.jm();
    final next = upcoming.first;
    final nextContact = contacts[next.contactId];
    return SbCard(
      radius: 28,
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _NowLine(),
          _NextUp(
            reminder: next,
            contact: nextContact,
            time: time.format(next.dateTime),
            relative: _relative(next.dateTime.difference(now)),
            promise: nextContact == null ? null : promiseFor(nextContact.id),
            onOpen: () => onOpenReminder(next),
            onCall: nextContact == null || nextContact.phoneNumber.trim().isEmpty ? null : () => onCall(nextContact),
          ),
          for (final r in upcoming.skip(1))
            // A Container counts the 1 dp top border in its height, like the board.
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: sb.fill)),
              ),
              child: _AgendaRow(
                reminder: r,
                contact: contacts[r.contactId],
                timeLabel: time.format(r.dateTime),
                onTap: () => onOpenReminder(r),
              ),
            ),
        ],
      ),
    );
  }

  /// "20 min", "2 h", "2 h 15" — the board shows "20 min" under the time.
  static String _relative(Duration d) {
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    return minutes == 0 ? '$hours h' : '$hours h $minutes';
  }
}

/// What shows under a name: the company, or what the reminder is about.
String _detailFor(Contact? contact, Reminder reminder) {
  if (contact == null) return '';
  if (contact.company.trim().isNotEmpty) return contact.company.trim();
  if (contact.role.trim().isNotEmpty) return contact.role.trim();
  return reminder.title;
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
            width: _Agenda.timeColumn,
            child: Text(
              'Now',
              style: TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w700, color: accent),
            ),
          ),
          const SizedBox(width: _Agenda.gap),
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
  const _AgendaRow({required this.reminder, required this.contact, required this.timeLabel, required this.onTap});

  final Reminder reminder;
  final Contact? contact;
  final String timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final name = contact?.name ?? reminder.title;
    final detail = _detailFor(contact, reminder);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: _Agenda.timeColumn,
              child: Text(
                timeLabel,
                style: TextStyle(
                  fontSize: 15,
                  height: 20 / 15,
                  fontWeight: FontWeight.w600,
                  color: sb.text2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: _Agenda.gap),
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
                  if (detail.isNotEmpty)
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, height: 18 / 13, color: sb.text2),
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
    final name = contact?.name ?? reminder.title;
    final detail = _detailFor(contact, reminder);
    // A padded Call button is 48 high around its 40 dp pill; take the extra
    // 4 dp above and below out of the gaps so the pill lands where the board has it.
    final slack = onCall != null ? 4.0 : 0.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 - slack),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _Agenda.timeColumn,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 15,
                      height: 20 / 15,
                      fontWeight: FontWeight.w700,
                      color: sb.text,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    relative,
                    style: TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      color: sb.text2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: _Agenda.gap),
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
                              style: TextStyle(
                                fontSize: 18,
                                height: 24 / 18,
                                fontWeight: FontWeight.w700,
                                color: sb.text,
                              ),
                            ),
                            if (detail.isNotEmpty)
                              Text(
                                detail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14, height: 20 / 14, color: sb.text2),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (promise != null || onCall != null) ...[
                  SizedBox(height: 12 - slack),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (promise != null)
                        Flexible(
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 32),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: sb.oweBg, borderRadius: BorderRadius.circular(10)),
                            child: Text(
                              'You owe: ${promise!.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                height: 20 / 14,
                                fontWeight: FontWeight.w700,
                                color: sb.oweFg,
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      if (onCall != null) ...[
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: onCall,
                          icon: const Icon(LucideIcons.phone, size: 16),
                          label: const Text('Call'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            tapTargetSize: MaterialTapTargetSize.padded,
                            textStyle: const TextStyle(
                              fontFamily: AppFonts.body,
                              fontFamilyFallback: AppFonts.bodyFallback,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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

/// "Waiting on you" with the late count in red and up to three overlapping
/// faces (a red dot on anyone late), then "+N".
class _WaitingOnYou extends StatelessWidget {
  const _WaitingOnYou({required this.people, required this.onTap});

  final List<({Contact contact, bool late})> people;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final lateCount = people.where((p) => p.late).length;
    final shown = people.take(3).toList();
    final extra = people.length - shown.length;
    final faces = shown.length + (extra > 0 ? 1 : 0);
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
                  Text(
                    'Waiting on you',
                    style: TextStyle(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w700, color: sb.text),
                  ),
                  Text(
                    lateCount > 0 ? '$lateCount late' : '${people.length} ${people.length == 1 ? 'person' : 'people'}',
                    style: TextStyle(
                      fontSize: 13,
                      height: 18 / 13,
                      fontWeight: FontWeight.w600,
                      color: lateCount > 0 ? sb.late : sb.text2,
                    ),
                  ),
                ],
              ),
            ),
            // Faces overlap by 8; their 3 dp rings and the late dots paint
            // outside this box, as box-shadows do on the board.
            SizedBox(
              height: 40,
              width: 40.0 + 32.0 * (faces - 1),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < shown.length; i++)
                    Positioned(
                      left: 32.0 * i,
                      top: 0,
                      child: SbFace(name: shown[i].contact.name, size: 40, ring: sb.surface),
                    ),
                  if (extra > 0)
                    Positioned(
                      left: 32.0 * shown.length,
                      top: 0,
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: SbTint.neutral.bg,
                          shape: BoxShape.circle,
                          border: Border.all(color: sb.surface, width: 3, strokeAlign: BorderSide.strokeAlignOutside),
                        ),
                        child: Text(
                          '+$extra',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SbTint.neutral.fg),
                        ),
                      ),
                    ),
                  // Late dots go on top of the faces that overlap them.
                  for (var i = 0; i < shown.length; i++)
                    if (shown[i].late)
                      Positioned(
                        left: 32.0 * i + 40 - 11,
                        top: 0,
                        child: SbLateDot(ring: sb.surface),
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
