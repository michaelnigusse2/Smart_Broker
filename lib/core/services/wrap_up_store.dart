import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_log.dart';

/// A finished call that still needs wrapping up: the after-call notification
/// was shown and you haven't added a note or said it's settled.
class WrapUp {
  const WrapUp({
    required this.callId,
    required this.contactId,
    required this.name,
    required this.seconds,
    required this.at,
    this.owe = '',
    this.marks = const [],
  });

  final String callId;
  final String contactId;
  final String name;
  final int seconds;
  final DateTime at;

  /// The first thing you owe them, as shown during the call.
  final String owe;

  /// Moments marked during the call: {type: mine|theirs|followUp, at: seconds}.
  final List<Map<String, dynamic>> marks;

  Map<String, dynamic> toJson() => {
    'callId': callId,
    'contactId': contactId,
    'name': name,
    'seconds': seconds,
    'at': at.millisecondsSinceEpoch,
    'owe': owe,
    'marks': marks,
  };

  factory WrapUp.fromJson(Map<String, dynamic> json) => WrapUp(
    callId: json['callId'] as String? ?? '',
    contactId: json['contactId'] as String? ?? '',
    name: json['name'] as String? ?? '',
    seconds: json['seconds'] as int? ?? 0,
    at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int? ?? 0),
    owe: json['owe'] as String? ?? '',
    marks: [for (final m in (json['marks'] as List? ?? const [])) Map<String, dynamic>.from(m as Map)],
  );

  /// "6:42"
  String get length => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// The calls waiting to be wrapped up ("2 calls to wrap up" on Today).
///
/// Kept in `SharedPreferencesAsync`, which never caches, so the app, the
/// call overlay and the notification-action isolate all see the same list.
class WrapUpStore {
  WrapUpStore._();

  static const _key = 'call_wrap_ups';

  /// Calls older than this drop off on their own.
  static const keepFor = Duration(days: 3);

  static final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  static Future<List<WrapUp>> all({DateTime? now}) async {
    try {
      final raw = await _prefs.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      final cutoff = (now ?? DateTime.now()).subtract(keepFor);
      return [
        for (final item in jsonDecode(raw) as List) WrapUp.fromJson(Map<String, dynamic>.from(item as Map)),
      ].where((w) => w.at.isAfter(cutoff)).toList()..sort((a, b) => b.at.compareTo(a.at));
    } catch (e) {
      AppLog.w('WrapUps', 'could not read wrap-ups', e);
      return [];
    }
  }

  static Future<void> _save(List<WrapUp> items) =>
      _prefs.setString(_key, jsonEncode([for (final w in items) w.toJson()]));

  static Future<void> add(WrapUp wrapUp) async {
    final items = await all();
    items.removeWhere((w) => w.callId == wrapUp.callId);
    items.insert(0, wrapUp);
    await _save(items);
  }

  static Future<void> remove(String callId) async {
    final items = await all();
    items.removeWhere((w) => w.callId == callId);
    await _save(items);
  }

  static Future<WrapUp?> find(String callId) async {
    for (final w in await all()) {
      if (w.callId == callId) return w;
    }
    return null;
  }
}
