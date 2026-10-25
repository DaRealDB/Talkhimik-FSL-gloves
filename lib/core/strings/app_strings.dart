/// Centralized user-facing copy.
///
/// NFR-7 / P4: terminology audit lives here — the app says
/// "Deaf and non-speaking", never "deaf and mute". Reviewing this file
/// reviews the copy policy.
class AppStrings {
  AppStrings._();

  static const appTitle = 'Talkhimik';
  static const appTagline = 'FSL Smart Glove · Bridging silent gestures '
      'to spoken Filipino words';

  // Connection and status (FR-12)
  static const mockGloveName = 'Mock glove';
  static const realGloveName = 'Talkhimik Glove';
  static const connectionLost = 'Connection lost — reconnecting…';
  static const connected = 'Connected';
  static const disconnected = 'Not connected';
  static const reconnecting = 'Reconnecting…';
  static const uncalibrated = 'Uncalibrated';
  // Firmware STATUS error codes (Code Reference §5.3)
  static const sensorFault = 'Sensor fault';
  static const captureNotCalibrating = 'Capture not allowed';
  static const unknownCommand = 'Unknown command';
  static const spanReject = 'Redo — too close to flat';
  static const gloveError = 'Glove error';
  static const connectGlove = 'Connect glove';
  static const blePermissionDenied =
      'Bluetooth permissions were denied. Allow nearby devices and try '
      'again (C-S1).';
  static const connectFailed =
      'Could not connect to the glove. Check that it is powered on and '
      'nearby.';

  // Live screen (master §6.1)
  static const liveTitle = 'Live';
  static const leftHandLabel = 'L';
  static const rightHandLabel = 'R';
  static const freshness = 'Freshness';
  static const stale = 'Stale';
  static const packetLoss = 'Packet loss';
  static const updateRate = 'Update rate';
  static const battery = 'Battery';
  static const details = 'Details';
  static const rawAdc = 'Raw ADC';
  static const resistanceOhm = 'Resistance (Ω)';
  static const zeroYaw = 'Zero yaw';
  static const vibrateTest = 'Vibrate';
  static const weakSignal = 'Weak signal';
  static const handMismatchWarning = 'Hand mismatch — check glove name';
  static const noFramesYet = 'No frames yet';

  // Demo controls (dev-only)
  static const demoControlsTitle = 'Demo controls (mock glove)';
  static const stopScenario = 'Stop';
  static const emitHigh = 'Emit (high conf)';
  static const emitLow = 'Emit (low conf)';
  static const connect = 'Connect';
  static const disconnect = 'Disconnect';
  static const commandPrefix = 'Send:';

  // Transcript (FR-1, FR-3)
  static const emptyTranscript =
      'Sign a letter or phrase to begin.\n\nRecognized gestures appear here '
      'as text and speech.';
  static const clearTranscript = 'Clear transcript';

  // Reply panel (FR-7)
  static const replyHint = 'Type a reply for the signer…';
  static const sendReply = 'Send reply';

  // Calibration wizard (master §4)
  static const calibrationTitle = 'Calibration';
  static const calibrationPickHand = 'Choose the glove to calibrate';
  static const calibrationStart = 'Start calibration';
  static const calibrationAbort = 'Cancel';
  static const calibrationCapture = 'Capture';
  static const calibrationCapturing = 'Capturing…';
  static const calibrationDone = 'Done';
  static const calibrationSavedTitle = 'Calibration profile saved';
  static const calibrationNoProfile = 'No calibration profile yet.';
  static const calibrationProfileSummary = 'Current profile';
  static const calibrationSpanReject = 'Bend further and try again.';
  static const calibrationWiringWarning = 'Check the wiring on this finger.';
  static const calibrationUnknownCommand = 'The glove did not understand '
      'that command.';
  static String calibrationFlatPrompt(String finger) =>
      'Hold your $finger flat';
  static String calibrationBendPrompt(String finger) =>
      'Bend your $finger to 90°';

  // Record mode (FR-9)
  static const recordModeTitle = 'Record mode';
  static const recordIntroTitle = 'Collect labeled training data';
  static const recordIntroBody = 'Researcher mode: prompt FSL signs and '
      'record labeled samples with the participant ID for the training '
      'pipeline. Consent must be given before any data is collected.';
  static const recordNeedsParticipant =
      'Set the participant ID in Settings first (FR-13).';
  static const recordNeedsConsent =
      'Consent must be given before data collection (NFR-8).';
  static const recordStart = 'Start recording';
  static const recordSkip = 'Skip sign';
  static const recordAbort = 'Abort';
  static const recordSignPrompt = 'Sign this:';
  static const recordLastSample = 'Last sample';
  static const recordSamples = 'samples';
  static const recordSession = 'Session';
  static const recordDoneTitle = 'Recording complete';
  static const recordLogsHint =
      'Rows appear under Session logs for CSV export (FR-16).';
  static const recordDone = 'Done';
}
