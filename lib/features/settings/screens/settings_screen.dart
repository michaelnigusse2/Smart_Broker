import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:io' show Platform;
import '../../../core/database/seed_data.dart';
import '../../../core/repositories/contact_repository.dart';
import '../../../core/services/app_log.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ai_consent_dialog.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../core/services/api_key_service.dart';
import '../../../core/services/ai_provider.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/call_detection_service.dart';
import '../../../core/services/call_matching_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../models/call_entry.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  AiProvider _provider = AiProvider.fallback;
  bool _isObscured = true;
  bool _isChecking = false;
  bool _hasKey = false;
  String? _statusMessage;

  // Call detection state
  final _callDetectionService = CallDetectionService();
  final _callMatchingService = CallMatchingService();
  final _settingsService = SettingsService();

  bool _callPermissionGranted = false;
  bool _callServiceRunning = false;

  bool _promptAfterCall = true;
  int _minCallDuration = 10;
  OverlayMode _overlayMode = OverlayMode.knownOnly;
  bool _overlayPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
    _loadCallDetectionState();
  }

  Future<void> _loadKey() async {
    final provider = await _settingsService.getAiProvider();
    final key = await ApiKeyService().getKey(provider);
    final model = await _settingsService.getAiModel(provider);
    if (!mounted) return;
    setState(() {
      _provider = provider;
      _modelController.text = model;
      _apiKeyController.text = key ?? '';
      _hasKey = key != null && key.isNotEmpty;
      _statusMessage = _hasKey ? 'Connected' : 'Not configured';
    });
  }

  Future<void> _selectProvider(AiProvider? provider) async {
    if (provider == null || provider.id == _provider.id) return;
    await _settingsService.setAiProvider(provider);
    await _loadKey();
  }

  Future<void> _loadCallDetectionState() async {
    final promptEnabled = await _settingsService.getPromptAfterCall();
    final minDuration = await _settingsService.getMinCallDuration();
    final overlayMode = await _settingsService.getOverlayMode();

    bool overlayPerm = false;
    try {
      overlayPerm = await FlutterOverlayWindow.isPermissionGranted();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _promptAfterCall = promptEnabled;
        _minCallDuration = minDuration;
        _overlayMode = overlayMode;
        _overlayPermissionGranted = overlayPerm;
      });
    }

    if (!_callDetectionService.isSupported) return;

    final permGranted = await _callDetectionService.isPermissionGranted();
    final running = await _callDetectionService.isRunning();

    if (mounted) {
      setState(() {
        _callPermissionGranted = permGranted;
        _callServiceRunning = running;
      });
    }
  }

  Future<void> _saveKey() async {
    final key = _apiKeyController.text.trim();
    final model = _modelController.text.trim();
    if (key.isEmpty) {
      await ApiKeyService().deleteKey(_provider);
      if (!mounted) return;
      setState(() {
        _hasKey = false;
        _statusMessage = 'Not configured';
      });
      return;
    }

    setState(() {
      _isChecking = true;
      _statusMessage = 'Validating...';
    });

    final aiService = AiService(provider: _provider, apiKey: key, model: model);
    final result = await aiService.validateKey();

    if (!mounted) return;

    if (result == 'valid') {
      await ApiKeyService().saveKey(_provider, key);
      await _settingsService.setAiModel(_provider, model);
      if (!mounted) return;
      setState(() {
        _hasKey = true;
        _statusMessage = 'Connected';
        _isChecking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API Key saved successfully')),
      );
    } else {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Failed: $result';
        _isChecking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to validate API Key'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _toggleCallDetection(bool enable) async {
    if (enable) {
      // Request permission first
      if (!_callPermissionGranted) {
        final granted = await _callDetectionService.requestPermission();
        if (!mounted) return;
        setState(() => _callPermissionGranted = granted);
        if (!granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Phone permission is required for call detection')),
          );
          return;
        }
      }
      // Start the service
      final started = await _callDetectionService.start();
      if (started) {
        _callMatchingService.startListening();
        await _settingsService.setCallDetectionEnabled(true);
      }
      // The service reports itself running once Android has created it.
      await Future.delayed(const Duration(milliseconds: 500));
      final running = await _callDetectionService.isRunning();
      if (!mounted) return;
      setState(() => _callServiceRunning = running);
      if (!running) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call detection could not start on this device')),
        );
      }
    } else {
      await _settingsService.setCallDetectionEnabled(false);
      await _callDetectionService.stop();
      _callMatchingService.stopListening();
      if (!mounted) return;
      setState(() => _callServiceRunning = false);
    }
  }

  Future<void> _loadDemoData() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final added = await SeedData.loadDemoData();
      if (added) await NotificationService().rescheduleAll();
      messenger.showSnackBar(
        SnackBar(
          content: Text(added ? 'Demo data loaded' : 'Demo data is already loaded'),
        ),
      );
    } catch (e, st) {
      AppLog.e('Settings', 'loading demo data failed', e, st);
      messenger.showSnackBar(SnackBar(content: Text('Could not load demo data: $e')));
    }
  }

  Future<void> _showSimulateCallDialog() async {
    // Default to a real contact's number so the overlay shows in "Known contacts" mode.
    final contacts = await ContactRepository().getAll();
    if (!mounted) return;
    final phoneController = TextEditingController(
      text: contacts.isNotEmpty ? contacts.first.phoneNumber.trim() : '+251900000099',
    );
    String selectedType = 'incoming';
    final durationController = TextEditingController(text: '20');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Simulate Call'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Call Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'incoming', child: Text('Incoming')),
                  DropdownMenuItem(value: 'outgoing', child: Text('Outgoing')),
                  DropdownMenuItem(value: 'missed', child: Text('Missed')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedType = val);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: durationController,
                decoration: const InputDecoration(
                  labelText: 'Duration (seconds)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final callType = switch (selectedType) {
                  'incoming' => CallType.incoming,
                  'outgoing' => CallType.outgoing,
                  _ => CallType.missed,
                };

                final number = phoneController.text.trim();
                final duration = Duration(seconds: int.tryParse(durationController.text) ?? 0);
                Navigator.pop(ctx);

                final messenger = ScaffoldMessenger.of(context);
                final overlayReady = await _callMatchingService.overlayWouldShowFor(number);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      overlayReady
                          ? 'Simulating $selectedType call — the overlay will appear now'
                          : 'Simulating $selectedType call (no overlay: it is off, not permitted, '
                                'or the number is not a contact)',
                    ),
                  ),
                );
                await _callMatchingService.simulateCall(
                  phoneNumber: number,
                  type: callType,
                  duration: duration,
                );
                messenger.showSnackBar(
                  SnackBar(content: Text('Simulated $selectedType call logged')),
                );
              },
              child: const Text('Simulate'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = Platform.isAndroid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ConstrainedLayout(
        child: ListView(
          children: [
            const SizedBox(height: AppSpacing.md),
            _buildSectionHeader(context, 'Appearance'),
            ListTile(
              leading: const Icon(LucideIcons.moon),
              title: const Text('Theme'),
              subtitle: const Text('Light (Default)'),
              trailing: const Icon(LucideIcons.chevronRight, size: 20),
              onTap: () {},
            ),
            const Divider(height: 1),

            _buildSectionHeader(context, 'AI Integration'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<AiProvider>(
                    initialValue: _provider,
                    key: ValueKey(_provider.id),
                    decoration: const InputDecoration(
                      labelText: 'Provider',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final p in AiProvider.all) DropdownMenuItem(value: p, child: Text(p.name)),
                    ],
                    onChanged: _isChecking ? null : _selectProvider,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('${_provider.name} API Key', style: const TextStyle(fontWeight: FontWeight.w500)),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _statusMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: _hasKey ? AppColors.primary : AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: null,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: _isObscured,
                    decoration: InputDecoration(
                      hintText: 'Enter your API key',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_isObscured ? LucideIcons.eye : LucideIcons.eyeOff),
                        onPressed: () {
                          setState(() {
                            _isObscured = !_isObscured;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _modelController,
                    decoration: InputDecoration(
                      labelText: 'Model',
                      helperText: 'Default: ${_provider.defaultModel}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Visit ${_provider.keyUrl} to get a free key')),
                            );
                          },
                          child: const Text('Get Key'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isChecking ? null : _saveKey,
                          child: _isChecking
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(LucideIcons.shieldCheck),
              title: const Text('Data & privacy'),
              subtitle: const Text('What AI Review sends, and to whom'),
              trailing: const Icon(LucideIcons.chevronRight, size: 20),
              onTap: () => showAiDataNotice(context, _provider),
            ),
            const Divider(height: 1),

            // ── Call Detection Section ──────────────────────────────
            _buildSectionHeader(context, 'Call Detection'),
            if (!isAndroid)
              const ListTile(
                leading: Icon(LucideIcons.phoneOff, color: AppColors.textTertiary),
                title: Text('Not available on iOS'),
                subtitle: Text('Call detection requires Android'),
              )
            else ...[
              SwitchListTile(
                secondary: Icon(
                  LucideIcons.phoneCall,
                  color: _callServiceRunning ? AppColors.primary : AppColors.textTertiary,
                ),
                title: const Text('Call Detection'),
                subtitle: Text(
                  _callServiceRunning
                      ? 'Service running'
                      : (_callPermissionGranted ? 'Service stopped' : 'Permission required'),
                  style: TextStyle(
                    color: _callServiceRunning ? AppColors.primary : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                value: _callServiceRunning,
                activeThumbColor: AppColors.primary,
                onChanged: _toggleCallDetection,
              ),
              if (!_callPermissionGranted)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: OutlinedButton.icon(
                    icon: const Icon(LucideIcons.shield, size: 16),
                    label: const Text('Grant Permissions'),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final granted = await _callDetectionService.requestPermission();
                      if (!mounted) return;
                      setState(() => _callPermissionGranted = granted);
                      messenger.showSnackBar(
                        SnackBar(content: Text(granted ? 'Permissions granted' : 'Permissions denied')),
                      );
                    },
                  ),
                ),

              if (_callPermissionGranted && _callServiceRunning) ...[
                const Divider(),
                SwitchListTile(
                  title: const Text('Prompt after calls'),
                  subtitle: const Text('Show a notification to add notes when a call ends'),
                  value: _promptAfterCall,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) async {
                    await _settingsService.setPromptAfterCall(val);
                    if (mounted) setState(() => _promptAfterCall = val);
                  },
                ),
                if (_promptAfterCall)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xl, right: AppSpacing.xl, bottom: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Minimum call duration'),
                            Text('$_minCallDuration seconds', style: const TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                        Slider(
                          value: _minCallDuration.toDouble(),
                          min: 0,
                          max: 60,
                          divisions: 12,
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            setState(() => _minCallDuration = val.toInt());
                          },
                          onChangeEnd: (val) async {
                            await _settingsService.setMinCallDuration(val.toInt());
                          },
                        ),
                      ],
                    ),
                  ),
              ],

              const Divider(),
              ...[
                ListTile(
                  title: const Text('Live call overlay'),
                  subtitle: Text(switch (_overlayMode) {
                    OverlayMode.knownOnly =>
                      'Floating notes window for calls with your contacts. Unknown numbers get no overlay and no prompt.',
                    OverlayMode.all => 'Floating notes window and prompt for every call, including unknown numbers.',
                    OverlayMode.off => 'No floating window during calls.',
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                  child: SegmentedButton<OverlayMode>(
                    segments: const [
                      ButtonSegment(value: OverlayMode.knownOnly, label: Text('Contacts')),
                      ButtonSegment(value: OverlayMode.all, label: Text('All calls')),
                      ButtonSegment(value: OverlayMode.off, label: Text('Off')),
                    ],
                    selected: {_overlayMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) async {
                      final mode = selection.first;
                      await _settingsService.setOverlayMode(mode);
                      if (mounted) setState(() => _overlayMode = mode);
                    },
                  ),
                ),
                if (_overlayMode != OverlayMode.off && !_overlayPermissionGranted)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: OutlinedButton.icon(
                      icon: const Icon(LucideIcons.monitor, size: 16),
                      label: const Text('Grant Overlay Permission'),
                      onPressed: () async {
                        try {
                          await FlutterOverlayWindow.requestPermission();
                          final granted = await FlutterOverlayWindow.isPermissionGranted();
                          if (!context.mounted) return;
                          setState(() => _overlayPermissionGranted = granted);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(granted ? 'Overlay permission granted' : 'Overlay permission denied'),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      },
                    ),
                  ),
              ],
            ],
            const Divider(height: 1),

            _buildSectionHeader(context, 'Developer Tools'),
            if (kDebugMode)
              ListTile(
                leading: const Icon(LucideIcons.database),
                title: const Text('Load demo data'),
                subtitle: const Text('Debug builds only — adds 8 fictional contacts'),
                trailing: const Icon(LucideIcons.chevronRight, size: 20),
                onTap: _loadDemoData,
              ),
            if (isAndroid)
              ListTile(
                leading: const Icon(LucideIcons.phoneForwarded),
                title: const Text('Simulate Call'),
                subtitle: const Text('Test call detection pipeline'),
                trailing: const Icon(LucideIcons.chevronRight, size: 20),
                onTap: _showSimulateCallDialog,
              ),
            ListTile(
              leading: const Icon(LucideIcons.trash2),
              title: const Text('Reset Data'),
              trailing: const Icon(LucideIcons.chevronRight, size: 20),
              onTap: () {},
            ),

            const SizedBox(height: AppSpacing.xxl),
            const Center(
              child: Text(
                'SmartBroker v1.0.0\nPhase 8 Call Detection',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.lg, top: AppSpacing.xl, bottom: AppSpacing.sm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
