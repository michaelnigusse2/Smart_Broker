import 'package:flutter/services.dart';

/// Opens the phone's dialer with a number filled in. The person presses the
/// green button themselves, so the app needs no extra calling permission.
class PhoneDialer {
  static const _channel = MethodChannel('smart_broker/call_detection');

  static Future<bool> dial(String number) async {
    final trimmed = number.trim();
    if (trimmed.isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>('dial', {'number': trimmed}) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens the phone's messaging app with a new message to [number].
  static Future<bool> text(String number) async {
    final trimmed = number.trim();
    if (trimmed.isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>('text', {'number': trimmed}) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
