// dart:ffi bindings for the NeMo-Speech.cpp ASR C API (include/nemo_speech/asr.h)
// plus SmartBroker's addition (backend `threads`, `nemo_speech_asr_warmup`;
// tool/scribe/patches). Only the calls offline dictation needs.
//
// Used only inside the dictation isolate (offline_transcriber.dart): every
// call here can block for a long time.
import 'dart:ffi';

import 'package:ffi/ffi.dart';

const scribeLibrary = 'libnemo_speech_asr_c.so';

/// nemo_speech_asr_status
const asrOk = 0;

final class AsrBackendConfig extends Struct {
  @Size()
  external int size;
  @Int32()
  external int gpu; // -1 = CPU
  @Int32()
  external int threads; // 0 = min(8, hardware threads)
}

final class AsrModelConfig extends Struct {
  @Size()
  external int size;
  external Pointer<Utf8> path;
  external Pointer<Utf8> name;
}

final class AsrRecognizerConfig extends Struct {
  @Size()
  external int size;
  external Pointer<AsrBackendConfig> backend;
  external Pointer<AsrModelConfig> model;
  external Pointer<Void> streaming;
  external Pointer<Void> decoder;
  external Pointer<Void> vad;
  external Pointer<Void> endpointing;
  external Pointer<Void> postproc;
  external Pointer<Void> diar;
  external Pointer<Void> batching;
}

final class AsrRecognitionOptions extends Struct {
  @Size()
  external int size;
  external Pointer<Utf8> requestId;
  external Pointer<Utf8> languageCode;
  @Bool()
  external bool interimResults;
  @Bool()
  external bool enableWordTimeOffsets;
  @Bool()
  external bool enableAutomaticPunctuation;
  @Bool()
  external bool verbatimTranscripts;
  @Bool()
  external bool profanityFilter;
  @Int32()
  external int stopHistoryEouMs;
  external Pointer<Void> speechContexts;
  @Size()
  external int speechContextCount;
  @Int32()
  external int maxAlternatives;
  @Bool()
  external bool enableSpeakerDiarization;
  @Int32()
  external int maxSpeakerCount;
}

typedef _OptionsDefaultC = AsrRecognitionOptions Function();
typedef _CreateC = Int32 Function(Pointer<AsrRecognizerConfig>, Pointer<Pointer<Void>>);
typedef AsrCreateFn = int Function(Pointer<AsrRecognizerConfig>, Pointer<Pointer<Void>>);
typedef _HandleC = Void Function(Pointer<Void>);
typedef AsrHandleFn = void Function(Pointer<Void>);
typedef _HandleStatusC = Int32 Function(Pointer<Void>);
typedef AsrHandleStatusFn = int Function(Pointer<Void>);
typedef _StreamC = Int32 Function(Pointer<Void>, Pointer<AsrRecognitionOptions>, Pointer<Pointer<Void>>);
typedef AsrStreamFn = int Function(Pointer<Void>, Pointer<AsrRecognitionOptions>, Pointer<Pointer<Void>>);
typedef _PushC = Int32 Function(Pointer<Void>, Pointer<Float>, Size, Int32);
typedef AsrPushFn = int Function(Pointer<Void>, Pointer<Float>, int, int);
typedef _NextC = Int32 Function(Pointer<Void>, Pointer<Pointer<Void>>);
typedef AsrNextFn = int Function(Pointer<Void>, Pointer<Pointer<Void>>);
typedef _IsFinalC = Bool Function(Pointer<Void>);
typedef AsrIsFinalFn = bool Function(Pointer<Void>);
typedef _TranscriptC = Pointer<Utf8> Function(Pointer<Void>, Size);
typedef AsrTranscriptFn = Pointer<Utf8> Function(Pointer<Void>, int);
typedef _StringC = Pointer<Utf8> Function();
typedef AsrStringFn = Pointer<Utf8> Function();

class ScribeBindings {
  ScribeBindings(DynamicLibrary lib)
    : optionsDefault = lib.lookupFunction<_OptionsDefaultC, _OptionsDefaultC>(
        'nemo_speech_asr_recognition_options_default',
      ),
      create = lib.lookupFunction<_CreateC, AsrCreateFn>('nemo_speech_asr_create'),
      destroy = lib.lookupFunction<_HandleC, AsrHandleFn>('nemo_speech_asr_destroy'),
      warmup = lib.lookupFunction<_HandleStatusC, AsrHandleStatusFn>('nemo_speech_asr_warmup'),
      streamingRecognize = lib.lookupFunction<_StreamC, AsrStreamFn>('nemo_speech_asr_streaming_recognize'),
      streamPush = lib.lookupFunction<_PushC, AsrPushFn>('nemo_speech_asr_stream_push_f32'),
      streamFinish = lib.lookupFunction<_HandleStatusC, AsrHandleStatusFn>('nemo_speech_asr_stream_finish'),
      streamNext = lib.lookupFunction<_NextC, AsrNextFn>('nemo_speech_asr_stream_next'),
      streamClose = lib.lookupFunction<_HandleC, AsrHandleFn>('nemo_speech_asr_stream_close'),
      resultIsFinal = lib.lookupFunction<_IsFinalC, AsrIsFinalFn>('nemo_speech_asr_result_is_final'),
      resultTranscript = lib.lookupFunction<_TranscriptC, AsrTranscriptFn>('nemo_speech_asr_result_transcript'),
      resultDestroy = lib.lookupFunction<_HandleC, AsrHandleFn>('nemo_speech_asr_result_destroy'),
      lastError = lib.lookupFunction<_StringC, AsrStringFn>('nemo_speech_asr_last_error'),
      version = lib.lookupFunction<_StringC, AsrStringFn>('nemo_speech_asr_version');

  static ScribeBindings open() => ScribeBindings(DynamicLibrary.open(scribeLibrary));

  final AsrRecognitionOptions Function() optionsDefault;
  final AsrCreateFn create;
  final AsrHandleFn destroy;
  final AsrHandleStatusFn warmup;
  final AsrStreamFn streamingRecognize;
  final AsrPushFn streamPush;
  final AsrHandleStatusFn streamFinish;
  final AsrNextFn streamNext;
  final AsrHandleFn streamClose;
  final AsrIsFinalFn resultIsFinal;
  final AsrTranscriptFn resultTranscript;
  final AsrHandleFn resultDestroy;
  final AsrStringFn lastError;
  final AsrStringFn version;

  String errorText(int status) {
    final p = lastError();
    final message = p == nullptr ? '' : p.toDartString();
    return message.isEmpty ? 'speech engine error $status' : message;
  }
}
