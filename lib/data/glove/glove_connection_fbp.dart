import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/constants/gatt_ids.dart';
import '../../domain/models/device_status.dart';
import '../../domain/models/gesture_result.dart';
import '../codec/device_status_codec.dart';
import '../codec/gesture_packet_codec.dart';
import 'ble_permissions.dart';
import 'glove_connection.dart';

/// Real BLE implementation over flutter_blue_plus (SRS C-S1, C-F5, C-F7).
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
    this.permissions = const PermissionHandlerBlePermissions(),
    this.scanTimeout = const Duration(seconds: 15),
    this.connectTimeout = const Duration(seconds: 15),
  });

  final BlePermissions permissions;

  /// How long the scan hunts for the glove's advertisement.
  final Duration scanTimeout;

  /// How long one connect + service discovery attempt may take.
  final Duration connectTimeout;

  final _gestures = StreamController<GestureResultPacket>.broadcast();
  final _status = StreamController<DeviceStatusPacket>.broadcast();
  final _phases = StreamController<GloveConnectionPhase>.broadcast();

  final List<StreamSubscription<Object?>> _subs = [];
  BluetoothDevice? _device;
  BluetoothCharacteristic? _commandChar;
  bool _manualDisconnect = false;
  bool _disposed = false;

  @override
  Stream<GestureResultPacket> get gestureResults => _gestures.stream;

  @override
  Stream<DeviceStatusPacket> get deviceStatus => _status.stream;

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

      // 3. Scan for the glove by advertised name + service (SRS C-F4).
      _addPhase(GloveConnectionPhase.scanning);
      await FlutterBluePlus.startScan(
        withServices: [Guid(GattIds.gloveService)],
        timeout: scanTimeout,
      );
      final result = await FlutterBluePlus.onScanResults
          .expand((results) => results)
          .firstWhere(
              (r) => r.advertisementData.advName == GattIds.deviceName)
          .timeout(
            scanTimeout,
            onTimeout: () => throw StateError(
                'Glove "${GattIds.deviceName}" not found within '
                '${scanTimeout.inSeconds} s'),
          );
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

      // 5. Find the three characteristics (Table III-1); a missing one
      //    means the profile does not match the SRS contract.
      final gestureChar =
          _findCharacteristic(services, GattIds.gestureResult);
      final statusChar =
          _findCharacteristic(services, GattIds.deviceStatus);
      final commandChar = _findCharacteristic(services, GattIds.appCommand);
      if (gestureChar == null || statusChar == null || commandChar == null) {
        throw StateError('Glove GATT profile does not match SRS Table III-1');
      }

      // 6. Subscribe to the two NOTIFY characteristics.
      await gestureChar.setNotifyValue(true);
      await statusChar.setNotifyValue(true);

      // 7. Link-loss detection feeds the auto-reconnect state machine
      //    (C-S5, NFR-9: the banner must appear within 3 s).
      _track(target.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected &&
            !_manualDisconnect) {
          _addPhase(GloveConnectionPhase.disconnected);
        }
      }));

      // 8. Gesture results: decode the 7-byte packet (Table III-2).
      //    Malformed packets are skipped — the link stays up.
      final gestureSub = gestureChar.onValueReceived.listen((bytes) {
        try {
          _gestures.add(
              GesturePacketCodec.decode(Uint8List.fromList(bytes)));
        } on FormatException {
          // Skipped: not a gesture result payload.
        }
      });
      _track(gestureSub);
      target.cancelWhenDisconnected(gestureSub);

      // 9. Device status: READ once now, then NOTIFY keeps it fresh.
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
        final initial =
            Uint8List.fromList(await statusChar.read());
        _status.add(DeviceStatusCodec.decode(initial));
      } on FormatException {
        // Firmware contract mismatch; the NOTIFY path still works.
      }

      // 10. Short connection interval for snappy gesture → speech
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

  /// WRITE one command byte to the App Command characteristic (C-F5).
  @override
  Future<void> sendCommand(AppCommand command) async {
    _assertNotDisposed();
    final device = _device;
    final commandChar = _commandChar;
    if (device == null || !device.isConnected || commandChar == null) {
      throw StateError('Glove is not connected');
    }
    await commandChar.write([command.code]);
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
    _status.close();
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
