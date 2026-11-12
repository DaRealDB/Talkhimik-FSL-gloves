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
  static const mockGloveName = 'Demo glove';
  static const realGloveName = 'Real glove';
  static const demoTag = 'Demo';
  static const statusBothConnected = 'Both gloves connected';
  static const statusOneConnected = 'One glove connected';
  static const statusConnecting = 'Connecting…';
  static const statusNotConnected = 'Not connected';
  static const connectionDetails = 'Connection details';
  static const uncalibratedBanner = 'Uncalibrated — calibrate now';
  static const connectGloves = 'Connect gloves';
  static const listening = 'Listening';
  static const mtuTooSmall = 'Glove data link too small (MTU)';
  static const notifyTelemetryFailed =
      'Notifications could not be enabled on the glove';
  // BLE diagnostics (Developer panel, fix B1)
  static const bleDiagnosticsTitle = 'BLE diagnostics';
  static const diagPhase = 'Phase';
  static const diagBond = 'Bond';
  static const diagMtu = 'MTU';
  static const diagChars = 'Characteristics';
  static const diagNotify = 'Notify results';
  static const diagFrames = 'Frames';
  static const diagLastLen = 'Last payload';
  static const diagRejects = 'Rejects';
  static const diagLastError = 'Last error';
  static const diagFreshness = 'Since telemetry';
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
  static const homeTab = 'Home';
  static const moreTab = 'More';
  static const leftHandLabel = 'L';
  static const rightHandLabel = 'R';
  static const leftHandTitle = 'Left hand';
  static const rightHandTitle = 'Right hand';
  static const freshness = 'Freshness';
  static const stale = 'Stale';
  static const packetLoss = 'Packet loss';
  static const updateRate = 'Update rate';
  static const details = 'Details';
  static const rawAdc = 'Raw ADC';
  static const resistanceOhm = 'Resistance (Ω)';
  static const zeroYaw = 'Zero yaw';
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
  static const transcriptHeader = 'Transcript';
  static const emptyTranscript =
      'Sign a letter and hold it steady for a moment.\n\n'
      'Recognized signs appear here as text and speech.';
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

  // Record mode (FR-9, master §5)
  static const recordModeTitle = 'Record mode';
  static const recordNeedsParticipant =
      'Set the participant ID in Settings first (FR-13).';
  static const recordNeedsConsent =
      'Consent must be given before data collection (NFR-8).';
  static const recordNeedsCalibration =
      'Calibrate the glove before recording (cal_id 0).';
  static const recordNeedsLabel = 'Enter a label for the take.';
  static const datasetLabel = 'Label';
  static const datasetLabelHint = 'e.g. A, KUMUSTA';
  static const datasetStartTake = 'Start take';
  static const datasetStopTake = 'Stop take';
  static const datasetRecording = 'Recording';
  static const datasetSessions = 'Dataset sessions';
  static const datasetShare = 'Share';
  static const datasetDelete = 'Delete';
  static const datasetRows = 'rows';
  static const datasetDropped = 'dropped';
  static const recordStart = 'Start recording';
  static const recordAbort = 'Abort';

  // Dataset coverage + share-all (C2)
  static const restLabelItem = 'REST — hand relaxed';
  static const coverageTitle = 'Dataset coverage';
  static const coverageHint =
      'Record each letter 10+ times; move your hand a little between '
      'takes; record REST so the app knows when you are not signing.';
  static const coverageLater = 'later';
  static const coverageNeedsData = 'needs data';
  static const coverageOk = 'ok';
  static const coverageGood = 'good';
  static const shareAll = 'Share all for training';
  static const shareAllNoData =
      'No recorded data yet — record some takes first.';
  static String coverageSummary(int ready, int targets, int takes,
          int restTakes) =>
      '$ready of $targets letters ready · $takes takes · '
      '$restTakes REST takes';

  // Phone-side recognition (C1)
  static const recognitionSection = 'Recognition';
  static const recognitionSigningHand = 'Signing hand';
  static const recognitionSigningHandSubtitle =
      'Which glove the phone reads signs from.';
  static const signingHandAuto = 'Auto';
  static const signingHandLeft = 'Left';
  static const signingHandRight = 'Right';
  static const phoneRecognitionToggle = 'Phone recognition';
  static const phoneRecognitionToggleSubtitle =
      'Recognize signs on the phone until the glove sends its own results.';
  static const recogDebugTitle = 'Recognition debug';
  static const recogDebugStandInNote =
      'Stand-in rules — replaced by the trained model later.';
  static const recogDebugClassifier = 'Classifier';
  static const recogDebugModelVersion = 'Model version';
  static const recogDebugTrainedOn = 'Trained on';
  static const recogDebugActiveHand = 'Hand';
  static const recogDebugRawClass = 'Raw class';
  static const recogDebugRawLabel = 'Raw letter';
  static const recogDebugConfidence = 'Confidence';
  static const recogDebugTop3 = 'Top 3';
  static const recogDebugVotes = 'Votes';
  static const recogDebugGate = 'Blocked by';
  static const recogDebugLastEmitted = 'Last emitted';
  static const recogDebugInactive =
      'Recognition is off (mock mode or developer toggle).';
  static const recogDebugPaused =
      'Paused — the glove is sending its own results.';
  static const recogDebugNoHand = 'No signing hand connected.';
  static const gateUncalibrated = 'uncalibrated';
  static const gateStale = 'stale';
  static const gateInvalidFinger = 'invalid finger';
  static const gateReleased = 'released';
}
