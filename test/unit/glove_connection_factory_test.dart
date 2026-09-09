import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/data/glove/glove_connection_factory.dart';
import 'package:talkhimik_app/data/glove/glove_connection_fbp.dart';
import 'package:talkhimik_app/data/glove/mock_glove_connection.dart';

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
}
