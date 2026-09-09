import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/data_collection_controller.dart';
import '../../application/providers.dart';
import '../../core/strings/app_strings.dart';
import '../widgets/gating_card.dart';

/// FR-9: researcher record mode — intro with the consent/participant gate,
/// prompted labeled signs, and the run summary.
class CollectScreen extends ConsumerWidget {
  const CollectScreen({super.key});

  static const startButtonKey = Key('collect-start-button');
  static const skipButtonKey = Key('collect-skip-button');
  static const abortButtonKey = Key('collect-abort-button');
  static const doneButtonKey = Key('collect-done-button');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dataCollectionControllerProvider);
    final controller = ref.read(dataCollectionControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.recordModeTitle)),
      // The Done action stays reachable even with a long label list.
      persistentFooterButtons: state.phase == CollectionPhase.done
          ? [
              FilledButton(
                key: CollectScreen.doneButtonKey,
                onPressed: controller.resetToIdle,
                child: const Text(AppStrings.recordDone),
              ),
            ]
          : null,
      body: switch (state.phase) {
        CollectionPhase.idle => _IdleView(state: state, ref: ref),
        CollectionPhase.prompting => _PromptingView(state: state, ref: ref),
        CollectionPhase.done => _DoneView(state: state),
      },
    );
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({required this.state, required this.ref});

  final CollectionState state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
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
                Text(AppStrings.recordIntroTitle,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text(AppStrings.recordIntroBody),
                const SizedBox(height: 8),
                Text(
                  '${state.repsPerPrompt} ${AppStrings.recordSamples} per '
                  'sign · '
                  '${ref.read(vocabularyRepositoryProvider).letters.length} '
                  'labels',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: CollectScreen.startButtonKey,
                  icon: const Icon(Icons.fiber_manual_record),
                  label: const Text(AppStrings.recordStart),
                  onPressed: () => ref
                      .read(dataCollectionControllerProvider.notifier)
                      .start(),
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
                Text('Participant & consent',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Participant: '
                  '${settings.participantId.isEmpty ? '—' : settings.participantId}',
                ),
                const SizedBox(height: 4),
                Text(
                  'Consent: '
                  '${settings.consentGiven ? 'given' : 'not given'}',
                ),
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

  final CollectionState state;
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
            'Label ${state.promptIndex + 1} of ${state.prompts.length} · '
            '${state.sessionId}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(AppStrings.recordSignPrompt),
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
                      ? '${AppStrings.recordLastSample}: —'
                      : '${AppStrings.recordLastSample}: '
                          '${state.lastSampleConfidence}%',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                key: CollectScreen.skipButtonKey,
                icon: const Icon(Icons.skip_next_outlined),
                label: const Text(AppStrings.recordSkip),
                onPressed: () => ref
                    .read(dataCollectionControllerProvider.notifier)
                    .skip(),
              ),
              TextButton(
                key: CollectScreen.abortButtonKey,
                onPressed: () => ref
                    .read(dataCollectionControllerProvider.notifier)
                    .abort(),
                child: const Text(AppStrings.recordAbort),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({required this.state});

  final CollectionState state;

  @override
  Widget build(BuildContext context) {
    final labels = [
      for (final prompt in state.prompts)
        if ((state.counts[prompt.wordId] ?? 0) > 0) prompt,
    ];
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
                Text(AppStrings.recordDoneTitle,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '${state.totalRecorded} samples · '
                  '${state.skippedCount} skipped',
                ),
                const SizedBox(height: 4),
                Text(
                  '${AppStrings.recordSession}: ${state.sessionId}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.recordLogsHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        if (labels.isNotEmpty)
          Card(
            child: Column(
              children: [
                for (final prompt in labels)
                  ListTile(
                    dense: true,
                    title: Text(prompt.filipino),
                    subtitle: Text(
                      '${state.counts[prompt.wordId]} '
                      '${AppStrings.recordSamples}',
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
