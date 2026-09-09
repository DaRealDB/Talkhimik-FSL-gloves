import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tts/tts_service.dart';
import 'providers.dart';

/// TTS configuration (SRS FR-2, FR-15).
class TtsState {
  const TtsState({
    this.muted = false,
    this.language = 'fil',
    this.rate = 1.0,
    this.voice,
    this.voices = const [],
    this.initialized = false,
  });

  final bool muted;
  final String language; // 'fil' | 'en' (mirrors the output language setting)
  final double rate;
  final String? voice;

  /// Voices the platform engine offers for the current language (FR-15).
  final List<TtsVoice> voices;

  final bool initialized;

  TtsState copyWith({
    bool? muted,
    String? language,
    double? rate,
    String? voice,
    List<TtsVoice>? voices,
    bool? initialized,
  }) =>
      TtsState(
        muted: muted ?? this.muted,
        language: language ?? this.language,
        rate: rate ?? this.rate,
        voice: voice ?? this.voice,
        voices: voices ?? this.voices,
        initialized: initialized ?? this.initialized,
      );
}

class TtsController extends Notifier<TtsState> {
  @override
  TtsState build() => const TtsState();

  /// Loads persisted settings and initializes the platform engine.
  /// Called once from the app bootstrap (main.dart).
  Future<void> initialize() async {
    final settings = ref.read(settingsServiceProvider);
    final language = await settings.outputLanguage();
    final rate = await settings.ttsRate();
    final voice = await settings.ttsVoice();
    final muted = await settings.ttsMuted();

    final service = ref.read(ttsServiceProvider);
    await service.init(
      language: _engineTag(language),
      rate: rate,
      voice: voice,
    );
    state = TtsState(
      language: language,
      rate: rate,
      voice: voice,
      voices: await service.getVoices(_engineTag(language)),
      muted: muted,
      initialized: true,
    );
  }

  /// Speaks [text] unless muted. Never throws: speech is an output channel
  /// that must not take the transcript down with it (FR-2, plan risk #4).
  ///
  /// Deliberately works before [initialize] completes: the engine falls
  /// back to platform defaults until persisted settings load.
  Future<void> speak(String text) async {
    if (state.muted) return;
    await ref.read(ttsServiceProvider).speak(text);
  }

  Future<void> setMuted(bool muted) async {
    await ref.read(settingsServiceProvider).setTtsMuted(muted);
    state = state.copyWith(muted: muted);
  }

  Future<void> setLanguage(String language) async {
    final service = ref.read(ttsServiceProvider);
    await service.setLanguage(_engineTag(language));
    await ref.read(settingsServiceProvider).setOutputLanguage(language);
    state = state.copyWith(
      language: language,
      voices: await service.getVoices(_engineTag(language)),
    );
  }

  Future<void> setRate(double rate) async {
    await ref.read(ttsServiceProvider).setRate(rate);
    await ref.read(settingsServiceProvider).setTtsRate(rate);
    state = state.copyWith(rate: rate);
  }

  Future<void> setVoice(String voice) async {
    await ref.read(ttsServiceProvider).setVoice(voice);
    await ref.read(settingsServiceProvider).setTtsVoice(voice);
    state = state.copyWith(voice: voice);
  }

  static String _engineTag(String language) =>
      language == 'en' ? 'en-US' : 'fil-PH';
}
