import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:talkhimik_app/data/storage/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // The Async API (SharedPreferencesAsync) has its own platform instance.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('defaults match the SRS contract', () async {
    final service = SharedPrefsSettingsService();
    expect(await service.outputLanguage(), 'fil');
    expect(await service.ttsRate(), 1.0);
    expect(await service.ttsVoice(), isNull);
    expect(await service.ttsMuted(), isFalse);
    expect(await service.largeText(), isTrue); // NFR-7 default
    expect(await service.participantId(), '');
    expect(await service.consentGiven(), isFalse);
    expect(await service.consentDate(), isNull);
    expect(await service.forceMock(), isFalse);
    expect(await service.demoScenario(), isNull);
  });

  test('values round-trip through persistence', () async {
    final service = SharedPrefsSettingsService();
    await service.setOutputLanguage('en');
    await service.setTtsRate(0.7);
    await service.setTtsVoice('fil-PH-voice-1');
    await service.setTtsMuted(true);
    await service.setLargeText(false);
    await service.setParticipantId('P-001');
    await service.setConsentGiven(true);
    await service.setConsentDate(DateTime(2026, 9, 9));
    await service.setForceMock(true);
    await service.setDemoScenario('alphabetSweep');

    // A fresh service instance reads the same persisted store.
    final reread = SharedPrefsSettingsService();
    expect(await reread.outputLanguage(), 'en');
    expect(await reread.ttsRate(), 0.7);
    expect(await reread.ttsVoice(), 'fil-PH-voice-1');
    expect(await reread.ttsMuted(), isTrue);
    expect(await reread.largeText(), isFalse);
    expect(await reread.participantId(), 'P-001');
    expect(await reread.consentGiven(), isTrue);
    expect(await reread.consentDate(), DateTime(2026, 9, 9));
    expect(await reread.forceMock(), isTrue);
    expect(await reread.demoScenario(), 'alphabetSweep');
  });

  test('nullable fields clear when set to null', () async {
    final service = SharedPrefsSettingsService();
    await service.setTtsVoice('some-voice');
    await service.setConsentDate(DateTime(2026, 9, 9));
    await service.setDemoScenario('mixedConfidence');

    await service.setTtsVoice(null);
    await service.setConsentDate(null);
    await service.setDemoScenario(null);

    expect(await service.ttsVoice(), isNull);
    expect(await service.consentDate(), isNull);
    expect(await service.demoScenario(), isNull);
  });
}
