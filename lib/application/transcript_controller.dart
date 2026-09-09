import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/confidence.dart';
import '../domain/models/gesture_result.dart';
import '../domain/models/log_entry.dart';
import '../domain/models/transcript_entry.dart';
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
class TranscriptController extends Notifier<TranscriptState> {
  StreamSubscription<GestureResultPacket>? _gestureSub;
  int _nextEntryId = 1;

  @override
  TranscriptState build() {
    final connection = ref.read(gloveConnectionProvider);
    _gestureSub = connection.gestureResults.listen(_onGesture);
    ref.onDispose(() => _gestureSub?.cancel());
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
      confidence: packet.confidence,
      confidenceLevel: level,
      source: ref.read(gloveIsMockProvider) ? 'mock' : 'glove',
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
