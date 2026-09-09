/// GATT contract constants shared between the glove firmware (ESP32-S3,
/// NimBLE) and this app. Source: SRS Section III, Table III-1.
///
/// The UUIDs below are the example values from the SRS and must be finalized
/// together with the firmware team before firmware freeze (SRS open item 2).
library;

class GattIds {
  GattIds._();

  /// Advertised device name of the glove.
  static const String deviceName = 'Talkhimik-Glove';

  /// Talkhimik Glove Service — container for the three characteristics.
  static const String gloveService = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';

  /// Gesture Result: NOTIFY — fired once per completed, above-threshold
  /// gesture. Packet layout per SRS Table III-2 (see [gesturePacketLength]).
  static const String gestureResult = '4fafc201-1fb5-459e-8fcc-c5c9c3319d42';

  /// Device Status: READ + NOTIFY — battery %, connection state, active mode,
  /// last error code.
  static const String deviceStatus = '4fafc201-1fb5-459e-8fcc-c5c9c3319d43';

  /// App Command: WRITE — app-to-glove control (see [AppCommand]).
  static const String appCommand = '4fafc201-1fb5-459e-8fcc-c5c9c3319d44';

  /// Gesture result packet length in bytes: word_id u16 + confidence u8 +
  /// timestamp_ms u32 (little-endian).
  static const int gesturePacketLength = 7;
}

/// Reconnection policy for the stateless glove (SRS C-F7, C-S5, NFR-9).
class ReconnectPolicy {
  ReconnectPolicy._();

  /// Backoff steps in seconds: 1, 2, 4, 8, then cap at 30 s.
  static const List<int> backoffSeconds = [1, 2, 4, 8, 30];

  /// The app must surface a visible "connection lost" state within this
  /// bound (SRS C-S5: 3 s).
  static const Duration lostNoticeBound = Duration(seconds: 3);
}
