import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/confidence.dart';
import '../core/strings/app_strings.dart';
import '../data/glove/glove_connection.dart';
import '../domain/models/gesture_result.dart';
import '../domain/models/log_entry.dart';
import '../domain/vocab/vocab_entry.dart';
import 'providers.dart';

/// Researcher record-mode flow states (SRS FR-9).
enum CollectionPhase { idle, prompting, done }

/// Researcher mode: prompt FSL signs and record labeled samples with the
/// participant id, for the training pipeline (SRS FR-9, NFR-8 consent gate).
class CollectionState {
  const CollectionState({
    this.phase = CollectionPhase.idle,
    this.prompts = const [],
    this.promptIndex = 0,
    this.repsDone = 0,
    this.repsPerPrompt = 5,
    this.lastSampleConfidence,
    this.counts = const {},
    this.skippedCount = 0,
    this.sessionId = '',
    this.participantId = '',
    this.error,
  });

  final CollectionPhase phase;

  /// Labels for this run (the 28-letter FSL alphabet by default).
  final List<VocabEntry> prompts;

  final int promptIndex;
  final int repsDone;
  final int repsPerPrompt;

  /// Confidence of the last captured sample, for live feedback.
  final int? lastSampleConfidence;

  /// label wordId → samples recorded so far in this run.
  final Map<int, int> counts;

  /// Labels the researcher skipped (signer couldn't produce the sign).
  final int skippedCount;

  /// Dedicated session for this run; rows land under it (FR-16 export).
  final String sessionId;

  final String participantId;

  /// User-facing gating message (consent / participant id).
  final String? error;

  VocabEntry? get currentPrompt =>
      promptIndex < prompts.length ? prompts[promptIndex] : null;

  int get totalRecorded => counts.values.fold(0, (a, b) => a + b);

  CollectionState copyWith({
    CollectionPhase? phase,
    List<VocabEntry>? prompts,
    int? promptIndex,
    int? repsDone,
    int? repsPerPrompt,
    int? lastSampleConfidence,
    Map<int, int>? counts,
    int? skippedCount,
    String? sessionId,
    String? participantId,
    String? error,
  }) =>
      CollectionState(
        phase: phase ?? this.phase,
        prompts: prompts ?? this.prompts,
        promptIndex: promptIndex ?? this.promptIndex,
        repsDone: repsDone ?? this.repsDone,
        repsPerPrompt: repsPerPrompt ?? this.repsPerPrompt,
        lastSampleConfidence: lastSampleConfidence,
        counts: counts ?? this.counts,
        skippedCount: skippedCount ?? this.skippedCount,
        sessionId: sessionId ?? this.sessionId,
        participantId: participantId ?? this.participantId,
        error: error,
      );
}

/// Records labeled samples into the [LogStore] while prompting the signer.
///
/// Shell contract (revisit with the firmware team): a sample is the glove's
/// ordinary gesture packet, re-labeled with the prompted word and stamped
/// with the observed word in `originalWordId` for later review. The SRS
/// FR-9 target is labeled RAW SENSOR STREAMS — that requires a firmware
/// stream contract that does not exist yet; the export pipeline in place
/// (FR-10/FR-16) carries this shell's data until then.
class DataCollectionController extends Notifier<CollectionState> {
  DataCollectionController({this.repsPerPrompt = 5});

  /// Injectable for tests; production uses the default.
  final int repsPerPrompt;

  StreamSubscription<GestureResultPacket>? _gestureSub;

  @override
  CollectionState build() {
    final connection = ref.read(gloveConnectionProvider);
    _gestureSub = connection.gestureResults.listen(_onSample);
    ref.onDispose(() => _gestureSub?.cancel());
    return CollectionState(repsPerPrompt: repsPerPrompt);
  }

  /// Starts a run. NFR-8: consent verified before collection; FR-13: the
  /// anonymized participant id is required.
  Future<void> start() async {
    final settings = ref.read(settingsServiceProvider);
    final participantId = (await settings.participantId()).trim();
    if (participantId.isEmpty) {
      state = state.copyWith(error: AppStrings.recordNeedsParticipant);
      return;
    }
    if (!await settings.consentGiven()) {
      state = state.copyWith(error: AppStrings.recordNeedsConsent);
      return;
    }

    final sessionId = newSessionId();
    await ref.read(logStoreProvider).startSession(SessionMeta(
          sessionId: sessionId,
          participantId: participantId,
          startedAt: DateTime.now(),
        ));

    await ref
        .read(gloveConnectionProvider)
        .sendCommand(AppCommand.startStream);
    state = state.copyWith(
      phase: CollectionPhase.prompting,
      prompts: ref.read(vocabularyRepositoryProvider).letters,
      promptIndex: 0,
      repsDone: 0,
      counts: const {},
      skippedCount: 0,
      sessionId: sessionId,
      participantId: participantId,
      lastSampleConfidence: null,
      error: null,
    );
  }

  void _onSample(GestureResultPacket packet) {
    if (state.phase != CollectionPhase.prompting) return;
    final prompt = state.currentPrompt;
    if (prompt == null) return;

    // Labeled row: wordId is the prompted label, originalWordId the
    // observed word (null when they match).
    final logEntry = GestureLogEntry(
      participantId: state.participantId,
      sessionId: state.sessionId,
      wordId: prompt.wordId,
      filipinoText: prompt.filipino,
      englishText: prompt.english,
      confidence: packet.confidence,
      confidenceLevel: ConfidenceThresholds.levelName(
          ConfidenceThresholds.levelFor(packet.confidence)),
      latencyMs: packet.latencyMs,
      gloveTimestampMs: packet.gloveTimestampMs,
      receivedAt: packet.receivedAt,
      originalWordId: packet.wordId == prompt.wordId ? null : packet.wordId,
      source: 'collection',
      appVersion: ref.read(appVersionProvider),
    );
    // Fire-and-forget: recording must never block the prompt flow.
    unawaited(ref.read(logStoreProvider).appendEvent(logEntry).then<void>(
          (_) {},
          onError: (_) {},
        ));

    final counts = Map<int, int>.from(state.counts);
    counts[prompt.wordId] = (counts[prompt.wordId] ?? 0) + 1;

    final nextRep = state.repsDone + 1;
    if (nextRep >= state.repsPerPrompt) {
      final nextIndex = state.promptIndex + 1;
      if (nextIndex >= state.prompts.length) {
        unawaited(_finish(counts, packet.confidence));
      } else {
        state = state.copyWith(
          promptIndex: nextIndex,
          repsDone: 0,
          counts: counts,
          lastSampleConfidence: packet.confidence,
        );
      }
    } else {
      state = state.copyWith(
        repsDone: nextRep,
        counts: counts,
        lastSampleConfidence: packet.confidence,
      );
    }
  }

  /// The researcher can skip a label the signer cannot produce; no rows
  /// are recorded for it.
  void skip() {
    if (state.phase != CollectionPhase.prompting) return;
    final nextIndex = state.promptIndex + 1;
    if (nextIndex >= state.prompts.length) {
      unawaited(_finish(state.counts, null));
    } else {
      state = state.copyWith(
        promptIndex: nextIndex,
        repsDone: 0,
        skippedCount: state.skippedCount + 1,
      );
    }
  }

  Future<void> _finish(Map<int, int> counts, int? lastConfidence) async {
    await ref
        .read(gloveConnectionProvider)
        .sendCommand(AppCommand.stopStream);
    state = state.copyWith(
      phase: CollectionPhase.done,
      counts: counts,
      lastSampleConfidence: lastConfidence,
    );
  }

  /// Stops mid-run. Rows already recorded stay (FR-10 data integrity);
  /// only the in-flight prompt is discarded.
  Future<void> abort() async {
    await ref
        .read(gloveConnectionProvider)
        .sendCommand(AppCommand.stopStream);
    state = state.copyWith(
      phase: CollectionPhase.idle,
      promptIndex: 0,
      repsDone: 0,
      lastSampleConfidence: null,
    );
  }

  /// Back to the idle screen after reviewing the done summary.
  void resetToIdle() => state = state.copyWith(
        phase: CollectionPhase.idle,
        promptIndex: 0,
        repsDone: 0,
        counts: const {},
        skippedCount: 0,
        lastSampleConfidence: null,
        error: null,
      );
}
