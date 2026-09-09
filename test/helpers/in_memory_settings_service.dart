import 'package:talkhimik_app/data/storage/settings_service.dart';

/// In-memory [SettingsService] with the same defaults as the real one —
/// widget tests use this so nothing touches shared_preferences.
class InMemorySettingsService implements SettingsService {
  /// Public fields for test setup; names deliberately avoid the interface
  /// methods, which can't share names with fields of the same identifier.
  String language = 'fil';
  bool muted = false;
  String participant = '';

  double _rate = 1.0;
  String? _voice;
  bool _largeText = true;
  bool _consent = false;
  DateTime? _consentAt;
  bool _forceMock = false;
  String? _demoScenario;

  @override
  Future<String> outputLanguage() async => language;
  @override
  Future<void> setOutputLanguage(String value) async => language = value;
  @override
  Future<double> ttsRate() async => _rate;
  @override
  Future<void> setTtsRate(double value) async => _rate = value;
  @override
  Future<String?> ttsVoice() async => _voice;
  @override
  Future<void> setTtsVoice(String? value) async => _voice = value;
  @override
  Future<bool> ttsMuted() async => muted;
  @override
  Future<void> setTtsMuted(bool value) async => muted = value;
  @override
  Future<bool> largeText() async => _largeText;
  @override
  Future<void> setLargeText(bool value) async => _largeText = value;
  @override
  Future<String> participantId() async => participant;
  @override
  Future<void> setParticipantId(String value) async => participant = value;
  @override
  Future<bool> consentGiven() async => _consent;
  @override
  Future<void> setConsentGiven(bool value) async => _consent = value;
  @override
  Future<DateTime?> consentDate() async => _consentAt;
  @override
  Future<void> setConsentDate(DateTime? value) async => _consentAt = value;
  @override
  Future<bool> forceMock() async => _forceMock;
  @override
  Future<void> setForceMock(bool value) async => _forceMock = value;
  @override
  Future<String?> demoScenario() async => _demoScenario;
  @override
  Future<void> setDemoScenario(String? value) async => _demoScenario = value;
}
