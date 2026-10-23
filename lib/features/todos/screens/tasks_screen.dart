import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/repositories/contact_repository.dart';
import '../../../core/repositories/todo_repository.dart';
import '../../../core/services/app_log.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sb_widgets.dart';
import '../../../core/utils/day_labels.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../models/todo_item.dart';
import '../../../models/todo_with_contact.dart';
import '../../home/screens/main_shell.dart';
import '../widgets/promise_sheet.dart';

/// The Promises tab, built to the "Espresso · final" Promises board: what
/// you owe and what's owed to you, each grouped into Late, This week and
/// Later, with a circle to tick each one off.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, this.clock});

  /// Fixed "now" for tests.
  final DateTime Function()? clock;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _todoRepo = TodoRepository();

  List<TodoWithContact> _all = [];
  OwedBy _side = OwedBy.me;
  bool _loading = true;
  bool _failed = false;
  bool _showDone = false;

  DateTime get _now => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    MainShell.currentTab.addListener(_onTabChanged);
    _load();
  }

  @override
  void dispose() {
    MainShell.currentTab.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (MainShell.currentTab.value == MainShell.promisesTab) _load();
  }

  Future<void> _load() async {
    try {
      final all = await _todoRepo.getAll();
      if (!mounted) return;
      setState(() {
        _all = all;
        _loading = false;
        _failed = false;
      });
    } catch (e, st) {
      AppLog.e('Promises', 'could not load promises', e, st);
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  void _snack(String message, {SnackBarAction? action}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    // An Undo stays a few seconds, not until dismissed.
    messenger.showSnackBar(SnackBar(content: Text(message), action: action, persist: false));
  }

  Future<void> _add() async {
    final contacts = await ContactRepository().getAll();
    if (!mounted) return;
    if (contacts.isEmpty) {
      _snack('Add a person first');
      return;
    }
    contacts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final promise = await showPromiseSheet(context, contacts: contacts);
    if (promise == null) return;
    await _todoRepo.insert(promise);
    if (mounted && promise.owedBy != _side) setState(() => _side = promise.owedBy);
    _load();
  }

  Future<void> _toggleDone(TodoWithContact item) async {
    await _todoRepo.toggleCompleted(item.id);
    _load();
    if (!mounted || item.isCompleted) return;
    _snack(
      'Marked done',
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          await _todoRepo.toggleCompleted(item.id);
          _load();
        },
      ),
    );
  }

  Future<void> _openPerson(TodoWithContact item) async {
    await Navigator.pushNamed(context, AppRoutes.contactDetail, arguments: item.contactId);
    if (mounted) _load();
  }

  Future<void> _actions(TodoWithContact item) async {
    final sb = context.sb;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: sb.canvas,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (ctx) => _ActionsSheet(title: item.title),
    );
    if (!mounted || action == null) return;
    if (action == 'person') return _openPerson(item);
    if (action == 'edit') {
      final contacts = await ContactRepository().getAll();
      if (!mounted) return;
      final changed = await showPromiseSheet(context, contacts: contacts, editing: item.todo);
      if (changed == null) return;
      await _todoRepo.update(changed);
      _load();
      return;
    }
    await _todoRepo.delete(item.id);
    _load();
    _snack(
      'Promise deleted',
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          await _todoRepo.insert(item.todo);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_failed) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Couldn't load promises", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    final now = _now;
    final open = _all.where((t) => !t.isCompleted);
    final mineCount = open.where((t) => t.todo.owedBy == OwedBy.me).length;
    final theirsCount = open.where((t) => t.todo.owedBy == OwedBy.them).length;
    final side = open.where((t) => t.todo.owedBy == _side).toList()
      ..sort((a, b) => (a.todo.dueAt ?? DateTime(9999)).compareTo(b.todo.dueAt ?? DateTime(9999)));
    final done = _all.where((t) => t.isCompleted && t.todo.owedBy == _side).toList()
      ..sort((a, b) => (b.completedAt ?? b.createdAt).compareTo(a.completedAt ?? a.createdAt));

    final late = <TodoWithContact>[];
    final week = <TodoWithContact>[];
    final later = <TodoWithContact>[];
    final anytime = <TodoWithContact>[];
    for (final item in side) {
      final due = item.todo.dueAt;
      if (due == null) {
        anytime.add(item);
      } else if (due.isBefore(now)) {
        late.add(item);
      } else if (DayLabels.daysBetween(now, due) < 7) {
        week.add(item);
      } else {
        later.add(item);
      }
    }

    final groups = [
      (label: 'Late', items: late, isLate: true),
      (label: 'This week', items: week, isLate: false),
      (label: 'Later', items: later, isLate: false),
      (label: 'Any time', items: anytime, isLate: false),
    ].where((g) => g.items.isNotEmpty).toList();

    final sb = context.sb;
    var delay = 0;
    Duration nextDelay() => Duration(milliseconds: (delay++ * 80).clamp(0, 240));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ConstrainedLayout(
          child: RefreshIndicator(
            color: sb.primary,
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 128),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text('Promises', style: Theme.of(context).textTheme.headlineLarge),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SbCircleButton(icon: LucideIcons.plus, tooltip: 'Add a promise', onPressed: _add, filled: true),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SbRise(
                  delay: nextDelay(),
                  child: _SideSwitch(
                    side: _side,
                    mine: mineCount,
                    theirs: theirsCount,
                    onChanged: (side) => setState(() {
                      _side = side;
                      _showDone = false;
                    }),
                  ),
                ),
                if (groups.isEmpty) ...[
                  const SizedBox(height: 22),
                  _Nothing(side: _side),
                ],
                for (final group in groups) ...[
                  const SizedBox(height: 22),
                  SbCap(group.label, color: group.isLate ? sb.late : null),
                  SbRise(
                    delay: nextDelay(),
                    child: SbCard(
                      child: Column(
                        children: [
                          for (var i = 0; i < group.items.length; i++)
                            _PromiseRow(
                              item: group.items[i],
                              side: _side,
                              now: now,
                              first: i == 0,
                              onOpen: () => _openPerson(group.items[i]),
                              onLongPress: () => _actions(group.items[i]),
                              onDone: () => _toggleDone(group.items[i]),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (done.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _showDone = !_showDone),
                      child: Text(_showDone ? 'Hide done' : 'Show done · ${done.length}'),
                    ),
                  ),
                  if (_showDone)
                    SbCard(
                      child: Column(
                        children: [
                          for (var i = 0; i < done.length; i++)
                            _PromiseRow(
                              item: done[i],
                              side: _side,
                              now: now,
                              first: i == 0,
                              onOpen: () => _openPerson(done[i]),
                              onLongPress: () => _actions(done[i]),
                              onDone: () => _toggleDone(done[i]),
                            ),
                        ],
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

/// "You owe 5 | Owed to you 3" in a pill; the chosen side is espresso.
class _SideSwitch extends StatelessWidget {
  const _SideSwitch({required this.side, required this.mine, required this.theirs, required this.onChanged});

  final OwedBy side;
  final int mine;
  final int theirs;
  final ValueChanged<OwedBy> onChanged;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    Widget tab(OwedBy value, String label, int count) {
      final selected = side == value;
      final style = TextStyle(
        fontSize: 15,
        height: 20 / 15,
        fontWeight: FontWeight.w600,
        color: selected ? sb.onPrimary : sb.text2,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: '$label, $count',
          excludeSemantics: true,
          child: SbPressable(
            onTap: () => onChanged(value),
            child: Container(
              height: 42,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: selected ? sb.primary : null, borderRadius: BorderRadius.circular(99)),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$label '),
                    TextSpan(
                      text: '$count',
                      style: TextStyle(color: selected ? sb.onPrimary.withValues(alpha: 0.7) : sb.text2),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ),
        ),
      );
    }

    return SbCard(
      radius: 999,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          tab(OwedBy.me, 'You owe', mine),
          const SizedBox(width: 4),
          tab(OwedBy.them, 'Owed to you', theirs),
        ],
      ),
    );
  }
}

/// Face, what was promised and to (or from) whom, when, and the done circle.
class _PromiseRow extends StatelessWidget {
  const _PromiseRow({
    required this.item,
    required this.side,
    required this.now,
    required this.first,
    required this.onOpen,
    required this.onLongPress,
    required this.onDone,
  });

  final TodoWithContact item;
  final OwedBy side;
  final DateTime now;
  final bool first;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final firstName = item.contactName.trim().split(RegExp(r'\s+')).first;
    final who = side == OwedBy.me ? 'to $firstName' : 'from $firstName';
    final due = item.todo.dueAt;
    final done = item.isCompleted;
    final late = !done && due != null && due.isBefore(now);
    final when = due == null ? '' : (late ? DayLabels.late(due, now) : DayLabels.due(due, now));
    return Container(
      constraints: BoxConstraints(minHeight: first ? 66 : 67),
      decoration: first
          ? null
          : BoxDecoration(
              border: Border(top: BorderSide(color: sb.fill)),
            ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: '${item.title}, $who${when.isEmpty ? '' : ', $when'}',
              hint: 'Opens $firstName. Long-press to change or delete.',
              excludeSemantics: true,
              child: InkWell(
                onTap: onOpen,
                onLongPress: onLongPress,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 66),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Row(
                      children: [
                        SbFace(name: item.contactName, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    height: 22 / 16,
                                    fontWeight: FontWeight.w600,
                                    color: done ? sb.text3 : sb.text,
                                    decoration: done ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                Text(
                                  who,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, height: 18 / 13, color: sb.text2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (when.isNotEmpty && !done) ...[
                          const SizedBox(width: 12),
                          Text(
                            when,
                            style: TextStyle(
                              fontSize: 13,
                              height: 18 / 13,
                              fontWeight: FontWeight.w700,
                              color: late ? sb.late : sb.text2,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                        const SizedBox(width: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: done ? 'Mark not done: ${item.title}' : 'Mark done: ${item.title}',
            excludeSemantics: true,
            child: InkResponse(
              onTap: onDone,
              radius: 22,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? sb.primary : null,
                      border: done ? null : Border.all(color: sb.track, width: 2),
                    ),
                    child: done ? Icon(LucideIcons.check, size: 14, color: sb.onPrimary) : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _Nothing extends StatelessWidget {
  const _Nothing({required this.side});

  final OwedBy side;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final text = Theme.of(context).textTheme;
    return SbCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: sb.fill, borderRadius: BorderRadius.circular(12)),
            child: Icon(LucideIcons.arrowLeftRight, size: 20, color: sb.text2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  side == OwedBy.me ? 'Nothing you owe' : 'No one owes you',
                  style: text.titleSmall?.copyWith(fontSize: 16),
                ),
                Text('Promises from your notes land here', style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionsSheet extends StatelessWidget {
  const _ActionsSheet({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final actions = [
      (id: 'person', icon: LucideIcons.user, label: 'Open person', danger: false),
      (id: 'edit', icon: LucideIcons.pencil, label: 'Change', danger: false),
      (id: 'delete', icon: LucideIcons.trash2, label: 'Delete', danger: true),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          SbCard(
            child: Column(
              children: [
                for (var i = 0; i < actions.length; i++)
                  InkWell(
                    onTap: () => Navigator.pop(context, actions[i].id),
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
                          Text(
                            actions[i].label,
                            style: TextStyle(
                              fontSize: 16,
                              height: 22 / 16,
                              fontWeight: FontWeight.w600,
                              color: actions[i].danger ? sb.late : sb.text,
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
    );
  }
}
