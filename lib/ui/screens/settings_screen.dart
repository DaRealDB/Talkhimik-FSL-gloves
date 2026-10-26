import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../data/glove/mock_glove_connection.dart';
import '../widgets/ble_diagnostics_panel.dart';
import '../widgets/header_band.dart';

/// FR-15 (language, voice, rate, large text), FR-13 (anonymized participant
/// profile with consent), and dev demo options.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _participantController = TextEditingController();

  @override
  void dispose() {
    _participantController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transcript = ref.watch(transcriptControllerProvider);
    final tts = ref.watch(ttsControllerProvider);
    final participant = ref.watch(settingsControllerProvider);
    final transcriptController = ref.read(transcriptControllerProvider.notifier);
    final ttsController = ref.read(ttsControllerProvider.notifier);
    final settingsController = ref.read(settingsControllerProvider.notifier);

    // Seed the field once the persisted id arrives (and only if the user
    // hasn't started typing).
    if (participant.loaded &&
        _participantController.text.isEmpty &&
        participant.participantId.isNotEmpty) {
      _participantController.text = participant.participantId;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Column(
        children: [
          const HeaderBand(title: 'Settings'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
          _section(context, 'Output language'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'fil', label: Text('Filipino')),
              ButtonSegment(value: 'en', label: Text('English')),
            ],
            selected: {transcript.language},
            onSelectionChanged: (selection) =>
                transcriptController.setLanguage(selection.first),
          ),
          const SizedBox(height: 16),
          _section(context, 'Speech'),
          SwitchListTile(
            title: const Text('Mute speech'),
            subtitle: const Text('Quiet settings (FR-2)'),
            value: tts.muted,
            onChanged: (v) => ttsController.setMuted(v),
          ),
          ListTile(
            title: const Text('Speech rate'),
            subtitle: Text('${tts.rate.toStringAsFixed(1)}×'),
            trailing: SizedBox(
              width: 160,
              child: Slider(
                value: tts.rate.clamp(0.5, 1.5),
                min: 0.5,
                max: 1.5,
                divisions: 10,
                onChanged: (v) => ttsController.setRate(v),
              ),
            ),
          ),
          if (tts.voices.isNotEmpty)
            ListTile(
              title: const Text('Voice'),
              trailing: DropdownButton<String>(
                value: tts.voice ?? tts.voices.first.id,
                items: [
                  for (final v in tts.voices)
                    DropdownMenuItem(value: v.id, child: Text(v.name)),
                ],
                onChanged: (v) {
                  if (v != null) ttsController.setVoice(v);
                },
              ),
            ),
          const SizedBox(height: 16),
          _section(context, 'Accessibility'),
          SwitchListTile(
            title: const Text('Large signer-facing text'),
            subtitle: const Text(
                'Deaf and non-speaking users read replies at large size '
                '(NFR-7)'),
            value: transcript.largeText,
            onChanged: (v) => transcriptController.setLargeText(v),
          ),
          const SizedBox(height: 16),
          _section(context, 'Participant profile (anonymized)'),
          TextField(
            key: const Key('participant-id-field'),
            controller: _participantController,
            decoration: const InputDecoration(
              labelText: 'Participant ID',
              helperText:
                  'IDs only — never names (FR-13, DR-4). Data collection '
                  'stays blocked without consent.',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => settingsController.setParticipantId(v),
          ),
          SwitchListTile(
            key: const Key('consent-switch'),
            title: const Text('Informed consent recorded'),
            subtitle: Text(
              participant.consentDate == null
                  ? 'Required before data collection (M4)'
                  : 'Recorded ${_date(participant.consentDate!)}',
            ),
            value: participant.consentGiven,
            onChanged: (v) => settingsController.setConsentGiven(v),
          ),
          SwitchListTile(
            title: const Text('Participant is a minor'),
            subtitle: const Text('Minors require parental consent (M4)'),
            value: participant.isMinor,
            onChanged: (v) => settingsController.setIsMinor(v),
          ),
          const SizedBox(height: 16),
          // Dev flags are tucked away so a signer/researcher never sees
          // them unless they go looking (simplify pass).
          ExpansionTile(
            title: Text('Developer',
                style: Theme.of(context).textTheme.titleSmall),
            tilePadding: EdgeInsets.zero,
            children: [
              SwitchListTile(
                title: const Text('Force mock glove'),
                subtitle: const Text('Swaps the connection live; '
                    'field-testing aid'),
                value: participant.forceMock,
                onChanged: (v) => settingsController.setForceMock(v),
              ),
              ListTile(
                title: const Text('Startup demo scenario'),
                trailing: DropdownButton<String?>(
                  value: participant.demoScenario,
                  hint: const Text('None'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    for (final s in MockScenario.values)
                      DropdownMenuItem(value: s.name, child: Text(s.label)),
                  ],
                  onChanged: (v) => settingsController.setDemoScenario(v),
                ),
              ),
              // Live link diagnostics (fix B1) — works with mock values too.
              const BleDiagnosticsPanel(),
            ],
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      );

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
