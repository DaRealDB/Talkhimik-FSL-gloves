import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/strings/app_strings.dart';
import '../domain/models/cal_info_packet.dart';
import '../domain/models/calibration_table.dart';
import '../domain/models/dataset_row.dart';
import '../domain/models/dataset_session.dart';
import '../domain/models/telemetry_packet.dart';
import '../domain/sensing/sensor_math.dart';
import 'providers.dart';

enum RecordingPhase { idle, recording }

/// The dataset recorder engine (master §5): 5 Hz sampling per connected
/// glove from the latest telemetry frame, one session per
/// (hand, calibration_id), drops counted — never silently kept.
class RecorderState {
  const RecorderState({
    this.phase = RecordingPhase.idle,
    this.active = const {},
    this.sessions = const [],
    this.takeActive = false,
    this.label = '',
    this.error,
    this.undoLabel = '',
    this.revision = 0,
  });

  final RecordingPhase phase;

  /// Live sessions, one per recording hand.
  final Map<GloveHand, DatasetSession> active;

  /// Finished sessions on disk, newest first.
  final List<DatasetSessionSummary> sessions;

  /// Rows are only written while a labeled take is running.
  final bool takeActive;

  /// Label of the current/next take (picker or free text).
  final String label;

  /// User-facing gating message.
  final String? error;

  /// Label of the last finished take that
  /// [DatasetRecorderController.undoLastTake] can remove; '' when none.
  final String undoLabel;

  /// Bumped whenever rows are removed from disk (coverage rebuild cue).
  final int revision;

  RecorderState copyWith({
    RecordingPhase? phase,
    Map<GloveHand, DatasetSession>? active,
    List<DatasetSessionSummary>? sessions,
    bool? takeActive,
    String? label,
    String? error,
    String? undoLabel,
    int? revision,
  }) =>
      RecorderState(
        phase: phase ?? this.phase,
        active: active ?? this.active,
        sessions: sessions ?? this.sessions,
        takeActive: takeActive ?? this.takeActive,
        label: label ?? this.label,
        error: error,
        undoLabel: undoLabel ?? this.undoLabel,
        revision: revision ?? this.revision,
      );
}

class DatasetRecorderController extends Notifier<RecorderState> {
  /// Injectable for tests; production samples at 200 ms (5 Hz, master §5.1).
  DatasetRecorderController(
      [this.sampleInterval = const Duration(milliseconds: 200)]);

  final Duration sampleInterval;

  final List<StreamSubscription<Object?>> _subs = [];
  final Map<GloveHand, TelemetryPacket> _latest = {};
  final Map<GloveHand, int?> _lastSampledSeq = {};
  final Random _random = Random();
  Timer? _sampler;

  /// Current take counter + label — owned here, not per session, because a
  /// take can start before the first frame opens the session.
  int _takeId = 0;
  String _takeLabel = '';

  /// Sessions that received rows in the current/last take — what undo
  /// rewrites (a take can span a calibration change → several sessions).
  final Map<String, DatasetSession> _takeSessions = {};
  int? _undoTakeId;

  @override
  RecorderState build() {
    // watch, not read: a Force-mock toggle swaps the connections and the
    // recorder must rebind to the new instances.
    _subs.add(ref
        .watch(gloveConnectionProvider)
        .telemetry
        .listen((t) => _latest[GloveHand.left] = t));
    _subs.add(ref
        .watch(rightGloveConnectionProvider)
        .telemetry
        .listen((t) => _latest[GloveHand.right] = t));
    ref.onDispose(() {
      for (final s in _subs) {
        unawaited(s.cancel());
      }
      _sampler?.cancel();
    });
    _loadSessions();
    return const RecorderState();
  }

  Future<void> _loadSessions() async {
    try {
      final sessions = await ref.read(datasetWriterProvider).listSessions();
      if (!ref.mounted) return;
      state = state.copyWith(sessions: sessions);
    } catch (_) {
      // Directory unavailable (web, or a teardown race in tests): the
      // list stays empty — never take the recorder down with it.
    }
  }

  /// Consent (NFR-8) and the anonymized participant id (FR-13) gate the
  /// recording; a connected uncalibrated glove (cal_id 0) blocks it
  /// (master §5.1).
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
    final live = ref.read(liveControllerProvider);
    for (final hand in const [GloveHand.left, GloveHand.right]) {
      final id = live.forHand(hand).calInfo?.calibrationId ?? 0;
      final connected = live.forHand(hand).telemetry != null;
      if (connected && id == 0) {
        state = state.copyWith(error: AppStrings.recordNeedsCalibration);
        return;
      }
    }
    state = state.copyWith(phase: RecordingPhase.recording, error: null);
    _sampler?.cancel();
    _sampler = Timer.periodic(sampleInterval, (_) => unawaited(sampleNow()));
  }

  /// One sampling tick: the latest frame of each hand flows through the
  /// drop rules and, while a take is active, into the session's CSV.
  @visibleForTesting
  Future<void> sampleNow() async {
    if (state.phase != RecordingPhase.recording) return;
    for (final hand in const [GloveHand.left, GloveHand.right]) {
      final frame = _latest[hand];
      if (frame == null) continue;
      await _sampleHand(hand, frame);
    }
  }

  Future<void> _sampleHand(GloveHand hand, TelemetryPacket frame) async {
    // Never record uncalibrated (cal_id 0, master §5.1).
    if (frame.calibrationId == 0) return;

    final session = state.active[hand] ??
        await _openSession(hand, frame.calibrationId);
    // A flex or IMU-mount calibration change closes the session and opens
    // a new file — files never mix calibrations.
    if (session.calibrationId != frame.calibrationId ||
        session.mountCalibrationId != _mountIdFor(hand)) {
      await _closeActive(hand);
      await _sampleHand(hand, frame);
      return;
    }

    // Wrap-safe seq gap vs the last SAMPLED frame; gap > 3 → drop.
    final lastSeq = _lastSampledSeq[hand];
    if (lastSeq != null && seqGap(lastSeq, frame.seq) > 3) {
      session.seqGapDrops++;
      session.droppedFrames++;
      _lastSampledSeq[hand] = frame.seq;
      return;
    }
    _lastSampledSeq[hand] = frame.seq;

    // ADC rail (raw 0 or 4095) on any VALID finger → drop.
    for (var i = 0; i < 5; i++) {
      final valid = session.validMask & (1 << i) != 0;
      final raw = frame.rawAdc[i];
      if (valid && (raw == 0 || raw == 4095)) {
        session.adcRail++;
        session.droppedFrames++;
        return;
      }
    }

    // Rows only flow while a labeled take is running (§5.1).
    if (!state.takeActive) return;

    final table = CalibrationTable(_calInfoFor(hand, session));
    final ohms = [
      for (var i = 0; i < 5; i++)
        adcToOhms(table.finger(i).rDiv, frame.rawAdc[i]),
    ];
    final angles = [
      for (var i = 0; i < 5; i++)
        ohmsToAngle(ohms[i], table.finger(i).flatOhm, table.finger(i).bent90Ohm),
    ];
    final row = DatasetRow(
      timestampMs: frame.receivedAt.millisecondsSinceEpoch,
      label: session.label,
      takeId: session.takeId,
      rawAdc: frame.rawAdc,
      ohms: ohms,
      angles: angles,
      rollDeg: frame.rollDeg,
      pitchDeg: frame.pitchDeg,
      yawDeg: frame.yawDeg,
      qualityFlag: frame.quality,
    );
    session.rows++;
    _takeSessions[session.sessionId] = session;
    await ref.read(datasetWriterProvider).appendRow(session, row);
    state = state.copyWith(active: {...state.active, hand: session});
  }

  Future<DatasetSession> _openSession(GloveHand hand, int calibrationId) async {
    final settings = ref.read(settingsServiceProvider);
    final participantId = (await settings.participantId()).trim();
    final signerId = participantId.isEmpty
        ? 'anon-${_random.nextInt(9000) + 1000}'
        : participantId;
    final live = ref.read(liveControllerProvider).forHand(hand);
    final calInfo = live.calInfo ?? _calInfoFor(hand, null);
    final table = CalibrationTable(calInfo);
    final session = DatasetSession(
      sessionId: 'S-${DateTime.now().millisecondsSinceEpoch}',
      signerId: signerId,
      hand: hand,
      calibrationId: calibrationId,
      firmwareVersion: calInfo.firmwareVersion,
      validMask: calInfo.validMask,
      rDiv: calInfo.rDiv,
      fingers: [
        for (final f in table.fingers)
          FingerInfo(
            name: f.name,
            valid: f.valid,
            weak: f.weak,
            flatOhm: f.flatOhm,
            bent90Ohm: f.bent90Ohm,
            flatAdc: f.flatAdc,
            bent90Adc: f.bent90Adc,
            spanCounts: f.spanCounts,
          ),
      ],
      startedAt: DateTime.now(),
      mountCalibrationId: _mountIdFor(hand),
    )
      // Seed the in-flight take (a take can precede the first frame).
      ..takeId = _takeId
      ..label = _takeLabel;
    await ref.read(datasetWriterProvider).openSession(session);
    state = state.copyWith(active: {...state.active, hand: session});
    return session;
  }

  int? _mountIdFor(GloveHand hand) => ref
      .read(liveControllerProvider)
      .forHand(hand)
      .status
      ?.mountCalibrationId;

  /// Fallback CAL_INFO when the live mirror is empty (should not happen
  /// for a calibrated glove): a benign all-valid, 10 kΩ profile.
  CalInfoPacket _calInfoFor(GloveHand hand, DatasetSession? session) {
    final live = ref.read(liveControllerProvider).forHand(hand).calInfo;
    if (live != null) return live;
    return CalInfoPacket(
      validMask: session?.validMask ?? 0x1F,
      weakMask: 0,
      calibrationId: session?.calibrationId ?? 0,
      flatOhm: const [30000, 30000, 30000, 30000, 30000],
      bent90Ohm: const [60000, 60000, 60000, 60000, 60000],
      flatAdc: const [0, 0, 0, 0, 0],
      bent90Adc: const [0, 0, 0, 0, 0],
      rDiv: const [10000, 10000, 10000, 10000, 10000],
      spanCounts: const [0, 0, 0, 0, 0],
      firmwareVersion: '1.2.0',
    );
  }

  /// Starts a labeled take (each Start press increments take_id; a new
  /// session restarts at 1 — master §5.1). Empty label → blocked. Sessions
  /// opened after this point are seeded with the current take.
  Future<void> startTake(String label) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(error: AppStrings.recordNeedsLabel);
      return;
    }
    _takeId++;
    _takeLabel = trimmed;
    _takeSessions.clear();
    _undoTakeId = null;
    final active = {...state.active};
    for (final session in active.values) {
      session.takeId = _takeId;
      session.label = trimmed;
    }
    state = state.copyWith(
        active: active,
        takeActive: true,
        label: trimmed,
        error: null,
        undoLabel: '');
  }

  /// Ends the current take; rows already written stay. The sidecar is
  /// (re)written now too, so a session is listed and shareable after every
  /// take — not only after Stop, which a killed app never reaches.
  Future<void> stopTake() async {
    if (state.takeActive && _takeSessions.isNotEmpty) _undoTakeId = _takeId;
    state = state.copyWith(
        takeActive: false,
        undoLabel: _undoTakeId == null ? '' : _takeLabel);
    for (final session in state.active.values) {
      await ref.read(datasetWriterProvider).closeSession(session);
    }
    await _loadSessions();
  }

  /// Stops recording and finalizes every active session (CSV already
  /// flushed per row; the sidecar is written here).
  Future<void> stop() async {
    _sampler?.cancel();
    _sampler = null;
    for (final hand in state.active.keys.toList()) {
      await _closeActive(hand);
    }
    state = state.copyWith(phase: RecordingPhase.idle, takeActive: false);
    await _loadSessions();
  }

  Future<void> _closeActive(GloveHand hand) async {
    final session = state.active[hand];
    if (session == null) return;
    await ref.read(datasetWriterProvider).closeSession(session);
    final active = {...state.active}..remove(hand);
    _lastSampledSeq.remove(hand);
    state = state.copyWith(active: active);
  }

  /// Deletes the last finished take's rows (a mislabeled or botched take)
  /// from every session it wrote to, then rewrites their sidecars. One
  /// level: the take before it stays.
  Future<void> undoLastTake() async {
    final takeId = _undoTakeId;
    if (takeId == null || state.takeActive) return;
    final writer = ref.read(datasetWriterProvider);
    for (final session in _takeSessions.values) {
      session.rows -= await writer.removeTake(session, takeId);
      await writer.closeSession(session);
    }
    _takeSessions.clear();
    _undoTakeId = null;
    state = state.copyWith(undoLabel: '', revision: state.revision + 1);
    await _loadSessions();
  }

  /// Removes a finished session's files from disk.
  Future<void> deleteSession(DatasetSessionSummary summary) async {
    await ref.read(datasetWriterProvider).deleteSession(summary);
    await _loadSessions();
  }

  /// Absolute paths of a session's files, for the share sheet.
  Future<List<String>> pathsFor(DatasetSessionSummary summary) =>
      ref.read(datasetWriterProvider).pathsFor(summary);
}
