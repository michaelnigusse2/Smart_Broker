import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';

/// Shown instead of the app when a fatal startup step (opening the local
/// database) fails, so the user sees what happened instead of a blank screen.
class StartupErrorApp extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;

  const StartupErrorApp({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartBroker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: StartupErrorScreen(error: error, onRetry: onRetry),
    );
  }
}

class StartupErrorScreen extends StatefulWidget {
  final Object error;
  final Future<void> Function() onRetry;

  const StartupErrorScreen({super.key, required this.error, required this.onRetry});

  @override
  State<StartupErrorScreen> createState() => _StartupErrorScreenState();
}

class _StartupErrorScreenState extends State<StartupErrorScreen> {
  bool _busy = false;

  Future<void> _retry() async {
    setState(() => _busy = true);
    await widget.onRetry();
    if (mounted) setState(() => _busy = false);
  }

  Future<bool> _confirm(String title, String message, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _reset() async {
    if (!await _confirm(
      'Reset local data?',
      'This deletes every contact, note, task, reminder and call stored in SmartBroker on this phone.',
      'Continue',
    )) {
      return;
    }
    if (!mounted) return;
    if (!await _confirm('Are you sure?', 'This cannot be undone.', 'Delete everything')) return;

    setState(() => _busy = true);
    try {
      await DatabaseHelper.deleteLocalDatabase();
    } catch (e) {
      debugPrint('StartupErrorScreen: could not delete database: $e');
    }
    await widget.onRetry();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final details = widget.error.toString();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              const Icon(LucideIcons.alertTriangle, size: 40, color: AppColors.error),
              const SizedBox(height: AppSpacing.lg),
              Text(
                "SmartBroker couldn't start",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Your local data could not be opened. Try again first. '
                'If it keeps failing, you can reset the local data.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(details, style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => Clipboard.setData(ClipboardData(text: details)),
                icon: const Icon(LucideIcons.copy, size: 16),
                label: const Text('Copy error details'),
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: _busy ? null : _retry,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Try again'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: _busy ? null : _reset,
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Reset local data'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
