import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/data/codec/device_status_codec.dart';
import 'package:talkhimik_app/domain/models/device_status.dart';

void main() {
  test('decodes battery, mode, and error code', () {
    final packet = DeviceStatusCodec.decode(Uint8List.fromList([87, 1, 2]));
    expect(packet.batteryPercent, 87);
    expect(packet.mode, GloveMode.streaming);
    expect(packet.linkUp, isTrue); // received over the live link
    expect(packet.lastErrorCode, 2);
  });

  test('clamps battery to 0–100', () {
    expect(
      DeviceStatusCodec.decode(Uint8List.fromList([250, 0, 0])).batteryPercent,
      100,
    );
  });

  test('unknown mode code maps to GloveMode.unknown', () {
    expect(
      DeviceStatusCodec.decode(Uint8List.fromList([50, 9, 0])).mode,
      GloveMode.unknown,
    );
  });

  test('rejects payloads that are not 3 bytes', () {
    expect(
      () => DeviceStatusCodec.decode(Uint8List.fromList([1, 2])),
      throwsFormatException,
    );
    expect(
      () => DeviceStatusCodec.decode(Uint8List.fromList([1, 2, 3, 4])),
      throwsFormatException,
    );
  });
}
