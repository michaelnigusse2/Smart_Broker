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
  const OnboardingScreen({super.key, this.initialStep = 0});

  /// Opens on a later step (0 = welcome … 4 = ready); for design snapshots.
  @visibleForTesting
  final int initialStep;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final _pages = PageController(initialPage: widget.initialStep);
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  late int _step = widget.initialStep;
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
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
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
            padding: const EdgeInsets.fromLTRB(24, 44, 24, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), child: button),
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
    // The board puts the greeting 248 dp down an 844 dp screen; keep the
    // same proportion on shorter and taller phones.
    final view = View.of(context);
    final statusBar = view.padding.top / view.devicePixelRatio;
    final screenHeight = view.physicalSize.height / view.devicePixelRatio;
    final greetingTop = (screenHeight * 248 / 844 - statusBar - 64).clamp(16.0, 400.0);
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Align(alignment: Alignment.centerRight, child: _LanguageSwitch()),
                SizedBox(height: greetingTop),
                const _CyclingGreeting(),
                const SizedBox(height: 14),
                Text(
                  'Your calls,\nremembered.',
                  style: text.headlineMedium?.copyWith(
                    fontSize: 28,
                    height: 34 / 28,
                    letterSpacing: -0.6,
                    fontWeight: FontWeight.w700,
                    color: sb.text2,
                  ),
                ),
                const SizedBox(height: 26),
                const _TibebStripe(width: 120),
                const Spacer(),
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

/// English | አማርኛ, as on the welcome board. The choice is saved; the
/// screens themselves are English until the Amharic translation lands.
class _LanguageSwitch extends StatefulWidget {
  const _LanguageSwitch();

  @override
  State<_LanguageSwitch> createState() => _LanguageSwitchState();
}

class _LanguageSwitchState extends State<_LanguageSwitch> {
  String _language = 'en';

  @override
  void initState() {
    super.initState();
    ProfileService().getLanguage().then((value) {
      if (mounted) setState(() => _language = value);
    });
  }

  Future<void> _choose(String language) async {
    if (language == _language) return;
    setState(() => _language = language);
    await ProfileService().setLanguage(language);
    if (!mounted || language != 'am') return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Amharic screens are on the way. Dictation already works in Amharic.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    Widget option(String code, String label) {
      final selected = _language == code;
      return Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: SbPressable(
          onTap: () => _choose(code),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? sb.primary : sb.surface.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                fontWeight: FontWeight.w600,
                color: selected ? sb.onPrimary : sb.text2,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: sb.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: sb.hairline),
        boxShadow: [BoxShadow(color: sb.shadow, blurRadius: 2, offset: const Offset(0, 1))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [option('en', 'English'), option('am', 'አማርኛ')]),
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
        height: 88,
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
        // The board's field is exactly 64 high; expands fills that box.
        SizedBox(
          height: 64,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.givenName],
            maxLength: 40,
            keyboardType: TextInputType.name,
            expands: true,
            maxLines: null,
            onSubmitted: (_) => onSubmitted(),
            style: const TextStyle(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w600),
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              hintText: 'Your first name',
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(horizontal: 18),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: BorderSide(color: sb.track, width: 2),
              ),
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

  // As on the board: "I sell" slate, "Real estate" cherry, "Something else" mocha.
  static const _tints = {
    WorkType.company: SbTint.sage,
    WorkType.sales: SbTint.slate,
    WorkType.realEstate: SbTint.cherry,
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

/// "Three quick things": contacts and calls (so the app knows who's calling),
/// the microphone, and the offline voice download, each with a switch.
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
        _contactsOn = callsOn;
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

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Contacts plus the phone permissions behind "who's calling" (the card
  /// shown during calls), and the permission to draw that card.
  Future<void> _setContacts(bool on) => _run(() async {
    if (!on) {
      await SettingsService().setCallDetectionEnabled(false);
      await _calls.stop();
      CallMatchingService().stopListening();
      if (mounted) setState(() => _contactsOn = false);
      return;
    }
    final contacts = await PhoneContactService().requestPermission();
    final phone = await _calls.requestPermission();
    if (phone && await _calls.start()) {
      CallMatchingService().startListening();
      await SettingsService().setCallDetectionEnabled(true);
      if (!await FlutterOverlayWindow.isPermissionGranted()) {
        await FlutterOverlayWindow.requestPermission();
      }
    }
    if (mounted) setState(() => _contactsOn = contacts && phone);
  });

  Future<void> _setMic(bool on) => _run(() async {
    if (!on) {
      // An app can't take back its own permission; Android settings can.
      _say('To turn the microphone off, use Android settings');
      return;
    }
    final granted = await DictationAudio.requestPermission();
    if (mounted) setState(() => _micOn = granted);
  });

  void _setVoice(bool on) {
    if (on) {
      _store.download();
    } else if (_store.isBusy) {
      _store.cancel();
    }
  }

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
              const TextSpan(text: 'Three quick things,\n'),
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
                subtitle: "Know who's calling",
                value: _contactsOn,
                onChanged: _busy ? null : _setContacts,
              ),
              _SetupRow(
                icon: LucideIcons.mic,
                tint: SbTint.mocha,
                title: 'Microphone',
                subtitle: 'For voice notes',
                value: _micOn,
                onChanged: _busy ? null : _setMic,
                divider: true,
              ),
              ListenableBuilder(
                listenable: _store,
                builder: (context, _) {
                  final status = _store.status;
                  final busy = _store.isBusy;
                  final pct = (_store.progress * 100).clamp(0, 100).round();
                  final subtitle = switch (status) {
                    ScribeModelStatus.ready => 'Ready · works offline',
                    ScribeModelStatus.downloading => '500 MB · Wi-Fi only · $pct%',
                    ScribeModelStatus.verifying => '500 MB · checking',
                    ScribeModelStatus.failed => 'Stopped · switch on to retry',
                    ScribeModelStatus.notDownloaded => '500 MB · Wi-Fi only',
                  };
                  return _SetupRow(
                    icon: LucideIcons.download,
                    tint: const SbTint(Color(0xFFF7DDD3), Color(0xFF8E3321)),
                    title: 'Offline voice',
                    subtitle: subtitle,
                    value: busy || status == ScribeModelStatus.ready,
                    onChanged: status == ScribeModelStatus.ready || status == ScribeModelStatus.verifying
                        ? null
                        : _setVoice,
                    progress: busy ? _store.progress.clamp(0.0, 1.0) : null,
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

/// One setup row: a 42 dp tinted icon tile, title and one line, a switch.
class _SetupRow extends StatelessWidget {
  const _SetupRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.progress,
    this.divider = false,
  });

  final IconData icon;
  final SbTint tint;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double? progress;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    return MergeSemantics(
      child: GestureDetector(
        // The whole row toggles, not just the switch.
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: _row(sb),
      ),
    );
  }

  Widget _row(SbPalette sb) {
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
            child: Icon(icon, size: 22, color: tint.fg),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 17, height: 22 / 17, fontWeight: FontWeight.w600, color: sb.text),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    height: 18 / 13,
                    color: sb.text2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: sb.fill),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch(value: value, onChanged: onChanged),
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
    Widget cap(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Semantics(header: true, child: Text(label, style: text.labelMedium)),
    );
    Widget chip(String label, Color bg, Color fg, {IconData? icon}) => Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
          Text(
            label,
            style: TextStyle(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
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
              cap('Before each call'),
              SbCard(
                radius: 22,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                              Text(
                                'Selam Tesfaye',
                                style: TextStyle(
                                  fontSize: 17,
                                  height: 22 / 17,
                                  fontWeight: FontWeight.w700,
                                  color: sb.text,
                                ),
                              ),
                              Text(
                                'Dashen Bank',
                                style: TextStyle(fontSize: 13, height: 18 / 13, color: sb.text2),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '10:30',
                          style: TextStyle(
                            fontSize: 15,
                            height: 20 / 15,
                            fontWeight: FontWeight.w700,
                            color: sb.text,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(minHeight: 30),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(color: sb.oweBg, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        'You owe: numbers',
                        style: TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w700, color: sb.oweFg),
                      ),
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
              cap('After each call'),
              SbCard(
                radius: 22,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Call with Selam · 6:42',
                      style: TextStyle(fontSize: 17, height: 22 / 17, fontWeight: FontWeight.w700, color: sb.text),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        chip('Settled', sb.goodBg, sb.goodFg, icon: LucideIcons.check),
                        chip('Add note', sb.fill, sb.primary, icon: LucideIcons.mic),
                        chip('Not now', sb.fill, sb.text2),
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
