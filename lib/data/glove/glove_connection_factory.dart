import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

import '../../domain/models/telemetry_packet.dart';
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

  /// The keep-area primary connection — the LEFT glove (master §7.3 binds
  /// the transcript/demo path to it).
  static GloveConnection create({bool forceMock = false}) =>
      createForHand(GloveHand.left, forceMock: forceMock);

  /// One connection per glove; [hand] binds the BLE scan to the full
  /// advertised name TALKHIMIK-L / TALKHIMIK-R.
  static GloveConnection createForHand(GloveHand hand,
          {bool forceMock = false}) {
    final onMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    return createWith(onMobile: onMobile, forceMock: forceMock, hand: hand);
  }

  /// Test seam: platform detection overridden so the Android/iOS branch is
  /// unit-testable off-device.
  static GloveConnection createWith({
    required bool onMobile,
    required bool forceMock,
    GloveHand hand = GloveHand.left,
  }) =>
      (onMobile && !forceMock)
          ? FlutterBlueGloveConnection(hand: hand)
          : MockGloveConnection();
}
