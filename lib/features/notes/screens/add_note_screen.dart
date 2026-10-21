import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../models/note.dart';
import '../../../core/repositories/note_repository.dart';
import '../../../core/services/overlay_draft_service.dart';
import '../../../core/transcription/dictation_controller.dart';
import '../../../core/transcription/offline_transcriber.dart';
import '../widgets/dictation_panel.dart';

class AddNoteScreen extends StatefulWidget {
  const AddNoteScreen({super.key});

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  final TextEditingController _noteController = TextEditingController();
  String? _contactId;
  Note? _note;
  bool _isPostCall = false;
  String? _durationStr;
  bool _isDraftRestored = false;
  bool _isSaving = false;
  final _draftService = OverlayDraftService();

  /// Id of the note once it has been saved from this screen (so pressing
  /// Save/AI Review again updates it instead of creating a duplicate).
  String? _savedNoteId;

  /// The text as last saved, to tell whether closing would lose edits.
  String? _savedText;

  /// Offline Amharic dictation; null on phones without the native library.
  DictationController? _dictation;

  @override
  void initState() {
    super.initState();
    if (OfflineTranscriber.isSupported) {
      _dictation = DictationController()..addListener(_onDictationChanged);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_contactId == null && _note == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        _contactId = args;
      } else if (args is Map<String, dynamic>) {
        _contactId = args['contactId'] as String?;
        _isPostCall = args['isPostCall'] as bool? ?? false;
        _durationStr = args['duration'] as String?;
      } else if (args is Note) {
        _note = args;
        _contactId = args.contactId;
        _noteController.text = args.rawText;
      }

      _loadDraftIfNeeded();
    }
  }

  Future<void> _loadDraftIfNeeded() async {
    // Restore anything typed in the call overlay (also after a post-call prompt).
    if (_contactId != null && _note == null) {
      final draft = await _draftService.loadDraft(_contactId!);
      if (draft != null && draft.isNotEmpty && _noteController.text.isEmpty) {
        if (mounted) {
          setState(() {
            _noteController.text = draft;
            _isDraftRestored = true;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _dictation?.removeListener(_onDictationChanged);
    _dictation?.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ── Dictation ────────────────────────────────────────────────────────

  Future<void> _startDictation() async {
    FocusScope.of(context).unfocus(); // room for the live text
    await _dictation?.start();
  }

  Future<void> _finishDictation() async {
    final text = await _dictation?.stop() ?? '';
    if (!mounted) return;
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No speech was recognised')));
      return;
    }
    _insertAtCursor(text);
  }

  void _onDictationChanged() {
    final d = _dictation;
    if (d == null || !mounted) return;
    setState(() {});
    if (d.state == DictationState.needsModel) {
      d.reset();
      _offerModelDownload();
    } else if (d.state == DictationState.error) {
      final message = d.error ?? 'Dictation stopped.';
      d.reset();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _offerModelDownload() async {
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download the Amharic model?'),
        content: const Text(
          'Dictation runs on this phone, so your notes are never uploaded. It needs a one-time '
          '499 MB download — best over Wi-Fi.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Open Settings')),
        ],
      ),
    );
    if (open == true && mounted) await Navigator.pushNamed(context, AppRoutes.settings);
  }

  /// Puts dictated text where the cursor is (or at the end), with spaces around it.
  void _insertAtCursor(String text) {
    final value = _noteController.value;
    final sel = value.selection;
    final start = sel.isValid ? sel.start : value.text.length;
    final end = sel.isValid ? sel.end : value.text.length;
    final before = value.text.substring(0, start);
    final after = value.text.substring(end);
    final lead = before.isEmpty || before.endsWith(' ') || before.endsWith('\n') ? '' : ' ';
    final trail = after.isEmpty || after.startsWith(' ') || after.startsWith('\n') ? '' : ' ';
    final inserted = '$lead$text$trail';
    _noteController.value = TextEditingValue(
      text: '$before$inserted$after',
      selection: TextSelection.collapsed(offset: before.length + inserted.length),
    );
  }

  /// Saves the raw note before anything else, so it survives no key, no
  /// network or a failed AI call. Returns the note id, or null if empty.
  Future<String?> _persist() async {
    final text = _noteController.text.trim();
    if (text.isEmpty || _contactId == null) return null;
    setState(() => _isSaving = true);
    try {
      final id = await NoteRepository().saveNote(
        contactId: _contactId!,
        rawText: text,
        existingNoteId: _savedNoteId ?? _note?.id,
      );
      _savedNoteId = id;
      _savedText = text;
      await _draftService.clearDraft(_contactId!);
      return id;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _save() async {
    final id = await _persist();
    if (id == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Note saved')),
    );
    Navigator.pop(context, true);
  }

  Future<void> _saveAndReview() async {
    final id = await _persist();
    if (id == null || !mounted) return;
    Navigator.pushNamed(
      context,
      AppRoutes.aiReview,
      arguments: {
        'contactId': _contactId,
        'rawText': _noteController.text.trim(),
        'noteId': id,
      },
    );
  }

  /// Closing with unsaved text keeps it as a draft instead of losing it.
  Future<void> _close() async {
    if (_dictation?.state == DictationState.listening) await _finishDictation();
    if (!mounted) return;
    final text = _noteController.text.trim();
    final unsaved = text.isNotEmpty && text != (_savedText ?? _note?.rawText);
    if (unsaved && _contactId != null) {
      await _draftService.saveDraft(_contactId!, text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft kept — it will be here next time')),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_contactId == null) {
      return const Scaffold(
        body: Center(child: Text('Error: No contact ID provided')),
      );
    }

    // The system back gesture goes through _close too, so typed text is kept.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface, // Distraction free pure white
        floatingActionButton: _dictation == null || _dictation!.isActive
            ? null
            : FloatingActionButton.extended(
                onPressed: _isSaving ? null : _startDictation,
                tooltip: 'Dictate in Amharic (works offline)',
                backgroundColor: AppColors.textPrimary,
                foregroundColor: Colors.white,
                icon: const Icon(LucideIcons.mic),
                label: const Text('Dictate'),
              ),
        bottomNavigationBar: _dictation != null && _dictation!.isActive
            ? DictationPanel(controller: _dictation!, onDone: _finishDictation, onCancel: () => _dictation!.cancel())
            : null,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.x),
            tooltip: 'Close',
            onPressed: _isSaving ? null : _close,
          ),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: const Text('Save'),
            ),
            TextButton.icon(
              onPressed: _isSaving ? null : _saveAndReview,
              icon: const Icon(LucideIcons.sparkles, size: 16),
              label: const Text('AI Review'),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ),
        body: ConstrainedLayout(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isPostCall)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.phone, size: 16, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Auto-detected call — $_durationStr',
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_isDraftRestored)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.fileClock, color: AppColors.primary, size: 16),
                        const SizedBox(width: AppSpacing.sm),
                        const Expanded(
                          child: Text(
                            'Draft from your last call restored',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500, fontSize: 13),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, color: AppColors.primary, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() => _isDraftRestored = false),
                        ),
                      ],
                    ),
                  ),
                Text(
                  'Meeting Notes',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.textTertiary),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _noteController,
                    maxLines: null,
                    expands: true,
                    autofocus: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18, height: 1.6),
                    decoration: InputDecoration(
                      hintText: 'Start typing...',
                      hintStyle: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(fontSize: 18, color: AppColors.textTertiary),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      // Room below the last line for the Dictate button.
                      contentPadding: EdgeInsets.only(bottom: _dictation == null ? 0 : 72),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
