import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/constants/gatt_ids.dart';
import '../../domain/models/cal_info_packet.dart';
import '../../domain/models/device_status.dart';
import '../../domain/models/gesture_result.dart';
import '../../domain/models/telemetry_packet.dart';
import '../codec/cal_info_codec.dart';
import '../codec/device_status_codec.dart';
import '../codec/telemetry_packet_codec.dart';
import 'ble_permissions.dart';
import 'glove_connection.dart';

/// Real BLE implementation over flutter_blue_plus, speaking the as-built
/// firmware GATT contract (Code Reference §5: TELEMETRY / STATUS / CAL_INFO /
/// COMMAND on service d84f9c2e-…, device name TALKHIMIK-L/R).
///
/// Contract with the controller layer (glove_controller.dart):
///  * phases are emitted only for PROGRESS (scanning → connecting →
///    discoveringServices → ready) and for REAL link loss / deliberate
///    teardown — a failed connect/reconnect rethrows silently and the
///    controller resets the phase; this keeps the auto-reconnect state
///    machine single-threaded;
///  * the glove is stateless (C-F7): [reconnect] re-runs the full flow.
///
/// IMPORTANT: flutter_blue_plus has no Windows implementation — importing
/// it compiles everywhere, but CALLING it off-Android/iOS throws
/// MissingPluginException. The factory in glove_connection_factory.dart
/// guarantees this class is only constructed on Android/iOS.
class FlutterBlueGloveConnection implements GloveConnection {
  FlutterBlueGloveConnection({
    this.hand = GloveHand.left,
    this.permissions = const PermissionHandlerBlePermissions(),
    this.scanTimeout = const Duration(seconds: 15),
    this.connectTimeout = const Duration(seconds: 15),
  });

  /// Which glove this connection binds to; the scan matches the full
  /// advertised name TALKHIMIK-L / TALKHIMIK-R (master §7.3).
  final GloveHand hand;

  /// The advertised name this connection's scan looks for.
  static String advertisedNameFor(GloveHand hand) =>
      '${GattIds.deviceNamePrefix}-${hand == GloveHand.left ? 'L' : 'R'}';

  final BlePermissions permissions;

  /// How long the scan hunts for the glove's advertisement.
  final Duration scanTimeout;

  /// How long one connect + service discovery attempt may take.
  final Duration connectTimeout;

  // Label packets are a later firmware stage; the stream stays open so the
  // transcript pipeline is identical to the mock's.
  final _gestures = StreamController<GestureResultPacket>.broadcast();
  final _telemetry = StreamController<TelemetryPacket>.broadcast();
  final _status = StreamController<DeviceStatusPacket>.broadcast();
  final _calInfo = StreamController<CalInfoPacket>.broadcast();
  final _phases = StreamController<GloveConnectionPhase>.broadcast();

  final List<StreamSubscription<Object?>> _subs = [];
  BluetoothDevice? _device;
  BluetoothCharacteristic? _commandChar;
  bool _manualDisconnect = false;
  bool _disposed = false;

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

  @override
  Future<void> connect() async {
    _assertNotDisposed();
    final device = _device;
    if (device != null && device.isConnected) {
      _addPhase(GloveConnectionPhase.ready);
      return;
    }

    _teardownSubs();
    _manualDisconnect = false;
    try {
      // 1. Permissions first (C-S1): scanning fails cryptically without
      //    them, the classic first-demo failure point.
      await permissions.ensureGranted();

      // 2. Adapter on? (Android only; turnOn throws off-Android.)
      if (FlutterBluePlus.adapterStateNow == BluetoothAdapterState.off) {
        await FlutterBluePlus.turnOn();
      }

      // 3. Scan for this connection's glove by its full advertised name
      //    (C-F4, master §7.3: the L/R suffix decides the hand).
      //    Deliberately UNFILTERED: ColorOS and other OEM stacks
      //    throttle/drop service-UUID-filtered LE scans into zero results,
      //    and a name match in Dart is reliable everywhere. Step 5's GATT
      //    discovery still validates the service contract.
      _addPhase(GloveConnectionPhase.scanning);
      final advertisedName = advertisedNameFor(hand);
      await FlutterBluePlus.startScan(timeout: scanTimeout);
      final ScanResult result;
      try {
        result = await FlutterBluePlus.onScanResults
            .expand((results) => results)
            .firstWhere((r) => r.advertisementData.advName == advertisedName)
            .timeout(scanTimeout);
      } on TimeoutException {
        throw StateError(
            'Glove "$advertisedName" not found within '
            '${scanTimeout.inSeconds} s');
      }
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
      final target = result.device;

      // 4. Connect → discover services (C-S1). License.nonprofit: the
      //    thesis is educational use under the FlutterBluePlus License.
      _addPhase(GloveConnectionPhase.connecting);
      await target.connect(license: License.nonprofit, timeout: connectTimeout);
      _addPhase(GloveConnectionPhase.discoveringServices);
      final services = await target.discoverServices();

      // 5. Find the four characteristics (Code Reference §5.1); a missing
      //    one means the profile does not match the firmware contract.
      final telemetryChar = _findCharacteristic(services, GattIds.telemetry);
      final statusChar = _findCharacteristic(services, GattIds.deviceStatus);
      final commandChar = _findCharacteristic(services, GattIds.command);
      final calInfoChar = _findCharacteristic(services, GattIds.calInfo);
      if (telemetryChar == null ||
          statusChar == null ||
          commandChar == null ||
          calInfoChar == null) {
        throw StateError(
            'Glove GATT profile does not match the firmware contract '
            '(Code Reference §5.1)');
      }

      // 6. Link-loss detection feeds the auto-reconnect state machine
      //    (C-S5, NFR-9: the banner must appear within 3 s).
      _track(target.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected &&
            !_manualDisconnect) {
          _addPhase(GloveConnectionPhase.disconnected);
        }
      }));

      // 7. Telemetry: decode the 29-byte frames (Code Reference §5.2).
      //    Malformed packets are skipped — the link stays up.
      final telemetrySub = telemetryChar.onValueReceived.listen((bytes) {
        try {
          _telemetry.add(
              TelemetryPacketCodec.decode(Uint8List.fromList(bytes)));
        } on FormatException {
          // Skipped: not a telemetry payload.
        }
      });
      _track(telemetrySub);
      target.cancelWhenDisconnected(telemetrySub);

      // 8. Device status: READ once now, then NOTIFY keeps it fresh.
      final statusSub = statusChar.onValueReceived.listen((bytes) {
        try {
          _status.add(DeviceStatusCodec.decode(Uint8List.fromList(bytes)));
        } on FormatException {
          // Skipped: not a device status payload.
        }
      });
      _track(statusSub);
      target.cancelWhenDisconnected(statusSub);
      try {
        final initial = Uint8List.fromList(await statusChar.read());
        _status.add(DeviceStatusCodec.decode(initial));
      } on FormatException {
        // Firmware contract mismatch; the NOTIFY path still works.
      }

      // 9. CAL_INFO: READ once (validity, firmware version), NOTIFY keeps
      //    the table fresh after each calibration save.
      final calInfoSub = calInfoChar.onValueReceived.listen((bytes) {
        try {
          _calInfo.add(CalInfoCodec.decode(Uint8List.fromList(bytes)));
        } on FormatException {
          // Skipped: not a CAL_INFO table.
        }
      });
      _track(calInfoSub);
      target.cancelWhenDisconnected(calInfoSub);
      try {
        final initial = Uint8List.fromList(await calInfoChar.read());
        _calInfo.add(CalInfoCodec.decode(initial));
      } on FormatException {
        // Firmware contract mismatch; the NOTIFY path still works.
      }

      // 10. Short connection interval for snappy telemetry
      //     (per Talkhimik_BLE_Integration_Steps.md, 15–30 ms).
      try {
        await target.requestConnectionPriority(
            connectionPriorityRequest: ConnectionPriority.balanced);
      } catch (_) {
        // Optional optimization — never fatal.
      }

      _device = target;
      _commandChar = commandChar;
      _addPhase(GloveConnectionPhase.ready);
    } catch (_) {
      // Best-effort cleanup; the controller resets the phase on failure.
      await _teardownDevice();
      rethrow;
    }
  }

  /// Stateless glove (C-F7): the exact same path as [connect].
  @override
  Future<void> reconnect() => connect();

  /// WRITE one command (opcode + optional payload) to the Command
  /// characteristic (C-F5).
  @override
  Future<void> sendCommand(AppCommand command, {int value = 0}) async {
    _assertNotDisposed();
    final device = _device;
    final commandChar = _commandChar;
    if (device == null || !device.isConnected || commandChar == null) {
      throw StateError('Glove is not connected');
    }
    await commandChar.write(command.encode(value: value));
  }

  /// Deliberate teardown — must NOT trigger auto-reconnect.
  @override
  Future<void> disconnect() async {
    _manualDisconnect = true;
    await _teardownDevice();
    _addPhase(GloveConnectionPhase.disconnected);
  }

  @override
  void dispose() {
    _disposed = true;
    _teardownSubs();
    _gestures.close();
    _telemetry.close();
    _status.close();
    _calInfo.close();
    _phases.close();
  }

  // ---------------------------------------------------------------- internals

  BluetoothCharacteristic? _findCharacteristic(
      List<BluetoothService> services, String uuid) {
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        if (characteristic.uuid.str128 == uuid) return characteristic;
      }
    }
    return null;
  }

  Future<void> _teardownDevice() async {
    final device = _device;
    _device = null;
    _commandChar = null;
    _teardownSubs();
    if (device == null) return;
    try {
      await device.disconnect();
    } catch (_) {
      // Already gone — nothing to clean up.
    }
  }

  void _teardownSubs() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs.clear();
  }

  void _track(StreamSubscription<Object?> sub) => _subs.add(sub);

  void _addPhase(GloveConnectionPhase phase) {
    if (_disposed) return;
    _phases.add(phase);
  }

  void _assertNotDisposed() {
    if (_disposed) throw StateError('Connection disposed');
  }
}
