import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/data/glove/glove_connection.dart';
import 'package:talkhimik_app/data/glove/mock_glove_connection.dart';
import 'package:talkhimik_app/domain/models/device_status.dart';

void main() {
  test('mock emulates the fw 1.3.0 mount calibration sequence', () async {
    final mock = MockGloveConnection(
        config: const MockGloveConfig(connectStepDelay: Duration.zero));
    addTearDown(mock.dispose);
    final statuses = <DeviceStatusPacket>[];
    mock.deviceStatus.listen(statuses.add);

    await mock.sendCommand(AppCommand.captureMountPose2);
    await Future<void>.delayed(Duration.zero);
    expect(statuses.last.lastErrorCode, 8); // POSE2 before POSE1
    expect(statuses.last.mountUncalibrated, isTrue);

    mock.forceImuError(6);
    await mock.sendCommand(AppCommand.captureMountPose1);
    await Future<void>.delayed(Duration.zero);
    expect(statuses.last.lastErrorCode, 6);

    await mock.sendCommand(AppCommand.captureMountPose1);
    await mock.sendCommand(AppCommand.captureMountPose2);
    await Future<void>.delayed(Duration.zero);
    expect(statuses.last.hasError, isFalse);
    expect(statuses.last.mountUncalibrated, isFalse);
    expect(statuses.last.mountCalibrationId, isNot(0));
  });
}
