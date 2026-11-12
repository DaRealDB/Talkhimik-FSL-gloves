/// Tunable constants for the phone-side recognizer (C1/C4).
///
/// Everything the team may want to tune without touching logic lives here:
/// gate freshness, stabilizer timing/voting, and the stand-in classifier's
/// honesty cap. The trained-model pipeline (C3/C4) supplies its own
/// confidence floor via labels.json — see TALKHIMIK.md §Recognition.
library;

class RecognitionConstants {
  RecognitionConstants._();

  /// A telemetry frame older than this is stale (mirrors §6.1 freshness).
  static const int staleFrameMs = 500;

  /// Stand-in rule classifier metadata (C1; replaced by C4's model).
  static const String thresholdSource = 'phone-threshold';
  static const String thresholdModelVersion = 'stand-in-v1';

  /// Trained-model classifier metadata (C4).
  static const String tfliteSource = 'phone-tflite';

  /// The 10 merged letter classes can never be certain about which of
  /// their member letters was signed — cap their confidence so the UI
  /// never presents a merged guess as a sure hit (concept C5).
  static const double thresholdConfidenceCap = 0.55;
}
