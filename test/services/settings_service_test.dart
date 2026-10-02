import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_broker/core/services/ai_provider.dart';
import 'package:smart_broker/core/services/settings_service.dart';

void main() {
  final settings = SettingsService();

  group('overlay mode', () {
    test('defaults to known contacts only', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await settings.getOverlayMode(), OverlayMode.knownOnly);
    });

    test('migrates the old on/off switch', () async {
      SharedPreferences.setMockInitialValues({'show_call_overlay': false});
      expect(await settings.getOverlayMode(), OverlayMode.off);

      SharedPreferences.setMockInitialValues({'show_call_overlay': true});
      expect(await settings.getOverlayMode(), OverlayMode.knownOnly);
    });

    test('saving a mode replaces the old switch', () async {
      SharedPreferences.setMockInitialValues({'show_call_overlay': false});
      await settings.setOverlayMode(OverlayMode.all);

      expect(await settings.getOverlayMode(), OverlayMode.all);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('show_call_overlay'), isFalse);
    });
  });

  group('AI settings', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('consent is per provider', () async {
      await settings.setAiConsent(AiProvider.groq);

      expect(await settings.hasAiConsent(AiProvider.groq), isTrue);
      expect(await settings.hasAiConsent(AiProvider.openRouter), isFalse);
    });

    test('model override falls back to the default', () async {
      expect(await settings.getAiModel(AiProvider.groq), AiProvider.groq.defaultModel);

      await settings.setAiModel(AiProvider.groq, '  custom/model ');
      expect(await settings.getAiModel(AiProvider.groq), 'custom/model');

      await settings.setAiModel(AiProvider.groq, '');
      expect(await settings.getAiModel(AiProvider.groq), AiProvider.groq.defaultModel);
    });

    test('unknown provider id falls back to Groq', () async {
      SharedPreferences.setMockInitialValues({'ai_provider': 'gone'});
      expect(await settings.getAiProvider(), AiProvider.groq);
    });
  });
}
