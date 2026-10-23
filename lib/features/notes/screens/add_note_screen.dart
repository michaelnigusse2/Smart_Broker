import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/repositories/contact_repository.dart';
import '../../../core/repositories/note_repository.dart';
import '../../../core/services/overlay_draft_service.dart';
import '../../../core/services/wrap_up_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sb_widgets.dart';
import '../../../core/transcription/dictation_controller.dart';
import '../../../core/transcription/offline_transcriber.dart';
import '../../../core/transcription/scribe_model_store.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../models/note.dart';

/// A note for one person, built to the "Espresso · final" quick-note board:
/// "Note for Selam", the words in large type as you say or type them, the
/// microphone level while it listens, and Cancel / Done, in a sheet over the
/// screen it was opened from. Done saves the note and opens "From your call"
/// to pick out the promises; closing keeps unsaved words as a draft.
///
/// Arguments: a contact id, a [Note] to edit, or a map with `contactId`,
/// `isPostCall`, `duration` ("6:42"), `marks` (from the call overlay) and
/// `callId` (the call on Today's wrap-up list; saving a note wraps it up).
class AddNoteScreen extends StatefulWidget {
  const AddNoteScreen({super.key});

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  final _noteController = TextEditingController();
  final _noteFocus = FocusNode();
  final _draftService = OverlayDraftService();

  String? _contactId;
  String _name = '';
  Note? _note;
  bool _isPostCall = false;
  String? _callId;
  String? _duration;
  List<Map<String, dynamic>> _marks = [];
  bool _draftRestored = false;
  bool _saving = false;

  /// Id of the note once saved from this screen (so saving again updates it).
  String? _savedNoteId;

  /// The text as last saved, to tell whether closing would lose edits.
  String? _savedText;

  /// Offline Amharic dictation; null on phones without the native library.
  DictationController? _dictation;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    if (OfflineTranscriber.isSupported) {
      _dictation = DictationController()..addListener(_onDictationChanged);
    }
    _noteController.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_contactId != null || _note != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      _contactId = args;
    } else if (args is Map) {
      _contactId = args['contactId'] as String?;
      _isPostCall = args['isPostCall'] as bool? ?? false;
      _duration = args['duration'] as String?;
      _callId = args['callId'] as String?;
      _marks = [for (final m in (args['marks'] as List? ?? const [])) Map<String, dynamic>.from(m as Map)];
    } else if (args is Note) {
      _note = args;
      _contactId = args.contactId;
      _noteController.text = args.rawText;
    }
    _start();
  }

  /// Loads the person, restores a draft, and starts listening straight away
  /// when the offline model is ready and there's nothing written yet.
  Future<void> _start() async {
    final id = _contactId;
    if (id == null) return;
    final contact = await ContactRepository().getById(id);
    if (_note == null) {
      final draft = await _draftService.loadDraft(id);
      if (draft != null && draft.isNotEmpty && _noteController.text.isEmpty) {
        _noteController.text = draft;
        _draftRestored = true;
      }
    }
    if (!mounted) return;
    setState(() => _name = contact?.name ?? '');
    final dictation = _dictation;
    if (dictation != null && _noteController.text.isEmpty && await ScribeModelStore.instance.ensureChecked()) {
      if (mounted) await _startDictation();
    } else if (mounted) {
      _noteFocus.requestFocus();
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _dictation?.removeListener(_onDictationChanged);
    _dictation?.dispose();
    _noteController.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  String get _firstName => _name.trim().isEmpty ? '' : _name.trim().split(RegExp(r'\s+')).first;

  bool get _listening => _dictation?.isActive ?? false;

  // ── Dictation ──────────────────────────────────────────────────

  Future<void> _startDictation() async {
    _noteFocus.unfocus();
    await _dictation?.start();
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _listening) setState(() {});
    });
  }

  /// Stops listening and puts what was said into the note.
  Future<void> _finishDictation() async {
    final text = await _dictation?.stop() ?? '';
    _clock?.cancel();
    if (!mounted || text.isEmpty) return;
    _insertAtCursor(text);
  }

  Future<void> _cancelDictation() async {
    await _dictation?.cancel();
    _clock?.cancel();
    if (mounted) setState(() {});
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
          '499 MB download, best over Wi-Fi.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Open Settings')),
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

  // ── Saving ─────────────────────────────────────────────────────

  /// Saves the raw note before anything else, so it survives no key, no
  /// network or a failed AI call. Returns the note id, or null if empty.
  Future<String?> _persist() async {
    final text = _noteController.text.trim();
    if (text.isEmpty || _contactId == null) return null;
    setState(() => _saving = true);
    try {
      final id = await NoteRepository().saveNote(
        contactId: _contactId!,
        rawText: text,
        existingNoteId: _savedNoteId ?? _note?.id,
      );
      _savedNoteId = id;
      _savedText = text;
      await _draftService.clearDraft(_contactId!);
      // The call it was about is wrapped up now.
      if (_callId != null) await WrapUpStore.remove(_callId!);
      return id;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Done: finish listening, save, and open "From your call".
  Future<void> _done() async {
    if (_listening) await _finishDictation();
    final id = await _persist();
    if (id == null || !mounted) return;
    await Navigator.pushNamed(
      context,
      AppRoutes.aiReview,
      arguments: {
        'contactId': _contactId,
        'rawText': _noteController.text.trim(),
        'noteId': id,
        'isPostCall': _isPostCall,
        'duration': ?_duration,
      },
    );
  }

  /// Closing with unsaved text keeps it as a draft instead of losing it.
  Future<void> _close() async {
    if (_listening) await _finishDictation();
    if (!mounted) return;
    final text = _noteController.text.trim();
    final unsaved = text.isNotEmpty && text != (_savedText ?? _note?.rawText);
    if (unsaved && _contactId != null) {
      await _draftService.saveDraft(_contactId!, text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft kept for next time')));
    }
    if (mounted) Navigator.pop(context);
  }

  // ── Build ──────────────────────────────────────────────────────

  static String _clockText(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  static String _markLabel(Map<String, dynamic> mark, String first) {
    final at = mark['at'] as int? ?? 0;
    final when = '${at ~/ 60}:${(at % 60).toString().padLeft(2, '0')}';
    final what = switch (mark['type']) {
      'mine' => 'You promised',
      'theirs' => first.isEmpty ? 'They promised' : '$first promised',
      _ => 'Follow up',
    };
    return '$what · $when';
  }

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    if (_contactId == null) {
      return const Scaffold(body: Center(child: Text('No person was given for this note.')));
    }
    final dictation = _dictation;
    final listening = _listening;
    final hasText = _noteController.text.trim().isNotEmpty;
    final live = dictation?.liveText ?? '';
    final bigText = TextStyle(fontSize: 21, height: 32 / 21, fontWeight: FontWeight.w500, color: sb.text);

    // The system back gesture goes through _close too, so typed text is kept.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            // The dimmed screen above the sheet: tap it to close.
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _saving ? null : _close,
                child: const SizedBox.expand(),
              ),
            ),
            ConstrainedLayout(
              child: Container(
                decoration: BoxDecoration(
                  color: sb.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                padding: EdgeInsets.fromLTRB(20, 10, 20, 24 + MediaQuery.paddingOf(context).bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drag the handle down to close.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragEnd: (d) {
                        if ((d.primaryVelocity ?? 0) > 200 && !_saving) _close();
                      },
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(color: sb.track, borderRadius: BorderRadius.circular(99)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        SbFace(name: _name.isEmpty ? '?' : _name, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _firstName.isEmpty ? 'Note' : 'Note for $_firstName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              height: 22 / 16,
                              fontWeight: FontWeight.w700,
                              color: sb.text,
                            ),
                          ),
                        ),
                        if (listening)
                          Semantics(
                            label: 'Listening, ${_clockText(dictation!.elapsed)}',
                            excludeSemantics: true,
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(color: sb.lateDot, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _clockText(dictation.elapsed),
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 20 / 14,
                                    fontWeight: FontWeight.w700,
                                    color: sb.text,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (_isPostCall && _duration != null)
                          Text(
                            'Call · $_duration',
                            style: TextStyle(
                              fontSize: 13,
                              height: 18 / 13,
                              fontWeight: FontWeight.w600,
                              color: sb.text2,
                            ),
                          ),
                      ],
                    ),
                    if (_marks.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final m in _marks)
                            SbTag(_markLabel(m, _firstName), background: sb.fill, foreground: sb.text, small: true),
                        ],
                      ),
                    ],
                    if (_draftRestored) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Picked up from your call',
                        style: TextStyle(fontSize: 13, height: 18 / 13, color: sb.text2),
                      ),
                    ],
                    const SizedBox(height: 18),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: 96,
                        maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                      ),
                      child: listening
                          ? SingleChildScrollView(
                              reverse: true,
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    if (hasText) TextSpan(text: '${_noteController.text.trim()} '),
                                    TextSpan(text: live),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: Container(
                                        width: 2,
                                        height: 24,
                                        margin: const EdgeInsets.only(left: 3),
                                        color: sb.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                style: bigText,
                              ),
                            )
                          : TextField(
                              controller: _noteController,
                              focusNode: _noteFocus,
                              minLines: 3,
                              maxLines: null,
                              textCapitalization: TextCapitalization.sentences,
                              style: bigText,
                              decoration: InputDecoration(
                                hintText: dictation == null ? 'What did you agree?' : 'Say it or type it',
                                hintStyle: bigText.copyWith(color: sb.text3),
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                    ),
                    if (listening) ...[
                      const SizedBox(height: 6),
                      _LevelBars(levels: dictation!.levels),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          flex: 10,
                          child: listening
                              ? _BottomButton(label: 'Cancel', onTap: _cancelDictation)
                              : _BottomButton(
                                  label: 'Talk',
                                  icon: LucideIcons.mic,
                                  onTap: dictation == null || _saving ? null : _startDictation,
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 14,
                          child: _BottomButton(
                            label: 'Done',
                            filled: true,
                            onTap: _saving || (!hasText && live.isEmpty) ? null : _done,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The microphone level as 34 thin bars, newest on the right.
class _LevelBars extends StatelessWidget {
  const _LevelBars({required this.levels});

  final List<double> levels;

  @override
  Widget build(BuildContext context) {
    final color = context.sb.primary;
    const count = DictationController.levelCount;
    final padded = [...List.filled(count - levels.length.clamp(0, count), 0.0), ...levels];
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 4,
              height: 6 + 36 * padded[i],
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.35 + 0.55 * padded[i]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  const _BottomButton({required this.label, required this.onTap, this.icon, this.filled = false});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final fg = filled ? sb.onPrimary : sb.text;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: SbPressable(
          onTap: onTap,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: filled ? sb.primary : sb.fill, borderRadius: BorderRadius.circular(99)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
                Text(
                  label,
                  style: TextStyle(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
