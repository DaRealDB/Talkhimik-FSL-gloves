import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/confidence.dart';
import '../domain/models/gesture_result.dart';
import '../domain/models/log_entry.dart';
import '../domain/models/transcript_entry.dart';
import '../domain/vocab/vocab_entry.dart';
import 'providers.dart';

/// Everything the conversation view shows (SRS FR-1, FR-3, FR-4, FR-7).
class TranscriptState {
  const TranscriptState({
    this.entries = const [],
    this.language = 'fil',
    this.largeText = true, // NFR-7: large signer-facing text by default
    this.sessionId = '',
    this.participantId = '',
  });

  final List<TranscriptEntry> entries;

  /// 'fil' | 'en' — which language variant the bubbles render.
  final String language;

  /// Signer-facing text at large size (FR-15 accessibility).
  final bool largeText;

  final String sessionId;
  final String participantId;

  TranscriptState copyWith({
    List<TranscriptEntry>? entries,
    String? language,
    bool? largeText,
    String? sessionId,
    String? participantId,
  }) =>
      TranscriptState(
        entries: entries ?? this.entries,
        language: language ?? this.language,
        largeText: largeText ?? this.largeText,
        sessionId: sessionId ?? this.sessionId,
        participantId: participantId ?? this.participantId,
      );
}

/// The core loop: gesture → decode → bubble → TTS → log (SRS end-to-end
/// data flow steps 5–7).
///
/// Two producers feed ONE path: the glove connection's label packets and
/// the phone-side recognizer's event bus (C1). Both emit
/// [GestureResultPacket]; label packets take precedence because the
/// recognizer pauses itself when one arrives.
class TranscriptController extends Notifier<TranscriptState> {
  StreamSubscription<GestureResultPacket>? _gestureSub;
  StreamSubscription<GestureResultPacket>? _recognitionSub;
  int _nextEntryId = 1;

  @override
  TranscriptState build() {
    final connection = ref.read(gloveConnectionProvider);
    _gestureSub = connection.gestureResults.listen(_onGesture);
    _recognitionSub =
        ref.read(recognitionEventBusProvider).stream.listen(_onGesture);
    ref.onDispose(() {
      unawaited(_gestureSub?.cancel());
      unawaited(_recognitionSub?.cancel());
    });
    _loadSettings();
    return const TranscriptState();
  }

  Future<void> _loadSettings() async {
    final settings = ref.read(settingsServiceProvider);
    final language = await settings.outputLanguage();
    final largeText = await settings.largeText();
    final participantId = await settings.participantId();
    final sessionId = newSessionId();
    await ref
        .read(logStoreProvider)
        .startSession(SessionMeta(
          sessionId: sessionId,
          participantId: participantId,
          startedAt: DateTime.now(),
        ));
    state = state.copyWith(
      language: language,
      largeText: largeText,
      sessionId: sessionId,
      participantId: participantId,
    );
  }

  void _onGesture(GestureResultPacket packet) {
    final vocab = ref.read(vocabularyRepositoryProvider);
    final entry = vocab.lookup(packet.wordId);
    final filipino = entry?.filipino ?? '(word ${packet.wordId})';
    final english = entry?.english ?? '(word ${packet.wordId})';
    final level = ConfidenceThresholds.levelFor(packet.confidence);

    final transcriptEntry = TranscriptEntry(
      id: _nextEntryId++,
      kind: TranscriptKind.signed,
      filipino: filipino,
      english: english,
      wordId: packet.wordId,
      confidence: packet.confidence,
      confidenceLevel: level,
      alternatives: packet.alternatives,
      // Phone-side events carry their own provenance; glove packets derive
      // it from the connection kind as before.
      source: packet.source ?? (ref.read(gloveIsMockProvider) ? 'mock' : 'glove'),
    );
    state = state.copyWith(entries: [...state.entries, transcriptEntry]);

    // Step 6: speak the selected language variant (FR-2).
    final text = state.language == 'en' ? english : filipino;
    ref.read(ttsControllerProvider.notifier).speak(text);

    // Step 7: log every accepted event (FR-10, NFR-1 latency field).
    final logEntry = GestureLogEntry(
      participantId: state.participantId,
      sessionId: state.sessionId,
      wordId: packet.wordId,
      filipinoText: filipino,
      englishText: english,
      confidence: packet.confidence,
      confidenceLevel: _levelName(level),
      latencyMs: packet.latencyMs,
      gloveTimestampMs: packet.gloveTimestampMs,
      receivedAt: packet.receivedAt,
      source: transcriptEntry.source,
      appVersion: ref.read(appVersionProvider),
      modelVersion: packet.modelVersion ?? 'n/a',
    );
    // Fire-and-forget: logging must never block the recognition loop.
    unawaited(ref.read(logStoreProvider).appendEvent(logEntry).then<void>(
          (_) {},
          onError: (_) {
            // Surface in debug only; the transcript path is unaffected.
          },
        ));
  }

  /// FR-7: what the hearing partner typed, shown large to the signer.
  void addPartnerMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(entries: [
      ...state.entries,
      TranscriptEntry(
        id: _nextEntryId++,
        kind: TranscriptKind.partner,
        filipino: trimmed,
        english: trimmed,
        source: 'partner',
      ),
    ]);
  }

  /// FR-6: one-tap playback of a saved phrase — speaks it and echoes it as
  /// a transcript bubble (no badge, no recognition log row).
  void playSavedPhrase(VocabEntry phrase) {
    state = state.copyWith(entries: [
      ...state.entries,
      TranscriptEntry(
        id: _nextEntryId++,
        kind: TranscriptKind.signed,
        filipino: phrase.filipino,
        english: phrase.english,
        wordId: phrase.wordId,
        source: 'savedPhrase',
      ),
    ]);
    ref
        .read(ttsControllerProvider.notifier)
        .speak(state.language == 'en' ? phrase.english : phrase.filipino);
  }

  /// FR-5: replaces a bubble's text with the chosen alternative, marks it
  /// corrected, and logs a `source=correction` row — the Cohen's Kappa
  /// evidence for Chapter 3 (M5).
  void correctEntry(int entryId, int newWordId) {
    final index = state.entries.indexWhere((e) => e.id == entryId);
    if (index < 0) return;
    final old = state.entries[index];
    final replacement = ref.read(vocabularyRepositoryProvider).lookup(newWordId);
    if (replacement == null) return;

    final correctedEntry = TranscriptEntry(
      id: old.id,
      kind: old.kind,
      filipino: replacement.filipino,
      english: replacement.english,
      wordId: newWordId,
      confidence: 100,
      confidenceLevel: ConfidenceLevel.high,
      corrected: true,
      originalWordId: old.wordId,
      source: 'correction',
    );
    final entries = [...state.entries];
    entries[index] = correctedEntry;
    state = state.copyWith(entries: entries);

    ref
        .read(ttsControllerProvider.notifier)
        .speak(state.language == 'en' ? replacement.english : replacement.filipino);

    final logEntry = GestureLogEntry(
      participantId: state.participantId,
      sessionId: state.sessionId,
      wordId: newWordId,
      filipinoText: replacement.filipino,
      englishText: replacement.english,
      confidence: 100,
      confidenceLevel: 'green',
      latencyMs: 0,
      gloveTimestampMs: DateTime.now().millisecondsSinceEpoch,
      receivedAt: DateTime.now(),
      corrected: true,
      originalWordId: old.wordId,
      source: 'correction',
      appVersion: ref.read(appVersionProvider),
    );
    unawaited(ref.read(logStoreProvider).appendEvent(logEntry).then<void>(
          (_) {},
          onError: (_) {},
        ));
  }

  /// FR-3: clears the transcript view only — logged events stay (FR-10).
  void clear() => state = state.copyWith(entries: const []);

  /// FR-3 re-read: speak one bubble again (respects mute).
  void reRead(int entryId) {
    for (final e in state.entries) {
      if (e.id == entryId) {
        ref
            .read(ttsControllerProvider.notifier)
            .speak(state.language == 'en' ? e.english : e.filipino);
        return;
      }
    }
  }

  /// FR-15: language toggle re-renders existing bubbles (both variants are
  /// always stored) and re-aims the TTS engine.
  Future<void> setLanguage(String language) async {
    state = state.copyWith(language: language);
    await ref.read(ttsControllerProvider.notifier).setLanguage(language);
  }

  Future<void> setLargeText(bool largeText) async {
    await ref.read(settingsServiceProvider).setLargeText(largeText);
    state = state.copyWith(largeText: largeText);
  }

  static String _levelName(ConfidenceLevel level) => switch (level) {
        ConfidenceLevel.high => 'green',
        ConfidenceLevel.medium => 'amber',
        ConfidenceLevel.low => 'red',
      };
}
