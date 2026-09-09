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
/// is honored once the settings layer is wired in M6; on Android it lets a
/// researcher demo without hardware.
class GloveConnectionFactory {
  GloveConnectionFactory._();

  static GloveConnection create({bool forceMock = false}) {
    final onMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    return (onMobile && !forceMock)
        ? FlutterBlueGloveConnection()
        : MockGloveConnection();
  }
}
