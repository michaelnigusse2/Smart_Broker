import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sb_widgets.dart';
import '../../../core/utils/day_labels.dart';
import '../../../models/contact.dart';
import '../../../models/todo_item.dart';

/// Opens the sheet to make a promise, or to change [editing]. With [contact]
/// the person is fixed; otherwise the sheet lets you pick one of [contacts].
/// Returns the promise to save, or null when closed.
Future<TodoItem?> showPromiseSheet(
  BuildContext context, {
  Contact? contact,
  List<Contact> contacts = const [],
  TodoItem? editing,
}) {
  return showModalBottomSheet<TodoItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.sb.canvas,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
    builder: (_) => _PromiseSheet(contact: contact, contacts: contacts, editing: editing),
  );
}

enum _Due { none, today, tomorrow, picked }

class _PromiseSheet extends StatefulWidget {
  const _PromiseSheet({required this.contact, required this.contacts, required this.editing});

  final Contact? contact;
  final List<Contact> contacts;
  final TodoItem? editing;

  @override
  State<_PromiseSheet> createState() => _PromiseSheetState();
}

class _PromiseSheetState extends State<_PromiseSheet> {
  late final _title = TextEditingController(text: widget.editing?.title ?? '');
  late OwedBy _owedBy = widget.editing?.owedBy ?? OwedBy.me;
  late String? _contactId = widget.contact?.id ?? widget.editing?.contactId;
  _Due _due = _Due.none;
  DateTime? _picked;

  @override
  void initState() {
    super.initState();
    final due = widget.editing?.dueAt;
    if (due != null) {
      // Show "Today" or "Tomorrow" selected rather than the date itself.
      _picked = due;
      final days = DayLabels.daysBetween(DateTime.now(), due);
      _due = days == 0
          ? _Due.today
          : days == 1
          ? _Due.tomorrow
          : _Due.picked;
    }
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Contact? get _person {
    if (widget.contact != null) return widget.contact;
    for (final c in widget.contacts) {
      if (c.id == _contactId) return c;
    }
    return null;
  }

  /// Promises are due by the end of the chosen day.
  static DateTime _endOf(DateTime day) => DateTime(day.year, day.month, day.day, 23, 59);

  DateTime? get _dueAt {
    final now = DateTime.now();
    switch (_due) {
      case _Due.none:
        return null;
      case _Due.today:
        return _keptOn(now) ?? _endOf(now);
      case _Due.tomorrow:
        final tomorrow = now.add(const Duration(days: 1));
        return _keptOn(tomorrow) ?? _endOf(tomorrow);
      case _Due.picked:
        return _picked;
    }
  }

  /// The promise's own due time when it already falls on [day] (so
  /// changing something else keeps it as it was).
  DateTime? _keptOn(DateTime day) {
    final picked = _picked;
    return picked != null && DayLabels.daysBetween(day, picked) == 0 ? picked : null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: _picked ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (day == null || !mounted) return;
    setState(() {
      _due = _Due.picked;
      _picked = _endOf(day);
    });
  }

  void _save() {
    final title = _title.text.trim();
    final contactId = _contactId;
    if (title.isEmpty || contactId == null) return;
    final editing = widget.editing;
    final dueAt = _dueAt;
    final promise = editing == null
        ? TodoItem(id: '', contactId: contactId, title: title, createdAt: DateTime.now(), dueAt: dueAt, owedBy: _owedBy)
        : editing.copyWith(
            contactId: contactId,
            title: title,
            owedBy: _owedBy,
            dueAt: dueAt,
            clearDueAt: dueAt == null,
          );
    Navigator.pop(context, promise);
  }

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final text = Theme.of(context).textTheme;
    final first = (_person?.name.trim().split(RegExp(r'\s+')).first) ?? '';
    final theyLabel = first.isEmpty ? 'They owe' : '$first owes';
    final canSave = _title.text.trim().isNotEmpty && _contactId != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.editing == null ? 'New promise' : 'Change promise', style: text.headlineSmall),
            const SizedBox(height: 16),
            _Segmented(
              left: 'You owe',
              right: theyLabel,
              rightSelected: _owedBy == OwedBy.them,
              onChanged: (right) => setState(() => _owedBy = right ? OwedBy.them : OwedBy.me),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              autofocus: widget.editing == null,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              style: TextStyle(fontSize: 17, height: 24 / 17, fontWeight: FontWeight.w600, color: sb.text),
              decoration: const InputDecoration(hintText: 'What was promised?'),
            ),
            if (widget.contact == null) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _contactId,
                isExpanded: true,
                decoration: const InputDecoration(hintText: 'Who with?'),
                items: [
                  for (final c in widget.contacts)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (id) => setState(() => _contactId = id),
              ),
            ],
            const SizedBox(height: 18),
            const SbCap('When'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(label: 'No date', selected: _due == _Due.none, onTap: () => setState(() => _due = _Due.none)),
                _Chip(label: 'Today', selected: _due == _Due.today, onTap: () => setState(() => _due = _Due.today)),
                _Chip(
                  label: 'Tomorrow',
                  selected: _due == _Due.tomorrow,
                  onTap: () => setState(() => _due = _Due.tomorrow),
                ),
                _Chip(
                  label: _due == _Due.picked && _picked != null
                      ? DateFormat('EEE d MMM').format(_picked!)
                      : 'Pick a day',
                  selected: _due == _Due.picked,
                  onTap: _pickDate,
                ),
              ],
            ),
            const SizedBox(height: 24),
            SbPrimaryButton(label: 'Save', onPressed: canSave ? _save : null),
          ],
        ),
      ),
    );
  }
}

/// Two choices in a pill, like the Promises board's "You owe | Owed to you".
class _Segmented extends StatelessWidget {
  const _Segmented({required this.left, required this.right, required this.rightSelected, required this.onChanged});

  final String left;
  final String right;
  final bool rightSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    Widget side(String label, bool selected, bool isRight) => Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: SbPressable(
          onTap: () => onChanged(isRight),
          child: Container(
            height: 42,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? sb.primary : null,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                height: 20 / 15,
                fontWeight: FontWeight.w600,
                color: selected ? sb.onPrimary : sb.text2,
              ),
            ),
          ),
        ),
      ),
    );
    return SbCard(
      radius: 999,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          side(left, !rightSelected, false),
          const SizedBox(width: 4),
          side(right, rightSelected, true),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    return Semantics(
      button: true,
      selected: selected,
      child: SbPressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? sb.primary : sb.surface,
            borderRadius: BorderRadius.circular(99),
            boxShadow: selected ? null : [BoxShadow(color: sb.shadow, blurRadius: 2, offset: const Offset(0, 1))],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              height: 20 / 14,
              fontWeight: FontWeight.w600,
              color: selected ? sb.onPrimary : sb.text,
            ),
          ),
        ),
      ),
    );
  }
}
