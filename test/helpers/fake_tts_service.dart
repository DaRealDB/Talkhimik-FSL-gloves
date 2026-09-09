import 'package:talkhimik_app/data/tts/tts_service.dart';

/// Records [speak] calls so tests can assert what the app said (FR-2).
class FakeTtsService implements TtsService {
  final List<String> spoken = [];
  String? lastLanguage;
  double? lastRate;
  String? lastVoice;
  int initCalls = 0;

  @override
  Future<void> init({
    required String language,
    required double rate,
    String? voice,
  }) async {
    initCalls++;
    lastLanguage = language;
    lastRate = rate;
    lastVoice = voice;
  }

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<List<TtsVoice>> getVoices(String language) async => const [
        TtsVoice(id: 'v1', name: 'Filipino voice'),
        TtsVoice(id: 'v2', name: 'English voice'),
      ];

  @override
  Future<void> setLanguage(String language) async {
    lastLanguage = language;
  }

  @override
  Future<void> setRate(double rate) async {
    lastRate = rate;
  }

  @override
  Future<void> setVoice(String voice) async {
    lastVoice = voice;
  }
}
