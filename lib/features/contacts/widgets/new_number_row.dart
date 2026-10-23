import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/repositories/new_number_repository.dart';
import '../../../core/services/phone_dialer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sb_widgets.dart';
import '../../../core/utils/phone_format.dart';
import '../../../models/new_number.dart';
import 'who_was_this_sheet.dart';

/// One new number: the number, what happened, a note if you typed one, and
/// Save (or Call back when you haven't talked yet). Tap: "Who was this?";
/// long-press: ignore it.
class NewNumberRow extends StatelessWidget {
  const NewNumberRow({super.key, required this.number, required this.onChanged, this.first = false});

  final NewNumber number;

  /// After it was saved, ignored or brought back.
  final VoidCallback onChanged;
  final bool first;

  Future<void> _open(BuildContext context) async {
    await showWhoWasThisSheet(context, number.phoneKey);
    onChanged();
  }

  Future<void> _ignore(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = NewNumberRepository();
    await repo.ignore(number.phoneKey);
    onChanged();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Ignored ${prettyPhone(number.phoneNumber)}'),
          // Undo stays a few seconds, not until dismissed.
          persist: false,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await repo.unignore(number.phoneKey);
              onChanged();
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final now = DateTime.now();
    final line = newNumberLine(number, now);
    final callFirst = number.waitingForCallBack && !number.talked;
    return Semantics(
      label: 'New number ${prettyPhone(number.phoneNumber)}, $line',
      child: InkWell(
        onTap: () => _open(context),
        onLongPress: () => _ignore(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: BoxDecoration(
            border: first ? null : Border(top: BorderSide(color: sb.fill)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prettyPhone(number.phoneNumber),
                      style: const TextStyle(
                        fontSize: 15,
                        height: 20 / 15,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      line,
                      style: TextStyle(
                        fontSize: 13,
                        height: 18 / 13,
                        color: number.waitingForCallBack ? sb.late : sb.text2,
                        fontWeight: number.waitingForCallBack ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    if (number.note.isNotEmpty)
                      Text(
                        'Note: ${number.note.replaceAll('\n', ' ')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, height: 18 / 13, color: sb.text2),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (callFirst)
                _SmallButton(
                  label: 'Call back',
                  icon: LucideIcons.phone,
                  filled: false,
                  onTap: () => PhoneDialer.dial(number.phoneNumber),
                )
              else
                _SmallButton(label: 'Save', onTap: () => _open(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onTap, this.icon, this.filled = true});

  final String label;
  final IconData? icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: SbPressable(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: filled ? sb.primary : sb.canvas, borderRadius: BorderRadius.circular(99)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: filled ? sb.onPrimary : sb.text),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: filled ? sb.onPrimary : sb.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
