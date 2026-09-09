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
  static const lowBattery = 'Low battery';
  static const sensorFault = 'Sensor fault';
  static const powerFault = 'Power fault';
  static const bleFault = 'BLE fault';
  static const gloveError = 'Glove error';

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
}
