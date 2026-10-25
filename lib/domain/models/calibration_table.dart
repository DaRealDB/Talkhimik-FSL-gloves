import 'package:meta/meta.dart';

import 'cal_info_packet.dart';

/// Finger order everywhere: thumb, pointer, middle, ring, pinky (master §2.1).
const List<String> fingerNames = ['thumb', 'pointer', 'middle', 'ring', 'pinky'];

/// One finger's typed record from the CAL_INFO table.
@immutable
class FingerCalibration {
  const FingerCalibration({
    required this.name,
    required this.valid,
    required this.weak,
    required this.flatOhm,
    required this.bent90Ohm,
    required this.flatAdc,
    required this.bent90Adc,
    required this.rDiv,
    required this.spanCounts,
  });

  final String name;

  /// Quality gate: bit set in CAL_INFO valid mask (excluded otherwise).
  final bool valid;

  /// Span under 100 ADC counts — accepted with a warning (weak mask bit).
  final bool weak;

  final double flatOhm;
  final double bent90Ohm;
  final int flatAdc;
  final int bent90Adc;

  /// Divider value the profile was captured with (R_DIV signature).
  final double rDiv;

  /// |bent90_adc − flat_adc|.
  final int spanCounts;
}

/// Typed per-finger view over a [CalInfoPacket] (master §7.2) — the single
/// source for calibration summaries (§4.4) and dataset sidecars (§5.3).
class CalibrationTable {
  CalibrationTable(this.packet);

  final CalInfoPacket packet;

  /// Header facts for summaries/sidecars (master §4.4, §5.3).
  int get calibrationId => packet.calibrationId;
  String get firmwareVersion => packet.firmwareVersion;

  List<FingerCalibration> get fingers => [
        for (var i = 0; i < fingerNames.length; i++)
          FingerCalibration(
            name: fingerNames[i],
            valid: packet.validMask & (1 << i) != 0,
            weak: packet.weakMask & (1 << i) != 0,
            flatOhm: packet.flatOhm[i],
            bent90Ohm: packet.bent90Ohm[i],
            flatAdc: packet.flatAdc[i],
            bent90Adc: packet.bent90Adc[i],
            rDiv: packet.rDiv[i],
            spanCounts: packet.spanCounts[i],
          ),
      ];

  /// One finger's record, 0 = thumb … 4 = pinky.
  FingerCalibration finger(int index) => fingers[index];
}
