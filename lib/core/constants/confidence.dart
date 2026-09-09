/// Confidence levels shown as color-coded badges on transcript bubbles
/// (SRS FR-4). The widget layer maps each level to its badge color
/// (green / amber / red); this file owns only the classification rule.
library;

enum ConfidenceLevel { high, medium, low }

class ConfidenceThresholds {
  ConfidenceThresholds._();

  /// Default thresholds; adjustable from the Settings screen (FR-15).
  static const int greenAtOrAbove = 80;
  static const int amberAtOrAbove = 60;

  /// green if confidence >= [green], amber if >= [amber], red otherwise.
  static ConfidenceLevel levelFor(
    int confidence, {
    int green = greenAtOrAbove,
    int amber = amberAtOrAbove,
  }) {
    if (confidence >= green) return ConfidenceLevel.high;
    if (confidence >= amber) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }

  /// Stored name for the FR-10 log schema ('green' | 'amber' | 'red').
  static String levelName(ConfidenceLevel level) => switch (level) {
        ConfidenceLevel.high => 'green',
        ConfidenceLevel.medium => 'amber',
        ConfidenceLevel.low => 'red',
      };
}
