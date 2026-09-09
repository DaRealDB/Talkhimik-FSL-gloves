/// A selectable voice reported by the platform TTS engine.
class TtsVoice {
  const TtsVoice({required this.id, required this.name});

  final String id;
  final String name;
}

/// Text-to-speech abstraction (SRS FR-2, C-S3).
///
/// Implementations: [FlutterTtsService] (OS-native engine via flutter_tts)
/// and the test fake. [speak] must never throw — a TTS failure must never
/// break the transcript path (plan risk #4).
abstract interface class TtsService {
  /// Platform language tag: 'fil-PH' for Filipino, 'en-US' for English.
  Future<void> init({
    required String language,
    required double rate,
    String? voice,
  });

  Future<void> speak(String text);

  Future<void> stop();

  Future<List<TtsVoice>> getVoices(String language);

  Future<void> setLanguage(String language);

  Future<void> setRate(double rate);

  Future<void> setVoice(String voice);
}
