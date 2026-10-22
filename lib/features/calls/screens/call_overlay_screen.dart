import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/services/call_overlay_state.dart';
import '../../../core/services/overlay_draft_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sb_widgets.dart';

/// The floating window during calls, built to the "Espresso · final" call
/// boards. Runs in its own Flutter engine (entry point `overlayMain` in
/// main.dart) and talks to the app through [CallOverlayState].
///
/// - Ringing: a small card at the top (who, when you last talked, what you
///   owe them), so the phone's own Accept and Decline stay free.
/// - On the call: a 60 dp pill with the timer and a mark button; tap it to
///   mark a moment ("I promised", "Selam promised", "Follow up") or type a note.
/// - When the call ends the window closes; the app follows up with one quiet
///   notification.
class CallOverlayScreen extends StatefulWidget {
  const CallOverlayScreen({super.key});

  @override
  State<CallOverlayScreen> createState() => _CallOverlayScreenState();
}

enum _View { card, pill, marks, typing }

class _CallOverlayScreenState extends State<CallOverlayScreen> {
  static const _unknownDraftKey = 'unknown_caller';

  String _phase = '';
  String? _contactId;
  String _name = '';
  String _number = '';
  String _company = '';
  int? _lastTalkAt;
  String _owe = '';
  int? _startedAt;
  int? _endedAt;
  List<Map<String, dynamic>> _marks = [];

  /// A call you placed. Android says "off the hook" as soon as you dial and
  /// never says when the other side picks up, so there's no talk timer: the
  /// call log gives the real length afterwards.
  bool _outgoing = false;
  Timer? _collapseTimer;

  /// Status bar height (logical px) measured by the main app. The overlay
  /// window starts at the very top of the screen and gets no insets itself.
  double _topInset = 0;

  _View _view = _View.card;
  bool _closing = false;

  final _noteController = TextEditingController();
  final _noteFocus = FocusNode();
  final _draftService = OverlayDraftService();
  final _cardKey = GlobalKey();
  double _lastHeight = 0;
  StreamSubscription<dynamic>? _messages;
  Timer? _pollTimer;
  Timer? _clockTimer;
  Timer? _debounceTimer;

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

  @override
  void dispose() {
    _messages?.cancel();
    _pollTimer?.cancel();
    _clockTimer?.cancel();
    _debounceTimer?.cancel();
    _collapseTimer?.cancel();
    _noteController.dispose();
    _noteFocus.dispose();
    super.dispose();
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
      _noteController.clear();
      _closing = false;
    }

    // Once we know who the call is with, move any text typed so far to that
    // person's draft (and restore an existing draft if the field is empty).
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
      final wasPhase = _phase;
      _phase = phase;
      _contactId = contactId;
      _name = (state['contactName'] as String? ?? '').trim();
      _number = (state['number'] as String? ?? '').trim();
      _company = (state['company'] as String? ?? '').trim();
      _lastTalkAt = state['lastTalkAt'] as int?;
      _owe = (state['owe'] as String? ?? '').trim();
      _startedAt = state['startedAt'] as int?;
      _endedAt = state['endedAt'] as int?;
      _outgoing = state['outgoing'] == true;
      _topInset = (state['topInset'] as num?)?.toDouble() ?? _topInset;
      _marks = [
        for (final m in (state['marks'] as List? ?? const [])) Map<String, dynamic>.from(m as Map),
      ];
      if (phase == 'ringing') {
        _view = _View.card;
      } else if (phase == 'active' && wasPhase != 'active') {
        if (_outgoing) {
          // Placing a call: who you're calling while it rings, then fold to
          // the bar (or sooner, on a tap).
          _view = _View.card;
          _collapseTimer?.cancel();
          _collapseTimer = Timer(const Duration(seconds: 8), () {
            if (mounted && _view == _View.card) setState(() => _view = _View.pill);
          });
        } else {
          _view = _View.pill;
        }
      }
    });

    if (phase == 'ended') await _endOfCall();
  }

  // ── Sizing ─────────────────────────────────────────────────────

  /// Fits the window to what's showing, so the rest of the screen (the phone's
  /// own call buttons) stays touchable.
  void _fitWindow() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final box = _cardKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final height = (_topInset + 12 + box.size.height + 16).ceilToDouble();
      if ((height - _lastHeight).abs() < 1) return;
      _lastHeight = height;
      try {
        await FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, height.round(), true);
      } catch (_) {}
    });
  }

  // ── Actions ────────────────────────────────────────────────────

  String get _draftKey => _contactId ?? _unknownDraftKey;

  String get _firstName {
    if (_name.isEmpty) return _number.isEmpty ? 'Caller' : _number;
    return _name.split(RegExp(r'\s+')).first;
  }

  int get _elapsedSeconds {
    if (_startedAt == null) return 0;
    final end = _endedAt ?? DateTime.now().millisecondsSinceEpoch;
    final seconds = (end - _startedAt!) ~/ 1000;
    return seconds < 0 ? 0 : seconds;
  }

  static String _clock(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  /// "talked yesterday", "talked 3 days ago" — empty when never.
  String get _lastTalk {
    final at = _lastTalkAt;
    if (at == null || at <= 0) return '';
    final then = DateTime.fromMillisecondsSinceEpoch(at);
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(then.year, then.month, then.day)).inDays;
    if (days <= 0) return 'talked today';
    if (days == 1) return 'talked yesterday';
    if (days < 14) return 'talked $days days ago';
    if (days < 60) return 'talked ${days ~/ 7} weeks ago';
    return 'talked ${days ~/ 30} months ago';
  }

  Future<void> _mark(String type) async {
    final mark = {'type': type, 'at': _elapsedSeconds};
    setState(() => _marks = [..._marks, mark]);
    final state = await CallOverlayState.read() ?? {};
    state['marks'] = [...(state['marks'] as List? ?? const []), mark];
    await CallOverlayState.write(state);
  }

  void _onTextChanged(String text) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () => _draftService.saveDraft(_draftKey, text));
  }

  void _startTyping() {
    setState(() => _view = _View.typing);
    WidgetsBinding.instance.addPostFrameCallback((_) => _noteFocus.requestFocus());
  }

  Future<void> _doneTyping() async {
    _noteFocus.unfocus();
    final text = _noteController.text.trim();
    if (text.isNotEmpty) {
      await _draftService.saveDraft(_draftKey, text);
      // The app picks this up after the call and opens it for review.
      await CallOverlayState.setPendingReview(contactId: _contactId, text: text);
    }
    if (mounted) setState(() => _view = _View.pill);
  }

  /// Hides the window for the rest of this call.
  Future<void> _hide() async {
    final state = await CallOverlayState.read() ?? {};
    state['hidden'] = true;
    await CallOverlayState.write(state);
    await FlutterOverlayWindow.closeOverlay();
  }

  /// The call is over: keep what was typed for review, then get out of the
  /// way. The call state stays for the app, which reads the marks and owes
  /// for its after-call notification and then clears it.
  Future<void> _endOfCall() async {
    if (_closing) return;
    _closing = true;
    final text = _noteController.text.trim();
    if (text.isNotEmpty) {
      await _draftService.saveDraft(_draftKey, text);
      await CallOverlayState.setPendingReview(contactId: _contactId, text: text);
    }
    await FlutterOverlayWindow.closeOverlay();
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _fitWindow();
    final Widget content = switch (_view) {
      _View.card => _RingCard(
        calling: _outgoing,
        onTap: _outgoing ? () => setState(() => _view = _View.pill) : null,
        name: _name.isEmpty ? (_number.isEmpty ? (_outgoing ? 'Outgoing call' : 'Incoming call') : _number) : _name,
        detail: [
          _company.isNotEmpty ? _company : (_contactId == null ? 'Not in your people' : ''),
          _lastTalk,
        ].where((s) => s.isNotEmpty).join(' · '),
        owe: _owe,
        onHide: _hide,
      ),
      _View.pill => _Pill(
        name: _firstName,
        faceName: _name.isEmpty ? '#' : _name,
        owe: _owe,
        clock: _outgoing ? '' : _clock(_elapsedSeconds),
        marked: _marks.isNotEmpty,
        onOpen: () => setState(() => _view = _View.marks),
      ),
      _View.marks => _MarkPanel(
        name: _firstName,
        faceName: _name.isEmpty ? '#' : _name,
        owe: _owe,
        clock: _outgoing ? '' : _clock(_elapsedSeconds),
        showTimes: !_outgoing,
        marks: _marks,
        onMark: _mark,
        onType: _startTyping,
        onClose: () => setState(() => _view = _View.pill),
      ),
      _View.typing => _TypePanel(
        name: _firstName,
        controller: _noteController,
        focusNode: _noteFocus,
        onChanged: _onTextChanged,
        onDone: _doneTyping,
      ),
    };
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      // The window is resized to fit what's showing, so lay the content out at
      // its own height (not the window's) and measure that.
      body: OverflowBox(
        alignment: Alignment.topCenter,
        minHeight: 0,
        maxHeight: double.infinity,
        child: Padding(
          padding: EdgeInsets.fromLTRB(10, 12 + _topInset, 10, 0),
          child: KeyedSubtree(key: _cardKey, child: content),
        ),
      ),
    );
  }
}

/// The white card the call boards use: 26 corners and a soft drop shadow.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.child, this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 14), this.radius = 26});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: context.sb.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(color: Color(0x47000000), blurRadius: 18, spreadRadius: -12, offset: Offset(0, 12)),
        ],
      ),
      child: child,
    );
  }
}

class _OweTag extends StatelessWidget {
  const _OweTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: sb.oweBg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        'You owe: $text',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w700, color: sb.oweFg),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.onTap, this.size = 32});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;

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
          width: size,
          height: size,
          decoration: BoxDecoration(color: sb.fill, shape: BoxShape.circle),
          child: Icon(icon, size: size * 0.45, color: sb.text),
        ),
      ),
    );
  }
}

/// While it rings: app line with a hide button, who is calling, what you owe.
class _RingCard extends StatelessWidget {
  const _RingCard({
    required this.name,
    required this.detail,
    required this.owe,
    required this.onHide,
    this.calling = false,
    this.onTap,
  });

  final String name;
  final String detail;
  final String owe;
  final VoidCallback onHide;

  /// You're the one calling (the card shows while it rings at their end).
  final bool calling;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    return Semantics(
      container: true,
      label: calling ? 'Calling $name' : '$name is calling',
      child: GestureDetector(
        onTap: onTap,
        child: _Sheet(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(color: sb.primary, borderRadius: BorderRadius.circular(7)),
                    child: Icon(LucideIcons.phone, size: 12, color: sb.honey),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      calling ? 'SmartBroker · calling' : 'SmartBroker',
                      style: TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600, color: sb.text2),
                    ),
                  ),
                  _RoundButton(icon: LucideIcons.x, label: 'Hide', onTap: onHide),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  SbFace(name: name, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 17, height: 22 / 17, fontWeight: FontWeight.w700, color: sb.text),
                        ),
                        if (detail.isNotEmpty)
                          Text(
                            detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, height: 18 / 13, color: sb.text2),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (owe.isNotEmpty) ...[
                const SizedBox(height: 12),
                _OweTag(owe),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// On the call, folded away: face, first name, what you owe, timer, mark.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.name,
    required this.faceName,
    required this.owe,
    required this.clock,
    required this.marked,
    required this.onOpen,
  });

  final String name;
  final String faceName;
  final String owe;
  final String clock;
  final bool marked;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    return Semantics(
      button: true,
      label: 'On a call with $name, $clock. Mark a moment.',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onOpen,
        child: _Sheet(
          radius: 999,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                SbFace(name: faceName, size: 44),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w700, color: sb.text),
                      ),
                      if (owe.isNotEmpty)
                        Text(
                          'You owe: $owe',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w700, color: sb.oweFg),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // A call you placed has no talk timer (see _outgoing).
                if (clock.isEmpty)
                  Icon(LucideIcons.phoneOutgoing, size: 16, color: sb.text2)
                else
                  Text(
                    clock,
                    style: TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      fontWeight: FontWeight.w700,
                      color: sb.text2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                const SizedBox(width: 10),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: sb.primary, shape: BoxShape.circle),
                  // Turns honey once something has been marked on this call.
                  child: Icon(LucideIcons.bookmark, size: 20, color: marked ? sb.honey : sb.onPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opened up: the three moments to mark (each shows when it was marked)
/// and a way to type a note.
class _MarkPanel extends StatelessWidget {
  const _MarkPanel({
    required this.name,
    required this.faceName,
    required this.owe,
    required this.clock,
    required this.marks,
    this.showTimes = true,
    required this.onMark,
    required this.onType,
    required this.onClose,
  });

  final String name;
  final String faceName;
  final String owe;
  final String clock;
  final List<Map<String, dynamic>> marks;

  /// Off for calls you placed: times would count from dialling, not from
  /// when they picked up.
  final bool showTimes;
  final ValueChanged<String> onMark;
  final VoidCallback onType;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    String? lastAt(String type) {
      final mine = marks.where((m) => m['type'] == type).toList();
      if (mine.isEmpty) return null;
      return _CallOverlayScreenState._clock(mine.last['at'] as int? ?? 0);
    }

    Widget tile(String type, String label) {
      final at = lastAt(type);
      final on = at != null;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          label: on ? (showTimes ? '$label, marked at $at' : '$label, marked') : label,
          excludeSemantics: true,
          child: SbPressable(
            onTap: () => onMark(type),
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: on ? sb.oweBg : sb.fill, borderRadius: BorderRadius.circular(18)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Two lines, so "Alemayehu promised" fits without cutting the name.
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: on ? 14 : 15,
                      height: 18 / 15,
                      fontWeight: FontWeight.w700,
                      color: on ? sb.oweFg : sb.text,
                    ),
                  ),
                  if (on && showTimes)
                    Row(
                      children: [
                        Icon(LucideIcons.check, size: 12, color: sb.oweFg),
                        const SizedBox(width: 4),
                        Text(
                          at,
                          style: TextStyle(
                            fontSize: 12,
                            height: 16 / 12,
                            fontWeight: FontWeight.w700,
                            color: sb.oweFg,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return _Sheet(
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SbFace(name: faceName, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w700, color: sb.text),
                ),
              ),
              if (clock.isEmpty)
                Icon(LucideIcons.phoneOutgoing, size: 16, color: sb.text2)
              else
                Text(
                  clock,
                  style: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w700,
                    color: sb.text2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              const SizedBox(width: 10),
              _RoundButton(icon: LucideIcons.chevronUp, label: 'Make smaller', onTap: onClose, size: 36),
            ],
          ),
          if (owe.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 0, 0),
              child: _OweTag(owe),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
            child: Text(
              'Mark a moment',
              style: TextStyle(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w700, color: sb.text2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Row(
              children: [
                tile('mine', 'I promised'),
                const SizedBox(width: 6),
                tile('theirs', '$name promised'),
                const SizedBox(width: 6),
                tile('followUp', 'Follow up'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 6),
            child: Semantics(
              button: true,
              child: InkWell(
                onTap: onType,
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 40,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.pencil, size: 14, color: sb.text2),
                      const SizedBox(width: 6),
                      Text(
                        'Type a note',
                        style: TextStyle(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w600, color: sb.text2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Typing during the call: a few lines, saved as a draft as you go.
class _TypePanel extends StatelessWidget {
  const _TypePanel({
    required this.name,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onDone,
  });

  final String name;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    return _Sheet(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Note for $name',
                  style: TextStyle(fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w700, color: sb.text),
                ),
              ),
              TextButton(onPressed: onDone, child: const Text('Done')),
            ],
          ),
          SizedBox(
            height: 140,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(fontSize: 16, height: 24 / 16, color: sb.text),
              decoration: const InputDecoration(
                hintText: 'What did you agree?',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
