import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/transcription/dictation_controller.dart';

/// Bottom panel while dictating: loading, live text, Done / Cancel.
class DictationPanel extends StatelessWidget {
  final DictationController controller;
  final VoidCallback onDone;
  final VoidCallback onCancel;

  const DictationPanel({super.key, required this.controller, required this.onDone, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = controller.state;
    final preparing = state == DictationState.preparing;
    final finishing = state == DictationState.finishing;

    return Material(
      color: AppColors.surfaceElevated,
      elevation: 6,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (preparing || finishing)
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    const _RecordingDot(),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      preparing
                          ? 'Loading the Amharic model…'
                          : finishing
                          ? 'Finishing…'
                          : 'Listening — Amharic, on this phone',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, maxHeight: 160),
                child: SingleChildScrollView(
                  reverse: true,
                  child: Text(
                    preparing
                        ? 'The first time takes a few seconds. Nothing is sent off the phone.'
                        : controller.liveText.isEmpty
                        ? 'Start speaking…'
                        : controller.liveText,
                    style: controller.liveText.isEmpty || preparing
                        ? theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)
                        : theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(onPressed: finishing ? null : onCancel, child: const Text('Cancel')),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: state == DictationState.listening ? onDone : null,
                      icon: const Icon(LucideIcons.check, size: 18),
                      label: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordingDot extends StatefulWidget {
  const _RecordingDot();

  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_pulse),
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
      ),
    );
  }
}
