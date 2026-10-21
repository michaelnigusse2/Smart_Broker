import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the fonts bundled in the app to the "Open-source licences" page.
void registerFontLicences() {
  LicenseRegistry.addLicense(() async* {
    for (final (packages, asset) in const [
      (['Inter (font)'], 'assets/licenses/font_inter.txt'),
      (['Bricolage Grotesque (font)'], 'assets/licenses/font_bricolage_grotesque.txt'),
      (['Menbere (font)'], 'assets/licenses/font_menbere.txt'),
      (['Noto Sans Ethiopic (font)'], 'assets/licenses/font_noto_sans_ethiopic.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks(packages, await rootBundle.loadString(asset));
    }
  });
}

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
