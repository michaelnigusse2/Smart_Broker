import 'package:flutter/material.dart';

class ConstrainedLayout extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ConstrainedLayout({
    super.key,
    required this.child,
    this.maxWidth = 700,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
