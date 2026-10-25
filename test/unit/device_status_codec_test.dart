import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/data/codec/device_status_codec.dart';
import 'package:talkhimik_app/domain/models/device_status.dart';

void main() {
  test('decodes the firmware STATUS frame: mode, step, battery, flags',
      () {
    final packet = DeviceStatusCodec.decode(
        Uint8List.fromList([1, 4, 87, 0x01, 0]));
    expect(packet.mode, GloveMode.calibrating);
    expect(packet.calibrationStep, 4); // ring flat
    expect(packet.batteryPercent, 87);
    expect(packet.uncalibrated, isTrue); // flags bit0
    expect(packet.linkUp, isTrue); // received over the live link
    expect(packet.lastErrorCode, 0);
    expect(packet.hasError, isFalse);
  });

  test('0xFF battery maps to null (VBAT sense disabled)', () {
    final packet = DeviceStatusCodec.decode(
        Uint8List.fromList([0, 0, 0xFF, 0, 0]));
    expect(packet.batteryPercent, isNull);
    expect(packet.mode, GloveMode.streaming);
    expect(packet.uncalibrated, isFalse);
  });

  test('firmware error codes decode 1..4', () {
    final packet = DeviceStatusCodec.decode(
        Uint8List.fromList([0, 10, 50, 0, 4]));
    expect(packet.lastErrorCode, 4);
    expect(packet.hasError, isTrue);
    expect(GloveErrorCode.fromCode(packet.lastErrorCode),
        GloveErrorCode.resistanceFault);
    expect(GloveErrorCode.fromCode(3), GloveErrorCode.spanReject);
    expect(GloveErrorCode.fromCode(2), GloveErrorCode.unknownCommand);
    expect(GloveErrorCode.fromCode(1), GloveErrorCode.captureNotCalibrating);
    expect(GloveErrorCode.fromCode(0), GloveErrorCode.none);
    expect(GloveErrorCode.fromCode(null), GloveErrorCode.none);
    expect(GloveErrorCode.fromCode(9), isNull); // unmapped → generic chip
  });

  test('clamps battery to 0–100', () {
    expect(
      DeviceStatusCodec.decode(
              Uint8List.fromList([0, 0, 250, 0, 0]))
          .batteryPercent,
      100,
    );
  });

  test('unknown mode code maps to GloveMode.unknown', () {
    expect(
      DeviceStatusCodec.decode(Uint8List.fromList([9, 0, 50, 0, 0])).mode,
      GloveMode.unknown,
    );
  });

  test('rejects payloads that are not 5 bytes', () {
    expect(
      () => DeviceStatusCodec.decode(Uint8List.fromList([1, 2, 3, 4])),
      throwsFormatException,
    );
    expect(
      () => DeviceStatusCodec.decode(Uint8List.fromList([1, 2, 3, 4, 5, 6])),
      throwsFormatException,
    );
  });
}
