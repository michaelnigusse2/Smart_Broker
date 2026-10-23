import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/services/ai_provider.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/api_key_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sb_widgets.dart';
import '../../../core/widgets/ai_consent_dialog.dart';

/// Settings → AI helper: which service finds the promises in your notes, its
/// key and model.
class AiHelperScreen extends StatefulWidget {
  const AiHelperScreen({super.key});

  @override
  State<AiHelperScreen> createState() => _AiHelperScreenState();
}

class _AiHelperScreenState extends State<AiHelperScreen> {
  final _settings = SettingsService();
  final _keyController = TextEditingController();
  final _modelController = TextEditingController();
  AiProvider _provider = AiProvider.fallback;
  bool _obscured = true;
  bool _checking = false;
  bool _hasKey = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final provider = await _settings.getAiProvider();
    final key = await ApiKeyService().getKey(provider);
    final model = await _settings.getAiModel(provider);
    if (!mounted) return;
    setState(() {
      _provider = provider;
      _keyController.text = key ?? '';
      _modelController.text = model;
      _hasKey = key != null && key.isNotEmpty;
      _problem = null;
    });
  }

  Future<void> _pick(AiProvider provider) async {
    if (provider.id == _provider.id || _checking) return;
    await _settings.setAiProvider(provider);
    await _load();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final key = _keyController.text.trim();
    final model = _modelController.text.trim();
    if (key.isEmpty) {
      await ApiKeyService().deleteKey(_provider);
      if (!mounted) return;
      setState(() => _hasKey = false);
      messenger.showSnackBar(const SnackBar(content: Text('Key removed')));
      return;
    }
    setState(() {
      _checking = true;
      _problem = null;
    });
    final result = await AiService(provider: _provider, apiKey: key, model: model).validateKey();
    if (!mounted) return;
    if (result == 'valid') {
      await ApiKeyService().saveKey(_provider, key);
      await _settings.setAiModel(_provider, model);
      if (!mounted) return;
      setState(() {
        _hasKey = true;
        _checking = false;
      });
      messenger.showSnackBar(const SnackBar(content: Text('Key saved')));
    } else {
      setState(() {
        _checking = false;
        _problem = result;
      });
    }
  }

  Future<void> _copyKeyLink() async {
    await Clipboard.setData(ClipboardData(text: 'https://${_provider.keyUrl}'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Link copied: open ${_provider.keyUrl} in your browser for a free key')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final text = Theme.of(context).textTheme;
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
              child: Text('AI helper', style: text.headlineMedium),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Finds the promises in your notes and writes the short summary. Use a free key from one of these.',
                style: text.bodyMedium?.copyWith(color: sb.text2),
              ),
            ),
            const SizedBox(height: 20),
            const SbCap('Service'),
            SbSegmented<AiProvider>(
              label: 'AI service',
              options: [for (final p in AiProvider.all) (p, p.name)],
              selected: AiProvider.all.firstWhere((p) => p.id == _provider.id, orElse: () => AiProvider.fallback),
              onChanged: _pick,
            ),
            const SizedBox(height: 20),
            SbCap(
              'Key',
              trailing: Text(
                _hasKey ? 'Added' : 'Not added',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _hasKey ? sb.goodFg : sb.text2,
                ),
              ),
            ),
            SbCard(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                    child: TextField(
                      controller: _keyController,
                      obscureText: _obscured,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: _bare('${_provider.name} key').copyWith(
                        suffixIcon: IconButton(
                          tooltip: _obscured ? 'Show the key' : 'Hide the key',
                          icon: Icon(_obscured ? LucideIcons.eye : LucideIcons.eyeOff, size: 20),
                          onPressed: () => setState(() => _obscured = !_obscured),
                        ),
                      ),
                    ),
                  ),
                  Container(height: 1, color: sb.fill),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: TextField(
                      controller: _modelController,
                      autocorrect: false,
                      decoration: _bare('Model (default ${_provider.defaultModel})'),
                    ),
                  ),
                ],
              ),
            ),
            if (_problem != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('That key didn\'t work: $_problem', style: TextStyle(fontSize: 14, color: sb.late)),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: _copyKeyLink, child: const Text('Get a free key')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _checking ? null : _save,
                    child: _checking
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: sb.onPrimary),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SbCard(
              child: SbListRow(
                first: true,
                leading: SbIconTile(icon: LucideIcons.shieldCheck, tint: sb.faces.last),
                title: 'What AI sees',
                subtitle: 'Only the note you send it',
                trailing: const SbChevron(),
                onTap: () => showAiDataNotice(context, _provider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _bare(String hint) => InputDecoration(
    hintText: hint,
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    contentPadding: const EdgeInsets.symmetric(vertical: 16),
  );
}
