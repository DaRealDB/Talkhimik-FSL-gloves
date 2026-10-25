import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/data/glove/glove_connection.dart';

void main() {
  test('payload-less commands encode as the bare opcode', () {
    expect(AppCommand.startCalibration.encode(), [0x01]);
    expect(AppCommand.captureFlat.encode(), [0x02]);
    expect(AppCommand.capture90.encode(), [0x03]);
    expect(AppCommand.cancelCalibration.encode(), [0x04]);
    expect(AppCommand.zeroYaw.encode(), [0x06]);
  });

  test('u16 payloads encode little-endian', () {
    expect(AppCommand.setRate.encode(value: 300), [0x05, 0x2C, 0x01]);
    expect(AppCommand.vibrate.encode(value: 1000), [0x08, 0xE8, 0x03]);
  });

  test('u8 payloads encode as one byte', () {
    expect(AppCommand.setHand.encode(value: 1), [0x07, 0x01]);
  });

  test('values that do not fit the payload throw RangeError', () {
    expect(() => AppCommand.setHand.encode(value: 256), throwsRangeError);
    expect(() => AppCommand.setRate.encode(value: 65536), throwsRangeError);
    expect(() => AppCommand.setRate.encode(value: -1), throwsRangeError);
  });
}
