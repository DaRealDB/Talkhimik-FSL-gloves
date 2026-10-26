import 'package:flutter/foundation.dart';

import 'glove_connection.dart';

/// Live BLE link diagnostics for one glove (fix B1). The connection
/// records every connect-sequence step, notify result, frame count, and
/// decode rejection here; the Developer panel renders it. Mock/fake
/// connections fill mock values so the panel works everywhere.
class BleDiagnostics extends ChangeNotifier {
  GloveConnectionPhase phase = GloveConnectionPhase.disconnected;

  /// Phone-side bond state ('none' / 'bonding' / 'bonded').
  String bondState = '—';

  /// Negotiated ATT MTU (null = not requested).
  int? mtu;
  int mtuAttempts = 0;

  /// The four contract characteristics: found (bool) at connect time.
  final Map<String, bool> characteristicsFound = {};

  /// Notify-enable result per characteristic: 'ok' or the error text.
  final Map<String, String> notifyResults = {};

  /// Notifications received per characteristic.
  final Map<String, int> notifyCounts = {};

  /// Byte length of the last notification payload.
  int? lastPayloadLength;

  /// Decode rejections BY REASON (never silently dropped — fix B1).
  int rejectsLength = 0;
  int rejectsException = 0;
  int rejectsHandMismatch = 0;

  String? lastError;
  DateTime? lastTelemetryAt;

  void touch() => notifyListeners();

  /// Seconds since the last telemetry frame (null = never).
  int? secondsSinceTelemetry() {
    final at = lastTelemetryAt;
    if (at == null) return null;
    return DateTime.now().difference(at).inSeconds;
  }
}
