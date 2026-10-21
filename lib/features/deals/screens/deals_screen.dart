import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sb_widgets.dart';
import '../../../core/widgets/constrained_layout.dart';

/// Deals: what each deal is worth and where it stands. The deal list itself
/// arrives with the next build; until then this tab says so plainly.
class DealsScreen extends StatelessWidget {
  const DealsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ConstrainedLayout(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 128),
            children: [
              Semantics(header: true, child: Text('Deals', style: text.headlineLarge)),
              const SizedBox(height: 24),
              SbCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4E3C4),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(LucideIcons.briefcase, size: 22, color: Color(0xFF7A4B0F)),
                    ),
                    const SizedBox(height: 16),
                    Text('Your deals will live here', style: text.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      'What each one is worth and where it stands: new, talking, offer or won. Coming in the next update.',
                      style: text.bodyMedium?.copyWith(color: sb.text2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
