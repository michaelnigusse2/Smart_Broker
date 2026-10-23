import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/repositories/call_repository.dart';
import '../../../core/repositories/contact_repository.dart';
import '../../../core/repositories/new_number_repository.dart';
import '../../../core/repositories/note_repository.dart';
import '../../../core/services/app_log.dart';
import '../../../core/services/phone_contact_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sb_widgets.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../models/contact.dart';
import '../../../models/phone_contact.dart';

/// Adds a person, or edits the [Contact] passed as the route argument (a
/// String argument prefills the number).
///
/// Pops with the saved person's id; with an existing person's id when the
/// number is already theirs and you choose to open them; or with
/// [deleteRequest] when you tap Delete while editing (the person screen
/// confirms and deletes).
class ContactFormScreen extends StatefulWidget {
  const ContactFormScreen({super.key});

  /// Popped when you ask to delete the person being edited.
  static const Symbol deleteRequest = #deletePerson;

  /// At most this many numbers per person.
  static const maxPhones = 5;

  /// Name is required.
  static String? validateName(String? value) => (value == null || value.trim().isEmpty) ? 'Enter a name' : null;

  /// A phone number needs at least 7 digits; spaces, dashes and + are fine.
  static String? validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Enter a phone number';
    if (digits.length < 7) return 'That number looks too short';
    return null;
  }

  /// Another number is optional (an empty row is dropped), but must look
  /// like a number when given.
  static String? validateOtherPhone(String? value) => (value ?? '').trim().isEmpty ? null : validatePhone(value);

  /// Email is optional, but must look like one if given.
  static String? validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ? null : 'Enter a valid email';
  }

  /// "Mobile", "Second phone", "Third phone", then "Another phone".
  static String phoneLabel(int index) => switch (index) {
    0 => 'Mobile',
    1 => 'Second phone',
    2 => 'Third phone',
    _ => 'Another phone',
  };

  @override
  State<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends State<ContactFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = ContactRepository();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _company = TextEditingController();
  final _role = TextEditingController();

  /// The main number first, then the others.
  final List<TextEditingController> _phones = [TextEditingController()];
  final List<FocusNode> _phoneFocus = [FocusNode()];

  /// Problems found on save that a validator can't see: a number saved for
  /// someone else, or typed twice.
  final Map<TextEditingController, String> _phoneErrors = {};

  Contact? _editing;
  String _history = '';
  bool _initialized = false;
  bool _saving = false;

  bool get _isNew => _editing == null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Contact) {
      _editing = args;
      _name.text = args.name;
      _phones.first.text = args.phoneNumber;
      for (final p in args.otherPhones) {
        _phones.add(TextEditingController(text: p));
        _phoneFocus.add(FocusNode());
      }
      _email.text = args.email;
      _company.text = args.company;
      _role.text = args.role;
      _loadHistory(args);
    } else if (args is String) {
      _phones.first.text = args; // prefilled number, e.g. from a new number
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _company, _role, ..._phones]) {
      c.dispose();
    }
    for (final f in _phoneFocus) {
      f.dispose();
    }
    super.dispose();
  }

  /// "Known since March · 14 calls", from their call history.
  Future<void> _loadHistory(Contact contact) async {
    try {
      final calls = await CallRepository().getByContactId(contact.id);
      if (!mounted) return;
      if (calls.isEmpty) {
        setState(() => _history = 'No calls yet');
        return;
      }
      final first = calls.map((c) => c.timestamp).reduce((a, b) => a.isBefore(b) ? a : b);
      final month = first.year == DateTime.now().year
          ? DateFormat('MMMM').format(first)
          : DateFormat('MMMM y').format(first);
      final count = calls.length == 1 ? '1 call' : '${calls.length} calls';
      setState(() => _history = 'Known since $month · $count');
    } catch (e, st) {
      AppLog.e('PersonForm', 'could not load call history', e, st);
    }
  }

  void _addPhone() {
    if (_phones.length >= ContactFormScreen.maxPhones) return;
    final focus = FocusNode();
    setState(() {
      _phones.add(TextEditingController());
      _phoneFocus.add(focus);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focus.requestFocus();
    });
  }

  void _removePhone(int index) {
    if (index == 0) return;
    final controller = _phones[index];
    final focus = _phoneFocus[index];
    setState(() {
      _phones.removeAt(index);
      _phoneFocus.removeAt(index);
      _phoneErrors.remove(controller);
    });
    // The row is gone after this frame; dispose then.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
      focus.dispose();
    });
  }

  void _clearError(TextEditingController controller) {
    if (_phoneErrors.remove(controller) != null) setState(() {});
  }

  Future<void> _save() async {
    if (_saving) return;
    _phoneErrors.clear();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final main = PhoneContact.normalizePhoneNumber(_phones.first.text.trim());

      // Other numbers: the typed ones, once each, never the main one again.
      final others = <String>[];
      final keys = {PhoneContact.matchKey(main)};
      for (final c in _phones.skip(1)) {
        final raw = c.text.trim();
        if (raw.isEmpty) continue;
        final number = PhoneContact.normalizePhoneNumber(raw);
        if (!keys.add(PhoneContact.matchKey(number))) {
          _phoneErrors[c] = 'This number is already on the list';
        } else {
          others.add(number);
        }
      }

      // A number belongs to one person.
      final mainOwner = await _repo.findByPhone(main);
      if (!mounted) return;
      if (mainOwner != null && mainOwner.id != _editing?.id) {
        if (_isNew) {
          await _numberTaken(mainOwner);
          return;
        }
        _phoneErrors[_phones.first] = 'Already saved for ${mainOwner.name}';
      }
      for (final c in _phones.skip(1)) {
        if (c.text.trim().isEmpty || _phoneErrors.containsKey(c)) continue;
        final owner = await _repo.findByPhone(c.text.trim());
        if (owner != null && owner.id != _editing?.id) _phoneErrors[c] = 'Already saved for ${owner.name}';
      }
      if (!mounted) return;
      if (_phoneErrors.isNotEmpty) {
        _formKey.currentState?.validate();
        return;
      }

      final base = _editing ?? Contact(id: '', name: '', phoneNumber: '', lastInteraction: DateTime.now());
      final contact = base.copyWith(
        name: _name.text.trim(),
        phoneNumber: main,
        otherPhones: others,
        email: _email.text.trim(),
        company: _company.text.trim(),
        role: _role.text.trim(),
      );
      final String id;
      if (_isNew) {
        id = await _repo.insert(contact);
      } else {
        await _repo.update(contact);
        id = contact.id;
      }
      await _takeNewNumberCalls(id, contact.allPhones);
      if (mounted) Navigator.pop(context, id);
    } catch (e, st) {
      AppLog.e('PersonForm', 'could not save', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't save. Try again.")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Calls from these numbers that waited in New numbers now belong to the
  /// person, with any note typed during them.
  Future<void> _takeNewNumberCalls(String contactId, List<String> numbers) async {
    final newNumbers = NewNumberRepository();
    for (final number in numbers) {
      final key = PhoneContact.matchKey(number);
      if (key.isEmpty) continue;
      try {
        final note = await newNumbers.assignTo(key, contactId);
        if (note.isNotEmpty) await NoteRepository().saveNote(contactId: contactId, rawText: note);
      } catch (e, st) {
        AppLog.e('PersonForm', 'could not move a new number\'s calls', e, st);
      }
    }
  }

  /// The main number already belongs to [owner]: offer to open them.
  Future<void> _numberTaken(Contact owner) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Number already saved'),
        content: Text('${owner.phoneNumber} belongs to ${owner.name}. A number can only belong to one person.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Change number')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Open ${owner.name}')),
        ],
      ),
    );
    if (open == true && mounted) Navigator.pop(context, owner.id);
  }

  Future<void> _fromPhoneContacts() async {
    final messenger = ScaffoldMessenger.of(context);
    final service = PhoneContactService();
    try {
      if (!await service.requestPermission()) {
        messenger.showSnackBar(const SnackBar(content: Text('Allow contacts to pick someone from your phone')));
        return;
      }
      final all = await service.getContacts();
      if (!mounted) return;
      final picked = await showModalBottomSheet<PhoneContact>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: context.sb.canvas,
        builder: (_) => _PhoneContactPicker(contacts: all),
      );
      if (picked == null || !mounted) return;
      setState(() {
        if (picked.displayName.trim().isNotEmpty) _name.text = picked.displayName.trim();
        _phones.first.text = picked.phoneNumber;
        _phoneErrors.remove(_phones.first);
      });
    } catch (e, st) {
      AppLog.e('PersonForm', 'could not read phone contacts', e, st);
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't open your phone contacts")));
    }
  }

  String get _firstName {
    final parts = _name.text.trim().split(RegExp(r'\s+'));
    return parts.first.isEmpty ? (_editing?.name ?? '') : parts.first;
  }

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final text = Theme.of(context).textTheme;
    final editing = _editing;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ConstrainedLayout(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            SbCircleButton(
                              icon: LucideIcons.x,
                              tooltip: 'Close',
                              onPressed: () => Navigator.maybePop(context),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: Text(
                                  _isNew ? 'New person' : 'Edit person',
                                  style: text.headlineSmall?.copyWith(
                                    fontSize: 22,
                                    height: 28 / 22,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (editing != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 10, 4, 14),
                          child: Row(
                            children: [
                              SbFace(name: editing.name, size: 64),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  _history,
                                  style: TextStyle(fontSize: 13, height: 18 / 13, color: sb.text2),
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        const SizedBox(height: 8),
                        SbCard(
                          onTap: _fromPhoneContacts,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                SbIconTile(icon: LucideIcons.contact, tint: SbTint(sb.accentTint, sb.accent)),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'From phone contacts',
                                        style: TextStyle(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        'Fills in name and number',
                                        style: TextStyle(fontSize: 13, height: 18 / 13, color: sb.text2),
                                      ),
                                    ],
                                  ),
                                ),
                                const SbChevron(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      SbCard(
                        child: _Field(
                          label: 'Name',
                          controller: _name,
                          hint: 'Their name',
                          big: true,
                          first: true,
                          autofocus: _isNew && _phones.first.text.isNotEmpty,
                          textCapitalization: TextCapitalization.words,
                          validator: ContactFormScreen.validateName,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const SbCap('Phone'),
                      SbCard(
                        child: Column(
                          children: [
                            for (var i = 0; i < _phones.length; i++)
                              _Field(
                                key: ObjectKey(_phones[i]),
                                label: ContactFormScreen.phoneLabel(i),
                                controller: _phones[i],
                                focusNode: _phoneFocus[i],
                                hint: '+251 9…',
                                first: i == 0,
                                keyboardType: TextInputType.phone,
                                validator: (v) =>
                                    (i == 0
                                        ? ContactFormScreen.validatePhone(v)
                                        : ContactFormScreen.validateOtherPhone(v)) ??
                                    _phoneErrors[_phones[i]],
                                onChanged: (_) => _clearError(_phones[i]),
                                trailing: i == 0
                                    ? null
                                    : _RemoveButton(
                                        label: 'Remove ${ContactFormScreen.phoneLabel(i).toLowerCase()}',
                                        onTap: () => _removePhone(i),
                                      ),
                              ),
                            if (_phones.length < ContactFormScreen.maxPhones) _AddNumberRow(onTap: _addPhone),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const SbCap('Work'),
                      SbCard(
                        child: Column(
                          children: [
                            _Field(
                              label: 'Company',
                              controller: _company,
                              hint: 'Optional',
                              first: true,
                              textCapitalization: TextCapitalization.words,
                            ),
                            _Field(
                              label: 'Role',
                              controller: _role,
                              hint: 'Optional',
                              textCapitalization: TextCapitalization.sentences,
                            ),
                            _Field(
                              label: 'Email',
                              controller: _email,
                              hint: 'Optional',
                              keyboardType: TextInputType.emailAddress,
                              validator: ContactFormScreen.validateEmail,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _save(),
                            ),
                          ],
                        ),
                      ),
                      if (editing != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                            child: TextButton.icon(
                              onPressed: () => Navigator.pop(context, ContactFormScreen.deleteRequest),
                              style: TextButton.styleFrom(
                                foregroundColor: sb.late,
                                minimumSize: const Size(0, 44),
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              icon: const Icon(LucideIcons.trash2, size: 18),
                              label: Text('Delete $_firstName'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: sb.canvas,
                border: Border(top: BorderSide(color: sb.fill)),
              ),
              child: SafeArea(
                top: false,
                child: ConstrainedLayout(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: SbPrimaryButton(
                      label: _isNew ? 'Add person' : 'Save',
                      height: 54,
                      onPressed: _saving ? null : _save,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled field inside a card: small label on top, bare text below.
class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.big = false,
    this.first = false,
    this.autofocus = false,
    this.focusNode,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.trailing,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool big;
  final bool first;
  final bool autofocus;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    const none = InputBorder.none;
    return Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: EdgeInsets.fromLTRB(16, 10, trailing == null ? 16 : 8, 10),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: sb.fill)),
      ),
      child: Row(
        children: [
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600, color: sb.text2),
                  ),
                  const SizedBox(height: 2),
                  TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: autofocus,
                    keyboardType: keyboardType,
                    textCapitalization: textCapitalization,
                    textInputAction: textInputAction,
                    validator: validator,
                    onChanged: onChanged,
                    onFieldSubmitted: onSubmitted,
                    style: big
                        ? TextStyle(fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w700, color: sb.text)
                        : TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w500, color: sb.text),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(color: sb.text3),
                      isDense: true,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      border: none,
                      enabledBorder: none,
                      focusedBorder: none,
                      errorBorder: none,
                      focusedErrorBorder: none,
                      disabledBorder: none,
                      errorStyle: TextStyle(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w600, color: sb.late),
                      errorMaxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// The small round minus beside another number.
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: SbPressable(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: sb.fill, shape: BoxShape.circle),
              child: Icon(LucideIcons.minus, size: 16, color: sb.text),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddNumberRow extends StatelessWidget {
  const _AddNumberRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: sb.fill)),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.plus, size: 18, color: sb.accent),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Add another number',
                  style: TextStyle(fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w600, color: sb.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pick someone from the phone's contacts: a search box and the list.
class _PhoneContactPicker extends StatefulWidget {
  const _PhoneContactPicker({required this.contacts});

  final List<PhoneContact> contacts;

  @override
  State<_PhoneContactPicker> createState() => _PhoneContactPickerState();
}

class _PhoneContactPickerState extends State<_PhoneContactPicker> {
  final _search = TextEditingController();
  late final List<PhoneContact> _sorted = [...widget.contacts]
    ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<PhoneContact> get _shown {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _sorted;
    final digits = q.replaceAll(RegExp(r'\D'), '');
    return [
      for (final c in _sorted)
        if (c.displayName.toLowerCase().contains(q) ||
            (digits.length >= 3 && c.phoneNumber.replaceAll(RegExp(r'\D'), '').contains(digits)))
          c,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final text = Theme.of(context).textTheme;
    final shown = _shown;
    final bottom = MediaQuery.paddingOf(context).bottom + MediaQuery.viewInsetsOf(context).bottom;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: sb.track, borderRadius: BorderRadius.circular(999)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 12),
              child: Text('From phone contacts', style: text.headlineSmall?.copyWith(fontSize: 22, height: 28 / 22)),
            ),
            SbCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search name or number',
                    hintStyle: TextStyle(color: sb.text3),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    prefixIcon: Icon(LucideIcons.search, size: 18, color: sb.text2),
                    prefixIconConstraints: const BoxConstraints(minWidth: 30),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: shown.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Text(
                        widget.contacts.isEmpty ? 'No contacts with a number on this phone' : 'No one matches',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: sb.text2),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(bottom: 16 + bottom),
                      itemCount: shown.length,
                      itemBuilder: (context, i) {
                        final c = shown[i];
                        final name = c.displayName.trim().isEmpty ? c.phoneNumber : c.displayName.trim();
                        final top = i == 0 ? const Radius.circular(AppRadius.lg) : Radius.zero;
                        final end = i == shown.length - 1 ? const Radius.circular(AppRadius.lg) : Radius.zero;
                        return Material(
                          color: sb.surface,
                          clipBehavior: Clip.antiAlias,
                          borderRadius: BorderRadius.vertical(top: top, bottom: end),
                          child: SbListRow(
                            first: i == 0,
                            leading: SbFace(name: name, size: 36),
                            title: name,
                            subtitle: c.phoneNumber,
                            onTap: () => Navigator.pop(context, c),
                          ),
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
