import '../../domain/models/device_status.dart';
import '../../domain/models/gesture_result.dart';

/// Connection lifecycle, as shown in the device status bar (FR-12).
enum GloveConnectionPhase {
  disconnected,
  scanning,
  connecting,
  discoveringServices,
  ready,
  reconnecting,
}

/// App-to-glove commands (SRS Table III-1, App Command characteristic).
enum AppCommand {
  stopStream(0x01),
  startStream(0x02),
  calibrate(0x03),
  sleep(0x04),
  queryStatus(0x05);

  const AppCommand(this.code);
  final int code;
}

/// The GATT contract in Dart — everything the app knows how to say to the
/// glove (SRS Section III).
///
/// Two implementations: [FlutterBlueGloveConnection] (real BLE, Android/iOS)
/// and [MockGloveConnection] (simulated glove for development, demos, and
/// tests). The glove is stateless (C-F7): any reconnect resumes cleanly.
abstract interface class GloveConnection {
  /// Decoded gesture result packets (NOTIFY on the Gesture Result char).
  Stream<GestureResultPacket> get gestureResults;

  /// Battery/mode/error updates (READ + NOTIFY on the Device Status char).
  Stream<DeviceStatusPacket> get deviceStatus;

  /// Drives the status bar and the auto-reconnect state machine.
  Stream<GloveConnectionPhase> get phaseChanges;

  /// Scan (by device name + service) → connect → discover → subscribe.
  Future<void> connect();

  /// Re-entry into [connect]; identical path because the glove keeps no
  /// session state (C-F7).
  Future<void> reconnect();

  /// WRITE one command byte to the App Command characteristic.
  Future<void> sendCommand(AppCommand command);

  /// Deliberate teardown — must NOT trigger auto-reconnect.
  Future<void> disconnect();

  void dispose();
}
