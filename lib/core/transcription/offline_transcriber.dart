import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../services/app_log.dart';
import 'scribe_bindings.dart';

/// A speech recogniser fed with live audio. [OfflineTranscriber] runs Addis
/// Scribe on the phone; tests use a fake.
abstract class SpeechEngine {
  /// Starts a new note. Audio from [addAudio] is transcribed until
  /// [finishSession] or [cancelSession].
  Future<void> startSession();

  /// 16 kHz mono 16-bit little-endian PCM.
  void addAudio(Uint8List pcm16);

  /// The transcript so far, updated as words are recognised.
  Stream<String> get transcripts;

  /// Flushes the remaining audio and returns the whole transcript.
  Future<String> finishSession();

  Future<void> cancelSession();

  Future<void> dispose();
}

class ScribeException implements Exception {
  final String message;
  const ScribeException(this.message);

  @override
  String toString() => message;
}

/// Addis Scribe (NeMo-Speech.cpp) in a background isolate, so loading
/// (several seconds) and decoding never block the UI.
class OfflineTranscriber implements SpeechEngine {
  OfflineTranscriber._(this._isolate, this._port, this._events, this._toWorker, this.version) {
    _events.listen(_onMessage);
  }

  static const _tag = 'Scribe';
  static const sampleRate = 16000;
  static const languageCode = 'am-ET';

  static bool? _supported;

  /// True on 64-bit Android phones, where the native library ships in the app.
  static bool get isSupported {
    if (_supported != null) return _supported!;
    if (!Platform.isAndroid) return _supported = false;
    try {
      DynamicLibrary.open(scribeLibrary);
      return _supported = true;
    } catch (e) {
      AppLog.w(_tag, 'native library unavailable', e);
      return _supported = false;
    }
  }

  /// Four threads were fastest on a Snapdragon 865 (eight include the slow cores).
  static int get defaultThreads => math.min(4, Platform.numberOfProcessors);

  /// Loads and warms up the model: about 0.7 GB of memory and 5–15 s.
  static Future<OfflineTranscriber> load({required String modelPath, int? threads}) async {
    final port = ReceivePort();
    final events = port.asBroadcastStream();
    final stopwatch = Stopwatch()..start();
    final isolate = await Isolate.spawn(
      _workerMain,
      _WorkerArgs(port.sendPort, modelPath, threads ?? defaultThreads),
      debugName: 'dictation',
    );
    final first = await events.first as List;
    if (first[0] != 'ready') {
      port.close();
      isolate.kill(priority: Isolate.immediate);
      throw ScribeException(first.length > 1 ? '${first[1]}' : 'The speech model could not be loaded');
    }
    AppLog.i(_tag, 'model ready in ${stopwatch.elapsedMilliseconds} ms (${first[2]})');
    return OfflineTranscriber._(isolate, port, events, first[1] as SendPort, first[2] as String);
  }

  final Isolate _isolate;
  final ReceivePort _port;
  final Stream<dynamic> _events;
  final SendPort _toWorker;
  final String version;

  final _transcripts = StreamController<String>.broadcast();
  Completer<void>? _starting;
  Completer<String>? _finishing;
  Completer<void>? _cancelling;
  bool _disposed = false;

  @override
  Stream<String> get transcripts => _transcripts.stream;

  void _onMessage(dynamic message) {
    final m = message as List;
    switch (m[0]) {
      case 'started':
        _starting?.complete();
        _starting = null;
      case 'partial':
        _transcripts.add(m[1] as String);
      case 'final':
        _finishing?.complete(m[1] as String);
        _finishing = null;
      case 'cancelled':
        _cancelling?.complete();
        _cancelling = null;
      case 'error':
        final error = ScribeException(m[1] as String);
        AppLog.w(_tag, 'engine error', error);
        for (final c in [_starting, _cancelling]) {
          c?.completeError(error);
        }
        _finishing?.completeError(error);
        _starting = _cancelling = null;
        _finishing = null;
        _transcripts.addError(error);
    }
  }

  @override
  Future<void> startSession() {
    _checkAlive();
    final c = _starting = Completer<void>();
    _toWorker.send(const ['start']);
    return c.future;
  }

  @override
  void addAudio(Uint8List pcm16) {
    if (_disposed) return;
    _toWorker.send([
      'audio',
      TransferableTypedData.fromList([pcm16]),
    ]);
  }

  @override
  Future<String> finishSession() {
    _checkAlive();
    final c = _finishing = Completer<String>();
    _toWorker.send(const ['finish']);
    return c.future;
  }

  @override
  Future<void> cancelSession() {
    if (_disposed) return Future.value();
    final c = _cancelling = Completer<void>();
    _toWorker.send(const ['cancel']);
    return c.future;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final exited = ReceivePort();
    _isolate.addOnExitListener(exited.sendPort);
    _toWorker.send(const ['dispose']);
    // Freeing the model is quick; don't hang a screen on a stuck worker.
    await exited.first.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _isolate.kill(priority: Isolate.immediate);
      },
    );
    exited.close();
    _port.close();
    await _transcripts.close();
  }

  void _checkAlive() {
    if (_disposed) throw const ScribeException('The speech model has been unloaded');
  }
}

// ─── Worker isolate ──────────────────────────────────────────────────────────

class _WorkerArgs {
  final SendPort reply;
  final String modelPath;
  final int threads;
  const _WorkerArgs(this.reply, this.modelPath, this.threads);
}

void _workerMain(_WorkerArgs args) {
  final worker = _Worker(args.reply);
  final String version;
  try {
    version = worker.load(args.modelPath, args.threads);
  } catch (e) {
    args.reply.send(['error', '$e']);
    worker.release();
    return;
  }
  final inbox = ReceivePort();
  args.reply.send(['ready', inbox.sendPort, version]);
  inbox.listen((message) {
    final m = message as List;
    try {
      switch (m[0]) {
        case 'start':
          worker.start();
          args.reply.send(const ['started']);
        case 'audio':
          final text = worker.push((m[1] as TransferableTypedData).materialize().asUint8List());
          if (text != null) args.reply.send(['partial', text]);
        case 'finish':
          args.reply.send(['final', worker.finish()]);
        case 'cancel':
          worker.closeStream();
          args.reply.send(const ['cancelled']);
        case 'dispose':
          worker.release();
          inbox.close();
      }
    } catch (e) {
      worker.closeStream();
      args.reply.send(['error', '$e']);
    }
  });
}

class _Worker {
  _Worker(this.reply);

  final SendPort reply;
  late final ScribeBindings _b;
  Pointer<Void> _recognizer = nullptr;
  Pointer<Void> _stream = nullptr;
  Pointer<AsrRecognitionOptions> _options = nullptr;
  final Pointer<Pointer<Void>> _out = calloc<Pointer<Void>>();
  Pointer<Float> _buffer = nullptr;
  int _bufferLength = 0;

  /// Text of finished utterances, plus the hypothesis for the current one.
  String _committed = '';
  String _interim = '';

  String load(String modelPath, int threads) {
    _b = ScribeBindings.open();
    final backend = calloc<AsrBackendConfig>();
    final model = calloc<AsrModelConfig>();
    final config = calloc<AsrRecognizerConfig>();
    final path = modelPath.toNativeUtf8();
    try {
      backend.ref
        ..size = sizeOf<AsrBackendConfig>()
        ..gpu = -1
        ..threads = threads;
      model.ref
        ..size = sizeOf<AsrModelConfig>()
        ..path = path
        ..name = nullptr;
      config.ref
        ..size = sizeOf<AsrRecognizerConfig>()
        ..backend = backend
        ..model = model;
      _check(_b.create(config, _out));
      _recognizer = _out.value;
    } finally {
      calloc
        ..free(path)
        ..free(config)
        ..free(model)
        ..free(backend);
    }
    _check(_b.warmup(_recognizer));

    _options = calloc<AsrRecognitionOptions>();
    _options.ref = _b.optionsDefault();
    _options.ref
      ..languageCode = OfflineTranscriber.languageCode.toNativeUtf8()
      ..interimResults = true
      ..enableAutomaticPunctuation = false; // the model writes no punctuation
    final v = _b.version();
    return v == nullptr ? 'nemo-speech' : v.toDartString();
  }

  void start() {
    closeStream();
    _committed = '';
    _interim = '';
    _check(_b.streamingRecognize(_recognizer, _options, _out));
    _stream = _out.value;
  }

  /// Converts 16-bit PCM to float, decodes what it can and returns the new
  /// transcript, or null if nothing changed.
  String? push(Uint8List pcm16) {
    if (_stream == nullptr) return null;
    final n = pcm16.lengthInBytes ~/ 2;
    if (n == 0) return null;
    if (n > _bufferLength) {
      if (_buffer != nullptr) calloc.free(_buffer);
      _buffer = calloc<Float>(n);
      _bufferLength = n;
    }
    final samples = _buffer.asTypedList(n);
    final view = ByteData.sublistView(pcm16);
    for (var i = 0; i < n; i++) {
      samples[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
    }
    _check(_b.streamPush(_stream, _buffer, n, OfflineTranscriber.sampleRate));
    return _drain() ? _text : null;
  }

  String finish() {
    if (_stream == nullptr) return _text;
    _check(_b.streamFinish(_stream));
    _drain();
    final text = _text;
    closeStream();
    return text;
  }

  String get _text => [_committed, _interim].where((s) => s.isNotEmpty).join(' ');

  bool _drain() {
    var changed = false;
    while (true) {
      _check(_b.streamNext(_stream, _out));
      final result = _out.value;
      if (result == nullptr) return changed;
      final p = _b.resultTranscript(result, 0);
      final text = p == nullptr ? '' : p.toDartString().trim();
      if (_b.resultIsFinal(result)) {
        if (text.isNotEmpty) _committed = _committed.isEmpty ? text : '$_committed $text';
        _interim = '';
      } else {
        _interim = text;
      }
      _b.resultDestroy(result);
      changed = true;
    }
  }

  void closeStream() {
    if (_stream != nullptr) {
      _b.streamClose(_stream);
      _stream = nullptr;
    }
  }

  void release() {
    closeStream();
    if (_recognizer != nullptr) {
      _b.destroy(_recognizer);
      _recognizer = nullptr;
    }
    if (_options != nullptr) {
      calloc
        ..free(_options.ref.languageCode)
        ..free(_options);
      _options = nullptr;
    }
    if (_buffer != nullptr) calloc.free(_buffer);
    _buffer = nullptr;
    calloc.free(_out);
  }

  void _check(int status) {
    if (status != asrOk) throw ScribeException(_b.errorText(status));
  }
}
