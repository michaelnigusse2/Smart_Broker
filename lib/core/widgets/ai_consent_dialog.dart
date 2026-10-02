import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../services/ai_provider.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

/// Makes sure the user has accepted the AI data notice for [provider].
/// Returns true if AI processing may go ahead.
Future<bool> ensureAiConsent(BuildContext context, AiProvider provider) async {
  final settings = SettingsService();
  if (await settings.hasAiConsent(provider)) return true;
  if (!context.mounted) return false;
  final accepted = await showAiDataNotice(context, provider, askForConsent: true);
  if (accepted) await settings.setAiConsent(provider);
  return accepted;
}

/// Explains what is sent to the AI provider. With [askForConsent] the user
/// must choose; otherwise it is informational (Settings → Data & privacy).
Future<bool> showAiDataNotice(
  BuildContext context,
  AiProvider provider, {
  bool askForConsent = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: !askForConsent,
    builder: (ctx) => AlertDialog(
      icon: const Icon(LucideIcons.shieldCheck, color: AppColors.primary),
      title: const Text('How AI Review uses your notes'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('When you run AI Review, SmartBroker sends this to ${provider.name}:'),
            const SizedBox(height: AppSpacing.sm),
            const _Bullet('the note you wrote'),
            const _Bullet("the contact's name"),
            const _Bullet('summaries of your last 3 notes with them'),
            const _Bullet('their open task titles'),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Nothing is sent until you run AI Review. Everything else stays on this phone. '
              'The API key is yours, so their terms apply to your account.',
            ),
            const SizedBox(height: AppSpacing.md),
            Text("${provider.name}'s data policy:", style: const TextStyle(fontWeight: FontWeight.w600)),
            SelectableText(provider.privacyUrl, style: const TextStyle(color: AppColors.primary)),
          ],
        ),
      ),
      actions: askForConsent
          ? [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('I understand')),
            ]
          : [
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Close')),
            ],
    ),
  );
  return result ?? false;
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
