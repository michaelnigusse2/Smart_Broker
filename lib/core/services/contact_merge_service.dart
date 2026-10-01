import '../../models/contact.dart';
import '../../models/phone_contact.dart';
import '../../models/unified_contact.dart';
import '../repositories/contact_repository.dart';
import 'phone_contact_service.dart';

class ContactMergeService {
  final ContactRepository _contactRepo = ContactRepository();
  final PhoneContactService _phoneService = PhoneContactService();

  Future<List<UnifiedContact>> getUnifiedContacts() async {
    // 1. Fetch from both sources
    final smartContacts = await _contactRepo.getAll();
    List<PhoneContact> phoneContacts = [];
    
    // We try to fetch phone contacts, but if permission is denied, it will just return empty or throw
    // The service handles asking for permission, but UI should ideally do it.
    try {
      if (await _phoneService.requestPermission()) {
        phoneContacts = await _phoneService.getContacts();
      }
    } catch (e) {
      // If error (e.g. permission denied), we proceed with just smart contacts
      phoneContacts = [];
    }

    // 2. Build maps for merging
    final smartContactsByPhone = <String, Contact>{};
    for (var c in smartContacts) {
      final key = PhoneContact.matchKey(c.phoneNumber);
      if (key.isNotEmpty) {
        smartContactsByPhone[key] = c;
      }
    }

    final unifiedList = <UnifiedContact>[];
    final processedSmartContactIds = <String>{};

    // 3. Process Phone Contacts
    for (var pc in phoneContacts) {
      final match = smartContactsByPhone[PhoneContact.matchKey(pc.phoneNumber)];

      if (match != null) {
        // The same person is often saved several times (SIM, Google, WhatsApp).
        if (processedSmartContactIds.contains(match.id)) continue;
        // Merge! SmartBroker data wins for all fields
        unifiedList.add(UnifiedContact(
          id: match.id,
          name: match.name, // SmartBroker name takes precedence
          phoneNumber: match.phoneNumber,
          email: match.email,
          company: match.company,
          role: match.role,
          lastInteraction: match.lastInteraction,
          pendingTasksCount: match.pendingTasksCount,
          avatarUrl: match.avatarUrl,
          isSmartBrokerContact: true,
          isPhoneContact: true,
        ));
        processedSmartContactIds.add(match.id);
      } else {
        // Phone-only contact
        unifiedList.add(UnifiedContact(
          id: pc.id,
          name: pc.displayName,
          phoneNumber: pc.phoneNumber,
          lastInteraction: DateTime.fromMillisecondsSinceEpoch(0),
          isSmartBrokerContact: false,
          isPhoneContact: true,
        ));
      }
    }

    // 4. Add remaining SmartBroker contacts (not in phone book)
    for (var sc in smartContacts) {
      if (!processedSmartContactIds.contains(sc.id)) {
        unifiedList.add(UnifiedContact(
          id: sc.id,
          name: sc.name,
          phoneNumber: sc.phoneNumber,
          email: sc.email,
          company: sc.company,
          role: sc.role,
          lastInteraction: sc.lastInteraction,
          pendingTasksCount: sc.pendingTasksCount,
          avatarUrl: sc.avatarUrl,
          isSmartBrokerContact: true,
          isPhoneContact: false,
        ));
      }
    }

    // 5. Sort alphabetically by name
    unifiedList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return unifiedList;
  }
}
