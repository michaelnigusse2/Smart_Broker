import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/repositories/call_repository.dart';
import '../../../core/repositories/contact_repository.dart';
import '../../../core/repositories/note_repository.dart';
import '../../../core/repositories/reminder_repository.dart';
import '../../../core/repositories/todo_repository.dart';
import '../../../core/services/app_log.dart';
import '../../../core/services/call_matching_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/overlay_draft_service.dart';
import '../../../core/services/phone_dialer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sb_widgets.dart';
import '../../../core/utils/day_labels.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../models/call_entry.dart';
import '../../../models/contact.dart';
import '../../../models/note.dart';
import '../../../models/reminder.dart';
import '../../../models/todo_item.dart';
import '../../home/screens/main_shell.dart';
import '../../todos/widgets/promise_sheet.dart';

/// A person, built to the "Espresso · final" Person board: who they are,
/// Call / Text / Note, the promises between you, and your last talks.
/// Editing, call history and deleting live behind "More".
class ContactDetailScreen extends StatefulWidget {
  const ContactDetailScreen({super.key, this.clock});

  /// Fixed "now" for tests.
  final DateTime Function()? clock;

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  final _contactRepo = ContactRepository();
  final _noteRepo = NoteRepository();
  final _todoRepo = TodoRepository();
  final _reminderRepo = ReminderRepository();
  final _callRepo = CallRepository();

  String? _contactId;
  Contact? _contact;
  List<Note> _notes = [];
  List<TodoItem> _promises = [];
  List<Reminder> _reminders = [];
  List<CallEntry> _calls = [];
  bool _loading = true;
  String? _error;
  bool _allTalks = false;

  bool _initialized = false;
  StreamSubscription<CallEntry>? _callLogSubscription;

  DateTime get _now => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _callLogSubscription = CallMatchingService().onCallLogged.listen((call) {
      if (call.contactId == _contactId) _load();
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
    if (_initialized) return;
    _initialized = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      _contactId = args;
      _load();
    } else {
      setState(() {
        _error = 'No contact was given.';
        _loading = false;
      });
    }
  }

  Future<void> _load() async {
    final id = _contactId;
    if (id == null) return;
    try {
      final contact = await _contactRepo.getById(id);
      if (contact == null) throw StateError('This person is no longer saved.');
      final notes = await _noteRepo.getByContactId(id);
      final todos = await _todoRepo.getByContactId(id);
      final reminders = await _reminderRepo.getByContactId(id);
      final calls = await _callRepo.getByContactId(id);
      if (!mounted) return;
      setState(() {
        _contact = contact;
        _notes = notes;
        _promises = todos.where((t) => !t.isCompleted).toList()..sort(_byWhoThenDue);
        _reminders = reminders;
        _calls = calls;
        _loading = false;
        _error = null;
      });
    } catch (e, st) {
      AppLog.e('Person', 'could not load the person', e, st);
      if (mounted) {
        setState(() {
          _error = e is StateError ? e.message : "Couldn't load this person.";
          _loading = false;
        });
      }
    }
  }

  /// What you owe first, then what they owe; soonest due first in each.
  static int _byWhoThenDue(TodoItem a, TodoItem b) {
    if (a.owedBy != b.owedBy) return a.owedBy == OwedBy.me ? -1 : 1;
    return (a.dueAt ?? DateTime(9999)).compareTo(b.dueAt ?? DateTime(9999));
  }

  void _snack(String message, {SnackBarAction? action}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(message), action: action));
  }

  Future<void> _call() async {
    final opened = await PhoneDialer.dial(_contact!.phoneNumber);
    if (!opened && mounted) _snack("Couldn't open the phone's dialer");
  }

  Future<void> _text() async {
    final opened = await PhoneDialer.text(_contact!.phoneNumber);
    if (!opened && mounted) _snack("Couldn't open messages");
  }

  Future<void> _note() async {
    await Navigator.pushNamed(context, AppRoutes.addNote, arguments: _contact!.id);
    if (mounted) _load();
  }

  Future<void> _openNote(Note note) async {
    await Navigator.pushNamed(context, AppRoutes.noteDetail, arguments: note.id);
    if (mounted) _load();
  }

  void _allPromises() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    MainShell.currentTab.value = MainShell.promisesTab;
  }

  // ── Promises ───────────────────────────────────────────────────

  Future<void> _addPromise() async {
    final promise = await showPromiseSheet(context, contact: _contact);
    if (promise == null) return;
    await _todoRepo.insert(promise);
    _load();
  }

  Future<void> _promiseActions(TodoItem promise) async {
    final action = await _showActions(context, promise.title, [
      (id: 'done', icon: LucideIcons.check, label: 'Done', danger: false),
      (id: 'edit', icon: LucideIcons.pencil, label: 'Change', danger: false),
      (id: 'delete', icon: LucideIcons.trash2, label: 'Delete', danger: true),
    ]);
    if (!mounted || action == null) return;
    switch (action) {
      case 'done':
        await _todoRepo.toggleCompleted(promise.id);
        _load();
        _snack(
          'Marked done',
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await _todoRepo.toggleCompleted(promise.id);
              _load();
            },
          ),
        );
      case 'edit':
        final changed = await showPromiseSheet(context, contact: _contact, editing: promise);
        if (changed == null) return;
        await _todoRepo.update(changed);
        _load();
      case 'delete':
        await _todoRepo.delete(promise.id);
        _load();
        _snack(
          'Promise deleted',
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await _todoRepo.insert(promise);
              _load();
            },
          ),
        );
    }
  }

  // ── Talks ──────────────────────────────────────────────────────

  Future<void> _talkActions(Note note) async {
    final action = await _showActions(context, _talkLine(note), [
      (id: 'open', icon: LucideIcons.fileText, label: 'Open', danger: false),
      (id: 'delete', icon: LucideIcons.trash2, label: 'Delete', danger: true),
    ]);
    if (!mounted || action == null) return;
    if (action == 'open') return _openNote(note);
    final confirmed = await _confirm(
      title: 'Delete this note?',
      body: 'Promises and reminders made from it stay.',
      action: 'Delete',
    );
    if (confirmed != true) return;
    await _noteRepo.delete(note.id);
    _load();
  }

  // ── More ───────────────────────────────────────────────────────

  Future<void> _more() async {
    final contact = _contact!;
    final action = await _showActions(context, contact.name, [
      (id: 'promise', icon: LucideIcons.arrowLeftRight, label: 'Add a promise', danger: false),
      (id: 'edit', icon: LucideIcons.pencil, label: 'Edit details', danger: false),
      (id: 'calls', icon: LucideIcons.history, label: 'Call history', danger: false),
      (id: 'delete', icon: LucideIcons.trash2, label: 'Delete', danger: true),
    ]);
    if (!mounted || action == null) return;
    switch (action) {
      case 'promise':
        await _addPromise();
      case 'edit':
        await Navigator.pushNamed(context, AppRoutes.contactForm, arguments: contact);
        if (mounted) _load();
      case 'calls':
        await _showCallHistory();
      case 'delete':
        await _delete();
    }
  }

  Future<void> _showCallHistory() {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: context.sb.canvas,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (_) => _CallHistorySheet(calls: _calls),
    );
  }

  /// Deletes the person with everything linked to them, after a confirmation
  /// that says what will be lost.
  Future<void> _delete() async {
    final contact = _contact!;
    String count(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
    final allTodos = await _todoRepo.getByContactId(contact.id);
    if (!mounted) return;
    final confirmed = await _confirm(
      title: 'Delete ${contact.name}?',
      body:
          'This also deletes ${count(_notes.length, 'note')}, ${count(allTodos.length, 'promise')}, '
          '${count(_reminders.length, 'reminder')} and ${count(_calls.length, 'logged call')}. '
          'This cannot be undone.',
      action: 'Delete',
    );
    if (confirmed != true || !mounted) return;
    try {
      // Reminders are deleted with the person, so their alarms must go too.
      for (final reminder in _reminders) {
        await NotificationService().cancelReminder(reminder.id);
      }
      await _contactRepo.delete(contact.id);
      await OverlayDraftService().clearDraft(contact.id);
      if (!mounted) return;
      _snack('${contact.name} deleted');
      Navigator.pop(context);
    } catch (e, st) {
      AppLog.e('Person', 'could not delete', e, st);
      if (mounted) _snack("Couldn't delete ${contact.name}");
    }
  }

  Future<bool?> _confirm({required String title, required String body, required String action}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: TextStyle(color: ctx.sb.late)),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final contact = _contact;
    if (_error != null || contact == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error ?? "Couldn't load this person.", textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final now = _now;
    final talks = _allTalks ? _notes : _notes.take(3).toList();
    final detail = [contact.company, contact.role, contact.phoneNumber]
        .map((s) => s.trim())
        .firstWhere(
          (s) => s.isNotEmpty,
          orElse: () => '',
        );
    final canCall = contact.phoneNumber.trim().isNotEmpty;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ConstrainedLayout(
          child: RefreshIndicator(
            color: context.sb.primary,
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              children: [
                Row(
                  children: [
                    SbCircleButton(
                      icon: LucideIcons.chevronLeft,
                      tooltip: 'Back',
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    const Spacer(),
                    SbCircleButton(icon: LucideIcons.moreHorizontal, tooltip: 'More', onPressed: _more),
                  ],
                ),
                const SizedBox(height: 20),
                SbRise(
                  child: _Header(name: contact.name, detail: detail),
                ),
                const SizedBox(height: 18),
                SbRise(
                  delay: const Duration(milliseconds: 80),
                  child: _Actions(
                    onCall: canCall ? _call : null,
                    onText: canCall ? _text : null,
                    onNote: _note,
                  ),
                ),
                if (_promises.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  SbCap(
                    'Promises',
                    trailing: _CapLink(label: 'All', onTap: _allPromises),
                  ),
                  SbRise(
                    delay: const Duration(milliseconds: 160),
                    child: _Promises(
                      promises: _promises,
                      firstName: contact.name.trim().split(RegExp(r'\s+')).first,
                      now: now,
                      onTap: _promiseActions,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                SbCap(
                  'Last talks',
                  trailing: _notes.length > 3
                      ? _CapLink(
                          label: _allTalks ? 'Fewer' : 'All ${_notes.length}',
                          onTap: () => setState(() => _allTalks = !_allTalks),
                        )
                      : null,
                ),
                SbRise(
                  delay: const Duration(milliseconds: 240),
                  child: _Talks(notes: talks, now: now, onTap: _openNote, onLongPress: _talkActions),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The first line worth showing for a note: its summary, else what was said.
String _talkLine(Note note) {
  final source = note.aiSummary.trim().isNotEmpty ? note.aiSummary : note.rawText;
  final line = source
      .split('\n')
      .map((l) => l.trim().replaceFirst(RegExp(r'^[-•*]\s*'), ''))
      .firstWhere((l) => l.isNotEmpty, orElse: () => '');
  return line.isEmpty ? 'Note' : line;
}

/// Face 68, name in Bricolage 30/34, company (or role, or number) under it.
class _Header extends StatelessWidget {
  const _Header({required this.name, required this.detail});

  final String name;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          SbFace(name: name, size: 68),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, height: 22 / 15, color: sb.text2),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Call (espresso, a little wider), Text and Note: 50 dp pills.
class _Actions extends StatelessWidget {
  const _Actions({required this.onCall, required this.onText, required this.onNote});

  final VoidCallback? onCall;
  final VoidCallback? onText;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 13,
          child: _ActionPill(icon: LucideIcons.phone, label: 'Call', onTap: onCall, filled: true),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 10,
          child: _ActionPill(icon: LucideIcons.messageSquare, label: 'Text', onTap: onText),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 10,
          child: _ActionPill(icon: LucideIcons.mic, label: 'Note', onTap: onNote),
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.icon, required this.label, required this.onTap, this.filled = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final enabled = onTap != null;
    final fg = filled ? sb.onPrimary : sb.text;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: SbPressable(
          onTap: onTap,
          child: Container(
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? sb.primary : sb.surface,
              borderRadius: BorderRadius.circular(99),
              boxShadow: filled ? null : [BoxShadow(color: sb.shadow, blurRadius: 2, offset: const Offset(0, 1))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: fg),
                SizedBox(width: filled ? 8 : 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w600, color: fg),
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

/// A caramel text link at the end of a section label ("All").
class _CapLink extends StatelessWidget {
  const _CapLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            label,
            style: TextStyle(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w700, color: context.sb.accent),
          ),
        ),
      ),
    );
  }
}

/// "You owe" rows (red arrow out) then "Selam owes" rows (green arrow in).
class _Promises extends StatelessWidget {
  const _Promises({required this.promises, required this.firstName, required this.now, required this.onTap});

  final List<TodoItem> promises;
  final String firstName;
  final DateTime now;
  final ValueChanged<TodoItem> onTap;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    return SbCard(
      child: Column(
        children: [
          for (var i = 0; i < promises.length; i++)
            _PromiseRow(
              promise: promises[i],
              who: promises[i].owedBy == OwedBy.me ? 'You owe' : '$firstName owes',
              now: now,
              divider: i > 0 ? sb.fill : null,
              onTap: () => onTap(promises[i]),
            ),
        ],
      ),
    );
  }
}

class _PromiseRow extends StatelessWidget {
  const _PromiseRow({
    required this.promise,
    required this.who,
    required this.now,
    required this.divider,
    required this.onTap,
  });

  final TodoItem promise;
  final String who;
  final DateTime now;
  final Color? divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final mine = promise.owedBy == OwedBy.me;
    final due = promise.dueAt;
    final late = due != null && due.isBefore(now);
    final when = due == null ? '' : (late ? DayLabels.late(due, now) : DayLabels.due(due, now));
    final Color whenColor;
    if (late) {
      whenColor = sb.late;
    } else {
      whenColor = mine ? sb.oweFg : sb.text2;
    }
    return Semantics(
      button: true,
      label: '$who ${promise.title}${when.isEmpty ? '' : ', $when'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: divider == null ? 64 : 65),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: divider == null
              ? null
              : BoxDecoration(
                  border: Border(top: BorderSide(color: divider!)),
                ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: mine ? sb.oweBg : sb.goodBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  mine ? LucideIcons.arrowUpRight : LucideIcons.arrowDownLeft,
                  size: 17,
                  color: mine ? sb.oweFg : sb.goodFg,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        who,
                        style: TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w700, color: sb.text2),
                      ),
                      Text(
                        promise.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600, color: sb.text),
                      ),
                    ],
                  ),
                ),
              ),
              if (when.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(
                  when,
                  style: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: mine || late ? FontWeight.w700 : FontWeight.w600,
                    color: whenColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Yesterday — Wants 3-year term": the date in a 78 dp column, one line each.
class _Talks extends StatelessWidget {
  const _Talks({required this.notes, required this.now, required this.onTap, required this.onLongPress});

  final List<Note> notes;
  final DateTime now;
  final ValueChanged<Note> onTap;
  final ValueChanged<Note> onLongPress;

  static String _when(DateTime t, DateTime now) {
    final days = DayLabels.daysBetween(t, now);
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    return DateFormat(t.year == now.year ? 'd MMM' : 'd MMM y').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    if (notes.isEmpty) {
      return SbCard(
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          child: Text(
            'No talks yet. Tap Note after a call.',
            style: TextStyle(fontSize: 15, height: 21 / 15, color: sb.text2),
          ),
        ),
      );
    }
    return SbCard(
      child: Column(
        children: [
          for (var i = 0; i < notes.length; i++)
            InkWell(
              onTap: () => onTap(notes[i]),
              onLongPress: () => onLongPress(notes[i]),
              child: Container(
                constraints: BoxConstraints(minHeight: i == 0 ? 52 : 53),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: i == 0
                    ? null
                    : BoxDecoration(
                        border: Border(top: BorderSide(color: sb.fill)),
                      ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 78,
                      child: Text(
                        _when(notes[i].createdAt, now),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 13,
                          height: 18 / 13,
                          fontWeight: FontWeight.w600,
                          color: sb.text2,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _talkLine(notes[i]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, height: 21 / 15, fontWeight: FontWeight.w500, color: sb.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A short list of choices in a sheet, for row taps and "More".
Future<String?> _showActions(
  BuildContext context,
  String title,
  List<({String id, IconData icon, String label, bool danger})> actions,
) {
  final sb = context.sb;
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    backgroundColor: sb.canvas,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: sb.track, borderRadius: BorderRadius.circular(99)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          SbCard(
            child: Column(
              children: [
                for (var i = 0; i < actions.length; i++)
                  InkWell(
                    onTap: () => Navigator.pop(ctx, actions[i].id),
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
                          Icon(actions[i].icon, size: 20, color: actions[i].danger ? sb.late : sb.text),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              actions[i].label,
                              style: TextStyle(
                                fontSize: 16,
                                height: 22 / 16,
                                fontWeight: FontWeight.w600,
                                color: actions[i].danger ? sb.late : sb.text,
                              ),
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
}

/// Every logged call with this person, newest first.
class _CallHistorySheet extends StatelessWidget {
  const _CallHistorySheet({required this.calls});

  final List<CallEntry> calls;

  static String _length(Duration d) {
    if (d.inMinutes == 0) return '${d.inSeconds}s';
    final seconds = d.inSeconds % 60;
    return '${d.inMinutes}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (ctx, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: sb.track, borderRadius: BorderRadius.circular(99)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
            child: Text('Call history', style: Theme.of(ctx).textTheme.titleMedium),
          ),
          if (calls.isEmpty)
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text('No calls logged yet.', style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: sb.text2)),
            )
          else
            SbCard(
              child: Column(
                children: [
                  for (var i = 0; i < calls.length; i++)
                    Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: i == 0
                          ? null
                          : BoxDecoration(
                              border: Border(top: BorderSide(color: sb.fill)),
                            ),
                      child: Row(
                        children: [
                          Icon(
                            switch (calls[i].type) {
                              CallType.incoming => LucideIcons.phoneIncoming,
                              CallType.outgoing => LucideIcons.phoneOutgoing,
                              CallType.missed => LucideIcons.phoneMissed,
                            },
                            size: 18,
                            color: calls[i].type == CallType.missed ? sb.late : sb.text2,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  switch (calls[i].type) {
                                    CallType.incoming => 'Incoming',
                                    CallType.outgoing => 'Outgoing',
                                    CallType.missed => 'Missed',
                                  },
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 20 / 15,
                                    fontWeight: FontWeight.w600,
                                    color: calls[i].type == CallType.missed ? sb.late : sb.text,
                                  ),
                                ),
                                Text(
                                  DateFormat('EEE d MMM · HH:mm').format(calls[i].timestamp),
                                  style: TextStyle(fontSize: 13, height: 18 / 13, color: sb.text2),
                                ),
                              ],
                            ),
                          ),
                          if (calls[i].type != CallType.missed)
                            Text(
                              _length(calls[i].duration),
                              style: TextStyle(
                                fontSize: 13,
                                height: 18 / 13,
                                fontWeight: FontWeight.w600,
                                color: sb.text2,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
