import 'dart:async';

import 'package:flutter/services.dart';

/// Microphone audio for offline dictation (Android, `DictationAudioPlugin.kt`):
/// 16 kHz mono 16-bit little-endian PCM in ~100 ms chunks.
class DictationAudio {
  DictationAudio._();

  static const _methods = MethodChannel('smart_broker/dictation');
  static const _audio = EventChannel('smart_broker/dictation_audio');

  static Future<bool> hasPermission() async => await _methods.invokeMethod<bool>('hasMicPermission') ?? false;

  /// Shows the system prompt if needed; true when the app may record.
  static Future<bool> requestPermission() async => await _methods.invokeMethod<bool>('requestMicPermission') ?? false;

  /// Listening starts on subscribe and stops when the subscription is cancelled.
  static Stream<Uint8List> stream() => _audio.receiveBroadcastStream().map((chunk) => chunk as Uint8List);

  static Future<DeviceInfo> deviceInfo(String path) async {
    final map = await _methods.invokeMapMethod<String, Object?>('deviceInfo', {'path': path}) ?? const {};
    return DeviceInfo(
      totalRamBytes: (map['totalRamBytes'] as num?)?.toInt(),
      freeStorageBytes: (map['freeStorageBytes'] as num?)?.toInt(),
      supportedAbis: (map['supportedAbis'] as List?)?.cast<String>() ?? const [],
    );
  }
}

class DeviceInfo {
  final int? totalRamBytes;
  final int? freeStorageBytes;
  final List<String> supportedAbis;

  const DeviceInfo({this.totalRamBytes, this.freeStorageBytes, this.supportedAbis = const []});

  /// The model needs about 0.7 GB while streaming. On 3 GB phones (which
  /// report under 3.2 GB) Android may close the app during a long note.
  bool get isLowRam => totalRamBytes != null && totalRamBytes! < 3200 * 1024 * 1024;
}
