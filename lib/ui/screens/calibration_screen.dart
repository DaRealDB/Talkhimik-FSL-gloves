import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/calibration_controller.dart';
import '../../application/providers.dart';
import '../../core/strings/app_strings.dart';
import '../widgets/gating_card.dart';

/// FR-8: the guided calibration flow — intro/summary, prompted sample
/// signs, and the saved-profile review.
class CalibrationScreen extends ConsumerWidget {
  const CalibrationScreen({super.key});

  static const startButtonKey = Key('calibration-start-button');
  static const abortButtonKey = Key('calibration-abort-button');
  static const doneButtonKey = Key('calibration-done-button');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calibrationControllerProvider);
    final controller = ref.read(calibrationControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.calibrationTitle)),
      // The Done action stays reachable even with a long stats list.
      persistentFooterButtons: state.phase == CalibrationPhase.done
          ? [
              FilledButton(
                key: CalibrationScreen.doneButtonKey,
                onPressed: controller.resetToIdle,
                child: const Text(AppStrings.calibrationDone),
              ),
            ]
          : null,
      body: switch (state.phase) {
        CalibrationPhase.idle => _IdleView(state: state, ref: ref),
        CalibrationPhase.prompting => _PromptingView(state: state, ref: ref),
        CalibrationPhase.done => _DoneView(state: state, ref: ref),
      },
    );
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({required this.state, required this.ref});

  final CalibrationState state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final profile = state.profile;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.error != null) GatingCard(message: state.error!),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.calibrationIntroTitle,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text(AppStrings.calibrationIntroBody),
                const SizedBox(height: 8),
                Text(
                  '${state.repsPerPrompt} ${AppStrings.calibrationRepsOf} per '
                  'sign · '
                  '${ref.read(vocabularyRepositoryProvider).letters.length} '
                  'letters',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: CalibrationScreen.startButtonKey,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text(AppStrings.calibrationStart),
                  onPressed: () =>
                      ref.read(calibrationControllerProvider.notifier).start(),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.calibrationProfileSummary,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (profile == null)
                  const Text(AppStrings.calibrationNoProfile)
                else ...[
                  Text(
                    'Participant ${profile.participantId} · '
                    '${profile.savedAt.toLocal()}'.split('.').first,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${profile.stats.length} words · mean '
                    '${profile.overallMean.toStringAsFixed(1)}%',
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PromptingView extends StatelessWidget {
  const _PromptingView({required this.state, required this.ref});

  final CalibrationState state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final prompt = state.currentPrompt;
    final progress = (state.promptIndex +
            state.repsDone / state.repsPerPrompt) /
        state.prompts.length;
    return Column(
      children: [
        LinearProgressIndicator(value: progress),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Word ${state.promptIndex + 1} of ${state.prompts.length}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(AppStrings.calibrationSignPrompt),
                const SizedBox(height: 12),
                // Signer-facing prompt at large size (NFR-7).
                Text(
                  prompt?.filipino ?? '',
                  style: const TextStyle(fontSize: 72),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < state.repsPerPrompt; i++)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          i < state.repsDone
                              ? Icons.circle
                              : Icons.circle_outlined,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  state.lastSampleConfidence == null
                      ? '${AppStrings.calibrationLastSample}: —'
                      : '${AppStrings.calibrationLastSample}: '
                          '${state.lastSampleConfidence}%',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextButton(
            key: CalibrationScreen.abortButtonKey,
            onPressed: () =>
                ref.read(calibrationControllerProvider.notifier).abort(),
            child: const Text(AppStrings.calibrationAbort),
          ),
        ),
      ],
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({
    required this.state,
    required this.ref,
  });

  final CalibrationState state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final profile = state.profile;
    if (profile == null) return const SizedBox.shrink();
    final vocab = ref.read(vocabularyRepositoryProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(Icons.check_circle,
                    color: Colors.green.shade400, size: 40),
                const SizedBox(height: 8),
                Text(AppStrings.calibrationSavedTitle,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '${profile.stats.length} words · mean '
                  '${profile.overallMean.toStringAsFixed(1)}%',
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Column(
            children: [
              for (final stat in profile.stats)
                ListTile(
                  dense: true,
                  title: Text(
                    vocab.lookup(stat.wordId)?.filipino ??
                        '(word ${stat.wordId})',
                  ),
                  subtitle: Text(
                    '${stat.sampleCount} samples · mean '
                    '${stat.meanConfidence.toStringAsFixed(1)}% · '
                    '${stat.minConfidence}–${stat.maxConfidence}%',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
