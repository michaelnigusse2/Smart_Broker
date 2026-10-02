import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/services/call_overlay_state.dart';
import '../../../core/services/overlay_draft_service.dart';
import '../../../core/theme/app_theme.dart';

/// The floating window shown during calls. Runs in its own Flutter engine
/// (entry point `overlayMain` in main.dart) and talks to the app through
/// [CallOverlayState].
class CallOverlayScreen extends StatefulWidget {
  const CallOverlayScreen({super.key});

  @override
  State<CallOverlayScreen> createState() => _CallOverlayScreenState();
}

class _CallOverlayScreenState extends State<CallOverlayScreen> {
  static const _unknownDraftKey = 'unknown_caller';

  String _phase = '';
  String? _contactId;
  String _title = 'Current call';
  List<String> _pendingTasks = [];
  String _lastNoteSummary = '';
  int? _startedAt;
  int? _endedAt;

  final _noteController = TextEditingController();
  final _draftService = OverlayDraftService();
  StreamSubscription<dynamic>? _messages;
  Timer? _pollTimer;
  Timer? _clockTimer;
  Timer? _debounceTimer;
  bool _showSavedIndicator = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    // The app pings us whenever the call state changes…
    _messages = FlutterOverlayWindow.overlayListener.listen((_) => _refresh());
    // …and we poll as a fallback while a call is on screen.
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_phase.isNotEmpty) _refresh();
    });
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _phase == 'active') setState(() {});
    });
    _refresh();
  }

  Future<void> _refresh() async {
    final state = await CallOverlayState.read();
    if (!mounted) return;
    if (state == null) {
      if (_phase.isNotEmpty) setState(() => _phase = '');
      return;
    }
    final phase = state['phase'] as String? ?? '';
    final contactId = state['contactId'] as String?;
    final isNewCall = (phase == 'ringing' && _phase != 'ringing') || (_phase.isEmpty && phase.isNotEmpty);

    if (isNewCall) {
      _submitted = false;
      _noteController.clear();
    }

    // Once we know who the call is with, move any text typed so far to that
    // contact's draft (and restore an existing draft if the field is empty).
    if (contactId != null && contactId != _contactId) {
      final existing = await _draftService.loadDraft(contactId);
      if (_noteController.text.trim().isEmpty && existing != null) {
        _noteController.text = existing;
      } else if (_noteController.text.trim().isNotEmpty) {
        await _draftService.saveDraft(contactId, _noteController.text);
      }
    }
    if (!mounted) return;

    setState(() {
      _phase = phase;
      _contactId = contactId;
      final name = state['contactName'] as String?;
      final number = state['number'] as String?;
      _title = (name != null && name.isNotEmpty)
          ? name
          : (number != null && number.isNotEmpty ? number : 'Current call');
      _pendingTasks = List<String>.from(state['pendingTasks'] as List? ?? const []);
      _lastNoteSummary = state['lastNoteSummary'] as String? ?? '';
      _startedAt = state['startedAt'] as int?;
      _endedAt = state['endedAt'] as int?;
    });
  }

  String get _draftKey => _contactId ?? _unknownDraftKey;

  void _onTextChanged(String text) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () async {
      await _draftService.saveDraft(_draftKey, text);
      if (!mounted) return;
      setState(() => _showSavedIndicator = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showSavedIndicator = false);
      });
    });
  }

  Future<void> _handleSaveAndProcess() async {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;
    await _draftService.saveDraft(_draftKey, text);
    await CallOverlayState.setPendingReview(contactId: _contactId, text: text);
    // Best effort: if the app is listening it opens AI Review straight away.
    try {
      await FlutterOverlayWindow.shareData({
        'action': 'openAiReview',
        'contactId': _contactId,
        'noteText': text,
      });
    } catch (_) {}
    if (!mounted) return;
    setState(() => _submitted = true);
    await Future.delayed(const Duration(milliseconds: 1800));
    await _close();
  }

  Future<void> _handleDismiss() async {
    final text = _noteController.text.trim();
    if (text.isNotEmpty) await _draftService.saveDraft(_draftKey, text);
    await _close();
  }

  Future<void> _close() async {
    await CallOverlayState.clear();
    if (mounted) setState(() => _phase = '');
    await FlutterOverlayWindow.closeOverlay();
  }

  @override
  void dispose() {
    _messages?.cancel();
    _pollTimer?.cancel();
    _clockTimer?.cancel();
    _debounceTimer?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int get _elapsedSeconds {
    if (_startedAt == null) return 0;
    final end = _endedAt ?? DateTime.now().millisecondsSinceEpoch;
    final seconds = (end - _startedAt!) ~/ 1000;
    return seconds < 0 ? 0 : seconds;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Material(
            color: AppColors.surface,
            elevation: 8,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            clipBehavior: Clip.antiAlias,
            child: _submitted
                ? _buildSubmitted()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const Divider(height: 1),
                      Expanded(child: _buildContent()),
                      const Divider(height: 1),
                      _buildFooter(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitted() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.checkCircle, color: AppColors.success, size: 36),
            SizedBox(height: AppSpacing.md),
            Text('Note saved', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Open SmartBroker to review it with AI.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    Color iconColor = AppColors.primary;
    String subtitle = 'Incoming call…';
    if (_phase == 'active') {
      iconColor = AppColors.success;
      subtitle = 'On call — ${_formatDuration(_elapsedSeconds)}';
    } else if (_phase == 'ended') {
      iconColor = AppColors.error;
      subtitle = 'Call ended — ${_formatDuration(_elapsedSeconds)}';
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(LucideIcons.phone, color: iconColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (_showSavedIndicator) const Text('Draft saved', style: TextStyle(fontSize: 10, color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _buildBriefing() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (_contactId == null)
          const Text(
            'Not a saved contact yet.',
            style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textTertiary),
          )
        else ...[
          const Text(
            'Pending tasks',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (_pendingTasks.isEmpty)
            const Text(
              'No pending tasks',
              style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textTertiary),
            )
          else
            ..._pendingTasks.map(
              (t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(LucideIcons.square, size: 14, color: AppColors.textTertiary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(t, style: const TextStyle(fontSize: 14))),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Last note',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _lastNoteSummary.isEmpty ? 'No previous notes' : _lastNoteSummary,
            style: TextStyle(
              fontSize: 14,
              color: _lastNoteSummary.isEmpty ? AppColors.textTertiary : AppColors.textPrimary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildContent() {
    if (_phase == 'ringing' || _phase.isEmpty) return _buildBriefing();
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: TextField(
        controller: _noteController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        onChanged: _onTextChanged,
        decoration: const InputDecoration(
          hintText: 'Type notes while you talk…',
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _handleDismiss,
            child: const Text('Dismiss', style: TextStyle(color: AppColors.textSecondary)),
          ),
          if (_phase == 'active' || _phase == 'ended') ...[
            const SizedBox(width: AppSpacing.sm),
            ElevatedButton.icon(
              onPressed: _handleSaveAndProcess,
              icon: const Icon(LucideIcons.sparkles, size: 16),
              label: const Text('Save & Process'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
