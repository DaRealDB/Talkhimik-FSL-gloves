import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/data/glove/glove_connection_factory.dart';
import 'package:talkhimik_app/data/glove/glove_connection_fbp.dart';
import 'package:talkhimik_app/data/glove/mock_glove_connection.dart';
import 'package:talkhimik_app/domain/models/telemetry_packet.dart';

void main() {
  test('mobile platforms get the real BLE client', () {
    expect(
      GloveConnectionFactory.createWith(onMobile: true, forceMock: false),
      isA<FlutterBlueGloveConnection>(),
    );
  });

  test('non-mobile platforms get the mock', () {
    expect(
      GloveConnectionFactory.createWith(onMobile: false, forceMock: false),
      isA<MockGloveConnection>(),
    );
  });

  test('forceMock overrides mobile (FR field-testing aid)', () {
    expect(
      GloveConnectionFactory.createWith(onMobile: true, forceMock: true),
      isA<MockGloveConnection>(),
    );
  });

  test('createForHand binds the BLE client to the requested hand '
      '(master §7.3)', () {
    final left = GloveConnectionFactory.createWith(
        onMobile: true, forceMock: false, hand: GloveHand.left);
    expect((left as FlutterBlueGloveConnection).hand, GloveHand.left);

    final right = GloveConnectionFactory.createWith(
        onMobile: true, forceMock: false, hand: GloveHand.right);
    expect((right as FlutterBlueGloveConnection).hand, GloveHand.right);
  });

  test('create() is the keep-area primary (left) connection', () {
    expect(
      (GloveConnectionFactory.createWith(onMobile: true, forceMock: false)
              as FlutterBlueGloveConnection)
          .hand,
      GloveHand.left,
    );
  });

  test('advertisedNameFor maps hands to firmware device names', () {
    expect(FlutterBlueGloveConnection.advertisedNameFor(GloveHand.left),
        'TALKHIMIK-L');
    expect(FlutterBlueGloveConnection.advertisedNameFor(GloveHand.right),
        'TALKHIMIK-R');
  });
}
