import '../../domain/models/cal_info_packet.dart';
import '../../domain/models/device_status.dart';
import '../../domain/models/gesture_result.dart';
import '../../domain/models/telemetry_packet.dart';
import 'ble_diagnostics.dart';

/// Connection lifecycle, as shown in the device status bar (FR-12).
enum GloveConnectionPhase {
  disconnected,
  scanning,
  connecting,
  discoveringServices,
  ready,
  reconnecting,
}

/// App-to-glove commands — the firmware COMMAND characteristic opcodes
/// (Code Reference §5.4): u8 opcode + optional little-endian payload.
enum AppCommand {
  startCalibration(0x01),
  captureFlat(0x02),
  capture90(0x03),
  cancelCalibration(0x04),
  setRate(0x05, payloadBytes: 2), // u16 LE ms (firmware clamps 20–1000)
  zeroYaw(0x06),
  setHand(0x07, payloadBytes: 1), // 0 = left, 1 = right (NVS)
  vibrate(0x08, payloadBytes: 2), // u16 LE ms
  // fw 1.3.0 IMU mount calibration — each blocks the glove ~2 s (telemetry
  // pauses); the result arrives as the STATUS error byte (0 = ok).
  captureMountPose1(0x09), // back of hand up, fingers forward, still 2 s
  captureMountPose2(0x0A), // fingers straight up, still 2 s; saves mount
  calibrateGyro(0x0B); // glove at rest 2 s; re-measures gyro bias

  const AppCommand(this.code, {this.payloadBytes = 0});

  final int code;

  /// Payload width in bytes (0 = no payload).
  final int payloadBytes;

  /// Serializes opcode + little-endian payload for one WRITE.
  /// [value] must fit in [payloadBytes]; zero for payload-less commands.
  List<int> encode({int value = 0}) {
    if (payloadBytes == 0) return [code];
    if (value < 0 || value >= (1 << (payloadBytes * 8))) {
      throw RangeError.range(value, 0, (1 << (payloadBytes * 8)) - 1,
          'value', 'does not fit in $payloadBytes bytes');
    }
    return [code, for (var i = 0; i < payloadBytes; i++) (value >> (8 * i)) & 0xFF];
  }
}

/// The GATT contract in Dart — everything the app knows how to say to the
/// glove (firmware contract, Code Reference §5).
///
/// Two implementations: [FlutterBlueGloveConnection] (real BLE, Android/iOS)
/// and [MockGloveConnection] (simulated glove for development, demos, and
/// tests). The glove is stateless (C-F7): any reconnect resumes cleanly.
abstract interface class GloveConnection {
  /// Decoded gesture result packets — the production label-packet stream.
  ///
  /// The as-built firmware does not emit label packets yet (it streams raw
  /// telemetry and the dashboard classifies client-side), so only the mock
  /// drives this stream today; the codec and contract (SRS Table III-2) are
  /// in place for the on-glove TFLM stage.
  Stream<GestureResultPacket> get gestureResults;

  /// Decoded 29-byte sensor frames (NOTIFY on the Telemetry characteristic).
  Stream<TelemetryPacket> get telemetry;

  /// Battery/mode/calibration-step/error updates (READ + NOTIFY on the
  /// Device Status characteristic).
  Stream<DeviceStatusPacket> get deviceStatus;

  /// Full calibration profile table, pushed after each calibration save and
  /// read once on connect (READ + NOTIFY on the CAL_INFO characteristic).
  Stream<CalInfoPacket> get calInfo;

  /// Drives the status bar and the auto-reconnect state machine.
  Stream<GloveConnectionPhase> get phaseChanges;

  /// Live link diagnostics for the Developer panel (fix B1).
  BleDiagnostics get diagnostics;

  /// Scan (by device name prefix + service) → connect → discover →
  /// subscribe.
  Future<void> connect();

  /// Re-entry into [connect]; identical path because the glove keeps no
  /// session state (C-F7).
  Future<void> reconnect();

  /// WRITE one command (opcode + optional payload) to the Command
  /// characteristic.
  Future<void> sendCommand(AppCommand command, {int value = 0});

  /// READs the Device Status characteristic once and pushes the result into
  /// [deviceStatus] — a fallback for when its NOTIFYs are not arriving.
  Future<void> refreshStatus();

  /// Deliberate teardown — must NOT trigger auto-reconnect.
  Future<void> disconnect();

  void dispose();
}
