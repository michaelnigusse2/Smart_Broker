import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../core/widgets/contact_card.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/contact_merge_service.dart';
import '../../../core/repositories/reminder_repository.dart';
import '../../../models/unified_contact.dart';

// ─── Filter definition ───────────────────────────────────────────────────────
enum ContactFilter { all, recent, hasTasks, overdue }

extension ContactFilterLabel on ContactFilter {
  String get label {
    switch (this) {
      case ContactFilter.all:
        return 'All';
      case ContactFilter.recent:
        return 'Recent';
      case ContactFilter.hasTasks:
        return 'Has Tasks';
      case ContactFilter.overdue:
        return 'Overdue';
    }
  }
}

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ContactMergeService _mergeService = ContactMergeService();
  final ReminderRepository _reminderRepo = ReminderRepository();

  List<UnifiedContact> _allContacts = [];
  Set<String> _overdueContactIds = {};
  bool _isLoading = true;
  String? _error;

  String _searchQuery = '';
  ContactFilter _activeFilter = ContactFilter.all;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final contacts = await _mergeService.getUnifiedContacts();
      final overdueReminders = await _reminderRepo.getOverdue();
      final overdueIds = overdueReminders.map((r) => r.contactId).toSet();

      if (mounted) {
        setState(() {
          _allContacts = contacts;
          _overdueContactIds = overdueIds;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<UnifiedContact> get _filteredContacts {
    // 1. Apply search
    var contacts = _allContacts.where((c) {
      return c.name.toLowerCase().contains(_searchQuery.toLowerCase()) || c.phoneNumber.contains(_searchQuery);
    }).toList();

    // 2. Apply filter
    switch (_activeFilter) {
      case ContactFilter.all:
        // Already sorted alphabetically by ContactMergeService,
        // but let's keep the existing logic of recent first for 'All'
        // Wait, the plan says we merge and sort alphabetically. Let's just return them.
        break;
      case ContactFilter.recent:
        // Interacted within the last 7 days
        final cutoff = DateTime.now().subtract(const Duration(days: 7));
        contacts =
            contacts
                .where((c) => c.lastInteraction.isAfter(cutoff) && c.lastInteraction.millisecondsSinceEpoch > 0)
                .toList()
              ..sort((a, b) => b.lastInteraction.compareTo(a.lastInteraction));
        break;
      case ContactFilter.hasTasks:
        contacts = contacts.where((c) => c.pendingTasksCount > 0).toList()
          ..sort((a, b) => b.pendingTasksCount.compareTo(a.pendingTasksCount));
        break;
      case ContactFilter.overdue:
        contacts = contacts.where((c) => _overdueContactIds.contains(c.id)).toList();
        break;
    }

    return contacts;
  }

  int? _badgeCount(ContactFilter filter) {
    switch (filter) {
      case ContactFilter.hasTasks:
        return _allContacts.where((c) => c.pendingTasksCount > 0).length;
      case ContactFilter.overdue:
        return _overdueContactIds.length;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(child: Text('Error: $_error')),
      );
    }

    final filtered = _filteredContacts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.userPlus),
            onPressed: () {},
            tooltip: 'Add contact',
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: ConstrainedLayout(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Search ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search contacts…',
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),

            // ─── Filters ────────────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: Row(
                children: ContactFilter.values.map((filter) {
                  final isSelected = _activeFilter == filter;
                  final int? badge = _badgeCount(filter);
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: GestureDetector(
                      onTap: () => setState(() => _activeFilter = filter),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.textPrimary : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              filter.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isSelected ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                            if (badge != null && badge > 0) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.25)
                                      : AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$badge',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // ─── Result count ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: Text(
                '${filtered.length} contact${filtered.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textTertiary),
              ),
            ),

            // ─── List ───────────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyState(filter: _activeFilter)
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 100),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return ContactCard(
                            contact: filtered[index],
                            onTap: () {
                              if (filtered[index].isSmartBrokerContact) {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.contactDetail,
                                  arguments: filtered[index].id,
                                ).then((_) => _loadData());
                              } else {
                                // We will create this route
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.phoneContactDetail,
                                  arguments: filtered[index],
                                ).then((_) => _loadData());
                              }
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state per filter ──────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final ContactFilter filter;

  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    String message;
    IconData icon;
    switch (filter) {
      case ContactFilter.recent:
        message = 'No contacts in the last 7 days';
        icon = LucideIcons.clock;
        break;
      case ContactFilter.hasTasks:
        message = 'No contacts with pending tasks';
        icon = LucideIcons.checkSquare;
        break;
      case ContactFilter.overdue:
        message = 'No overdue follow-ups';
        icon = LucideIcons.alarmCheck;
        break;
      default:
        message = 'No contacts found';
        icon = LucideIcons.users;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
