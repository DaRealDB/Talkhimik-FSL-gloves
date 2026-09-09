import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'tts_service.dart';

/// OS-native TTS via flutter_tts (SRS C-S3).
///
/// Android ships a Filipino voice via the Google TTS engine; Windows and
/// web voices vary, so every call degrades with a debug warning instead of
/// throwing. flutter_tts' speech rate is platform-scaled (1.0 = the
/// engine's normal rate) — the app's 0.5–1.5 slider maps directly.
class FlutterTtsService implements TtsService {
  FlutterTtsService([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  Future<void> init({
    required String language,
    required double rate,
    String? voice,
  }) async {
    try {
      // Don't block the UI on speech finishing (default awaitSpeakCompletion
      // queues calls); speak() below never awaits completion.
      await _tts.awaitSpeakCompletion(false);
      await _tts.setLanguage(language);
      await _tts.setSpeechRate(rate);
      if (voice != null) {
        await _tts.setVoice({'name': voice});
      }
    } catch (e) {
      debugPrint('TtsService init degraded ($language, rate $rate): $e');
    }
  }

  @override
  Future<void> speak(String text) async {
    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TtsService speak degraded: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('TtsService stop degraded: $e');
    }
  }

  @override
  Future<List<TtsVoice>> getVoices(String language) async {
    try {
      final raw = await _tts.getVoices;
      return [
        for (final v in raw)
          if (v['name'] is String)
            TtsVoice(id: v['name'] as String, name: v['name'] as String),
      ];
    } catch (e) {
      debugPrint('TtsService getVoices degraded: $e');
      return const [];
    }
  }

  @override
  Future<void> setLanguage(String language) async {
    try {
      await _tts.setLanguage(language);
    } catch (e) {
      debugPrint('TtsService setLanguage degraded: $e');
    }
  }

  @override
  Future<void> setRate(double rate) async {
    try {
      await _tts.setSpeechRate(rate);
    } catch (e) {
      debugPrint('TtsService setRate degraded: $e');
    }
  }

  @override
  Future<void> setVoice(String voice) async {
    try {
      await _tts.setVoice({'name': voice});
    } catch (e) {
      debugPrint('TtsService setVoice degraded: $e');
    }
  }
}
