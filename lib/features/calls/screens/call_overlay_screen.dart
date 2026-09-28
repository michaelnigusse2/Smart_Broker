import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/overlay_draft_service.dart';

enum OverlayState { briefing, activeCall, callEnded }

class CallOverlayScreen extends StatefulWidget {
  const CallOverlayScreen({super.key});

  @override
  State<CallOverlayScreen> createState() => _CallOverlayScreenState();
}

class _CallOverlayScreenState extends State<CallOverlayScreen> {
  OverlayState _state = OverlayState.briefing;
  String _contactName = 'Unknown';
  String _contactId = '';
  List<String> _pendingTasks = [];
  String _lastNoteSummary = '';
  
  final _noteController = TextEditingController();
  final _draftService = OverlayDraftService();
  Timer? _debounceTimer;
  Timer? _callDurationTimer;
  int _callSeconds = 0;
  bool _showSavedIndicator = false;

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event == null) return;
      try {
        final Map<String, dynamic> data = jsonDecode(event.toString());
        
        if (data['action'] == 'init') {
          setState(() {
            _contactName = data['contactName'] ?? 'Unknown';
            _contactId = data['contactId'] ?? '';
            _pendingTasks = List<String>.from(data['pendingTasks'] ?? []);
            _lastNoteSummary = data['lastNoteSummary'] ?? '';
          });
        } else if (data['action'] == 'active') {
          setState(() => _state = OverlayState.activeCall);
          _startTimer();
        } else if (data['action'] == 'ended') {
          setState(() => _state = OverlayState.callEnded);
          _stopTimer();
        }
      } catch (e) {
        debugPrint('Overlay JSON parse error: $e');
      }
    });
  }

  void _startTimer() {
    _callDurationTimer?.cancel();
    _callSeconds = 0;
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _callSeconds++);
    });
  }

  void _stopTimer() {
    _callDurationTimer?.cancel();
  }

  void _onTextChanged(String text) {
    if (_contactId.isEmpty) return;
    
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () async {
      await _draftService.saveDraft(_contactId, text);
      setState(() => _showSavedIndicator = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showSavedIndicator = false);
      });
    });
  }

  Future<void> _handleSaveAndProcess() async {
    if (_contactId.isEmpty) return;
    final text = _noteController.text.trim();
    if (text.isNotEmpty) {
      await _draftService.saveDraft(_contactId, text);
      await FlutterOverlayWindow.shareData(jsonEncode({
        'action': 'openAiReview',
        'contactId': _contactId,
        'noteText': text,
      }));
    }
    await FlutterOverlayWindow.closeOverlay();
  }

  Future<void> _handleDismiss() async {
    final text = _noteController.text.trim();
    if (_contactId.isNotEmpty && text.isNotEmpty) {
      await _draftService.saveDraft(_contactId, text);
    }
    await FlutterOverlayWindow.closeOverlay();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _debounceTimer?.cancel();
    _stopTimer();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, spreadRadius: 1)
                ]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const Divider(height: 1),
                  Flexible(child: _buildContent()),
                  const Divider(height: 1),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    Color iconColor = AppColors.textSecondary;
    String titleText = _contactName;
    String subtitleText = 'Incoming call...';

    if (_state == OverlayState.activeCall) {
      iconColor = AppColors.success;
      titleText = _contactName;
      subtitleText = 'Active call — ${_formatDuration(_callSeconds)}';
    } else if (_state == OverlayState.callEnded) {
      iconColor = AppColors.error;
      titleText = 'Call Ended';
      subtitleText = 'Duration: ${_formatDuration(_callSeconds)}';
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
                Text(titleText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(subtitleText, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (_showSavedIndicator)
            const Text('Draft saved', style: TextStyle(fontSize: 10, color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_state == OverlayState.briefing) {
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const Text('Pending Tasks', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          if (_pendingTasks.isEmpty)
            const Text('No pending tasks', style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textTertiary))
          else
            ..._pendingTasks.map((t) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.square, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(t, style: const TextStyle(fontSize: 14))),
                ],
              ),
            )),
            
          const SizedBox(height: AppSpacing.lg),
          const Text('Last Note Summary', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Text(
              _lastNoteSummary.isEmpty ? 'No previous notes' : _lastNoteSummary,
              style: TextStyle(
                fontSize: 14, 
                fontStyle: _lastNoteSummary.isEmpty ? FontStyle.italic : FontStyle.normal,
                color: _lastNoteSummary.isEmpty ? AppColors.textTertiary : AppColors.textPrimary
              ),
            ),
          ),
        ],
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_state == OverlayState.callEnded)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.xs),
                color: AppColors.error.withValues(alpha: 0.1),
                child: const Row(
                  children: [
                    Icon(LucideIcons.info, size: 14, color: AppColors.error),
                    SizedBox(width: 4),
                    Expanded(child: Text('Call ended — finish typing your thoughts.', style: TextStyle(fontSize: 12, color: AppColors.error))),
                  ],
                ),
              ),
            Flexible(
              child: TextField(
                controller: _noteController,
                maxLines: null,
                minLines: 3,
                autofocus: true,
                onChanged: _onTextChanged,
                decoration: const InputDecoration(
                  hintText: 'Start typing notes...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _handleDismiss,
            child: const Text('Dismiss', style: TextStyle(color: AppColors.textSecondary)),
          ),
          if (_state != OverlayState.briefing) ...[
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
