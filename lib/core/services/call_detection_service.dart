import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';

/// Flutter-side wrapper around the native call detection MethodChannel/EventChannel.
class CallDetectionService {
  static const _methodChannel = MethodChannel('smart_broker/call_detection');
  static const _eventChannel = EventChannel('smart_broker/call_events');

  static final CallDetectionService _instance = CallDetectionService._internal();
  factory CallDetectionService() => _instance;
  CallDetectionService._internal();

  Stream<Map<String, dynamic>>? _callEventsStream;

  /// Returns true if the platform supports call detection (Android only).
  bool get isSupported => Platform.isAndroid;

  /// Request READ_PHONE_STATE permission via native ActivityCompat.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>('requestPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Check if READ_PHONE_STATE permission is already granted.
  Future<bool> isPermissionGranted() async {
    if (!isSupported) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>('isPermissionGranted');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Start the foreground call detection service.
  Future<bool> start() async {
    if (!isSupported) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>('startService');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Stop the foreground call detection service.
  Future<bool> stop() async {
    if (!isSupported) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>('stopService');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Check if the call detection service is currently running.
  Future<bool> isRunning() async {
    if (!isSupported) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>('isServiceRunning');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Stream of call events from the native side.
  /// Each event fires when a phone call ends.
  Stream<Map<String, dynamic>> get callEvents {
    _callEventsStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _callEventsStream!;
  }
}
