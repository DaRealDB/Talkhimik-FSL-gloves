import 'dart:async';
import 'dart:math' as math;

import '../../core/constants/gatt_ids.dart';
import '../../domain/models/cal_info_packet.dart';
import '../../domain/models/device_status.dart';
import '../../domain/models/gesture_result.dart';
import '../../domain/models/telemetry_packet.dart';
import 'ble_diagnostics.dart';
import 'glove_connection.dart';

/// Demo/test scenarios the mock can run (dev-only; FR debug aid).
/// Trimmed to the minimum that demonstrates the product (simplify pass):
/// the transcript/TTS path and the reconnect core.
enum MockScenario {
  alphabetSweep('Alphabet sweep'),
  mixedConfidence('Mixed confidence'),
  randomDisconnect('Random disconnect');

  const MockScenario(this.label);
  final String label;
}

/// Timing knobs for [MockGloveConnection]; tests pass zero-length durations
/// so nothing depends on wall-clock time.
class MockGloveConfig {
  const MockGloveConfig({
    this.gestureCadence = const Duration(milliseconds: 900),
    this.connectStepDelay = const Duration(milliseconds: 250),
    this.disconnectAfter = const Duration(seconds: 20),
    this.reconnectDelay = const Duration(seconds: 5),
    this.batteryStartPercent = 100,
    this.telemetryEnabled = true,
    this.telemetryRate = const Duration(milliseconds: 50),
    this.lossBurstEvery = const Duration(seconds: 7),
  });

  final Duration gestureCadence;
  final Duration connectStepDelay;
  final Duration disconnectAfter;
  final Duration reconnectDelay;
  final int batteryStartPercent;

  /// Whether the mock streams telemetry after connect (master Phase 6);
  /// widget tests disable it to keep their timers deterministic.
  final bool telemetryEnabled;

  /// Telemetry notify period (mirrors the firmware's 50 ms).
  final Duration telemetryRate;

  /// A seq-gap burst (~5 lost frames) every 7 s, like the dashboard's demo.
  final Duration lossBurstEvery;
}

/// Simulated glove — the development/demo/testing harness that stands in
/// for the ESP32-S3 until (and after) hardware exists. First-class, not
/// throwaway: the mock is how the panel demo runs and how widget tests
/// exercise every FR without a real device.
///
/// The mock models BOTH gloves: label packets over [gestureResults] (the
/// production stage; the transcript is bound to it) and, when
/// [MockGloveConfig.telemetryEnabled], the firmware contract — 29-byte
/// telemetry with moving fingers/IMU, STATUS-driven calibration wizard
/// (steps 1→10, forced errors 3/4, incrementing calibration_id), CAL_INFO
/// notifies, and a periodic loss burst (master Phase 6).
class MockGloveConnection implements GloveConnection {
  MockGloveConnection({
    MockGloveConfig config = const MockGloveConfig(),
    DateTime Function()? clock,
    this.hand = GloveHand.left,
  })  : _config = config,
        _clock = clock ?? DateTime.now,
        _battery = config.batteryStartPercent;

  final MockGloveConfig _config;
  final DateTime Function() _clock;

  /// Which glove this mock simulates (master §7.3); the telemetry `hand`
  /// byte carries it.
  final GloveHand hand;

  /// Link diagnostics (fix B1): the mock fills plausible values so the
  /// Developer panel demos everywhere.
  @override
  final BleDiagnostics diagnostics = BleDiagnostics();

  final _gestures = StreamController<GestureResultPacket>.broadcast();
  final _telemetry = StreamController<TelemetryPacket>.broadcast();
  final _status = StreamController<DeviceStatusPacket>.broadcast();
  final _calInfo = StreamController<CalInfoPacket>.broadcast();
  final _phases = StreamController<GloveConnectionPhase>.broadcast();

  /// Every command the app sent, in order (assertion aid for tests/demos).
  final List<AppCommand> commandLog = [];

  GloveConnectionPhase _phase = GloveConnectionPhase.disconnected;
  GloveMode _mode = GloveMode.streaming;
  final int _battery;
  int? _lastError;

  Timer? _scenarioTimer;
  Timer? _disconnectTimer;
  Timer? _reconnectTimer;
  Timer? _telemetryTimer;
  Timer? _lossBurstTimer;
  MockScenario? _activeScenario;
  List<int> _script = const [];
  int _scriptIndex = 0;
  int _confidencePatternIndex = 0;

  // Firmware-contract emulation (master Phase 6).
  int _seq = 0;
  double _animTime = 0;
  int _calId = 0;
  int _calStep = 0;
  bool _calibrating = false;
  int? _forcedCalError;
  // fw 1.3.0 IMU mount emulation (0 = firmware default mount in use).
  int _mountId = 0;
  bool _havePose1 = false;
  int? _forcedImuError;

  /// Set by [dispose]; in-flight connect() delays and the telemetry engine
  /// check it so a swapped-out mock never restarts timers (bugfix).
  bool _disposed = false;

  /// Seeded for deterministic tests; the interactive demo doesn't care.
  final math.Random _random = math.Random(42);

  @override
  Stream<GestureResultPacket> get gestureResults => _gestures.stream;

  @override
  Stream<TelemetryPacket> get telemetry => _telemetry.stream;

  @override
  Stream<DeviceStatusPacket> get deviceStatus => _status.stream;

  @override
  Stream<CalInfoPacket> get calInfo => _calInfo.stream;

  @override
  Stream<GloveConnectionPhase> get phaseChanges => _phases.stream;

  /// The battery value the scenario has drained to; used by tests.
  int get batteryPercent => _battery;

  MockScenario? get activeScenario => _activeScenario;

  @override
  Future<void> connect() async {
    _stopReconnectTimer();
    _setPhase(GloveConnectionPhase.scanning);
    await Future<void>.delayed(_config.connectStepDelay);
    if (_disposed) return;
    _setPhase(GloveConnectionPhase.connecting);
    await Future<void>.delayed(_config.connectStepDelay);
    if (_disposed) return;
    _setPhase(GloveConnectionPhase.ready);
    diagnostics.mtu = 247;
    diagnostics.bondState = 'none';
    diagnostics.notifyResults[GattIds.telemetry] = 'ok';
    diagnostics.notifyResults[GattIds.deviceStatus] = 'ok';
    diagnostics.notifyResults[GattIds.calInfo] = 'ok';
    _emitStatus();
    _emitCalInfo();
    if (_config.telemetryEnabled) _startTelemetry();
  }

  /// Stateless glove: the exact same path as [connect] (C-F7).
  @override
  Future<void> reconnect() => connect();

  /// Makes the NEXT capture fail with firmware error 3 (span reject, stays
  /// on the step) or 4 (resistance fault, advances) — master §4.3 tests.
  void forceCalibrationError(int code) => _forcedCalError = code;

  /// Makes the NEXT mount/gyro command fail with firmware error [code]
  /// (5–10, config.h StatusError).
  void forceImuError(int code) => _forcedImuError = code;

  /// The mock's current mount_calibration_id (assertion aid).
  int get mountCalibrationId => _mountId;

  /// The mock's current calibration id (assertion aid).
  int get calibrationId => _calId;

  @override
  Future<void> sendCommand(AppCommand command, {int value = 0}) async {
    commandLog.add(command);
    switch (command) {
      case AppCommand.startCalibration:
        _calibrating = true;
        _calStep = 1;
        _mode = GloveMode.calibrating;
      case AppCommand.captureFlat:
        if (_calibrating) _capture(isFlat: true);
      case AppCommand.capture90:
        if (_calibrating) _capture(isFlat: false);
      case AppCommand.cancelCalibration:
        _calibrating = false;
        _calStep = 0;
        _mode = GloveMode.streaming;
      case AppCommand.setRate:
      case AppCommand.zeroYaw:
      case AppCommand.setHand:
      case AppCommand.vibrate:
        break;
      case AppCommand.captureMountPose1:
        _lastError = _takeImuError();
        _havePose1 = _lastError == null;
      case AppCommand.captureMountPose2:
        _lastError = _havePose1 ? _takeImuError() : 8; // ERR_MOUNT_SEQUENCE
        if (_lastError == null) {
          _mountId = _random.nextInt(0x7FFFFFFF) + 1; // random non-zero
          _havePose1 = false;
        }
      case AppCommand.calibrateGyro:
        _lastError = _takeImuError();
    }
    _emitStatus();
  }

  // shortcut: captures are instant, the real glove blocks ~2 s.
  int? _takeImuError() {
    final e = _forcedImuError;
    _forcedImuError = null;
    return e;
  }

  /// One wizard capture (master §4.2): a forced error fires once, then the
  /// step advances; after step 10 the profile is saved with a bumped
  /// calibration_id and CAL_INFO is pushed.
  void _capture({required bool isFlat}) {
    final forced = _forcedCalError;
    if (forced != null) {
      _forcedCalError = null;
      _lastError = forced;
      if (forced == 4) {
        _calStep++; // resistance fault: firmware marks + advances
        if (_calStep > 10) _completeCalibration();
      }
      return;
    }
    _lastError = null;
    _calStep++;
    if (_calStep > 10) _completeCalibration();
  }

  void _completeCalibration() {
    _calibrating = false;
    _calStep = 0;
    _mode = GloveMode.streaming;
    _calId++;
    _emitCalInfo();
  }

  /// CAL_INFO mirror of the mock's (simulated) NVS profile.
  void _emitCalInfo() {
    _calInfo.add(CalInfoPacket(
      validMask: 0x1F,
      weakMask: 0,
      calibrationId: _calId,
      flatOhm: const [30000, 30000, 30000, 30000, 30000],
      bent90Ohm: const [60000, 60000, 60000, 60000, 60000],
      flatAdc: const [500, 500, 500, 500, 500],
      bent90Adc: const [1500, 1500, 1500, 1500, 1500],
      rDiv: const [10000, 10000, 10000, 10000, 10000],
      spanCounts: const [1000, 1000, 1000, 1000, 1000],
      firmwareVersion: '1.3.0',
    ));
  }

  void _startTelemetry() {
    if (_disposed) return;
    _telemetryTimer?.cancel();
    _telemetryTimer =
        Timer.periodic(_config.telemetryRate, (_) => _emitTelemetry());
    if (_config.lossBurstEvery > Duration.zero) {
      _lossBurstTimer?.cancel();
      _lossBurstTimer = Timer.periodic(_config.lossBurstEvery,
          (_) => _seq += 6); // ~5 lost frames, like the dashboard demo
    }
  }

  /// One 29-byte-equivalent telemetry frame with animated fingers/IMU.
  void _emitTelemetry() {
    _seq++;
    _animTime += _config.telemetryRate.inMilliseconds / 1000.0;
    diagnostics.notifyCounts[GattIds.telemetry] =
        (diagnostics.notifyCounts[GattIds.telemetry] ?? 0) + 1;
    diagnostics.lastPayloadLength = 29;
    diagnostics.lastTelemetryAt = _clock();
    diagnostics.touch();
    final angles = [
      for (var i = 0; i < 5; i++)
        ((45 + 40 * math.sin(_animTime * 2 + i * 0.7)).clamp(0.0, 90.0))
            .round(),
    ];
    _telemetry.add(TelemetryPacket(
      hand: hand,
      seq: _seq,
      angles: angles,
      rollDeg: 15 * math.sin(_animTime * 0.8),
      pitchDeg: 10 * math.sin(_animTime * 1.1),
      yawDeg: 20 * math.sin(_animTime * 0.5),
      rawAdc: [100, 200, 300, 400, 500],
      calibrationId: _calId,
      quality: 0x1F,
      receivedAt: _clock(),
    ));
  }

  void _stopTelemetry() {
    _telemetryTimer?.cancel();
    _telemetryTimer = null;
    _lossBurstTimer?.cancel();
    _lossBurstTimer = null;
  }

  @override
  Future<void> disconnect() async {
    stopScenario();
    _stopTelemetry();
    _setPhase(GloveConnectionPhase.disconnected);
  }

  // ---------------------------------------------------------------- scenario

  /// Starts a scripted scenario (or stops any running one first).
  void startScenario(MockScenario scenario) {
    stopScenario();
    _activeScenario = scenario;
    switch (scenario) {
      case MockScenario.alphabetSweep:
        _script = [for (var i = 1; i <= 28; i++) i];
        _scriptIndex = 0;
        _scenarioTimer = Timer.periodic(_config.gestureCadence, (_) {
          if (_scriptIndex >= _script.length) {
            stopScenario();
            return;
          }
          emitGesture(
            wordId: _script[_scriptIndex++],
            confidence: 92 + _random.nextInt(8),
          );
        });
      case MockScenario.mixedConfidence:
        // Cycle green (~90) / amber (~70) / red (~50); amber and red carry
        // top-3 alternatives so the FR-5 flow is demoable on demand.
        const pattern = [
          (1, 90, false),
          (2, 70, true),
          (3, 50, true),
        ];
        _scenarioTimer = Timer.periodic(_config.gestureCadence, (_) {
          final (wordId, conf, withAlts) =
              pattern[_confidencePatternIndex++ % pattern.length];
          emitGesture(
            wordId: wordId,
            confidence: conf,
            alternatives: withAlts
                ? [
                    for (var i = 1; i <= 3; i++)
                      AlternativePrediction(
                        wordId: wordId + i,
                        confidence: 68 - (i - 1) * 13,
                      ),
                  ]
                : const [],
          );
        });
      case MockScenario.randomDisconnect:
        _disconnectTimer = Timer(_config.disconnectAfter, () {
          disconnect();
          _reconnectTimer = Timer(_config.reconnectDelay, () {
            // Only rejoin if the app hasn't already reconnected us.
            if (_phase == GloveConnectionPhase.disconnected) {
              reconnect();
            }
          });
        });
    }
  }

  /// Stops any running scenario; leaves the link alone.
  void stopScenario() {
    _scenarioTimer?.cancel();
    _scenarioTimer = null;
    _disconnectTimer?.cancel();
    _disconnectTimer = null;
    _activeScenario = null;
  }

  /// Emits one decoded gesture packet (manual demo path + scenario engine).
  /// The glove timestamp is backdated 25–105 ms so latency logs look
  /// realistic on the export screen.
  void emitGesture({
    required int wordId,
    required int confidence,
    List<AlternativePrediction> alternatives = const [],
  }) {
    final now = _clock();
    final gloveTimestampMs =
        now.millisecondsSinceEpoch - (25 + _random.nextInt(81));
    _gestures.add(GestureResultPacket(
      wordId: wordId,
      confidence: confidence.clamp(0, 100),
      gloveTimestampMs: gloveTimestampMs,
      receivedAt: now,
      alternatives: alternatives,
    ));
  }

  // ------------------------------------------------------------------ internals

  void _setPhase(GloveConnectionPhase phase) {
    _phase = phase;
    _phases.add(phase);
  }

  void _emitStatus() {
    _status.add(DeviceStatusPacket(
      batteryPercent: _battery,
      mode: _mode,
      calibrationStep: _calStep,
      linkUp: _phase == GloveConnectionPhase.ready,
      lastErrorCode: _lastError,
      mountUncalibrated: _mountId == 0,
      mountCalibrationId: _mountId,
    ));
  }

  void _stopReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  @override
  void dispose() {
    _disposed = true;
    stopScenario();
    _stopReconnectTimer();
    _stopTelemetry();
    _gestures.close();
    _telemetry.close();
    _status.close();
    _calInfo.close();
    _phases.close();
  }
}
