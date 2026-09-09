import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/strings/app_strings.dart';
import '../widgets/demo_controls.dart';
import '../widgets/device_status_bar.dart';
import '../widgets/reply_panel.dart';
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
    // the transcript is one tap away. The real glove requires a permission
    // flow (C-S1) and connects explicitly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(gloveIsMockProvider)) {
        ref.read(gloveControllerProvider.notifier).connect();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appTitle),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: AppStrings.clearTranscript,
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () =>
                ref.read(transcriptControllerProvider.notifier).clear(),
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
            Expanded(
              child: TranscriptView(),
            ),
            const ReplyPanel(),
          ],
        ),
      ),
    );
  }
}
