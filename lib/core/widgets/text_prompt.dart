import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Asks for one line of text in a dialog. Returns the trimmed text, or null
/// when cancelled or left empty.
///
/// The text field's controller lives in the dialog's own State, so it is
/// disposed only after the closing animation has finished.
Future<String?> showTextPromptDialog(
  BuildContext context, {
  required String title,
  String initialText = '',
  String hint = '',
  String confirmLabel = 'Save',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextPromptDialog(title: title, initialText: initialText, hint: hint, confirmLabel: confirmLabel),
  );
}

/// Same as [showTextPromptDialog], as a bottom sheet that follows the keyboard.
Future<String?> showTextPromptSheet(
  BuildContext context, {
  required String title,
  String hint = '',
  String confirmLabel = 'Save',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (_) => _TextPromptSheet(title: title, hint: hint, confirmLabel: confirmLabel),
  );
}

class _TextPromptDialog extends StatefulWidget {
  final String title;
  final String initialText;
  final String hint;
  final String confirmLabel;

  const _TextPromptDialog({
    required this.title,
    required this.initialText,
    required this.hint,
    required this.confirmLabel,
  });

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

class _TextPromptSheet extends StatefulWidget {
  final String title;
  final String hint;
  final String confirmLabel;

  const _TextPromptSheet({required this.title, required this.hint, required this.confirmLabel});

  @override
  State<_TextPromptSheet> createState() => _TextPromptSheetState();
}

class _TextPromptSheetState extends State<_TextPromptSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: widget.hint, border: const OutlineInputBorder()),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.sb.primary,
                foregroundColor: context.sb.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
              child: Text(widget.confirmLabel),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
