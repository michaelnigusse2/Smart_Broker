import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/repositories/contact_repository.dart';
import '../../../core/repositories/note_repository.dart';
import '../../../core/repositories/todo_repository.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/app_log.dart';
import '../../../core/services/note_save_service.dart';
import '../../../core/services/overlay_draft_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sb_widgets.dart';
import '../../../core/utils/reminder_time.dart';
import '../../../core/widgets/ai_consent_dialog.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../core/widgets/past_reminder_dialog.dart';
import '../../../models/ai_result.dart';
import '../../../models/todo_item.dart';

/// "From your call", built to the "Espresso · final" recap board: what you
/// said, the promises the AI found both ways (tap the arrow to flip who owes,
/// edit or remove any), the follow-up, and Save.
///
/// Arguments: `contactId`, `rawText`, `noteId`, and for calls `isPostCall`
/// and `duration`.
class AiReviewScreen extends StatefulWidget {
  const AiReviewScreen({super.key, this.analyzeForTest});

  /// Stands in for the AI in tests: skips the key and consent checks.
  @visibleForTesting
  final Future<AiResult> Function(String rawText)? analyzeForTest;

  @override
  State<AiReviewScreen> createState() => _AiReviewScreenState();
}

class _Promise {
  _Promise(String title, this.owedBy) : controller = TextEditingController(text: title);

  final TextEditingController controller;
  OwedBy owedBy;
}

class _AiReviewScreenState extends State<AiReviewScreen> {
  final _noteRepo = NoteRepository();
  final _todoRepo = TodoRepository();
  final _contactRepo = ContactRepository();

  String? _contactId;
  String? _rawText;
  String? _noteId;
  bool _isPostCall = false;
  String? _duration;
  String _name = '';

  final _summaryController = TextEditingController();
  final List<_Promise> _promises = [];
  bool _includeReminder = true;
  final _reminderTitleController = TextEditingController();
  DateTime _reminderDateTime = DateTime.now().add(const Duration(days: 1));

  bool _initialized = false;
  bool _processing = true;
  bool _saving = false;
  String? _saveError;
  String? _aiError;
  String _loadingMessage = 'Reading your note…';
  Timer? _loadingTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _contactId = args['contactId'] as String?;
      _rawText = args['rawText'] as String?;
      _noteId = args['noteId'] as String?;
      _isPostCall = args['isPostCall'] as bool? ?? false;
      _duration = args['duration'] as String?;
    }
    _reminderDateTime = DateTime(_reminderDateTime.year, _reminderDateTime.month, _reminderDateTime.day, 9);
    _checkApiKeyAndAnalyze();
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _summaryController.dispose();
    _reminderTitleController.dispose();
    for (final p in _promises) {
      p.controller.dispose();
    }
    super.dispose();
  }

  String get _firstName => _name.trim().isEmpty ? '' : _name.trim().split(RegExp(r'\s+')).first;

  void _startLoadingMessages() {
    _loadingTimer?.cancel();
    var step = 0;
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      step++;
      if (!mounted) return;
      if (step == 1) setState(() => _loadingMessage = 'Finding promises…');
      if (step == 2) setState(() => _loadingMessage = 'Writing it up…');
    });
  }

  Future<void> _checkApiKeyAndAnalyze() async {
    // The note is saved before any AI call so it can never be lost.
    if (_noteId == null && _contactId != null && _rawText != null) {
      try {
        _noteId = await _noteRepo.saveNote(contactId: _contactId!, rawText: _rawText!);
        await OverlayDraftService().clearDraft(_contactId!);
      } catch (e, st) {
        AppLog.e('AiReview', 'could not save note', e, st);
        if (!mounted) return;
        setState(() {
          _aiError = "Couldn't save the note: $e";
          _processing = false;
        });
        return;
      }
    }
    final contact = _contactId == null ? null : await _contactRepo.getById(_contactId!);
    if (mounted) setState(() => _name = contact?.name ?? '');
    final fake = widget.analyzeForTest;
    if (fake != null) {
      _show(await fake(_rawText ?? ''));
      return;
    }
    final aiService = await AiService.fromSettings();
    if (!mounted) return;
    if (aiService == null) {
      _showNoKeyDialog();
      return;
    }
    if (!await ensureAiConsent(context, aiService.provider)) {
      if (!mounted) return;
      _keepWithoutAi('Note saved. Nothing was sent to the AI.');
      return;
    }
    _analyzeNote(aiService);
  }

  Future<void> _analyzeNote(AiService aiService) async {
    if (!mounted) return;
    setState(() {
      _processing = true;
      _aiError = null;
      _loadingMessage = 'Reading your note…';
    });
    _startLoadingMessages();

    try {
      if (_contactId == null || _rawText == null) throw Exception('Missing context');

      // Background = other notes only. This note is already saved (and may
      // have an older summary if it's being re-reviewed).
      final previousNotes = await _noteRepo.getByContactId(_contactId!);
      final previousSummaries = previousNotes
          .where((n) => n.id != _noteId && n.aiSummary.isNotEmpty)
          .take(3)
          .map((n) => n.aiSummary)
          .join('\n');

      // Exclude this note's own tasks: on a re-review the model must be free
      // to list them again or they would be treated as dropped.
      final pendingTodos = (await _todoRepo.getByContactId(
        _contactId!,
      )).where((t) => !t.isCompleted && t.noteId != _noteId).map((t) => t.title).join('\n');

      final result = await aiService.analyzeNote(
        contactName: _name.isEmpty ? 'Unknown' : _name,
        rawNote: _rawText!,
        previousNotes: previousSummaries.isEmpty ? 'None' : previousSummaries,
        pendingTodos: pendingTodos.isEmpty ? 'None' : pendingTodos,
      );
      _show(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiError = e.toString();
        _processing = false;
      });
    } finally {
      _loadingTimer?.cancel();
    }
  }

  /// Fills the review with what the AI found.
  void _show(AiResult result) {
    if (!mounted) return;
    setState(() {
      _summaryController.text = result.summary;
      for (final p in _promises) {
        p.controller.dispose();
      }
      _promises
        ..clear()
        ..addAll([for (final t in result.actionItems) _Promise(t, OwedBy.me)])
        ..addAll([for (final t in result.theirItems) _Promise(t, OwedBy.them)]);
      _reminderTitleController.text = result.reminderTitle ?? '';
      _includeReminder = result.reminderTitle != null;
      if (result.reminderDate != null) _reminderDateTime = result.reminderDate!;
      _processing = false;
    });
  }

  void _showNoKeyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Add an AI key?'),
        content: const Text('To find the promises in your notes, add a free AI key (for example Groq) in Settings.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _keepWithoutAi();
            },
            child: const Text('Keep the note'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, AppRoutes.settings).then((_) => _checkApiKeyAndAnalyze());
            },
            child: const Text('Add a key'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _reminderDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_reminderDateTime));
    if (time == null || !mounted) return;
    setState(() => _reminderDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  List<String> _titles(OwedBy side) => [
    for (final p in _promises)
      if (p.owedBy == side && p.controller.text.trim().isNotEmpty) p.controller.text.trim(),
  ];

  /// Leaves the review and the note editor, back to where the note was started.
  void _finish() {
    Navigator.popUntil(context, (route) {
      final name = route.settings.name;
      return name != AppRoutes.aiReview && name != AppRoutes.addNote;
    });
  }

  /// The note is already saved; leave without an AI summary.
  void _keepWithoutAi([String message = 'Note saved without a summary']) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    _finish();
  }

  Future<void> _save() async {
    if (_contactId == null || _rawText == null) return;
    if (_includeReminder && !isSchedulable(_reminderDateTime)) {
      if (!await confirmPastReminder(context)) {
        await _pickDateTime();
        return;
      }
      if (!mounted) return;
    }

    // On a re-review, say which open promises from the earlier one would go.
    final removed = await NoteSaveService().openTasksThatWouldBeRemoved(
      _noteId!,
      _titles(OwedBy.me),
      newTheirTitles: _titles(OwedBy.them),
    );
    if (!mounted) return;
    if (removed.isNotEmpty) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remove these?'),
          content: Text(
            'They came from the last review of this note and aren\'t in this one:\n\n'
            '${removed.map((t) => '•  ${t.title}').join('\n')}',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final typed = _reminderTitleController.text.trim();
      final reminderTitle = typed.isNotEmpty
          ? typed
          : _summaryController.text.isNotEmpty
          ? 'Follow up: ${_summaryController.text.split('.').first}'
          : 'Follow up';
      await NoteSaveService().apply(
        ReviewedNote(
          noteId: _noteId!,
          contactId: _contactId!,
          rawText: _rawText!,
          summary: _summaryController.text.trim(),
          taskTitles: _titles(OwedBy.me),
          theirTitles: _titles(OwedBy.them),
          reminder: _includeReminder ? (title: reminderTitle, dateTime: _reminderDateTime) : null,
        ),
      );
      await OverlayDraftService().clearDraft(_contactId!);
      if (mounted) _finish();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = e.toString();
        });
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    if (_contactId == null) {
      return const Scaffold(body: Center(child: Text('Missing the note to review.')));
    }
    final ready = !_processing && _aiError == null;
    final who = [_firstName, if (_isPostCall && _duration != null) _duration!].where((s) => s.isNotEmpty).join(' · ');

    return Scaffold(
      body: SafeArea(
        child: ConstrainedLayout(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Row(
                  children: [
                    SbCircleButton(icon: LucideIcons.x, tooltip: 'Close', onPressed: () => Navigator.maybePop(context)),
                    const Spacer(),
                    if (who.isNotEmpty)
                      Text(
                        who,
                        style: TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          fontWeight: FontWeight.w600,
                          color: sb.text2,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _processing
                    ? _Waiting(message: _loadingMessage)
                    : _aiError != null
                    ? _Failed(
                        message: _aiError!,
                        onRetry: _checkApiKeyAndAnalyze,
                        onKeep: _keepWithoutAi,
                      )
                    : _review(context),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: ready
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SbPrimaryButton(
                  label: _saveError != null ? 'Try saving again' : 'Save',
                  onPressed: _saving ? null : _save,
                ),
              ),
            )
          : null,
    );
  }

  Widget _review(BuildContext context) {
    final sb = context.sb;
    final reminderWhen = DateFormat('EEE d MMM · HH:mm').format(_reminderDateTime);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
      children: [
        SbRise(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _isPostCall ? 'From your call' : 'From your note',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(height: 38 / 34),
            ),
          ),
        ),
        if (_saveError != null) ...[
          const SizedBox(height: 12),
          Text(_saveError!, style: TextStyle(color: sb.late)),
        ],
        const SizedBox(height: 18),
        SbRise(
          delay: const Duration(milliseconds: 80),
          child: SbCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: sb.fill, borderRadius: BorderRadius.circular(10)),
                  child: Icon(_isPostCall ? LucideIcons.mic : LucideIcons.fileText, size: 17, color: sb.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _summaryController,
                    maxLines: null,
                    maxLength: 500,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    style: TextStyle(fontSize: 16, height: 24 / 16, color: sb.text),
                    decoration: InputDecoration(
                      hintText: _rawText,
                      filled: false,
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.only(top: 5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        SbCap(
          _promises.isEmpty ? 'No promises found' : 'Promises found',
          trailing: _Link(
            label: 'Add',
            onTap: () => setState(() => _promises.add(_Promise('', OwedBy.me))),
          ),
        ),
        if (_promises.isNotEmpty)
          SbRise(
            delay: const Duration(milliseconds: 160),
            child: SbCard(
              child: Column(
                children: [
                  for (var i = 0; i < _promises.length; i++)
                    _PromiseRow(
                      key: ObjectKey(_promises[i]),
                      promise: _promises[i],
                      theyLabel: _firstName.isEmpty ? 'They owe' : '$_firstName owes',
                      first: i == 0,
                      onFlip: () => setState(
                        () => _promises[i].owedBy = _promises[i].owedBy == OwedBy.me ? OwedBy.them : OwedBy.me,
                      ),
                      onRemove: () => setState(() => _promises.removeAt(i).controller.dispose()),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 22),
        const SbCap('Follow-up'),
        SbRise(
          delay: const Duration(milliseconds: 240),
          child: SbCard(
            onTap: _pickDateTime,
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: sb.fill, borderRadius: BorderRadius.circular(10)),
                  child: Icon(LucideIcons.calendarClock, size: 17, color: sb.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _reminderTitleController,
                        style: TextStyle(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600, color: sb.text),
                        decoration: _bare('Call back about…'),
                      ),
                      Text(
                        reminderWhen,
                        style: TextStyle(fontSize: 13, height: 18 / 13, color: sb.text2),
                      ),
                    ],
                  ),
                ),
                Switch(value: _includeReminder, onChanged: (v) => setState(() => _includeReminder = v)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One promise: the arrow tile (tap to flip who owes), who owes, the
/// editable title and a remove button.
class _PromiseRow extends StatelessWidget {
  const _PromiseRow({
    super.key,
    required this.promise,
    required this.theyLabel,
    required this.first,
    required this.onFlip,
    required this.onRemove,
  });

  final _Promise promise;
  final String theyLabel;
  final bool first;
  final VoidCallback onFlip;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final mine = promise.owedBy == OwedBy.me;
    return Container(
      constraints: BoxConstraints(minHeight: first ? 64 : 65),
      padding: const EdgeInsets.only(left: 16, right: 4),
      decoration: first
          ? null
          : BoxDecoration(
              border: Border(top: BorderSide(color: sb.fill)),
            ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: mine ? 'You owe. Tap to switch.' : '$theyLabel. Tap to switch.',
            excludeSemantics: true,
            child: SbPressable(
              onTap: onFlip,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: mine ? sb.oweBg : sb.goodBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(
                  mine ? LucideIcons.arrowUpRight : LucideIcons.arrowDownLeft,
                  size: 17,
                  color: mine ? sb.oweFg : sb.goodFg,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mine ? 'You owe' : theyLabel,
                    style: TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w700, color: sb.text2),
                  ),
                  TextField(
                    controller: promise.controller,
                    autofocus: promise.controller.text.isEmpty,
                    maxLength: 200,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600, color: sb.text),
                    decoration: _bare('What was promised?'),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: onRemove,
            icon: Icon(LucideIcons.x, size: 18, color: sb.text3),
          ),
        ],
      ),
    );
  }
}

/// A text field with no box, for editing in place inside a card.
InputDecoration _bare(String hint) => InputDecoration(
  hintText: hint,
  isCollapsed: true,
  contentPadding: EdgeInsets.zero,
  filled: false,
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
);

class _Link extends StatelessWidget {
  const _Link({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            label,
            style: TextStyle(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w700, color: context.sb.accent),
          ),
        ),
      ),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: context.sb.primary),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 15, height: 20 / 15, color: context.sb.text2),
          ),
        ],
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onRetry, required this.onKeep});

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.cloudOff, size: 36, color: sb.text3),
            const SizedBox(height: 14),
            Text("Couldn't read the note", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, height: 18 / 13, color: sb.text2),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Try again'),
            ),
            TextButton(onPressed: onKeep, child: const Text('Keep the note as it is')),
          ],
        ),
      ),
    );
  }
}
