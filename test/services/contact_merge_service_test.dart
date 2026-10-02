import 'package:flutter_test/flutter_test.dart';
import 'package:smart_broker/core/repositories/contact_repository.dart';
import 'package:smart_broker/core/services/contact_merge_service.dart';
import 'package:smart_broker/core/services/phone_contact_service.dart';
import 'package:smart_broker/models/contact.dart';
import 'package:smart_broker/models/phone_contact.dart';

class _FakeContactRepository extends ContactRepository {
  final List<Contact> contacts;
  _FakeContactRepository(this.contacts);

  @override
  Future<List<Contact>> getAll() async => contacts;
}

class _FakePhoneContactService extends PhoneContactService {
  final List<PhoneContact> contacts;
  final bool granted;
  final bool fails;
  _FakePhoneContactService(this.contacts, {this.granted = true, this.fails = false});

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<List<PhoneContact>> getContacts() async {
    if (fails) throw Exception('contacts plugin failed');
    return contacts;
  }
}

Contact _crm(String id, String name, String phone) => Contact(
  id: id,
  name: name,
  phoneNumber: phone,
  lastInteraction: DateTime(2026, 1, 1),
  pendingTasksCount: 2,
);

PhoneContact _phone(String id, String name, String phone) =>
    PhoneContact(id: id, displayName: name, phoneNumber: phone);

void main() {
  ContactMergeService service(List<Contact> crm, List<PhoneContact> phone, {bool granted = true, bool fails = false}) =>
      ContactMergeService(
        contactRepo: _FakeContactRepository(crm),
        phoneService: _FakePhoneContactService(phone, granted: granted, fails: fails),
      );

  test('merges the same number in different formats; SmartBroker data wins', () async {
    final result = await service(
      [_crm('crm-1', 'Test Client One', '+251 911 000 001')],
      [_phone('p-1', 'Client (phone book)', '0911-000-001')],
    ).getUnifiedContacts();

    final merged = result.single;
    expect(merged.id, 'crm-1');
    expect(merged.name, 'Test Client One');
    expect(merged.pendingTasksCount, 2);
    expect(merged.isSmartBrokerContact, isTrue);
    expect(merged.isPhoneContact, isTrue);
  });

  test('shows a person saved several times in the phone book once', () async {
    final result = await service(
      [_crm('crm-1', 'Test Client One', '+251911000001')],
      [
        _phone('sim', 'One (SIM)', '0911000001'),
        _phone('google', 'One (Google)', '+251 911 000 001'),
        _phone('p-2', 'Phone Only', '0911000002'),
        _phone('p-2b', 'Phone Only (copy)', '+251911000002'),
      ],
    ).getUnifiedContacts();

    expect(result.map((c) => c.id), ['p-2', 'crm-1']);
  });

  test('keeps SmartBroker contacts that are not in the phone book', () async {
    final result = await service(
      [_crm('crm-1', 'Test Client One', '+251911000001')],
      [_phone('p-9', 'Another Person', '0911000009')],
    ).getUnifiedContacts();

    final crmOnly = result.firstWhere((c) => c.id == 'crm-1');
    expect(crmOnly.isPhoneContact, isFalse);
    expect(result, hasLength(2));
  });

  test('falls back to SmartBroker contacts when permission is denied or reading fails', () async {
    final crm = [_crm('crm-1', 'Test Client One', '+251911000001')];
    final phone = [_phone('p-9', 'Another Person', '0911000009')];

    final denied = await service(crm, phone, granted: false).getUnifiedContacts();
    final failed = await service(crm, phone, fails: true).getUnifiedContacts();

    expect(denied.map((c) => c.id), ['crm-1']);
    expect(failed.map((c) => c.id), ['crm-1']);
  });

  test('sorts by name, ignoring case', () async {
    final result = await service(
      [_crm('b', 'beta Client', '+251911000002')],
      [_phone('a', 'Alpha Person', '0911000001'), _phone('c', 'Gamma Person', '0911000003')],
    ).getUnifiedContacts();

    expect(result.map((c) => c.name), ['Alpha Person', 'beta Client', 'Gamma Person']);
  });
}
