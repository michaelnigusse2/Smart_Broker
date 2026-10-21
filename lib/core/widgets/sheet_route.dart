import 'package:flutter/material.dart';

/// A page that comes up from the bottom as a sheet over the screen below,
/// which stays visible behind a dim veil (the quick-note board). The page
/// draws its own sheet and decides what tapping the veil does.
class SheetRoute<T> extends PageRoute<T> {
  SheetRoute({required this.builder, super.settings});

  final WidgetBuilder builder;

  @override
  bool get opaque => false;

  @override
  Color? get barrierColor => const Color(0x7317110D);

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 380);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: const Cubic(.05, .7, .1, 1), reverseCurve: Curves.easeIn);
    return SlideTransition(
      position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
      child: child,
    );
  }
}
