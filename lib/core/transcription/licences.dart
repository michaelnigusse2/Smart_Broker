import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the native speech libraries shipped in the APK (they aren't Dart
/// packages, so Flutter doesn't list them) to the "Open-source licences" page.
void registerDictationLicences() {
  LicenseRegistry.addLicense(() async* {
    for (final (packages, asset) in const [
      (['NeMo-Speech.cpp'], 'assets/licenses/nemo_speech_cpp.txt'),
      (['ggml', 'llama.cpp'], 'assets/licenses/ggml.txt'),
      (['SentencePiece', 'protobuf-lite', 'abseil', 'darts-clone'], 'assets/licenses/sentencepiece.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks(packages, await rootBundle.loadString(asset));
    }
  });
}
