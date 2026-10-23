import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sb_widgets.dart';
import '../../../core/transcription/dictation_audio.dart';
import '../../../core/transcription/offline_transcriber.dart';
import '../../../core/transcription/scribe_model_store.dart';

/// Settings → Offline Amharic dictation: download, progress, delete, licence.
class OfflineDictationSettings extends StatefulWidget {
  final ScribeModelStore? store;

  /// The first row in its card (no line above it).
  final bool first;

  const OfflineDictationSettings({super.key, this.store, this.first = false});

  /// The explanation shown under the card that holds this row.
  static const about =
      'Dictate notes in Amharic with no internet. Audio stays on this phone. Numbers are written as digits; '
      'English words come out in Amharic letters, so check names and terms before saving.';

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
            child: Text('Delete', style: TextStyle(color: context.sb.late)),
          ),
        ],
      ),
    );
    if (ok == true) await _store.delete();
  }

  @override
  Widget build(BuildContext context) {
    final sb = context.sb;
    final tile = SbIconTile(icon: LucideIcons.mic, tint: sb.tintWarm);
    if (!OfflineTranscriber.isSupported) {
      return SbListRow(
        first: widget.first,
        leading: tile,
        title: 'Amharic voice',
        subtitle: 'Needs a 64-bit Android phone',
      );
    }
    final status = _store.status;
    Widget pill(String label, VoidCallback? onTap, {bool filled = true}) => SizedBox(
      height: 36,
      child: filled
          ? FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: Text(label),
            )
          : TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(label),
            ),
    );
    final (String subtitle, Widget? trailing) = switch (status) {
      ScribeModelStatus.ready => ('Ready · works offline', pill('Delete', _delete, filled: false)),
      ScribeModelStatus.downloading => (
        '${_mb(_store.receivedBytes)} of ${_mb(ScribeModel.sizeBytes)}',
        pill('Pause', _store.cancel, filled: false),
      ),
      ScribeModelStatus.verifying => ('Checking the download…', null),
      ScribeModelStatus.failed => (_store.error ?? 'Download failed', pill('Retry', _download)),
      ScribeModelStatus.notDownloaded => (
        _store.receivedBytes > 0
            ? 'Paused at ${_mb(_store.receivedBytes)} of ${_mb(ScribeModel.sizeBytes)}'
            : 'Works offline · ${_mb(ScribeModel.sizeBytes)}, use Wi-Fi',
        pill(_store.receivedBytes > 0 ? 'Resume' : 'Download', _download),
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SbListRow(first: widget.first, leading: tile, title: 'Amharic voice', subtitle: subtitle, trailing: trailing),
        if (status == ScribeModelStatus.downloading || status == ScribeModelStatus.verifying)
          Padding(
            padding: const EdgeInsets.fromLTRB(68, 0, 16, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 4,
                value: status == ScribeModelStatus.verifying ? null : _store.progress,
              ),
            ),
          ),
        if (_device?.isLowRam ?? false)
          Padding(
            padding: const EdgeInsets.fromLTRB(68, 0, 16, 12),
            child: Text(
              'This phone has little memory; long notes may stop if other apps are open.',
              style: TextStyle(fontSize: 13, height: 18 / 13, color: sb.late),
            ),
          ),
      ],
    );
  }

  static String _mb(int bytes) => '${(bytes / 1e6).round()} MB'; // decimal, as phones show storage
}
