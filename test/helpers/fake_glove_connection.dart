import 'dart:async';

import 'package:talkhimik_app/data/glove/ble_diagnostics.dart';
import 'package:talkhimik_app/data/glove/glove_connection.dart';
import 'package:talkhimik_app/domain/models/cal_info_packet.dart';
import 'package:talkhimik_app/domain/models/device_status.dart';
import 'package:talkhimik_app/domain/models/gesture_result.dart';
import 'package:talkhimik_app/domain/models/telemetry_packet.dart';

/// Controllable [GloveConnection] for tests: streams you drive by hand and
/// call counters for the reconnect state machine.
class FakeGloveConnection implements GloveConnection {
  final gestures = StreamController<GestureResultPacket>.broadcast();
  final telemetryController = StreamController<TelemetryPacket>.broadcast();
  final status = StreamController<DeviceStatusPacket>.broadcast();
  final calInfoController = StreamController<CalInfoPacket>.broadcast();
  final phases = StreamController<GloveConnectionPhase>.broadcast();

  int connectCalls = 0;
  int reconnectCalls = 0;
  int disconnectCalls = 0;
  final List<AppCommand> commands = [];

  /// When true, [reconnect] throws — simulating a glove that stays out of
  /// range so the controller's escalation logic can be exercised.
  bool failReconnects = false;

  /// When set, [connect] throws it — simulating permission denial, a glove
  /// that never appears in the scan, etc.
  Exception? throwOnConnect;

  @override
  final BleDiagnostics diagnostics = BleDiagnostics();

  @override
  Stream<GestureResultPacket> get gestureResults => gestures.stream;

  @override
  Stream<TelemetryPacket> get telemetry => telemetryController.stream;

  @override
  Stream<DeviceStatusPacket> get deviceStatus => status.stream;

  @override
  Stream<CalInfoPacket> get calInfo => calInfoController.stream;

  @override
  Stream<GloveConnectionPhase> get phaseChanges => phases.stream;

  @override
  Future<void> connect() async {
    connectCalls++;
    final error = throwOnConnect;
    if (error != null) throw error;
  }

  @override
  Future<void> reconnect() async {
    reconnectCalls++;
    if (failReconnects) {
      throw Exception('simulated out-of-range glove');
    }
  }

  /// When true, [sendCommand] throws like a failed BLE write.
  bool failCommands = false;

  /// What a STATUS READ returns via [refreshStatus]; null = nothing.
  DeviceStatusPacket? readableStatus;
  int statusReads = 0;

  @override
  Future<void> sendCommand(AppCommand command, {int value = 0}) async {
    if (failCommands) throw Exception('simulated write failure');
    commands.add(command);
  }

  @override
  Future<void> refreshStatus() async {
    statusReads++;
    final s = readableStatus;
    if (s != null) status.add(s);
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }

  void emitPhase(GloveConnectionPhase phase) => phases.add(phase);

  void emitStatus(DeviceStatusPacket packet) => status.add(packet);

  void emitTelemetry(TelemetryPacket packet) => telemetryController.add(packet);

  void emitCalInfo(CalInfoPacket packet) => calInfoController.add(packet);

  void emitGesture(GestureResultPacket packet) => gestures.add(packet);

  @override
  void dispose() {
    gestures.close();
    telemetryController.close();
    status.close();
    calInfoController.close();
    phases.close();
  }
}
