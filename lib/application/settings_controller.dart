import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Participant and dev settings (SRS FR-13, FR-15 demo options).
///
/// Language/TTS/accessibility settings live on their owning controllers
/// (TranscriptController, TtsController); this controller manages the
/// ethics-critical participant profile and the demo flags.
class SettingsState {
  const SettingsState({
    this.participantId = '',
    this.consentGiven = false,
    this.consentDate,
    this.isMinor = false,
    this.forceMock = false,
    this.demoScenario,
    this.signingHand = 'auto',
    this.phoneRecognitionEnabled = true,
    this.loaded = false,
  });

  final String participantId;
  final bool consentGiven;
  final DateTime? consentDate;
  final bool isMinor;
  final bool forceMock;
  final String? demoScenario;

  /// 'auto' | 'left' | 'right' — which glove the phone recognizer reads.
  final String signingHand;

  /// Developer toggle: phone-side recognition (default ON).
  final bool phoneRecognitionEnabled;

  final bool loaded;

  SettingsState copyWith({
    String? participantId,
    bool? consentGiven,
    DateTime? consentDate,
    bool? isMinor,
    bool? forceMock,
    String? demoScenario,
    String? signingHand,
    bool? phoneRecognitionEnabled,
    bool? loaded,
  }) =>
      SettingsState(
        participantId: participantId ?? this.participantId,
        consentGiven: consentGiven ?? this.consentGiven,
        consentDate: consentDate ?? this.consentDate,
        isMinor: isMinor ?? this.isMinor,
        forceMock: forceMock ?? this.forceMock,
        demoScenario: demoScenario ?? this.demoScenario,
        signingHand: signingHand ?? this.signingHand,
        phoneRecognitionEnabled:
            phoneRecognitionEnabled ?? this.phoneRecognitionEnabled,
        loaded: loaded ?? this.loaded,
      );
}

class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    _load();
    return const SettingsState();
  }  Future<void> _load() async {
    final settings = ref.read(settingsServiceProvider);
    state = SettingsState(
      participantId: await settings.participantId(),
      consentGiven: await settings.consentGiven(),
      consentDate: await settings.consentDate(),
      forceMock: await settings.forceMock(),
      demoScenario: await settings.demoScenario(),
      signingHand: await settings.signingHand(),
      phoneRecognitionEnabled: await settings.phoneRecognitionEnabled(),
      loaded: true,
    );
  }

  Future<void> setParticipantId(String id) async {
    final trimmed = id.trim();
    await ref.read(settingsServiceProvider).setParticipantId(trimmed);
    state = state.copyWith(participantId: trimmed);
  }

  Future<void> setConsentGiven(bool consent) async {
    final settings = ref.read(settingsServiceProvider);
    await settings.setConsentGiven(consent);
    await settings.setConsentDate(consent ? DateTime.now() : null);
    state = state.copyWith(
      consentGiven: consent,
      consentDate: consent ? DateTime.now() : null,
    );
  }

  Future<void> setIsMinor(bool isMinor) async {
    state = state.copyWith(isMinor: isMinor);
  }

  Future<void> setForceMock(bool value) async {
    // The live switch (bugfix): persisting alone never swapped the
    // connection — delegate to the provider that rebuilds the glove
    // providers (disposing the previous connection) and mirrors the flag.
    await ref.read(forceMockProvider.notifier).set(value);
    state = state.copyWith(forceMock: value);
  }

  Future<void> setDemoScenario(String? value) async {
    await ref.read(settingsServiceProvider).setDemoScenario(value);
    state = state.copyWith(demoScenario: value);
  }

  Future<void> setSigningHand(String value) async {
    await ref.read(settingsServiceProvider).setSigningHand(value);
    state = state.copyWith(signingHand: value);
  }

  Future<void> setPhoneRecognitionEnabled(bool value) async {
    await ref
        .read(settingsServiceProvider)
        .setPhoneRecognitionEnabled(value);
    state = state.copyWith(phoneRecognitionEnabled: value);
  }
}

/// The live Force-mock flag. Toggling flips this state; the glove
/// connection providers `watch` it, so each hand's connection is swapped
/// (old one disposed — streams, timers, reconnect loops) without a restart.
class ForceMockController extends Notifier<bool> {
  ForceMockController({this.initial = false});

  /// Value the bootstrap preloaded (main.dart) so startup has no flicker.
  final bool initial;

  @override
  bool build() {
    _load();
    return initial;
  }

  Future<void> _load() async {
    final saved = await ref.read(settingsServiceProvider).forceMock();
    if (ref.mounted && saved != state) state = saved;
  }

  Future<void> set(bool value) async {
    await ref.read(settingsServiceProvider).setForceMock(value);
    state = value;
  }
}
