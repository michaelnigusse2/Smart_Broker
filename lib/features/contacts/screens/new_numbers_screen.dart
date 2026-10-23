import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/repositories/new_number_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sb_widgets.dart';
import '../../../core/utils/phone_format.dart';
import '../../../models/new_number.dart';
import '../widgets/new_number_row.dart';

/// Every new number waiting to be saved ("See all" on People).
class NewNumbersScreen extends StatefulWidget {
  const NewNumbersScreen({super.key});

  @override
  State<NewNumbersScreen> createState() => _NewNumbersScreenState();
}

class _NewNumbersScreenState extends State<NewNumbersScreen> {
  List<NewNumber>? _numbers;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final numbers = await NewNumberRepository().open();
    if (mounted) setState(() => _numbers = numbers);
  }

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final text = Theme.of(context).textTheme;
    final numbers = _numbers;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SbCircleButton(
                icon: LucideIcons.chevronLeft,
                tooltip: 'Back',
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('New numbers', style: text.headlineMedium),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                "Calls from numbers you haven't saved. Tap one to say who it was.",
                style: text.bodyMedium?.copyWith(color: sb.text2),
              ),
            ),
            const SizedBox(height: 18),
            if (numbers == null)
              const Center(
                child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
              )
            else if (numbers.isEmpty)
              SbCard(
                padding: const EdgeInsets.all(16),
                child: Text('No new numbers right now.', style: TextStyle(fontSize: 15, color: sb.text2)),
              )
            else
              SbCard(
                child: Column(
                  children: [
                    for (final (i, n) in numbers.indexed) NewNumberRow(number: n, first: i == 0, onChanged: _load),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                "Long-press a number to ignore it. Numbers you don't save leave after 30 days.",
                style: TextStyle(fontSize: 12, height: 16 / 12, color: sb.text2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings → Ignored numbers: "Not a client" numbers, with Stop ignoring.
class IgnoredNumbersScreen extends StatefulWidget {
  const IgnoredNumbersScreen({super.key});

  @override
  State<IgnoredNumbersScreen> createState() => _IgnoredNumbersScreenState();
}

class _IgnoredNumbersScreenState extends State<IgnoredNumbersScreen> {
  List<NewNumber>? _numbers;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final numbers = await NewNumberRepository().ignored();
    if (mounted) setState(() => _numbers = numbers);
  }

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final text = Theme.of(context).textTheme;
    final numbers = _numbers;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SbCircleButton(
                icon: LucideIcons.chevronLeft,
                tooltip: 'Back',
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('Ignored numbers', style: text.headlineMedium),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'No call card, reminder or New numbers entry for these.',
                style: text.bodyMedium?.copyWith(color: sb.text2),
              ),
            ),
            const SizedBox(height: 18),
            if (numbers == null)
              const Center(
                child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
              )
            else if (numbers.isEmpty)
              SbCard(
                padding: const EdgeInsets.all(16),
                child: Text('You haven\'t ignored any numbers.', style: TextStyle(fontSize: 15, color: sb.text2)),
              )
            else
              SbCard(
                child: Column(
                  children: [
                    for (final (i, n) in numbers.indexed)
                      SbListRow(
                        first: i == 0,
                        leading: SbIconTile(icon: LucideIcons.ban, tint: sb.faces.last),
                        title: prettyPhone(n.phoneNumber),
                        subtitle: n.calls == 1 ? '1 call' : '${n.calls} calls',
                        trailing: TextButton(
                          onPressed: () async {
                            await NewNumberRepository().unignore(n.phoneKey);
                            await _load();
                          },
                          child: const Text('Stop ignoring'),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
