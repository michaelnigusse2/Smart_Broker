import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../core/constants/app_routes.dart';
import '../../../models/unified_contact.dart';
import '../../../models/contact.dart';
import '../../../core/repositories/contact_repository.dart';

class PhoneContactDetailScreen extends StatefulWidget {
  const PhoneContactDetailScreen({super.key});

  @override
  State<PhoneContactDetailScreen> createState() => _PhoneContactDetailScreenState();
}

class _PhoneContactDetailScreenState extends State<PhoneContactDetailScreen> {
  UnifiedContact? _unifiedContact;
  bool _initialized = false;
  bool _isSaving = false;

  final ContactRepository _contactRepo = ContactRepository();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is UnifiedContact) {
        _unifiedContact = args;
      }
      _initialized = true;
    }
  }

  Future<void> _addToSmartBroker() async {
    if (_unifiedContact == null || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final newContact = Contact(
        id: '', // repo will generate uuid
        name: _unifiedContact!.name,
        phoneNumber: _unifiedContact!.phoneNumber,
        email: '',
        company: '',
        role: '',
        lastInteraction: DateTime.now(),
        pendingTasksCount: 0,
        avatarUrl: '',
      );

      final newId = await _contactRepo.insert(newContact);

      if (mounted) {
        Navigator.of(context).popAndPushNamed(
          AppRoutes.contactDetail,
          arguments: newId,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add contact: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unifiedContact == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Error: No contact provided.')),
      );
    }

    final theme = Theme.of(context);
    final contact = _unifiedContact!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ConstrainedLayout(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.xxl),

              // Avatar
              CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.surfaceElevated,
                foregroundColor: AppColors.textPrimary,
                child: Text(
                  contact.initials,
                  style: theme.textTheme.displaySmall?.copyWith(fontSize: 32),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Name
              Text(
                contact.name,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),

              // Phone
              Text(
                contact.phoneNumber,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // Info Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: AppRadius.card,
                ),
                child: Column(
                  children: [
                    const Icon(LucideIcons.smartphone, size: 32, color: AppColors.textTertiary),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'This is a phone contact.',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Add ${contact.name} to SmartBroker to start logging notes, tasks, and calls.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // CTA Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _addToSmartBroker,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(LucideIcons.userPlus),
                  label: Text(_isSaving ? 'Adding...' : 'Add to SmartBroker'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
