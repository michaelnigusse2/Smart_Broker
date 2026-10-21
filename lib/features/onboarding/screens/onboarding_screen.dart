import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/services/app_log.dart';
import '../../../core/services/call_detection_service.dart';
import '../../../core/services/call_matching_service.dart';
import '../../../core/services/phone_contact_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sb_widgets.dart';
import '../../../core/transcription/dictation_audio.dart';
import '../../../core/transcription/scribe_model_store.dart';

/// First launch: a greeting, the person's name, their work, permissions, done.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  int _step = 0;
  WorkType? _work;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final profile = ProfileService();
    final name = await profile.getName();
    final work = await profile.getWork();
    if (!mounted) return;
    setState(() {
      if (_name.text.isEmpty) _name.text = name;
      _work ??= work;
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  String get _firstName => _name.text.trim();

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _pages.jumpToPage(step);
    } else {
      _pages.animateToPage(step, duration: const Duration(milliseconds: 380), curve: const Cubic(0.05, 0.7, 0.1, 1));
    }
    if (step == 1) {
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _step == 1) _nameFocus.requestFocus();
      });
    }
  }

  void _back() {
    if (_step > 0) _go(_step - 1);
  }

  Future<void> _saveNameAndContinue() async {
    if (_firstName.isEmpty) return;
    await ProfileService().setName(_firstName);
    if (mounted) _go(2);
  }

  Future<void> _saveWorkAndContinue() async {
    final work = _work;
    if (work == null) return;
    await ProfileService().setWork(work);
    if (mounted) _go(3);
  }

  Future<void> _finish() async {
    final profile = ProfileService();
    await profile.setName(_firstName);
    if (_work != null) await profile.setWork(_work!);
    await profile.setOnboarded(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.shell);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: PageView(
            controller: _pages,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _WelcomeStep(onStart: () => _go(1)),
              _StepFrame(
                step: 1,
                onBack: _back,
                button: ListenableBuilder(
                  listenable: _name,
                  builder: (context, _) => SbPrimaryButton(
                    label: 'Continue',
                    trailingIcon: LucideIcons.arrowRight,
                    onPressed: _firstName.isEmpty ? null : _saveNameAndContinue,
                  ),
                ),
                children: [_NameStep(controller: _name, focusNode: _nameFocus, onSubmitted: _saveNameAndContinue)],
              ),
              _StepFrame(
                step: 2,
                onBack: _back,
                button: SbPrimaryButton(
                  label: 'Continue',
                  trailingIcon: LucideIcons.arrowRight,
                  onPressed: _work == null ? null : _saveWorkAndContinue,
                ),
                children: [
                  _WorkStep(
                    name: _firstName,
                    selected: _work,
                    onSelect: (work) => setState(() => _work = work),
                  ),
                ],
              ),
              _StepFrame(
                step: 3,
                onBack: _back,
                button: SbPrimaryButton(
                  label: 'Continue',
                  trailingIcon: LucideIcons.arrowRight,
                  onPressed: () => _go(4),
                ),
                children: [_SetupStep(name: _firstName)],
              ),
              _StepFrame(
                step: 4,
                onBack: _back,
                button: SbPrimaryButton(label: 'Open Today', trailingIcon: LucideIcons.arrowRight, onPressed: _finish),
                children: [_ReadyStep(name: _firstName)],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Back button, four-step progress bar, the step's content (scrolls when the
/// text is large) and its button pinned at the bottom.
class _StepFrame extends StatelessWidget {
  const _StepFrame({required this.step, required this.onBack, required this.children, required this.button});

  final int step;
  final VoidCallback onBack;
  final List<Widget> children;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            children: [
              SbCircleButton(icon: LucideIcons.chevronLeft, tooltip: 'Back', onPressed: onBack, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Semantics(
                  label: 'Step $step of 4',
                  child: Row(
                    children: [
                      for (var i = 1; i <= 4; i++) ...[
                        if (i > 1) const SizedBox(width: 6),
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 4,
                            decoration: BoxDecoration(
                              color: i <= step ? sb.primary : sb.track,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), child: button),
      ],
    );
  }
}

// ── Step 0: welcome ──────────────────────────────────────────────

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final text = Theme.of(context).textTheme;
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 3),
                const _CyclingGreeting(),
                const SizedBox(height: 14),
                Text(
                  'Your calls,\nremembered.',
                  style: text.headlineMedium?.copyWith(color: sb.text2, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 26),
                const _TibebStripe(width: 120),
                const Spacer(flex: 4),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.shieldCheck, size: 15, color: sb.text2),
                    const SizedBox(width: 8),
                    Flexible(child: Text('Works offline · Amharic and English', style: text.bodySmall)),
                  ],
                ),
                const SizedBox(height: 16),
                SbPrimaryButton(label: 'Get started', trailingIcon: LucideIcons.arrowRight, onPressed: onStart),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// ሰላም → Hello → Akkam, one at a time. Stays on ሰላም when the phone asks
/// for less motion.
class _CyclingGreeting extends StatefulWidget {
  const _CyclingGreeting();

  @override
  State<_CyclingGreeting> createState() => _CyclingGreetingState();
}

class _CyclingGreetingState extends State<_CyclingGreeting> {
  static const _words = ['ሰላም', 'Hello', 'Akkam'];
  int _index = 0;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(const Duration(milliseconds: 2600), (_) {
        if (mounted) setState(() => _index = (_index + 1) % _words.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.displayLarge?.copyWith(fontSize: 76, height: 88 / 76, letterSpacing: -2.5);
    return Semantics(
      label: 'Selam, hello, akkam',
      excludeSemantics: true,
      child: SizedBox(
        height: 96,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          switchInCurve: const Cubic(0.05, 0.7, 0.1, 1),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.2), end: Offset.zero).animate(animation),
              child: child,
            ),
          ),
          layoutBuilder: (current, previous) =>
              Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
          child: FittedBox(
            key: ValueKey(_index),
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(_words[_index], maxLines: 1, style: style),
          ),
        ),
      ),
    );
  }
}

/// A short strip of the tibeb weave: honey diamonds with espresso centres.
class _TibebStripe extends StatelessWidget {
  const _TibebStripe({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(width, 10),
        painter: _TibebPainter(diamond: sb.honey, centre: SbPalette.light.primary, bar: sb.accent),
      ),
    );
  }
}

class _TibebPainter extends CustomPainter {
  _TibebPainter({required this.diamond, required this.centre, required this.bar});

  final Color diamond;
  final Color centre;
  final Color bar;

  @override
  void paint(Canvas canvas, Size size) {
    final big = Paint()..color = diamond;
    final small = Paint()..color = centre;
    final side = Paint()..color = bar;
    for (double x = 0; x + 20 <= size.width; x += 20) {
      canvas.drawPath(
        Path()
          ..moveTo(x + 10, 1)
          ..lineTo(x + 15, 5)
          ..lineTo(x + 10, 9)
          ..lineTo(x + 5, 5)
          ..close(),
        big,
      );
      canvas.drawPath(
        Path()
          ..moveTo(x + 10, 3.4)
          ..lineTo(x + 12, 5)
          ..lineTo(x + 10, 6.6)
          ..lineTo(x + 8, 5)
          ..close(),
        small,
      );
      canvas.drawRect(Rect.fromLTWH(x, 4, 2.5, 2), side);
      canvas.drawRect(Rect.fromLTWH(x + 17.5, 4, 2.5, 2), side);
    }
  }

  @override
  bool shouldRepaint(_TibebPainter old) => old.diamond != diamond || old.centre != centre || old.bar != bar;
}

// ── Step 1: name ─────────────────────────────────────────────────

class _NameStep extends StatelessWidget {
  const _NameStep({required this.controller, required this.focusNode, required this.onSubmitted});

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What should we\ncall you?', style: text.displaySmall),
        const SizedBox(height: 8),
        Text('ስምዎ ማን ነው?', style: text.bodyLarge?.copyWith(fontSize: 17, color: sb.text2)),
        const SizedBox(height: 36),
        Text('Your name', style: text.labelMedium),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.givenName],
          maxLength: 40,
          onSubmitted: (_) => onSubmitted(),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Your first name',
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.input,
              borderSide: BorderSide(color: sb.track, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(LucideIcons.lock, size: 15, color: sb.text2),
            const SizedBox(width: 8),
            Flexible(child: Text('Stays on this phone', style: text.bodySmall)),
          ],
        ),
      ],
    );
  }
}

// ── Step 2: work ─────────────────────────────────────────────────

class _WorkStep extends StatelessWidget {
  const _WorkStep({required this.name, required this.selected, required this.onSelect});

  final String name;
  final WorkType? selected;
  final ValueChanged<WorkType> onSelect;

  static const _icons = {
    WorkType.company: LucideIcons.briefcase,
    WorkType.sales: LucideIcons.trendingUp,
    WorkType.realEstate: LucideIcons.home,
    WorkType.other: LucideIcons.moreHorizontal,
  };

  static const _tints = {
    WorkType.company: SbTint.slate,
    WorkType.sales: SbTint.sage,
    WorkType.realEstate: SbTint(Color(0xFFF4E3C4), Color(0xFF7A4B0F)),
    WorkType.other: SbTint.mocha,
  };

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final text = Theme.of(context).textTheme;
    Widget tile(WorkType type) => Expanded(
      child: _WorkTile(
        label: type.label,
        icon: _icons[type]!,
        tint: _tints[type]!,
        selected: selected == type,
        onTap: () => onSelect(type),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Nice to meet you,\n'),
              TextSpan(
                text: name.isEmpty ? 'friend.' : '$name.',
                style: TextStyle(color: sb.accent),
              ),
            ],
          ),
          style: text.displaySmall,
        ),
        const SizedBox(height: 10),
        Text("What's your work?", style: text.bodyLarge?.copyWith(fontSize: 17, color: sb.text2)),
        const SizedBox(height: 28),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [tile(WorkType.company), const SizedBox(width: 10), tile(WorkType.sales)],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [tile(WorkType.realEstate), const SizedBox(width: 10), tile(WorkType.other)],
          ),
        ),
      ],
    );
  }
}

class _WorkTile extends StatelessWidget {
  const _WorkTile({
    required this.label,
    required this.icon,
    required this.tint,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final SbTint tint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: SbPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          constraints: const BoxConstraints(minHeight: 124),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? sb.primary : sb.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: sb.shadow, blurRadius: 2, offset: const Offset(0, 1))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selected ? sb.onPrimary.withValues(alpha: 0.12) : tint.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 21, color: selected ? sb.honey : tint.fg),
                  ),
                  const Spacer(),
                  AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(color: sb.honey, shape: BoxShape.circle),
                      child: const Icon(LucideIcons.check, size: 14, color: Color(0xFF2A1C15)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  height: 22 / 17,
                  fontWeight: FontWeight.w700,
                  color: selected ? sb.onPrimary : sb.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step 3: quick setup ──────────────────────────────────────────

class _SetupStep extends StatefulWidget {
  const _SetupStep({required this.name});

  final String name;

  @override
  State<_SetupStep> createState() => _SetupStepState();
}

class _SetupStepState extends State<_SetupStep> {
  final _calls = CallDetectionService();
  final _store = ScribeModelStore.instance;
  bool _contactsOn = false;
  bool _callsOn = false;
  bool _micOn = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final callsOn =
          _calls.isSupported && await _calls.isPermissionGranted() && await SettingsService().getCallDetectionEnabled();
      final micOn = Platform.isAndroid && await DictationAudio.hasPermission();
      await _store.ensureChecked();
      if (!mounted) return;
      setState(() {
        _callsOn = callsOn;
        _micOn = micOn;
      });
    } catch (e) {
      AppLog.w('Onboarding', 'could not read permission state', e);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e, st) {
      AppLog.e('Onboarding', 'setup step failed', e, st);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _allowContacts() => _run(() async {
    final granted = await PhoneContactService().requestPermission();
    if (mounted) setState(() => _contactsOn = granted);
  });

  Future<void> _allowCalls() => _run(() async {
    final granted = await _calls.requestPermission();
    if (!granted) return;
    if (await _calls.start()) {
      CallMatchingService().startListening();
      await SettingsService().setCallDetectionEnabled(true);
    }
    // The card shown during calls draws over the phone's call screen.
    if (!await FlutterOverlayWindow.isPermissionGranted()) {
      await FlutterOverlayWindow.requestPermission();
    }
    if (mounted) setState(() => _callsOn = true);
  });

  Future<void> _allowMic() => _run(() async {
    final granted = await DictationAudio.requestPermission();
    if (mounted) setState(() => _micOn = granted);
  });

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'A few quick things,\n'),
              TextSpan(
                text: widget.name.isEmpty ? 'and done.' : '${widget.name}.',
                style: TextStyle(color: sb.accent),
              ),
            ],
          ),
          style: text.displaySmall,
        ),
        const SizedBox(height: 28),
        SbCard(
          child: Column(
            children: [
              _SetupRow(
                icon: LucideIcons.users,
                tint: SbTint.slate,
                title: 'Your contacts',
                subtitle: "Know who's who",
                done: _contactsOn,
                actionLabel: 'Allow',
                onAction: _busy ? null : _allowContacts,
              ),
              _SetupRow(
                icon: LucideIcons.phone,
                tint: SbTint.sage,
                title: 'Calls',
                subtitle: "See who's calling",
                done: _callsOn,
                actionLabel: 'Allow',
                onAction: _busy ? null : _allowCalls,
                divider: true,
              ),
              _SetupRow(
                icon: LucideIcons.mic,
                tint: SbTint.mocha,
                title: 'Microphone',
                subtitle: 'For voice notes',
                done: _micOn,
                actionLabel: 'Allow',
                onAction: _busy ? null : _allowMic,
                divider: true,
              ),
              ListenableBuilder(
                listenable: _store,
                builder: (context, _) {
                  final status = _store.status;
                  final downloading = status == ScribeModelStatus.downloading || status == ScribeModelStatus.verifying;
                  final pct = (_store.progress * 100).clamp(0, 100).round();
                  final subtitle = switch (status) {
                    ScribeModelStatus.ready => 'Ready · works offline',
                    ScribeModelStatus.downloading => '500 MB · $pct%',
                    ScribeModelStatus.verifying => 'Checking the file',
                    ScribeModelStatus.failed => 'Download stopped · try again',
                    ScribeModelStatus.notDownloaded => '500 MB · use Wi-Fi',
                  };
                  return _SetupRow(
                    icon: LucideIcons.download,
                    tint: const SbTint(Color(0xFFF4E3C4), Color(0xFF7A4B0F)),
                    title: 'Offline voice',
                    subtitle: subtitle,
                    done: status == ScribeModelStatus.ready,
                    actionLabel: status == ScribeModelStatus.failed ? 'Retry' : 'Get',
                    onAction: downloading ? null : _store.download,
                    progress: downloading ? _store.progress.clamp(0.0, 1.0) : null,
                    divider: true,
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('Change these any time in Settings.', style: text.bodySmall),
        ),
      ],
    );
  }
}

class _SetupRow extends StatelessWidget {
  const _SetupRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.actionLabel,
    required this.onAction,
    this.progress,
    this.divider = false,
  });

  final IconData icon;
  final SbTint tint;
  final String title;
  final String subtitle;
  final bool done;
  final String actionLabel;
  final VoidCallback? onAction;
  final double? progress;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final text = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: divider ? Border(top: BorderSide(color: sb.fill)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: tint.bg, borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, size: 21, color: tint.fg),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall?.copyWith(fontSize: 17)),
                Text(subtitle, style: text.bodySmall),
                if (progress != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(value: progress, minHeight: 4),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (done)
            Semantics(
              label: '$title is on',
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: sb.goodBg, borderRadius: BorderRadius.circular(99)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.check, size: 15, color: sb.goodFg),
                    const SizedBox(width: 4),
                    Text(
                      'On',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: sb.goodFg),
                    ),
                  ],
                ),
              ),
            )
          else
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                minimumSize: const Size(64, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }
}

// ── Step 4: ready ────────────────────────────────────────────────

class _ReadyStep extends StatelessWidget {
  const _ReadyStep({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: "You're all set,\n"),
              TextSpan(
                text: name.isEmpty ? 'welcome.' : '$name.',
                style: TextStyle(color: sb.accent),
              ),
            ],
          ),
          style: text.displaySmall,
        ),
        const SizedBox(height: 10),
        Text("Here's how it works.", style: text.bodyLarge?.copyWith(fontSize: 17, color: sb.text2)),
        const SizedBox(height: 28),
        SbRise(
          delay: const Duration(milliseconds: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SbCap('When they call'),
              SbCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SbFace(name: 'Selam Tesfaye', size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Selam Tesfaye', style: text.titleMedium),
                              Text('Dashen Bank · talked yesterday', style: text.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        SbTag.owe(context, 'numbers'),
                        SbTag('Example', background: sb.fill, foreground: sb.text2),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SbRise(
          delay: const Duration(milliseconds: 200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SbCap('After you hang up'),
              SbCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Call with Selam · 6:42', style: text.titleSmall),
                    const SizedBox(height: 2),
                    Text('A quiet note, never the whole app', style: text.bodySmall),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        SbTag('Settled', icon: LucideIcons.check, background: sb.goodBg, foreground: sb.goodFg),
                        SbTag('Add note', icon: LucideIcons.mic, background: sb.fill, foreground: sb.text),
                        SbTag('Not now', background: sb.fill, foreground: sb.text2),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
