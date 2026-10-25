import 'package:meta/meta.dart';

/// One 5 Hz sample for the dataset (master §5.2). The lists are always
/// length 5 (thumb..pinky); fingers with valid-mask bit 0 lose their three
/// columns at write time.
@immutable
class DatasetRow {
  const DatasetRow({
    required this.timestampMs,
    required this.label,
    required this.takeId,
    required this.rawAdc,
    required this.ohms,
    required this.angles,
    required this.rollDeg,
    required this.pitchDeg,
    required this.yawDeg,
    required this.qualityFlag,
  });

  final int timestampMs;

  /// Free-text/selectable label of the take this sample belongs to.
  final String label;

  /// Take counter within the session (new session → 1).
  final int takeId;

  /// Raw 12-bit ADC, thumb..pinky (invalid fingers are placeholders).
  final List<int> rawAdc;

  /// Recomputed from raw + the session's CAL_INFO (master §3).
  final List<double> ohms;

  /// Recomputed angles (telemetry angles are for display only, §3).
  final List<double> angles;

  final double rollDeg;
  final double pitchDeg;
  final double yawDeg;

  /// Telemetry byte 28.
  final int qualityFlag;
}
