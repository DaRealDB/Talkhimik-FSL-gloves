import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

import 'glove_connection.dart';
import 'glove_connection_fbp.dart';
import 'mock_glove_connection.dart';

/// Chooses the right [GloveConnection] for the running platform.
///
/// flutter_blue_plus has no Windows implementation and Web Bluetooth needs
/// HTTPS + a user gesture, so anything that is not Android/iOS gets the
/// mock — which is also exactly what development, demos, and tests want.
///
/// [forceMock] (the Settings "Force mock" dev flag, FR field-testing aid)
/// lets a researcher demo without hardware on Android.
class GloveConnectionFactory {
  GloveConnectionFactory._();

  static GloveConnection create({bool forceMock = false}) {
    final onMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    return createWith(onMobile: onMobile, forceMock: forceMock);
  }

  /// Test seam: platform detection overridden so the Android/iOS branch is
  /// unit-testable off-device.
  static GloveConnection createWith({
    required bool onMobile,
    required bool forceMock,
  }) =>
      (onMobile && !forceMock)
          ? FlutterBlueGloveConnection()
          : MockGloveConnection();
}
