import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/constants/gatt_ids.dart';
import '../../domain/models/device_status.dart';
import '../../domain/models/gesture_result.dart';
import 'glove_connection.dart';

/// Real BLE implementation over flutter_blue_plus (SRS C-S1).
///
/// IMPORTANT: flutter_blue_plus has no Windows implementation — importing it
/// compiles everywhere, but CALLING it off-Android/iOS throws
/// MissingPluginException. The factory in glove_connection_factory.dart
/// guarantees this class is only constructed on Android/iOS.
///
/// Skeleton for M9 (real-device milestone): the full scan → connect →
/// subscribe → write flow lands once the glove firmware exists and can be
/// tested in stages per Talkhimik_BLE_Integration_Steps.md (nRF Connect
/// first, then this client).
class FlutterBlueGloveConnection implements GloveConnection {
  final _gestures = StreamController<GestureResultPacket>.broadcast();
  final _status = StreamController<DeviceStatusPacket>.broadcast();
  final _phases = StreamController<GloveConnectionPhase>.broadcast();

  final List<StreamSubscription<Object?>> _subs = [];
  BluetoothDevice? _device;

  @override
  Stream<GestureResultPacket> get gestureResults => _gestures.stream;

  @override
  Stream<DeviceStatusPacket> get deviceStatus => _status.stream;

  @override
  Stream<GloveConnectionPhase> get phaseChanges => _phases.stream;

  // TODO(M9): implement per the BLE integration steps —
  //   1. request permissions (permission_handler) before scanning;
  //   2. FlutterBluePlus.startScan(withServices: [Guid(GattIds.gloveService)]);
  //   3. first device with localName == GattIds.deviceName → connect(timeout);
  //   4. discoverServices(); setNotifyValue(true) on
  //      GattIds.gestureResult and GattIds.deviceStatus;
  //   5. onValueReceived → GesturePacketCodec.decode → _gestures.add;
  //   6. requestConnectionPriority(balanced) in try/catch (15–30 ms interval).
  @override
  Future<void> connect() async {
    throw UnimplementedError('M9: real BLE client not wired yet');
  }

  @override
  Future<void> reconnect() => connect();

  // TODO(M9): write the command byte to GattIds.appCommand.
  @override
  Future<void> sendCommand(AppCommand command) async {
    throw UnimplementedError('M9: real BLE client not wired yet');
  }

  @override
  Future<void> disconnect() async {
    await _device?.disconnect();
    _device = null;
    _phases.add(GloveConnectionPhase.disconnected);
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _gestures.close();
    _status.close();
    _phases.close();
  }
}
