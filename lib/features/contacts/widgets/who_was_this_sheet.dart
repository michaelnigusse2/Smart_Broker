import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/repositories/contact_repository.dart';
import '../../../core/repositories/new_number_repository.dart';
import '../../../core/repositories/note_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sb_widgets.dart';
import '../../../core/utils/day_labels.dart';
import '../../../core/utils/phone_format.dart';
import '../../../models/contact.dart';
import '../../../models/new_number.dart';

enum _Choice { newPerson, known, ignore }

String _clock(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _length(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// "Talked 2:14 · 11:05", "Missed 09:12 · talked yesterday", "Called you 3 times · no answer".
String newNumberLine(NewNumber n, DateTime now) {
  String when(DateTime t) => DayLabels.daysBetween(t, now) == 0
      ? _clock(t)
      : DayLabels.daysBetween(t, now) == 1
      ? 'yesterday'
      : DayLabels.due(t, now);
  if (n.waitingForCallBack && n.talked) return 'Missed ${when(n.lastMissedAt!)} · talked ${when(n.lastTalkAt!)}';
  if (n.waitingForCallBack) {
    return n.missed > 1 ? 'Called you ${n.missed} times · no answer' : 'Missed ${when(n.lastMissedAt!)}';
  }
  if (n.talked) return 'Talked ${_length(n.lastTalk)} · ${when(n.lastTalkAt!)}';
  return 'Called ${when(n.lastAt)}';
}

/// "Who was this?" for a new number: save them as a new person, add the
/// number to someone you know, or ignore it. Returns the person's id when
/// the number was saved to someone.
Future<String?> showWhoWasThisSheet(BuildContext context, String phoneKey) async {
  final messenger = ScaffoldMessenger.of(context);
  final number = await NewNumberRepository().find(phoneKey);
  if (!context.mounted) return null;
  if (number == null) {
    messenger.showSnackBar(const SnackBar(content: Text('That number is already sorted')));
    return null;
  }
  final result = await showModalBottomSheet<(String?, String)>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: context.sb.canvas,
    builder: (_) => _WhoWasThis(number: number),
  );
  if (result == null) return null;
  final (contactId, message) = result;
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      persist: false,
      action: contactId == null
          ? null
          : SnackBarAction(
              label: 'Open',
              onPressed: () => AppRoutes.globalNavigatorKey.currentState?.pushNamed(
                AppRoutes.contactDetail,
                arguments: contactId,
              ),
            ),
    ),
  );
  return contactId;
}

class _WhoWasThis extends StatefulWidget {
  const _WhoWasThis({required this.number});

  final NewNumber number;

  @override
  State<_WhoWasThis> createState() => _WhoWasThisState();
}

class _WhoWasThisState extends State<_WhoWasThis> {
  final _repo = NewNumberRepository();
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _search = TextEditingController();
  _Choice _choice = _Choice.newPerson;
  List<Contact> _people = [];
  String? _pickedId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _search.addListener(_find);
    _find();
  }

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    final q = _search.text.trim();
    final repo = ContactRepository();
    final found = q.isEmpty ? await repo.getAll() : await repo.search(q);
    if (mounted) setState(() => _people = found.take(q.isEmpty ? 4 : 8).toList());
  }

  Future<void> _keepNote(String contactId) async {
    final note = await _repo.assignTo(widget.number.phoneKey, contactId);
    if (note.isNotEmpty) await NoteRepository().saveNote(contactId: contactId, rawText: note);
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      switch (_choice) {
        case _Choice.newPerson:
          final name = _name.text.trim();
          if (name.isEmpty) return;
          final id = await ContactRepository().insert(
            Contact(
              id: '',
              name: name,
              phoneNumber: widget.number.phoneNumber,
              company: _company.text.trim(),
              lastInteraction: widget.number.lastAt,
            ),
          );
          await _keepNote(id);
          navigator.pop((id, 'Saved $name'));
        case _Choice.known:
          final id = _pickedId;
          if (id == null) return;
          await ContactRepository().addOtherPhone(id, widget.number.phoneNumber);
          await _keepNote(id);
          final person = _people.firstWhere((p) => p.id == id);
          navigator.pop((id, 'Added the number to ${person.name}'));
        case _Choice.ignore:
          await _repo.ignore(widget.number.phoneKey);
          navigator.pop((null, 'Ignored ${prettyPhone(widget.number.phoneNumber)}'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final text = Theme.of(context).textTheme;
    final n = widget.number;
    final picked = _people.where((p) => p.id == _pickedId).firstOrNull;
    final (String button, bool ready) = switch (_choice) {
      _Choice.newPerson => ('Save as a new person', _name.text.trim().isNotEmpty),
      _Choice.known => (
        picked == null ? 'Pick who it is' : 'Add the number to ${picked.name.trim().split(RegExp(r'\s+')).first}',
        picked != null,
      ),
      _Choice.ignore => ('Ignore this number', true),
    };
    InputDecoration bare(String hint) => InputDecoration(
      hintText: hint,
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SbFace(name: '#', size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(prettyPhone(n.phoneNumber), style: text.headlineSmall),
                      Text(
                        'New number · ${newNumberLine(n, DateTime.now())}',
                        style: TextStyle(fontSize: 13, height: 18 / 13, color: sb.text2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (n.note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: sb.accentTint, borderRadius: BorderRadius.circular(18)),
                child: Row(
                  children: [
                    Icon(LucideIcons.stickyNote, size: 18, color: sb.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        n.note,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, height: 20 / 14, color: sb.text),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('Who was this?', style: text.titleMedium),
            ),
            const SizedBox(height: 10),
            SbSegmented<_Choice>(
              label: 'Who was this?',
              options: const [
                (_Choice.newPerson, 'New person'),
                (_Choice.known, 'I know them'),
                (_Choice.ignore, 'Not a client'),
              ],
              selected: _choice,
              onChanged: (c) => setState(() => _choice = c),
            ),
            const SizedBox(height: 14),
            switch (_choice) {
              _Choice.newPerson => SbCard(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _name,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                        decoration: bare('Their name'),
                      ),
                    ),
                    Container(height: 1, color: sb.fill),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _company,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: bare('Company or what they want (optional)'),
                      ),
                    ),
                  ],
                ),
              ),
              _Choice.known => SbCard(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _search,
                        decoration: bare('Whose number is this?').copyWith(
                          prefixIcon: Icon(LucideIcons.search, size: 18, color: sb.text2),
                          prefixIconConstraints: const BoxConstraints(minWidth: 30),
                        ),
                      ),
                    ),
                    for (final p in _people)
                      SbListRow(
                        leading: SbFace(name: p.name, size: 36),
                        title: p.name,
                        subtitle: [
                          if (p.company.trim().isNotEmpty) p.company.trim(),
                          p.allPhones.length == 1 ? '1 number' : '${p.allPhones.length} numbers',
                        ].join(' · '),
                        trailing: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: p.id == _pickedId ? sb.primary : sb.track,
                              width: p.id == _pickedId ? 7 : 2,
                            ),
                          ),
                        ),
                        onTap: () => setState(() => _pickedId = p.id),
                      ),
                  ],
                ),
              ),
              _Choice.ignore => SbCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No more cards or reminders for this number',
                      style: TextStyle(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "It won't show in New numbers again. Undo any time in Settings, Ignored numbers.",
                      style: TextStyle(fontSize: 14, height: 20 / 14, color: sb.text2),
                    ),
                  ],
                ),
              ),
            },
            const SizedBox(height: 16),
            SbPrimaryButton(label: button, onPressed: ready && !_busy ? _save : null),
          ],
        ),
      ),
    );
  }
}
