import 'dart:async';
import 'dart:math';

import '../../domain/models/cal_info_packet.dart';
import '../../domain/models/device_status.dart';
import '../../domain/models/gesture_result.dart';
import '../../domain/models/telemetry_packet.dart';
import 'glove_connection.dart';

/// Demo/test scenarios the mock can run (dev-only; FR debug aid).
enum MockScenario {
  alphabetSweep('Alphabet sweep'),
  mixedConfidence('Mixed confidence'),
  lowBattery('Low battery'),
  sensorFault('Sensor fault'),
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
  });

  final Duration gestureCadence;
  final Duration connectStepDelay;
  final Duration disconnectAfter;
  final Duration reconnectDelay;
  final int batteryStartPercent;
}

/// Simulated glove — the development/demo/testing harness that stands in
/// for the ESP32-S3 until (and after) hardware exists. First-class, not
/// throwaway: the mock is how the panel demo runs and how widget tests
/// exercise every FR without a real device.
///
/// The mock models the PRODUCTION glove (label packets over [gestureResults])
/// rather than the telemetry-stage firmware, so the transcript pipeline is
/// fully exercisable; its [deviceStatus] follows the firmware STATUS layout.
class MockGloveConnection implements GloveConnection {
  MockGloveConnection({
    MockGloveConfig config = const MockGloveConfig(),
    DateTime Function()? clock,
  })  : _config = config,
        _clock = clock ?? DateTime.now,
        _battery = config.batteryStartPercent;

  final MockGloveConfig _config;
  final DateTime Function() _clock;

  final _gestures = StreamController<GestureResultPacket>.broadcast();
  final _telemetry = StreamController<TelemetryPacket>.broadcast();
  final _status = StreamController<DeviceStatusPacket>.broadcast();
  final _calInfo = StreamController<CalInfoPacket>.broadcast();
  final _phases = StreamController<GloveConnectionPhase>.broadcast();

  /// Every command the app sent, in order (assertion aid for tests/demos).
  final List<AppCommand> commandLog = [];

  GloveConnectionPhase _phase = GloveConnectionPhase.disconnected;
  GloveMode _mode = GloveMode.streaming;
  int _battery;
  int? _lastError;

  Timer? _scenarioTimer;
  Timer? _disconnectTimer;
  Timer? _reconnectTimer;
  MockScenario? _activeScenario;
  List<int> _script = const [];
  int _scriptIndex = 0;
  int _confidencePatternIndex = 0;

  /// Seeded for deterministic tests; the interactive demo doesn't care.
  final Random _random = Random(42);

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
    _setPhase(GloveConnectionPhase.connecting);
    await Future<void>.delayed(_config.connectStepDelay);
    _setPhase(GloveConnectionPhase.ready);
    _emitStatus();
  }

  /// Stateless glove: the exact same path as [connect] (C-F7).
  @override
  Future<void> reconnect() => connect();

  @override
  Future<void> sendCommand(AppCommand command, {int value = 0}) async {
    commandLog.add(command);
    switch (command) {
      case AppCommand.startCalibration:
      case AppCommand.captureFlat:
      case AppCommand.capture90:
        _mode = GloveMode.calibrating;
      case AppCommand.cancelCalibration:
        _mode = GloveMode.streaming;
      case AppCommand.setRate:
      case AppCommand.zeroYaw:
      case AppCommand.setHand:
      case AppCommand.vibrate:
        break;
    }
    _emitStatus();
  }

  @override
  Future<void> disconnect() async {
    stopScenario();
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
      case MockScenario.lowBattery:
        // Drain 100 → 12 % over ~60 s, one Device Status notify per second.
        // The UI flags < 15 % from the percentage itself (the firmware has
        // no low-battery error code).
        _battery = _config.batteryStartPercent;
        _scenarioTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          _battery = max(12, _battery - 2);
          _emitStatus();
          if (_battery <= 12) stopScenario();
        });
      case MockScenario.sensorFault:
        // Firmware error 4: resistance outside 1k..100k (finger fault).
        _lastError = GloveErrorCode.resistanceFault.code;
        _emitStatus();
        stopScenario();
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
      linkUp: _phase == GloveConnectionPhase.ready,
      lastErrorCode: _lastError,
    ));
  }

  void _stopReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  @override
  void dispose() {
    stopScenario();
    _stopReconnectTimer();
    _gestures.close();
    _telemetry.close();
    _status.close();
    _calInfo.close();
    _phases.close();
  }
}
