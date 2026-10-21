import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/repositories/contact_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sb_widgets.dart';
import '../../../models/contact.dart';
import '../../contacts/screens/contacts_screen.dart';
import '../../deals/screens/deals_screen.dart';
import '../../today/screens/today_screen.dart';
import '../../todos/screens/tasks_screen.dart';

/// The four tabs (Today, People, Promises, Deals) in a floating bar, with the
/// capture button beside it. Settings opens from the avatar on Today and the
/// calendar from Today's date.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static const homeTab = 0;
  static const contactsTab = 1;
  static const promisesTab = 2;
  static const dealsTab = 3;

  /// The calendar opens from Today's date now; kept for older callers.
  static const calendarTab = homeTab;

  /// The tab on screen, so tabs can refresh when they come back into view.
  static final ValueNotifier<int> currentTab = ValueNotifier(homeTab);

  /// Switches the tab from a screen inside the shell.
  static void selectTab(BuildContext context, int index) =>
      context.findAncestorStateOfType<_MainShellState>()?._select(index);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = MainShell.homeTab;

  static const _screens = [TodayScreen(), ContactsScreen(), TasksScreen(), DealsScreen()];

  static const _tabs = [
    (icon: LucideIcons.sun, label: 'Today'),
    (icon: LucideIcons.users, label: 'People'),
    (icon: LucideIcons.arrowLeftRight, label: 'Promises'),
    (icon: LucideIcons.briefcase, label: 'Deals'),
  ];

  @override
  void initState() {
    super.initState();
    MainShell.currentTab.value = _index;
  }

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    MainShell.currentTab.value = index;
  }

  Future<void> _capture() async {
    final contactId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _NoteForSheet(),
    );
    if (contactId == null || !mounted) return;
    await Navigator.of(context).pushNamed(AppRoutes.addNote, arguments: contactId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Row(
                children: [
                  Expanded(
                    child: _NavBar(tabs: _tabs, selected: _index, onSelect: _select),
                  ),
                  const SizedBox(width: 12),
                  _CaptureButton(onTap: _capture),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.tabs, required this.selected, required this.onSelect});

  final List<({IconData icon, String label})> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: sb.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: sb.hairline),
        boxShadow: [
          BoxShadow(color: sb.shadow, blurRadius: 2, offset: const Offset(0, 1)),
          BoxShadow(
            color: sb.shadow.withValues(alpha: sb.shadow.a * 1.6),
            blurRadius: 28,
            spreadRadius: -8,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: _NavItem(
                icon: tabs[i].icon,
                label: tabs[i].label,
                selected: i == selected,
                onTap: () => onSelect(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: SbPressable(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: 52,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? sb.primary : sb.surface.withValues(alpha: 0),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Icon(icon, size: selected ? 19 : 21, color: selected ? sb.onPrimary : sb.text2),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15),
              style: TextStyle(
                fontSize: 12,
                height: 16 / 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? sb.text : sb.text2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    return Tooltip(
      message: 'Add a note',
      child: Semantics(
        button: true,
        label: 'Add a note',
        excludeSemantics: true,
        child: SbPressable(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          haptic: false,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: sb.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: sb.shadow.withValues(alpha: 0.5),
                  blurRadius: 22,
                  spreadRadius: -10,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(LucideIcons.mic, size: 24, color: sb.onPrimary),
          ),
        ),
      ),
    );
  }
}

/// "Note for…": pick who the note is about. Most recent people first.
class _NoteForSheet extends StatefulWidget {
  const _NoteForSheet();

  @override
  State<_NoteForSheet> createState() => _NoteForSheetState();
}

class _NoteForSheetState extends State<_NoteForSheet> {
  final _repo = ContactRepository();
  final _query = TextEditingController();
  List<Contact> _people = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    final results = trimmed.isEmpty ? await _repo.getAll() : await _repo.search(trimmed);
    results.sort((a, b) => b.lastInteraction.compareTo(a.lastInteraction));
    if (!mounted || _query.text.trim() != trimmed) return;
    setState(() {
      _people = results.take(40).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final text = Theme.of(context).textTheme;
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text('Note for…', style: text.headlineSmall),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _query,
                onChanged: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Name or phone',
                  prefixIcon: Icon(LucideIcons.search, size: 20, color: sb.text2),
                  fillColor: sb.canvas,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(99),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(99),
                    borderSide: BorderSide(color: sb.primary, width: 2),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _people.isEmpty
                  ? Center(
                      child: Text('No one found', style: text.bodyMedium?.copyWith(color: sb.text2)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: _people.length,
                      itemBuilder: (context, i) {
                        final person = _people[i];
                        return ListTile(
                          minTileHeight: 64,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                          leading: SbFace(name: person.name, size: 40),
                          title: Text(
                            person.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall?.copyWith(fontSize: 16),
                          ),
                          subtitle: person.company.isEmpty
                              ? null
                              : Text(
                                  person.company,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodySmall,
                                ),
                          onTap: () => Navigator.of(context).pop(person.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
