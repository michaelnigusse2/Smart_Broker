import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sb_widgets.dart';
import '../../../core/utils/call_backs.dart';
import '../../../core/utils/phone_format.dart';
import '../../../models/new_number.dart';
import '../../../models/todo_item.dart';
import '../../calls/widgets/call_back_sheets.dart';
import '../../contacts/widgets/who_was_this_sheet.dart';

/// Today → "Call back": people you missed and haven't talked to since, each
/// with a call button, then missed new numbers. Long-press a person for
/// Remind me / Not needed.
class CallBackCard extends StatelessWidget {
  const CallBackCard({
    super.key,
    required this.callBacks,
    required this.newNumbers,
    required this.now,
    required this.promiseFor,
    required this.onOpen,
    required this.onCall,
    required this.onActions,
    required this.onNewNumber,
  });

  final List<CallBack> callBacks;

  /// New numbers whose last call you missed.
  final List<NewNumber> newNumbers;
  final DateTime now;
  final TodoItem? Function(String contactId) promiseFor;
  final ValueChanged<CallBack> onOpen;
  final ValueChanged<CallBack> onCall;
  final ValueChanged<CallBack> onActions;
  final ValueChanged<NewNumber> onNewNumber;

  static String _clock(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    return SbCard(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(LucideIcons.phoneMissed, size: 18, color: sb.late),
                const SizedBox(width: 8),
                Semantics(
                  header: true,
                  child: const Text(
                    'Call back',
                    style: TextStyle(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: callBacks.isEmpty
                      ? const SizedBox.shrink()
                      : ExcludeSemantics(
                          child: Text(
                            'Long-press to remind',
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, height: 18 / 13, color: sb.text2),
                          ),
                        ),
                ),
              ],
            ),
          ),
          for (final cb in callBacks)
            _CallBackRow(
              callBack: cb,
              now: now,
              promise: promiseFor(cb.contact.id),
              onOpen: () => onOpen(cb),
              onCall: () => onCall(cb),
              onActions: () => onActions(cb),
            ),
          for (final n in newNumbers)
            Semantics(
              button: true,
              label:
                  'New number ${prettyPhone(n.phoneNumber)}, missed ${_clock(n.lastMissedAt ?? n.lastAt)}. Who was this?',
              excludeSemantics: true,
              child: InkWell(
                onTap: () => onNewNumber(n),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: sb.fill)),
                  ),
                  child: Row(
                    children: [
                      const SbFace(name: '#', size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prettyPhone(n.phoneNumber),
                              style: const TextStyle(
                                fontSize: 15,
                                height: 20 / 15,
                                fontWeight: FontWeight.w600,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            Text(
                              'New number · ${newNumberLine(n, now).replaceFirst('Missed', 'missed')}',
                              style: TextStyle(fontSize: 13, height: 18 / 13, color: sb.text2),
                            ),
                          ],
                        ),
                      ),
                      const SbChevron(),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CallBackRow extends StatelessWidget {
  const _CallBackRow({
    required this.callBack,
    required this.now,
    required this.promise,
    required this.onOpen,
    required this.onCall,
    required this.onActions,
  });

  final CallBack callBack;
  final DateTime now;
  final TodoItem? promise;
  final VoidCallback onOpen;
  final VoidCallback onCall;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final cb = callBack;
    final late = cb.isLate(now);
    final line = callBackLine(cb, now);
    // When it's late, the first part ("Yesterday", "Missed 2 calls") is red.
    final cut = line.indexOf(' · ');
    final head = late && cut > 0 ? line.substring(0, cut) : '';
    final rest = head.isEmpty ? line : line.substring(cut);
    final reminder = cb.reminder;
    final first = cb.contact.name.trim().split(RegExp(r'\s+')).first;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: sb.fill)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label:
                  '${cb.contact.name}, $line${reminder == null ? '' : ', reminder ${reminderWhen(reminder.dateTime, now)}'}',
              hint: 'Long-press for Remind me or Not needed',
              excludeSemantics: true,
              child: InkWell(
                onTap: onOpen,
                onLongPress: onActions,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Row(
                    children: [
                      SbFace(name: cb.contact.name, size: 44, late: late),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cb.contact.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w700),
                            ),
                            Text.rich(
                              TextSpan(
                                children: [
                                  if (head.isNotEmpty)
                                    TextSpan(
                                      text: head,
                                      style: TextStyle(color: sb.late, fontWeight: FontWeight.w700),
                                    ),
                                  TextSpan(text: rest),
                                ],
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                height: 18 / 13,
                                color: sb.text2,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            if (reminder != null || promise != null) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (reminder != null)
                                    SbTag(
                                      'Reminder ${reminderWhen(reminder.dateTime, now)}',
                                      icon: LucideIcons.bell,
                                      small: true,
                                      background: sb.accentTint,
                                      foreground: sb.accent,
                                    ),
                                  if (promise != null)
                                    SbTag(
                                      'You owe: ${promise!.title}',
                                      small: true,
                                      background: sb.oweBg,
                                      foreground: sb.oweFg,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Semantics(
              button: true,
              label: 'Call $first back',
              excludeSemantics: true,
              child: SbPressable(
                onTap: onCall,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: sb.primary, shape: BoxShape.circle),
                  child: Icon(LucideIcons.phone, size: 18, color: sb.onPrimary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
