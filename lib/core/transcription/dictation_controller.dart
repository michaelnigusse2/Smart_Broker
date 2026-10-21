import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../services/app_log.dart';
import 'amharic_numbers.dart';
import 'dictation_audio.dart';
import 'offline_transcriber.dart';
import 'scribe_model_store.dart';

enum DictationState {
  idle,

  /// The model hasn't been downloaded yet (Settings → Offline Amharic dictation).
  needsModel,

  /// Loading and warming up the model (first use on this screen).
  preparing,
  listening,

  /// Flushing the last words after Stop.
  finishing,
  error,
}

/// Microphone → on-device Addis Scribe → live text, for one screen. The model
/// stays loaded until [dispose], so later dictations on the same note start at once.
class DictationController extends ChangeNotifier {
  DictationController({
    ScribeModelStore? store,
    Future<SpeechEngine> Function(String modelPath)? loadEngine,
    Stream<Uint8List> Function()? audio,
    Future<bool> Function()? requestPermission,
  }) : _store = store ?? ScribeModelStore.instance,
       _loadEngine = loadEngine ?? ((path) => OfflineTranscriber.load(modelPath: path)),
       _audio = audio ?? DictationAudio.stream,
       _requestPermission = requestPermission ?? DictationAudio.requestPermission;

  static const _tag = 'Dictation';

  final ScribeModelStore _store;
  final Future<SpeechEngine> Function(String modelPath) _loadEngine;
  final Stream<Uint8List> Function() _audio;
  final Future<bool> Function() _requestPermission;

  SpeechEngine? _engine;
  StreamSubscription<Uint8List>? _audioSub;
  StreamSubscription<String>? _textSub;
  bool _disposed = false;

  DictationState _state = DictationState.idle;
  String _liveText = '';
  String? _error;
  DateTime? _listeningSince;
  final List<double> _levels = [];

  /// How many recent microphone levels [levels] keeps (one per audio chunk).
  static const levelCount = 34;

  DictationState get state => _state;

  /// What has been recognised so far, numbers already written as digits.
  String get liveText => _liveText;
  String? get error => _error;
  bool get isActive =>
      _state == DictationState.preparing || _state == DictationState.listening || _state == DictationState.finishing;

  /// The most recent microphone levels, 0 (silent) to 1 (loud), oldest first.
  List<double> get levels => List.unmodifiable(_levels);

  /// How long this dictation has been listening.
  Duration get elapsed => _listeningSince == null ? Duration.zero : DateTime.now().difference(_listeningSince!);

  /// Loudness of one chunk of 16-bit little-endian PCM, eased so speech
  /// fills the bars and silence stays low.
  static double levelOf(Uint8List pcm) {
    if (pcm.length < 2) return 0;
    final data = ByteData.sublistView(pcm);
    var sum = 0.0;
    final samples = pcm.length ~/ 2;
    for (var i = 0; i < samples; i++) {
      final v = data.getInt16(i * 2, Endian.little) / 32768.0;
      sum += v * v;
    }
    final rms = math.sqrt(sum / samples);
    return math.min(1.0, math.sqrt(rms * 6));
  }

  void _addLevel(Uint8List chunk) {
    _levels.add(levelOf(chunk));
    if (_levels.length > levelCount) _levels.removeAt(0);
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    if (isActive) return;
    _error = null;
    _liveText = '';
    if (!await _store.ensureChecked()) {
      _set(DictationState.needsModel);
      return;
    }
    if (!await _requestPermission()) {
      _fail('Allow microphone access to dictate notes.');
      return;
    }
    _set(DictationState.preparing);
    try {
      if (_engine == null) {
        final loaded = await _loadEngine((await _store.modelFile()).path);
        if (_disposed) {
          // The screen closed while the model loaded: free its memory now.
          await loaded.dispose();
          return;
        }
        _engine = loaded;
      }
      final engine = _engine!;
      await engine.startSession();
      _textSub = engine.transcripts.listen(
        (text) {
          _liveText = normaliseAmharicNumbers(text);
          if (!_disposed) notifyListeners();
        },
        onError: (Object e) => _abort('Transcription stopped: $e'),
      );
      _levels.clear();
      _audioSub = _audio().listen((chunk) {
        engine.addAudio(chunk);
        _addLevel(chunk);
      }, onError: (Object e) => _abort(_micMessage(e)));
      _listeningSince = DateTime.now();
      _set(DictationState.listening);
    } catch (e) {
      AppLog.w(_tag, 'could not start', e);
      await _stopAudio();
      _fail(e is ScribeException ? 'The offline model could not start: ${e.message}' : 'Dictation could not start.');
    }
  }

  /// Stops listening and returns the whole note text, numbers as digits
  /// (empty if nothing was recognised).
  Future<String> stop() async {
    if (_state != DictationState.listening) return '';
    _set(DictationState.finishing);
    await _stopAudio();
    try {
      final raw = await _engine!.finishSession();
      await _textSub?.cancel();
      _textSub = null;
      _liveText = '';
      _set(DictationState.idle);
      return normaliseAmharicNumbers(raw.trim());
    } catch (e) {
      AppLog.w(_tag, 'finish failed', e);
      final kept = _liveText;
      _fail('The last words could not be processed.');
      return kept;
    }
  }

  /// Stops listening and discards what was said.
  Future<void> cancel() async {
    if (!isActive) {
      if (_state != DictationState.idle) _set(DictationState.idle);
      return;
    }
    await _stopAudio();
    await _textSub?.cancel();
    _textSub = null;
    try {
      await _engine?.cancelSession();
    } catch (_) {}
    _liveText = '';
    _set(DictationState.idle);
  }

  /// Back to idle after an error or the "download the model" prompt.
  void reset() {
    if (isActive) return;
    _error = null;
    _set(DictationState.idle);
  }

  Future<void> _abort(String message) async {
    await _stopAudio();
    await _textSub?.cancel();
    _textSub = null;
    try {
      await _engine?.cancelSession();
    } catch (_) {}
    _fail(message);
  }

  Future<void> _stopAudio() async {
    final sub = _audioSub;
    _audioSub = null;
    await sub?.cancel();
  }

  static String _micMessage(Object e) {
    final s = '$e';
    if (s.contains('NO_PERMISSION')) return 'Allow microphone access to dictate notes.';
    if (s.contains('MIC_UNAVAILABLE')) return 'The microphone is in use by another app.';
    return 'The microphone stopped.';
  }

  void _fail(String message) {
    _error = message;
    _set(DictationState.error);
  }

  void _set(DictationState s) {
    _state = s;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _audioSub?.cancel();
    _textSub?.cancel();
    final engine = _engine;
    _engine = null;
    if (engine != null) unawaited(engine.dispose());
    super.dispose();
  }
}
