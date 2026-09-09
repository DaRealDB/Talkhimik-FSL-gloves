import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/strings/app_strings.dart';
import '../data/glove/glove_connection.dart';
import '../domain/models/calibration_profile.dart';
import '../domain/models/gesture_result.dart';
import '../domain/vocab/vocab_entry.dart';
import 'providers.dart';

/// Guided-calibration flow states (SRS FR-8).
enum CalibrationPhase { idle, prompting, done }

/// The guided flow: prompt sample signs → capture reps → compute and store
/// the per-user calibration profile (SRS FR-8, M1 cross-user).
class CalibrationState {
  const CalibrationState({
    this.phase = CalibrationPhase.idle,
    this.prompts = const [],
    this.promptIndex = 0,
    this.repsDone = 0,
    this.repsPerPrompt = 3,
    this.lastSampleConfidence,
    this.profile,
    this.error,
  });

  final CalibrationPhase phase;

  /// Prompts for this run (the 28-letter FSL alphabet by default).
  final List<VocabEntry> prompts;

  final int promptIndex;
  final int repsDone;
  final int repsPerPrompt;

  /// Confidence of the last captured sample, for live feedback.
  final int? lastSampleConfidence;

  /// The most recently saved profile (persisted; shown on idle and done).
  final CalibrationProfile? profile;

  /// User-facing gating message (e.g. no participant id set).
  final String? error;

  VocabEntry? get currentPrompt =>
      promptIndex < prompts.length ? prompts[promptIndex] : null;

  CalibrationState copyWith({
    CalibrationPhase? phase,
    List<VocabEntry>? prompts,
    int? promptIndex,
    int? repsDone,
    int? repsPerPrompt,
    int? lastSampleConfidence,
    CalibrationProfile? profile,
    String? error,
  }) =>
      CalibrationState(
        phase: phase ?? this.phase,
        prompts: prompts ?? this.prompts,
        promptIndex: promptIndex ?? this.promptIndex,
        repsDone: repsDone ?? this.repsDone,
        repsPerPrompt: repsPerPrompt ?? this.repsPerPrompt,
        lastSampleConfidence: lastSampleConfidence,
        profile: profile ?? this.profile,
        error: error,
      );
}

/// Captures reps while the glove is in calibrating mode and turns them into
/// a [CalibrationProfile] (FR-8).
///
/// Shell contract (revisit with the firmware team): any gesture packet
/// reported during a prompt counts as one rep of the prompted sign. The
/// real ESP32-S3 may emit calibration-specific sample packets instead.
class CalibrationController extends Notifier<CalibrationState> {
  CalibrationController({this.repsPerPrompt = 3});

  /// Injectable for tests; production uses the default.
  final int repsPerPrompt;

  StreamSubscription<GestureResultPacket>? _gestureSub;

  /// wordId → confidences captured during the current run.
  final Map<int, List<int>> _samples = {};

  @override
  CalibrationState build() {
    _load();
    final connection = ref.read(gloveConnectionProvider);
    _gestureSub = connection.gestureResults.listen(_onSample);
    ref.onDispose(() => _gestureSub?.cancel());
    return CalibrationState(repsPerPrompt: repsPerPrompt);
  }

  Future<void> _load() async {
    final profile = await ref.read(calibrationProfileStoreProvider).load();
    if (profile != null) {
      state = state.copyWith(profile: profile);
    }
  }

  /// Begins the guided flow. Requires an anonymized participant id (FR-13):
  /// the profile is per-user by definition.
  Future<void> start() async {
    final participantId =
        await ref.read(settingsServiceProvider).participantId();
    if (participantId.trim().isEmpty) {
      state = state.copyWith(error: AppStrings.calibrationNeedsParticipant);
      return;
    }
    _samples.clear();
    await ref
        .read(gloveConnectionProvider)
        .sendCommand(AppCommand.calibrate);
    state = state.copyWith(
      phase: CalibrationPhase.prompting,
      prompts: ref.read(vocabularyRepositoryProvider).letters,
      promptIndex: 0,
      repsDone: 0,
      lastSampleConfidence: null,
      error: null,
    );
  }

  void _onSample(GestureResultPacket packet) {
    if (state.phase != CalibrationPhase.prompting) return;
    final prompt = state.currentPrompt;
    if (prompt == null) return;

    _samples.putIfAbsent(prompt.wordId, () => []).add(packet.confidence);
    final nextRep = state.repsDone + 1;
    if (nextRep >= state.repsPerPrompt) {
      final nextIndex = state.promptIndex + 1;
      if (nextIndex >= state.prompts.length) {
        unawaited(_finish(packet.confidence));
      } else {
        state = state.copyWith(
          promptIndex: nextIndex,
          repsDone: 0,
          lastSampleConfidence: packet.confidence,
        );
      }
    } else {
      state = state.copyWith(
        repsDone: nextRep,
        lastSampleConfidence: packet.confidence,
      );
    }
  }

  /// Computes the profile from the captured reps, stores it, and returns
  /// the glove to idle. The firmware cancel/exit path is TBD — stopStream
  /// is the closest app command today.
  Future<void> _finish(int lastConfidence) async {
    final stats = [
      for (final entry in _samples.entries)
        CalibrationWordStat(
          wordId: entry.key,
          sampleCount: entry.value.length,
          meanConfidence: entry.value.reduce((a, b) => a + b) /
              entry.value.length,
          minConfidence: entry.value.reduce(min),
          maxConfidence: entry.value.reduce(max),
        ),
    ];
    final profile = CalibrationProfile(
      participantId: await ref.read(settingsServiceProvider).participantId(),
      savedAt: DateTime.now(),
      stats: stats,
    );
    await ref.read(calibrationProfileStoreProvider).save(profile);
    await ref
        .read(gloveConnectionProvider)
        .sendCommand(AppCommand.stopStream);
    state = state.copyWith(
      phase: CalibrationPhase.done,
      lastSampleConfidence: lastConfidence,
      profile: profile,
    );
  }

  /// Stops mid-run; nothing is saved (the saved profile, if any, stays).
  Future<void> abort() async {
    _samples.clear();
    await ref
        .read(gloveConnectionProvider)
        .sendCommand(AppCommand.stopStream);
    state = state.copyWith(
      phase: CalibrationPhase.idle,
      promptIndex: 0,
      repsDone: 0,
      lastSampleConfidence: null,
    );
  }

  /// Back to the idle summary after reviewing the done screen.
  void resetToIdle() => state = state.copyWith(
        phase: CalibrationPhase.idle,
        promptIndex: 0,
        repsDone: 0,
        lastSampleConfidence: null,
        error: null,
      );
}
