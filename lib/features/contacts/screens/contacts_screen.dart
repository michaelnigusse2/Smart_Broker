import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/repositories/contact_repository.dart';
import '../../../core/repositories/reminder_repository.dart';
import '../../../core/repositories/todo_repository.dart';
import '../../../core/services/app_log.dart';
import '../../../core/services/contact_merge_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sb_widgets.dart';
import '../../../core/utils/day_labels.dart';
import '../../../core/utils/waiting_on_you.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../models/unified_contact.dart';
import '../../home/screens/main_shell.dart';

/// The People tab, built to the "Espresso · final" People board: the title
/// with search and add, the four people waiting on you most, then everyone.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, this.clock});

  /// Fixed "now" for tests.
  final DateTime Function()? clock;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  List<UnifiedContact> _everyone = [];
  List<WaitingPerson> _waiting = [];
  bool _loading = true;
  bool _failed = false;
  bool _searching = false;
  String _query = '';

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
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (MainShell.currentTab.value == MainShell.contactsTab) _load();
  }

  Future<void> _load() async {
    try {
      final everyone = await ContactMergeService().getUnifiedContacts();
      final contacts = await ContactRepository().getAll();
      final pending = await TodoRepository().getPending();
      final reminders = await ReminderRepository().getOpen();
      final now = _now;
      final missed = reminders.where((r) => r.dateTime.isBefore(now.subtract(const Duration(minutes: 5))));
      if (!mounted) return;
      setState(() {
        _everyone = everyone;
        _waiting = waitingOnYou(
          pending: pending,
          missed: missed,
          contacts: {for (final c in contacts) c.id: c},
          now: now,
        );
        _loading = false;
        _failed = false;
      });
    } catch (e, st) {
      AppLog.e('People', 'could not load people', e, st);
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  /// Names match anywhere; numbers match regardless of spaces, dashes or
  /// +251 vs 0.
  List<UnifiedContact> get _matches {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _everyone;
    final digits = query.replaceAll(RegExp(r'\D'), '');
    final local = digits.startsWith('0') ? digits.substring(1) : digits;
    return _everyone.where((c) {
      if (c.name.toLowerCase().contains(query)) return true;
      if (digits.length < 3) return false;
      final number = c.phoneNumber.replaceAll(RegExp(r'\D'), '');
      return number.contains(digits) || (local.length >= 3 && number.contains(local));
    }).toList();
  }

  void _startSearch() {
    setState(() => _searching = true);
    _searchFocus.requestFocus();
  }

  void _endSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _searching = false;
      _query = '';
    });
  }

  /// Opens the new-contact form, then the saved (or already existing) contact.
  Future<void> _addPerson() async {
    final id = await Navigator.pushNamed(context, AppRoutes.contactForm);
    if (!mounted) return;
    if (id is String) {
      await Navigator.pushNamed(context, AppRoutes.contactDetail, arguments: id);
    }
    if (mounted) _load();
  }

  Future<void> _open(UnifiedContact person) async {
    if (person.isSmartBrokerContact) {
      await Navigator.pushNamed(context, AppRoutes.contactDetail, arguments: person.id);
    } else {
      await Navigator.pushNamed(context, AppRoutes.phoneContactDetail, arguments: person);
    }
    if (mounted) _load();
  }

  Future<void> _openContact(String id) async {
    await Navigator.pushNamed(context, AppRoutes.contactDetail, arguments: id);
    if (mounted) _load();
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
              Text("Couldn't load people", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    final sb = context.sb;
    final people = _matches;
    final now = _now;
    final showWaiting = !_searching && _waiting.isNotEmpty;
    final String listLabel;
    if (_searching && _query.trim().isNotEmpty) {
      listLabel = people.isEmpty ? 'No one found' : '${people.length} found';
    } else {
      listLabel = 'Everyone · ${_everyone.length}';
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ConstrainedLayout(
          child: RefreshIndicator(
            color: sb.primary,
            onRefresh: _load,
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _searching
                        ? _SearchBar(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            onChanged: (v) => setState(() => _query = v),
                            onClose: _endSearch,
                          )
                        : _Header(onSearch: _startSearch, onAdd: _addPerson),
                  ),
                ),
                if (showWaiting)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SbCap('Waiting on you'),
                          SbRise(
                            child: _WaitingGrid(
                              people: _waiting.take(4).toList(),
                              now: now,
                              onTap: (p) => _openContact(p.contact.id),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                  sliver: SliverToBoxAdapter(child: SbCap(listLabel)),
                ),
                if (people.isEmpty && !_searching)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(child: _NoOneYet(onAdd: _addPerson)),
                  )
                else if (people.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: DecoratedSliver(
                      decoration: BoxDecoration(
                        color: sb.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: sb.shadow, blurRadius: 2, offset: const Offset(0, 1))],
                      ),
                      sliver: SliverList.builder(
                        itemCount: people.length,
                        itemBuilder: (context, i) => _PersonRow(
                          person: people[i],
                          ago: DayLabels.ago(people[i].lastInteraction, now),
                          first: i == 0,
                          last: i == people.length - 1,
                          onTap: () => _open(people[i]),
                        ),
                      ),
                    ),
                  ),
                // Room for the floating tab bar.
                const SliverToBoxAdapter(child: SizedBox(height: 128)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "People" in Bricolage 34/40, a search circle and an espresso add circle.
class _Header extends StatelessWidget {
  const _Header({required this.onSearch, required this.onAdd});

  final VoidCallback onSearch;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text('People', style: Theme.of(context).textTheme.headlineLarge),
            ),
          ),
          const SizedBox(width: 10),
          SbCircleButton(icon: LucideIcons.search, tooltip: 'Search people', onPressed: onSearch),
          const SizedBox(width: 10),
          SbCircleButton(icon: LucideIcons.plus, tooltip: 'Add a person', onPressed: onAdd, filled: true),
        ],
      ),
    );
  }
}

/// The search field that takes the title's place: a 44 dp pill and a close
/// circle, so the page doesn't jump.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.focusNode, required this.onChanged, required this.onClose});

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: BorderSide(color: sb.track, width: 1.5),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                style: TextStyle(fontSize: 16, height: 22 / 16, color: sb.text),
                decoration: InputDecoration(
                  hintText: 'Name or number',
                  prefixIcon: Icon(LucideIcons.search, size: 18, color: sb.text2),
                  filled: true,
                  fillColor: sb.surface,
                  contentPadding: EdgeInsets.zero,
                  border: pill,
                  enabledBorder: pill,
                  focusedBorder: pill.copyWith(borderSide: BorderSide(color: sb.primary, width: 1.5)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SbCircleButton(icon: LucideIcons.x, tooltip: 'Close search', onPressed: onClose),
        ],
      ),
    );
  }
}

/// Four cards across: face, first name, and when it's due ("2d late" in red).
class _WaitingGrid extends StatelessWidget {
  const _WaitingGrid({required this.people, required this.now, required this.onTap});

  final List<WaitingPerson> people;
  final DateTime now;
  final ValueChanged<WaitingPerson> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: i < people.length
                ? _WaitingCard(person: people[i], now: now, onTap: () => onTap(people[i]))
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({required this.person, required this.now, required this.onTap});

  final WaitingPerson person;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final name = person.contact.name.trim();
    final first = name.split(RegExp(r'\s+')).first;
    final due = person.due;
    final String when;
    if (due == null) {
      when = person.late ? 'Late' : 'No date';
    } else {
      when = person.late ? DayLabels.late(due, now) : DayLabels.due(due, now);
    }
    return Semantics(
      button: true,
      label: '$name, $when',
      excludeSemantics: true,
      child: SbCard(
        radius: 22,
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
        child: Column(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SbFace(name: name, size: 52),
                  if (person.late) const Positioned(top: 1, right: 1, child: SbLateDot(size: 12)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, height: 18 / 14, fontWeight: FontWeight.w600, color: sb.text),
            ),
            const SizedBox(height: 4),
            Text(
              when,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 16 / 12,
                fontWeight: FontWeight.w700,
                color: person.late ? sb.late : sb.text2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of the Everyone card: face, name, company or role, and how long
/// since you last talked.
class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.person,
    required this.ago,
    required this.first,
    required this.last,
    required this.onTap,
  });

  final UnifiedContact person;
  final String ago;
  final bool first;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final detail = person.company.trim().isNotEmpty ? person.company.trim() : person.role.trim();
    final radius = BorderRadius.vertical(
      top: first ? const Radius.circular(24) : Radius.zero,
      bottom: last ? const Radius.circular(24) : Radius.zero,
    );
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        // 64 dp rows, plus the 1 dp line above each one after the first, as on the board.
        child: Container(
          constraints: BoxConstraints(minHeight: first ? 64 : 65),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: first
              ? null
              : BoxDecoration(
                  border: Border(top: BorderSide(color: sb.fill)),
                ),
          child: Row(
            children: [
              SbFace(name: person.name, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        person.name,
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
              ),
              if (ago.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(
                  ago,
                  style: TextStyle(
                    fontSize: 13,
                    height: 18 / 13,
                    fontWeight: FontWeight.w600,
                    color: sb.text2,
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

class _NoOneYet extends StatelessWidget {
  const _NoOneYet({required this.onAdd});

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
            child: Icon(LucideIcons.users, size: 20, color: sb.text2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No one here yet', style: text.titleSmall?.copyWith(fontSize: 16)),
                Text('Add the people you call', style: text.bodySmall),
              ],
            ),
          ),
          TextButton(onPressed: onAdd, child: const Text('Add')),
        ],
      ),
    );
  }
}
