import 'dart:async';

import 'package:talkhimik_app/data/glove/glove_connection.dart';
import 'package:talkhimik_app/domain/models/device_status.dart';
import 'package:talkhimik_app/domain/models/gesture_result.dart';

/// Controllable [GloveConnection] for tests: streams you drive by hand and
/// call counters for the reconnect state machine.
class FakeGloveConnection implements GloveConnection {
  final gestures = StreamController<GestureResultPacket>.broadcast();
  final status = StreamController<DeviceStatusPacket>.broadcast();
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
  Stream<GestureResultPacket> get gestureResults => gestures.stream;

  @override
  Stream<DeviceStatusPacket> get deviceStatus => status.stream;

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

  @override
  Future<void> sendCommand(AppCommand command) async {
    commands.add(command);
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }

  void emitPhase(GloveConnectionPhase phase) => phases.add(phase);

  void emitStatus(DeviceStatusPacket packet) => status.add(packet);

  void emitGesture(GestureResultPacket packet) => gestures.add(packet);

  @override
  void dispose() {
    gestures.close();
    status.close();
    phases.close();
  }
}
