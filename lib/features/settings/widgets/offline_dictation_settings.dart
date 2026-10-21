import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/transcription/dictation_audio.dart';
import '../../../core/transcription/offline_transcriber.dart';
import '../../../core/transcription/scribe_model_store.dart';

/// Settings → Offline Amharic dictation: download, progress, delete, licence.
class OfflineDictationSettings extends StatefulWidget {
  final ScribeModelStore? store;

  const OfflineDictationSettings({super.key, this.store});

  @override
  State<OfflineDictationSettings> createState() => _OfflineDictationSettingsState();
}

class _OfflineDictationSettingsState extends State<OfflineDictationSettings> {
  late final ScribeModelStore _store = widget.store ?? ScribeModelStore.instance;
  DeviceInfo? _device;

  @override
  void initState() {
    super.initState();
    _store.addListener(_changed);
    _store.refresh();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    if (!OfflineTranscriber.isSupported) return;
    try {
      final info = await DictationAudio.deviceInfo((await _store.directory()).path);
      if (mounted) setState(() => _device = info);
    } catch (_) {
      // Only used for warnings.
    }
  }

  @override
  void dispose() {
    _store.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _download() async {
    final free = _device?.freeStorageBytes;
    if (free != null && free < ScribeModel.sizeBytes + 200 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Not enough free space: the model needs ${_mb(ScribeModel.sizeBytes)}, ${_mb(free)} free.'),
        ),
      );
      return;
    }
    await _store.download();
    if (!mounted) return;
    if (_store.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amharic model ready — tap Dictate when writing a note')),
      );
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete the Amharic model?'),
        content: Text('This frees ${_mb(ScribeModel.sizeBytes)}. You can download it again later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) await _store.delete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!OfflineTranscriber.isSupported) {
      return const ListTile(
        leading: Icon(LucideIcons.micOff, color: AppColors.textTertiary),
        title: Text('Offline dictation not available'),
        subtitle: Text('Needs a 64-bit Android phone'),
      );
    }

    final status = _store.status;
    final (String subtitle, Widget? trailing) = switch (status) {
      ScribeModelStatus.ready => (
        'Ready · ${_mb(ScribeModel.sizeBytes)} on this phone',
        TextButton(onPressed: _delete, child: const Text('Delete')),
      ),
      ScribeModelStatus.downloading => (
        'Downloading ${_mb(_store.receivedBytes)} of ${_mb(ScribeModel.sizeBytes)}',
        TextButton(onPressed: _store.cancel, child: const Text('Pause')),
      ),
      ScribeModelStatus.verifying => ('Checking the download…', null),
      ScribeModelStatus.failed => (
        _store.error ?? 'Download failed',
        TextButton(onPressed: _download, child: const Text('Retry')),
      ),
      ScribeModelStatus.notDownloaded => (
        _store.receivedBytes > 0
            ? 'Paused at ${_mb(_store.receivedBytes)} of ${_mb(ScribeModel.sizeBytes)}'
            : 'One-time download, ${_mb(ScribeModel.sizeBytes)} — use Wi-Fi',
        ElevatedButton(onPressed: _download, child: Text(_store.receivedBytes > 0 ? 'Resume' : 'Download')),
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: Icon(LucideIcons.mic, color: status == ScribeModelStatus.ready ? AppColors.primary : null),
          title: const Text('Amharic speech model'),
          subtitle: Text(subtitle),
          trailing: trailing,
          isThreeLine: status == ScribeModelStatus.failed,
        ),
        if (status == ScribeModelStatus.downloading || status == ScribeModelStatus.verifying)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.sm),
            child: LinearProgressIndicator(value: status == ScribeModelStatus.verifying ? null : _store.progress),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dictate notes in Amharic with no internet. Audio stays on this phone. '
                'Numbers are written as digits; English words come out in Amharic letters, '
                'so check names and terms before saving.',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              if (_device?.isLowRam ?? false) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'This phone has little memory; long notes may stop if other apps are open.',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Text(
                ScribeModel.attribution,
                style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                  onPressed: () => showLicensePage(context: context, applicationName: 'SmartBroker'),
                  child: const Text('Open-source licences'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _mb(int bytes) => '${(bytes / 1e6).round()} MB'; // decimal, as phones show storage
}
