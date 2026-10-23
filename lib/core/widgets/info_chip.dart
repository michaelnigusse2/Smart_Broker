import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class InfoChip extends StatelessWidget {
  final String label;
  final Color color;

  const InfoChip({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: context.sb.fill,
        borderRadius: BorderRadius.circular(4), // very subtle roundness
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
