import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import '../../models/phone_contact.dart';

class PhoneContactService {
  /// Request permissions to read contacts
  Future<bool> requestPermission() async {
    final status = await fc.FlutterContacts.permissions.request(fc.PermissionType.read);
    return status == fc.PermissionStatus.granted;
  }

  /// Fetches all device contacts that have at least one phone number
  Future<List<PhoneContact>> getContacts() async {
    // We only need basic info and properties (phones)
    final contacts = await fc.FlutterContacts.getAll(
      properties: {fc.ContactProperty.phone}, 
    );

    final List<PhoneContact> phoneContacts = [];

    for (final c in contacts) {
      if (c.phones.isNotEmpty) {
        // Just take the first phone number for now
        final phone = c.phones.first.number;
        
        // We'll skip fetching photos in bulk to keep it fast, but we can store the ID
        // so we could fetch it individually if needed later.
        phoneContacts.add(PhoneContact(
          id: c.id ?? '',
          displayName: c.displayName ?? '',
          phoneNumber: phone,
          photoUrl: null, // You can map c.photo if you use withPhoto: true
        ));
      }
    }

    return phoneContacts;
  }

  /// Finds a device contact with the same number (last 9 digits, like call matching).
  Future<PhoneContact?> findByPhoneNumber(String number) async {
    final contacts = await getContacts();
    for (final c in contacts) {
      if (PhoneContact.numbersMatch(c.phoneNumber, number)) return c;
    }
    return null;
  }
}
