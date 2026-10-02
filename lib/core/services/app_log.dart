import 'dart:collection';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// App-wide logging.
///
/// - Console output only in debug builds (release logcat stays clean).
/// - The last [capacity] entries are kept in memory so they can be shown
///   from Developer Tools later.
/// - Never pass note text or full phone numbers: use [maskPhone] and log
///   lengths/ids instead.
class AppLog {
  AppLog._();

  static const capacity = 500;
  static final ListQueue<String> _buffer = ListQueue<String>();

  /// Most recent entries, oldest first.
  static List<String> get entries => List.unmodifiable(_buffer);

  static void d(String tag, String message) => _log('D', tag, message);
  static void i(String tag, String message) => _log('I', tag, message);
  static void w(String tag, String message, [Object? error]) =>
      _log('W', tag, error == null ? message : '$message: $error');
  static void e(String tag, String message, [Object? error, StackTrace? stack]) {
    final text = StringBuffer(message);
    if (error != null) text.write(': $error');
    if (stack != null && kDebugMode) text.write('\n$stack');
    _log('E', tag, text.toString());
  }

  static void _log(String level, String tag, String message) {
    final line = '${DateTime.now().toIso8601String()} $level/$tag: $message';
    _buffer.addLast(line);
    while (_buffer.length > capacity) {
      _buffer.removeFirst();
    }
    if (kDebugMode) {
      debugPrint(line);
    } else {
      developer.log(message, name: tag, level: level == 'E' ? 1000 : 800);
    }
  }

  @visibleForTesting
  static void clear() => _buffer.clear();

  /// `+251911234567` → `+2519****567`. Keeps enough to recognise a number
  /// while debugging without exposing it.
  static String maskPhone(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 6) return '***';
    final prefix = number.trimLeft().startsWith('+') ? '+' : '';
    return '$prefix${digits.substring(0, 4)}****${digits.substring(digits.length - 3)}';
  }
}
