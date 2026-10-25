import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../application/dataset_recorder_controller.dart';
import '../../application/providers.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/anim.dart';
import '../widgets/header_band.dart';

/// Dataset recorder screen (master §5): labeled takes at 5 Hz per glove,
/// calibration-aware sessions, and the finished-sessions list with
/// share / delete actions.
class CollectScreen extends ConsumerStatefulWidget {
  const CollectScreen({super.key});

  @override
  ConsumerState<CollectScreen> createState() => _CollectScreenState();
}

class _CollectScreenState extends ConsumerState<CollectScreen> {
  final TextEditingController _labelController = TextEditingController();

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(datasetRecorderControllerProvider);
    final recorder = ref.read(datasetRecorderControllerProvider.notifier);
    final recording = state.phase == RecordingPhase.recording;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.recordModeTitle)),
      body: Column(
        children: [
          HeaderBand(
            title: AppStrings.recordModeTitle,
            chipLabel: recording && state.active.isNotEmpty
                ? '${state.active.length} glove(s)'
                : null,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
          if (state.error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(state.error!),
            ),
            const SizedBox(height: 12),
          ],
          // Label: vocabulary picker + free-text fallback (master §12.5).
          DropdownButtonFormField<String>(
            initialValue: state.label.isEmpty ? null : state.label,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: AppStrings.datasetLabel,
            ),
            items: [
              for (final e in [
                ...ref.read(vocabularyRepositoryProvider).letters,
                ...ref.read(vocabularyRepositoryProvider).phrases,
              ])
                DropdownMenuItem(
                  value: e.filipino,
                  child: Text('${e.filipino} (${e.english})',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) {
              if (v != null) _labelController.text = v;
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              hintText: AppStrings.datasetLabelHint,
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!recording)
                FilledButton.icon(
                  icon: const Icon(Icons.fiber_manual_record),
                  label: const Text(AppStrings.recordStart),
                  onPressed: () async {
                    await recorder.start();
                    if (!mounted) return;
                    if (ref.read(datasetRecorderControllerProvider).phase ==
                        RecordingPhase.recording) {
                      await recorder
                          .startTake(_labelController.text);
                      // Light haptic on recording start (motion pass).
                      HapticFeedback.selectionClick();
                    }
                  },
                )
              else
                OutlinedButton.icon(
                  icon: const Icon(Icons.stop),
                  label: const Text(AppStrings.recordAbort),
                  onPressed: () async {
                    HapticFeedback.selectionClick();
                    await recorder.stopTake();
                    await recorder.stop();
                  },
                ),
              if (recording && state.takeActive)
                OutlinedButton.icon(
                  icon: const Icon(Icons.pause_circle_outline),
                  label: const Text(AppStrings.datasetStopTake),
                  onPressed: recorder.stopTake,
                )
              else if (recording)
                OutlinedButton.icon(
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text(AppStrings.datasetStartTake),
                  onPressed: () => recorder.startTake(_labelController.text),
                ),
            ],
          ),
          if (recording) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                // Pulsing recording dot (static under reduce-motion/tests).
                LoopPulse(
                  scale: 1.4,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${AppStrings.datasetRecording}: '
                    '${state.active.values.map((s) => '${s.handTag} ${s.rows} '
                            '${AppStrings.datasetRows}').join(' · ')}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text(AppStrings.datasetSessions,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final s in state.sessions)
            FadeIn(
              key: ValueKey('session-${s.sessionId}'),
              child: Card(
              child: ListTile(
                title: Text(
                    '${s.handTag} · ${s.signerId} · cal_id ${s.calibrationId}'),
                subtitle: Text(
                    '${s.rows} ${AppStrings.datasetRows} · '
                    '${s.droppedFrames} ${AppStrings.datasetDropped} · '
                    '${(s.sizeBytes / 1024).toStringAsFixed(1)} kB'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: AppStrings.datasetShare,
                      icon: const Icon(Icons.share_outlined),
                      onPressed: () async {
                        final paths = await recorder.pathsFor(s);
                        if (!mounted) return;
                        await SharePlus.instance.share(ShareParams(
                          files: [for (final p in paths) XFile(p)],
                        ));
                      },
                    ),
                    IconButton(
                      tooltip: AppStrings.datasetDelete,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => recorder.deleteSession(s),
                    ),
                  ],
                ),
              ),
              ),
            ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
