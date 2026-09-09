import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';

/// Thrown when the signer/researcher refuses the Bluetooth permissions
/// (SRS C-S1); the UI maps it to a friendly message.
class BlePermissionDeniedException implements Exception {
  const BlePermissionDeniedException();

  @override
  String toString() => 'BlePermissionDeniedException';
}

/// Runtime Bluetooth permission gate for the real glove (SRS C-S1).
abstract interface class BlePermissions {
  /// Requests permissions if needed; throws [BlePermissionDeniedException]
  /// when the user declines.
  Future<void> ensureGranted();
}

/// permission_handler implementation. Android is the tested platform
/// (NFR-10): BLUETOOTH_SCAN + BLUETOOTH_CONNECT on Android 12+, auto-granted
/// legacy permissions below that (the plugin maps them). iOS prompts
/// natively on first BLE use via its Info.plist usage descriptions.
class PermissionHandlerBlePermissions implements BlePermissions {
  const PermissionHandlerBlePermissions();

  @override
  Future<void> ensureGranted() async {
    if (!kIsWeb && Platform.isIOS) return;

    final scan = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();
    if (!scan.isGranted || !connect.isGranted) {
      throw const BlePermissionDeniedException();
    }
  }
}
