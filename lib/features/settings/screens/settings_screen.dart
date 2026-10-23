import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/database/seed_data.dart';
import '../../../core/repositories/contact_repository.dart';
import '../../../core/repositories/new_number_repository.dart';
import '../../../core/services/ai_provider.dart';
import '../../../core/services/api_key_service.dart';
import '../../../core/services/app_log.dart';
import '../../../core/services/call_detection_service.dart';
import '../../../core/services/call_matching_service.dart';
import '../../../core/services/local_data_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/appearance.dart';
import '../../../core/theme/sb_widgets.dart';
import '../../../core/widgets/ai_consent_dialog.dart';
import '../../../models/call_entry.dart';
import '../widgets/offline_dictation_settings.dart';

/// Settings, as on the "Settings" board: you, Appearance, Calls, Notes and
/// AI, Your data.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsService = SettingsService();
  final _callDetectionService = CallDetectionService();
  final _callMatchingService = CallMatchingService();

  String _name = '';
  WorkType? _work;
  String _language = 'en';

  AiProvider _provider = AiProvider.fallback;
  bool _hasKey = false;

  bool _callPermissionGranted = false;
  bool _callServiceRunning = false;
  bool _promptAfterCall = true;
  bool _missedReminders = true;
  int _minCallDuration = 10;
  OverlayMode _overlayMode = OverlayMode.knownOnly;
  int _ignored = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = ProfileService();
    final name = await profile.getName();
    final work = await profile.getWork();
    final language = await profile.getLanguage();
    final provider = await _settingsService.getAiProvider();
    final key = await ApiKeyService().getKey(provider);
    final prompt = await _settingsService.getPromptAfterCall();
    final missed = await _settingsService.getMissedCallReminders();
    final minDuration = await _settingsService.getMinCallDuration();
    final mode = await _settingsService.getOverlayMode();
    final ignored = await NewNumberRepository().ignoredCount();
    var permission = false;
    var running = false;
    if (_callDetectionService.isSupported) {
      permission = await _callDetectionService.isPermissionGranted();
      running = await _callDetectionService.isRunning();
    }
    if (!mounted) return;
    setState(() {
      _name = name;
      _work = work;
      _language = language;
      _provider = provider;
      _hasKey = key != null && key.isNotEmpty;
      _promptAfterCall = prompt;
      _missedReminders = missed;
      _minCallDuration = minDuration;
      _overlayMode = mode;
      _ignored = ignored;
      _callPermissionGranted = permission;
      _callServiceRunning = running;
    });
  }

  void _say(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  // ── You ─────────────────────────────────────────────────────────

  Future<void> _editProfile() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: context.sb.canvas,
      builder: (_) => _ProfileSheet(name: _name, work: _work),
    );
    if (changed == true) await _load();
  }

  Future<void> _setLanguage(String language) async {
    setState(() => _language = language);
    await ProfileService().setLanguage(language);
    if (language == 'am') _say('Amharic screens are on the way. Dictation already works in Amharic.');
  }

  // ── Calls ───────────────────────────────────────────────────────

  Future<void> _setOverlayMode(OverlayMode mode) async {
    if (mode != OverlayMode.off) {
      var granted = false;
      try {
        granted = await FlutterOverlayWindow.isPermissionGranted();
        if (!granted) granted = await FlutterOverlayWindow.requestPermission() ?? false;
      } catch (_) {}
      if (!granted) {
        _say('Allow "Display over other apps" to see the call card');
        return;
      }
    }
    await _settingsService.setOverlayMode(mode);
    if (mounted) setState(() => _overlayMode = mode);
  }

  Future<void> _toggleCallDetection(bool enable) async {
    if (enable) {
      if (!_callPermissionGranted) {
        final granted = await _callDetectionService.requestPermission();
        if (!mounted) return;
        setState(() => _callPermissionGranted = granted);
        if (!granted) {
          _say('Phone permission is needed to know who is calling');
          return;
        }
      }
      if (await _callDetectionService.start()) {
        _callMatchingService.startListening();
        await _settingsService.setCallDetectionEnabled(true);
      }
      // The service reports itself running once Android has created it.
      await Future.delayed(const Duration(milliseconds: 500));
      final running = await _callDetectionService.isRunning();
      if (!mounted) return;
      setState(() => _callServiceRunning = running);
      if (!running) _say('Call detection could not start on this phone');
    } else {
      await _settingsService.setCallDetectionEnabled(false);
      await _callDetectionService.stop();
      _callMatchingService.stopListening();
      if (mounted) setState(() => _callServiceRunning = false);
    }
  }

  Future<void> _stopDetectionAsk() async {
    final stop = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop listening for calls?'),
        content: const Text('No call card, wrap-up or missed-call reminders until you turn it on again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep on')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Stop', style: TextStyle(color: context.sb.late)),
          ),
        ],
      ),
    );
    if (stop == true) await _toggleCallDetection(false);
  }

  Future<void> _setSkip(int seconds) async {
    final value = seconds.clamp(0, 60);
    setState(() => _minCallDuration = value);
    await _settingsService.setMinCallDuration(value);
  }

  // ── Your data ───────────────────────────────────────────────────

  Future<void> _resetLocalData() async {
    Future<bool> confirm(String title, String body, String action) async =>
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(action, style: TextStyle(color: context.sb.late)),
              ),
            ],
          ),
        ) ??
        false;

    if (!await confirm(
      'Delete everything?',
      'This deletes every person, note, promise, reminder and call stored in SmartBroker on this phone. '
          'Your settings and AI key are kept.',
      'Continue',
    )) {
      return;
    }
    if (!mounted) return;
    if (!await confirm('Are you sure?', 'This cannot be undone.', 'Delete everything')) return;
    if (!mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await LocalDataService().resetAll();
      messenger.showSnackBar(const SnackBar(content: Text('Everything on this phone was deleted')));
      navigator.pushNamedAndRemoveUntil(AppRoutes.shell, (_) => false);
    } catch (e, st) {
      AppLog.e('Settings', 'reset failed', e, st);
      messenger.showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  // ── Developer tools (debug builds) ─────────────────────────────

  Future<void> _loadDemoData() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final added = await SeedData.loadDemoData();
      if (added) await NotificationService().rescheduleAll();
      messenger.showSnackBar(SnackBar(content: Text(added ? 'Demo data loaded' : 'Demo data is already loaded')));
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

  // ── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final text = Theme.of(context).textTheme;
    final appearance = AppearanceController.instance;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SbCircleButton(
                icon: LucideIcons.chevronLeft,
                tooltip: 'Back',
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('Settings', style: text.headlineLarge),
            ),
            const SizedBox(height: 16),

            // You
            SbCard(
              onTap: _editProfile,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: sb.meBg, shape: BoxShape.circle),
                      child: Text(
                        _name.isEmpty ? '·' : SbFace.letterFor(_name),
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: sb.meFg),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_name.isEmpty ? 'Your name' : _name, style: text.titleLarge),
                          Text(
                            [if (_work != null) _work!.label, 'on this phone only'].join(' · '),
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

            const SizedBox(height: 24),
            const SbCap('Appearance'),
            ValueListenableBuilder<Appearance>(
              valueListenable: appearance,
              builder: (context, look, _) => SbCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _ThemeCard(
                            name: 'Ink',
                            line: 'Calm and neutral',
                            palette: SbPalette.inkLight,
                            selected: look.theme == AppThemeName.ink,
                            onTap: () => appearance.setTheme(AppThemeName.ink),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ThemeCard(
                            name: 'Espresso',
                            line: 'Warm coffee tones',
                            palette: SbPalette.espressoLight,
                            selected: look.theme == AppThemeName.espresso,
                            onTap: () => appearance.setTheme(AppThemeName.espresso),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const _RowLabel('Light or dark'),
                    const SizedBox(height: 8),
                    SbSegmented<ThemeMode>(
                      label: 'Light or dark',
                      options: const [
                        (ThemeMode.system, 'System'),
                        (ThemeMode.light, 'Light'),
                        (ThemeMode.dark, 'Dark'),
                      ],
                      selected: look.mode,
                      onChanged: appearance.setMode,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: _RowLabel('Language')),
                        SizedBox(
                          width: 200,
                          child: SbSegmented<String>(
                            label: 'Language',
                            options: const [('en', 'English'), ('am', 'አማርኛ')],
                            selected: _language,
                            onChanged: _setLanguage,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (Platform.isAndroid) ...[
              const SizedBox(height: 24),
              const SbCap('Calls'),
              SbCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              SbIconTile(icon: LucideIcons.monitorSmartphone, tint: sb.tintCool),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _RowLabel('Call card'),
                                    Text(
                                      "Who's calling and what you owe",
                                      style: TextStyle(fontSize: 13, height: 18 / 13, color: sb.text2),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SbSegmented<OverlayMode>(
                            label: 'Show the call card for',
                            options: const [
                              (OverlayMode.knownOnly, 'People I know'),
                              (OverlayMode.all, 'Everyone'),
                              (OverlayMode.off, 'Off'),
                            ],
                            selected: _overlayMode,
                            onChanged: _setOverlayMode,
                          ),
                        ],
                      ),
                    ),
                    _SwitchRow(
                      icon: LucideIcons.bellRing,
                      tint: SbTint(sb.accentTint, sb.accent),
                      title: 'After a call',
                      subtitle: 'One quiet note to wrap it up',
                      value: _promptAfterCall,
                      onChanged: (v) async {
                        setState(() => _promptAfterCall = v);
                        await _settingsService.setPromptAfterCall(v);
                      },
                    ),
                    _SwitchRow(
                      icon: LucideIcons.phoneMissed,
                      tint: SbTint(sb.oweBg, sb.late),
                      title: 'Missed calls',
                      subtitle: 'Remind me to call back',
                      value: _missedReminders,
                      onChanged: (v) async {
                        setState(() => _missedReminders = v);
                        await _settingsService.setMissedCallReminders(v);
                      },
                    ),
                    SbListRow(
                      leading: SbIconTile(icon: LucideIcons.timer, tint: sb.faces.last),
                      title: 'Skip short calls',
                      subtitle: 'No wrap-up under this',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StepButton(
                            icon: LucideIcons.minus,
                            label: 'Shorter',
                            onTap: _minCallDuration <= 0 ? null : () => _setSkip(_minCallDuration - 5),
                          ),
                          SizedBox(
                            width: 48,
                            child: Text(
                              '$_minCallDuration s',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          _StepButton(
                            icon: LucideIcons.plus,
                            label: 'Longer',
                            onTap: _minCallDuration >= 60 ? null : () => _setSkip(_minCallDuration + 5),
                          ),
                        ],
                      ),
                    ),
                    SbListRow(
                      leading: SbIconTile(icon: LucideIcons.phone, tint: sb.tintGreen),
                      title: 'Call detection',
                      subtitle: _callServiceRunning
                          ? 'Listening for calls'
                          : (_callPermissionGranted ? 'Off' : 'Needs phone permission'),
                      onTap: _callServiceRunning ? _stopDetectionAsk : null,
                      trailing: _callServiceRunning
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(color: sb.goodFg, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'On',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: sb.goodFg),
                                ),
                              ],
                            )
                          : FilledButton(
                              onPressed: () => _toggleCallDetection(true),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                              ),
                              child: const Text('Turn on'),
                            ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            const SbCap('Notes and AI'),
            SbCard(
              child: Column(
                children: [
                  SbListRow(
                    first: true,
                    leading: SbIconTile(icon: LucideIcons.sparkles, tint: sb.faces[4 % sb.faces.length]),
                    title: 'AI helper',
                    subtitle: _hasKey ? '${_provider.name} · key added' : 'Add a free key to find promises',
                    trailing: const SbChevron(),
                    onTap: () async {
                      await Navigator.pushNamed(context, AppRoutes.aiHelper);
                      await _load();
                    },
                  ),
                  SbListRow(
                    leading: SbIconTile(icon: LucideIcons.shieldCheck, tint: sb.faces.last),
                    title: 'What AI sees',
                    subtitle: 'Only the note you send it',
                    trailing: const SbChevron(),
                    onTap: () => showAiDataNotice(context, _provider),
                  ),
                  const OfflineDictationSettings(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Text(
                OfflineDictationSettings.about,
                style: TextStyle(fontSize: 12, height: 17 / 12, color: sb.text2),
              ),
            ),

            const SizedBox(height: 24),
            const SbCap('Your data'),
            SbCard(
              child: Column(
                children: [
                  SbListRow(
                    first: true,
                    leading: SbIconTile(icon: LucideIcons.ban, tint: sb.faces.last),
                    title: 'Ignored numbers',
                    subtitle: 'Never shown a call card',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_ignored',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: sb.text2),
                        ),
                        const SizedBox(width: 4),
                        const SbChevron(),
                      ],
                    ),
                    onTap: () async {
                      await Navigator.pushNamed(context, AppRoutes.ignoredNumbers);
                      await _load();
                    },
                  ),
                  SbListRow(
                    leading: SbIconTile(icon: LucideIcons.trash2, tint: SbTint(sb.oweBg, sb.late)),
                    title: 'Delete everything',
                    titleColor: sb.late,
                    subtitle: 'People, notes, promises and calls',
                    onTap: _resetLocalData,
                  ),
                ],
              ),
            ),

            if (kDebugMode) ...[
              const SizedBox(height: 24),
              const SbCap('Developer tools'),
              SbCard(
                child: Column(
                  children: [
                    SbListRow(
                      first: true,
                      leading: SbIconTile(icon: LucideIcons.database, tint: sb.faces.last),
                      title: 'Load demo data',
                      subtitle: 'Debug builds only: adds 8 fictional people',
                      onTap: _loadDemoData,
                    ),
                    SbListRow(
                      leading: SbIconTile(icon: LucideIcons.phoneForwarded, tint: sb.faces.last),
                      title: 'Simulate Call',
                      subtitle: 'Test call detection pipeline',
                      onTap: _showSimulateCallDialog,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () => showLicensePage(context: context, applicationName: 'SmartBroker'),
                child: Text(
                  'SmartBroker 1.0 · Open-source licences',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: sb.text2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600),
  );
}

/// Ink or Espresso, with a little picture of each.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.name,
    required this.line,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String line;
  final SbPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    return Semantics(
      button: true,
      selected: selected,
      label: '$name theme, $line',
      excludeSemantics: true,
      child: SbPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? sb.primary : sb.fill, width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 76,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: palette.canvas, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 16,
                      decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(6)),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 14,
                          decoration: BoxDecoration(color: palette.primary, borderRadius: BorderRadius.circular(99)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 20,
                          height: 14,
                          decoration: BoxDecoration(
                            color: palette.honey == palette.accent
                                ? palette.accent
                                : (name == 'Ink' ? palette.accent : palette.honey),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      line,
                      style: TextStyle(fontSize: 13, height: 18 / 13, color: sb.text2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final SbTint tint;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: SbListRow(
        leading: SbIconTile(icon: icon, tint: tint),
        title: title,
        subtitle: subtitle,
        trailing: Switch(value: value, onChanged: onChanged),
        onTap: () => onChanged(!value),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: SbPressable(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: sb.fill, shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: onTap == null ? sb.text3 : sb.text),
        ),
      ),
    );
  }
}

/// Your name and work, from the profile row.
class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet({required this.name, required this.work});

  final String name;
  final WorkType? work;

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  late final _name = TextEditingController(text: widget.name);
  late WorkType? _work = widget.work;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    await ProfileService().setName(_name.text.trim());
    if (_work != null) await ProfileService().setWork(_work!);
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('You', style: text.headlineSmall),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Your name'),
          ),
          const SizedBox(height: 14),
          const SbCap('Your work'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final w in WorkType.values)
                ChoiceChip(
                  label: Text(w.label),
                  selected: _work == w,
                  onSelected: (_) => setState(() => _work = w),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SbPrimaryButton(label: 'Save', onPressed: _save),
        ],
      ),
    );
  }
}
