import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_broker/core/transcription/dictation_controller.dart';
import 'package:smart_broker/core/transcription/offline_transcriber.dart';
import 'package:smart_broker/core/transcription/scribe_model_store.dart';

class FakeEngine implements SpeechEngine {
  final audio = <Uint8List>[];
  final _text = StreamController<String>.broadcast();
  String finalText = '';
  int sessions = 0;
  bool cancelled = false;
  bool disposed = false;

  void say(String text) => _text.add(text);

  @override
  Stream<String> get transcripts => _text.stream;

  @override
  Future<void> startSession() async => sessions++;

  @override
  void addAudio(Uint8List pcm16) => audio.add(pcm16);

  @override
  Future<String> finishSession() async => finalText;

  @override
  Future<void> cancelSession() async => cancelled = true;

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  late Directory tmp;
  late ScribeModelStore store;
  late StreamController<Uint8List> mic;
  late FakeEngine engine;
  var loads = 0;
  var permission = true;

  const spec = ModelFileSpec(fileName: 'm.gguf', url: 'https://x.example/m', sizeBytes: 4, sha256: '-');

  Future<void> installModel() async => (await store.modelFile()).writeAsBytes([1, 2, 3, 4]);

  DictationController controller({Future<SpeechEngine> Function(String)? load}) => DictationController(
    store: store,
    loadEngine:
        load ??
        (path) async {
          loads++;
          return engine;
        },
    audio: () => mic.stream,
    requestPermission: () async => permission,
  );

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dictation_test');
    store = ScribeModelStore(spec: spec, baseDirectory: () async => tmp);
    mic = StreamController<Uint8List>();
    engine = FakeEngine();
    loads = 0;
    permission = true;
  });
  tearDown(() async => tmp.delete(recursive: true));

  test('asks for the model when it is not downloaded', () async {
    final c = controller();
    await c.start();
    expect(c.state, DictationState.needsModel);
    expect(loads, 0);
  });

  test('needs microphone permission', () async {
    await installModel();
    permission = false;
    final c = controller();
    await c.start();
    expect(c.state, DictationState.error);
    expect(c.error, contains('microphone'));
  });

  test('streams audio to the engine, shows live text, returns the note', () async {
    await installModel();
    final c = controller();
    await c.start();
    expect(c.state, DictationState.listening);
    expect(mic.hasListener, isTrue);

    mic.add(Uint8List(3200));
    engine.say('እዚህ ሰፈር አስራ አምስት');
    await Future<void>.delayed(Duration.zero);
    expect(engine.audio, hasLength(1));
    expect(c.liveText, 'እዚህ ሰፈር 15');

    engine.finalText = ' እዚህ ሰፈር አስራ አምስት አመት ኖሪያለሁ ';
    final text = await c.stop();
    expect(text, 'እዚህ ሰፈር 15 አመት ኖሪያለሁ');
    expect(c.state, DictationState.idle);
    expect(mic.hasListener, isFalse, reason: 'the microphone is released');
  });

  test('keeps the model loaded between dictations', () async {
    await installModel();
    final c = controller();
    await c.start();
    await c.stop();
    mic = StreamController<Uint8List>();
    await c.start();
    expect(loads, 1);
    expect(engine.sessions, 2);
    c.dispose();
    expect(engine.disposed, isTrue);
  });

  test('cancel discards the session', () async {
    await installModel();
    final c = controller();
    await c.start();
    await c.cancel();
    expect(engine.cancelled, isTrue);
    expect(c.state, DictationState.idle);
    expect(mic.hasListener, isFalse);
  });

  test('a microphone failure stops dictation with a message', () async {
    await installModel();
    final c = controller();
    await c.start();
    mic.addError(Exception('MIC_UNAVAILABLE'));
    await Future<void>.delayed(Duration.zero);
    expect(c.state, DictationState.error);
    expect(c.error, contains('in use'));
  });

  test('closing the screen while the model loads frees it', () async {
    await installModel();
    final gate = Completer<SpeechEngine>();
    final c = controller(load: (_) => gate.future);
    final starting = c.start();
    await Future<void>.delayed(Duration.zero);
    c.dispose();
    gate.complete(engine);
    await starting;
    expect(engine.disposed, isTrue);
    expect(mic.hasListener, isFalse);
  });

  test('an engine that fails to load reports an error', () async {
    await installModel();
    final c = controller(load: (_) async => throw const ScribeException('out of memory'));
    await c.start();
    expect(c.state, DictationState.error);
    expect(c.error, contains('out of memory'));
  });
}
