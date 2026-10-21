import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';

/// A person's face: their first letter on a soft tint that's always the same
/// for that name. [late] adds a small red dot.
class SbFace extends StatelessWidget {
  const SbFace({super.key, required this.name, this.size = 40, this.late = false, this.ring});

  final String name;
  final double size;
  final bool late;

  /// Colour of the ring around the face and its dot (the surface behind it).
  final Color? ring;

  static String letterFor(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final first = trimmed.characters.first;
    // A saved phone number has no letter worth showing.
    if (RegExp(r'[0-9+]').hasMatch(first)) return '#';
    return first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final tint = SbTint.forName(name);
    final ringColor = ring;
    final face = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.bg,
        shape: BoxShape.circle,
        border: ringColor == null
            ? null
            : Border.all(color: ringColor, width: 3, strokeAlign: BorderSide.strokeAlignOutside),
      ),
      child: Text(
        letterFor(name),
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontFamily: AppFonts.body,
          fontFamilyFallback: AppFonts.bodyFallback,
          fontSize: size * 0.4,
          height: 1,
          fontWeight: FontWeight.w700,
          color: tint.fg,
        ),
      ),
    );
    if (!late) return ExcludeSemantics(child: face);
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            face,
            Positioned(
              top: 0,
              right: 0,
              child: SbLateDot(faceSize: size, ring: ringColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// The red "late" dot at a face's top-right: 11 dp on a 40 dp face, with a
/// 2 dp ring of the surface around it.
class SbLateDot extends StatelessWidget {
  const SbLateDot({super.key, this.faceSize = 40, this.ring});

  final double faceSize;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final dot = faceSize * 0.275;
    return Container(
      width: dot,
      height: dot,
      decoration: BoxDecoration(
        color: context.sb.lateDot,
        shape: BoxShape.circle,
        border: Border.all(color: ring ?? context.sb.surface, width: 2, strokeAlign: BorderSide.strokeAlignOutside),
      ),
    );
  }
}

/// A card on the canvas: surface colour, 24 corners, a soft shadow in light
/// mode and a hairline in dark mode. Tappable when [onTap] is set.
class SbCard extends StatelessWidget {
  const SbCard({super.key, required this.child, this.padding, this.onTap, this.radius = AppRadius.lg, this.color});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: sb.hairline),
    );
    final content = padding == null ? child : Padding(padding: padding!, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [BoxShadow(color: sb.shadow, blurRadius: 2, offset: const Offset(0, 1))],
      ),
      child: Material(
        color: color ?? sb.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

/// A small bold label above a group: "Waiting on you", "Before you call".
class SbCap extends StatelessWidget {
  const SbCap(this.label, {super.key, this.color, this.trailing});

  final String label;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(color: color ?? context.sb.text2);
    final text = Semantics(header: true, child: Text(label, style: style));
    if (trailing == null) {
      return Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 10), child: text);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          Expanded(child: text),
          trailing!,
        ],
      ),
    );
  }
}

/// A rounded tag: "You owe: numbers", "Offer", "2d late".
class SbTag extends StatelessWidget {
  const SbTag(
    this.label, {
    super.key,
    required this.background,
    required this.foreground,
    this.icon,
    this.small = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final bool small;

  /// The cherry "You owe" tag.
  factory SbTag.owe(BuildContext context, String what, {Key? key}) =>
      SbTag('You owe: $what', key: key, background: context.sb.oweBg, foreground: context.sb.oweFg);

  @override
  Widget build(BuildContext context) {
    final fontSize = small ? 12.0 : 14.0;
    return Container(
      constraints: BoxConstraints(minHeight: small ? 22 : 30),
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 12, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(small ? 8 : 10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: fontSize + 2, color: foreground), const SizedBox(width: 6)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: fontSize, height: 1.3, fontWeight: FontWeight.w700, color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// A round 44 dp button: espresso when [filled], otherwise on the surface.
class SbCircleButton extends StatelessWidget {
  const SbCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
    this.size = 44,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: SbPressable(
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: filled ? sb.primary : sb.surface,
              shape: BoxShape.circle,
              border: filled ? null : Border.all(color: sb.hairline),
              boxShadow: filled ? null : [BoxShadow(color: sb.shadow, blurRadius: 2, offset: const Offset(0, 1))],
            ),
            child: Icon(icon, size: 21, color: filled ? sb.onPrimary : sb.text),
          ),
        ),
      ),
    );
  }
}

/// Shrinks a little while pressed and gives a light tick, like a physical key.
class SbPressable extends StatefulWidget {
  const SbPressable({super.key, required this.child, required this.onTap, this.haptic = true});

  final Widget child;
  final VoidCallback? onTap;
  final bool haptic;

  @override
  State<SbPressable> createState() => _SbPressableState();
}

class _SbPressableState extends State<SbPressable> {
  bool _down = false;

  void _set(bool down) {
    if (widget.onTap == null || _down == down) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down && !reduceMotion ? 0.96 : 1,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// The big full-width button at the bottom of a step or sheet.
class SbPrimaryButton extends StatelessWidget {
  const SbPrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.trailingIcon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onPressed!();
              },
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(60),
          // Button text replaces the ambient style, so name the font here.
          textStyle: const TextStyle(
            fontFamily: AppFonts.body,
            fontFamilyFallback: AppFonts.bodyFallback,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 10)],
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (trailingIcon != null) ...[const SizedBox(width: 8), Icon(trailingIcon, size: 18)],
          ],
        ),
      ),
    );
  }
}

/// Fades and lifts its child in once, after [delay]. Skipped when the phone
/// asks for less motion.
class SbRise extends StatefulWidget {
  const SbRise({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<SbRise> createState() => _SbRiseState();
}

class _SbRiseState extends State<SbRise> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _t = CurvedAnimation(parent: _controller, curve: const Cubic(0.05, 0.7, 0.1, 1));
  Timer? _start;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _start = Timer(widget.delay, _controller.forward);
    }
  }

  @override
  void dispose() {
    _start?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return widget.child;
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(offset: Offset(0, 10 * (1 - _t.value)), child: child),
      ),
    );
  }
}
