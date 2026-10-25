import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/strings/app_strings.dart';
import '../../data/glove/glove_connection_factory.dart';
import '../../data/glove/mock_glove_connection.dart';
import '../widgets/demo_controls.dart';
import '../widgets/device_status_bar.dart';
import '../widgets/header_band.dart';
import '../widgets/reply_panel.dart';
import '../widgets/saved_phrases_panel.dart';
import '../widgets/transcript_view.dart';

/// Main screen: device status, transcript, reply panel, and (on dev
/// platforms) the mock-glove demo controls (SRS FR-1…FR-4, FR-7, FR-12).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Demo convenience: on dev platforms the mock glove auto-connects so
    // the transcript is one tap away; a saved startup scenario then starts
    // running. NEVER on a phone: the mock must not start itself there even
    // when Force mock is on (bugfix) — there it connects explicitly.
    // Both mock gloves connect so the Live screen demos two animated hands
    // without hardware (master DoD).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (GloveConnectionFactory.isMobile ||
          !ref.read(gloveIsMockProvider)) {
        return;
      }
      final gloveController = ref.read(gloveControllerProvider.notifier);
      await gloveController.connect();
      await ref.read(rightGloveControllerProvider.notifier).connect();
      if (!mounted) return;
      final scenarioName =
          await ref.read(settingsServiceProvider).demoScenario();
      if (scenarioName == null || !mounted) return;
      final glove = ref.read(gloveConnectionProvider);
      if (glove is MockGloveConnection) {
        final scenario = MockScenario.values
            .where((s) => s.name == scenarioName)
            .firstOrNull;
        if (scenario != null) glove.startScenario(scenario);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appTitle),
        centerTitle: true,
        // Six actions on a 360 dp phone: compact density keeps the row
        // inside the bar without dropping any tool (typography pass).
        actions: [
          for (final (tooltip, icon, route) in [
            (AppStrings.liveTitle, Icons.back_hand_outlined, '/live'),
            (AppStrings.clearTranscript, Icons.delete_sweep_outlined, null),
            (AppStrings.calibrationTitle, Icons.tune_outlined, '/calibration'),
            (AppStrings.recordModeTitle, Icons.fiber_manual_record_outlined,
                '/collect'),
            ('Session logs', Icons.file_download_outlined, '/export'),
            ('Settings', Icons.settings_outlined, '/settings'),
          ])
            IconButton(
              tooltip: tooltip,
              visualDensity: VisualDensity.compact,
              icon: Icon(icon),
              onPressed: () {
                if (route != null) {
                  Navigator.of(context).pushNamed(route);
                } else {
                  ref.read(transcriptControllerProvider.notifier).clear();
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: DeviceStatusBar(),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: DemoControls(),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: HeaderBand(title: 'Transcript'),
            ),
            Expanded(
              child: TranscriptView(),
            ),
            const SavedPhrasesPanel(),
            const ReplyPanel(),
          ],
        ),
      ),
    );
  }
}
