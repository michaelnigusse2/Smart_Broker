import 'package:flutter/material.dart';

import '../../../core/repositories/contact_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../models/contact.dart';
import '../../../models/phone_contact.dart';

/// Creates a contact, or edits the [Contact] passed as the route argument.
/// Pops with the saved contact's id (or an existing contact's id when the
/// user chooses to open the contact that already has this number).
class ContactFormScreen extends StatefulWidget {
  const ContactFormScreen({super.key});

  /// Name is required.
  static String? validateName(String? value) => (value == null || value.trim().isEmpty) ? 'Enter a name' : null;

  /// A phone number needs at least 7 digits; spaces, dashes and + are fine.
  static String? validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Enter a phone number';
    if (digits.length < 7) return 'That number looks too short';
    return null;
  }

  /// Email is optional, but must look like one if given.
  static String? validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ? null : 'Enter a valid email';
  }

  @override
  State<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends State<ContactFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = ContactRepository();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _company = TextEditingController();
  final _role = TextEditingController();

  Contact? _editing;
  bool _initialized = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Contact) {
      _editing = args;
      _name.text = args.name;
      _phone.text = args.phoneNumber;
      _email.text = args.email;
      _company.text = args.company;
      _role.text = args.role;
    } else if (args is String) {
      _phone.text = args; // prefilled number, e.g. from an unknown call
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _company, _role]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final phone = PhoneContact.normalizePhoneNumber(_phone.text.trim());
      final owner = await _repo.findByPhone(phone);
      if (!mounted) return;
      if (owner != null && owner.id != _editing?.id) {
        await _numberTaken(owner);
        return;
      }

      final contact = Contact(
        id: _editing?.id ?? '',
        name: _name.text.trim(),
        phoneNumber: phone,
        email: _email.text.trim(),
        company: _company.text.trim(),
        role: _role.text.trim(),
        lastInteraction: _editing?.lastInteraction ?? DateTime.now(),
        avatarUrl: _editing?.avatarUrl ?? '',
      );
      final String id;
      if (_editing == null) {
        id = await _repo.insert(contact);
      } else {
        await _repo.update(contact);
        id = contact.id;
      }
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save the contact: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The number already belongs to [owner]: offer to open that contact.
  Future<void> _numberTaken(Contact owner) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Number already saved'),
        content: Text('${owner.phoneNumber} belongs to ${owner.name}. A number can only belong to one contact.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Change number')),
          if (_editing == null)
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Open ${owner.name}')),
        ],
      ),
    );
    if (open == true && mounted) Navigator.pop(context, owner.id);
  }

  InputDecoration _decoration(String label, {String? hint}) =>
      InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing == null ? 'New contact' : 'Edit contact'),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: const Text('Save')),
        ],
      ),
      body: ConstrainedLayout(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              TextFormField(
                controller: _name,
                decoration: _decoration('Name *'),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: ContactFormScreen.validateName,
                autofocus: _editing == null && _phone.text.isNotEmpty,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _phone,
                decoration: _decoration('Phone *', hint: '+251 9…'),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator: ContactFormScreen.validatePhone,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _email,
                decoration: _decoration('Email'),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: ContactFormScreen.validateEmail,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _company,
                decoration: _decoration('Company'),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _role,
                decoration: _decoration('Role'),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_editing == null ? 'Save contact' : 'Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
