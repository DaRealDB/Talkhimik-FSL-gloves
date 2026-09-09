import 'package:meta/meta.dart';

/// Operating mode reported by the glove through the Device Status
/// characteristic (SRS C-H3, C-F6).
enum GloveMode { idle, streaming, calibrating, sleeping, unknown }

/// Error codes the glove can report through Device Status.
///
/// The SRS does not enumerate firmware error codes; these values are a
/// placeholder enumeration to be finalized with the firmware team.
enum GloveErrorCode {
  none(0),
  sensorFault(1),
  lowBattery(2),
  powerFault(3),
  bleFault(4);

  const GloveErrorCode(this.code);
  final int code;

  static GloveErrorCode fromCode(int? code) => switch (code) {
        1 => sensorFault,
        2 => lowBattery,
        3 => powerFault,
        4 => bleFault,
        0 || null => none,
        _ => bleFault,
      };
}

/// Snapshot of the glove's Device Status characteristic (SRS Table III-1).
@immutable
class DeviceStatusPacket {
  const DeviceStatusPacket({
    this.batteryPercent,
    this.mode = GloveMode.unknown,
    this.linkUp = false,
    this.lastErrorCode,
  });

  /// Battery charge, 0–100; null when the glove did not report it.
  final int? batteryPercent;

  final GloveMode mode;

  /// True while the BLE link is up.
  final bool linkUp;

  /// Last error reported by the glove (e.g. sensor fault); null when none.
  final int? lastErrorCode;

  bool get hasError => lastErrorCode != null && lastErrorCode != 0;
}
