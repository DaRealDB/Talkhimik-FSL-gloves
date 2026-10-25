import 'package:meta/meta.dart';

/// One decoded 104-byte CAL_INFO table (Code Reference §5.5).
///
/// The full calibration profile behind the telemetry stream: per-finger
/// flat/90° baselines in ohms and raw ADC, the R_DIV signature, span counts,
/// validity masks, and the firmware version. Pushed by the glove after every
/// calibration save and readable even while disconnected.
@immutable
class CalInfoPacket {
  const CalInfoPacket({
    required this.validMask,
    required this.weakMask,
    required this.calibrationId,
    required this.flatOhm,
    required this.bent90Ohm,
    required this.flatAdc,
    required this.bent90Adc,
    required this.rDiv,
    required this.spanCounts,
    required this.firmwareVersion,
  });

  /// Bit0..4 = finger passed the quality checks.
  final int validMask;

  /// Bit0..4 = finger span was under the 100-count warning threshold.
  final int weakMask;

  /// Bumps on every saved calibration.
  final int calibrationId;

  /// Flat / 90° resistance baselines in ohms, thumb..pinky.
  final List<double> flatOhm;
  final List<double> bent90Ohm;

  /// Raw 12-bit ADC at flat / 90°, thumb..pinky.
  final List<int> flatAdc;
  final List<int> bent90Adc;

  /// Divider values the profile was captured with (ohms per finger).
  final List<double> rDiv;

  /// |bent90_adc − flat_adc| per finger.
  final List<int> spanCounts;

  /// Firmware version as ASCII, zero-padded (e.g. '1.2.0').
  final String firmwareVersion;

  /// JSON round-trip for the CalInfo cache (mirror only — the glove's NVS
  /// stays authoritative, master §4.1).
  Map<String, Object?> toJson() => {
        'validMask': validMask,
        'weakMask': weakMask,
        'calibrationId': calibrationId,
        'flatOhm': flatOhm,
        'bent90Ohm': bent90Ohm,
        'flatAdc': flatAdc,
        'bent90Adc': bent90Adc,
        'rDiv': rDiv,
        'spanCounts': spanCounts,
        'firmwareVersion': firmwareVersion,
      };

  static CalInfoPacket fromJson(Map<String, Object?> json) => CalInfoPacket(
        validMask: json['validMask'] as int,
        weakMask: json['weakMask'] as int,
        calibrationId: json['calibrationId'] as int,
        flatOhm: [for (final v in json['flatOhm'] as List) (v as num).toDouble()],
        bent90Ohm: [
          for (final v in json['bent90Ohm'] as List) (v as num).toDouble(),
        ],
        flatAdc: [for (final v in json['flatAdc'] as List) v as int],
        bent90Adc: [for (final v in json['bent90Adc'] as List) v as int],
        rDiv: [for (final v in json['rDiv'] as List) (v as num).toDouble()],
        spanCounts: [for (final v in json['spanCounts'] as List) v as int],
        firmwareVersion: json['firmwareVersion'] as String,
      );
}
