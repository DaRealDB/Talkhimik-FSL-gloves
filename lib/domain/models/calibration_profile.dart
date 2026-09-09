import 'package:meta/meta.dart';

/// Per-word aggregate of one calibration run (SRS FR-8).
@immutable
class CalibrationWordStat {
  const CalibrationWordStat({
    required this.wordId,
    required this.sampleCount,
    required this.meanConfidence,
    required this.minConfidence,
    required this.maxConfidence,
  });

  final int wordId;
  final int sampleCount;

  /// Mean glove confidence 0–100 across the captured reps.
  final double meanConfidence;

  final int minConfidence;
  final int maxConfidence;

  Map<String, Object> toJson() => {
        'wordId': wordId,
        'sampleCount': sampleCount,
        'meanConfidence': meanConfidence,
        'minConfidence': minConfidence,
        'maxConfidence': maxConfidence,
      };

  static CalibrationWordStat fromJson(Map<String, Object?> json) =>
      CalibrationWordStat(
        wordId: json['wordId'] as int,
        sampleCount: json['sampleCount'] as int,
        meanConfidence: (json['meanConfidence'] as num).toDouble(),
        minConfidence: json['minConfidence'] as int,
        maxConfidence: json['maxConfidence'] as int,
      );
}

/// A saved per-user calibration profile (SRS FR-8, Definition of Terms:
/// "calibration profile"). The guided flow prompts sample signs, aggregates
/// the glove's reported confidence per word, and stores the result so
/// inference can be adjusted per signer (M1 cross-user).
///
/// Placeholder until the firmware calibration protocol exists: stats are
/// derived from ordinary gesture packets captured during the prompts, not
/// from raw sensor baselines. Revisit when the ESP32-S3 firmware team
/// defines the calibration packet contract.
@immutable
class CalibrationProfile {
  const CalibrationProfile({
    required this.participantId,
    required this.savedAt,
    required this.stats,
  });

  final String participantId;
  final DateTime savedAt;

  /// One stat per prompted word, in prompt order.
  final List<CalibrationWordStat> stats;

  /// Mean of the per-word means (plain average; Chapter 3 may prefer a
  /// sample-weighted mean).
  double get overallMean => stats.isEmpty
      ? 0
      : stats.map((s) => s.meanConfidence).reduce((a, b) => a + b) /
          stats.length;

  Map<String, Object> toJson() => {
        'participantId': participantId,
        'savedAt': savedAt.millisecondsSinceEpoch,
        'stats': [for (final s in stats) s.toJson()],
      };

  static CalibrationProfile fromJson(Map<String, Object?> json) =>
      CalibrationProfile(
        participantId: json['participantId'] as String,
        savedAt: DateTime.fromMillisecondsSinceEpoch(json['savedAt'] as int),
        stats: [
          for (final s in json['stats'] as List)
            CalibrationWordStat.fromJson((s as Map).cast<String, Object?>()),
        ],
      );
}
