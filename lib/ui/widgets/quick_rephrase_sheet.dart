import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/models/gesture_result.dart';
import '../../domain/models/transcript_entry.dart';

/// FR-5: bottom sheet with the top-3 alternative predictions for a bubble.
/// One tap corrects the transcript (and logs the correction for the
/// inter-rater analysis).
class QuickRephraseSheet extends ConsumerWidget {
  const QuickRephraseSheet({
    super.key,
    required this.entry,
    required this.alternatives,
  });

  final TranscriptEntry entry;
  final List<AlternativePrediction> alternatives;

  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required TranscriptEntry entry,
    required List<AlternativePrediction> alternatives,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (_) => QuickRephraseSheet(
        entry: entry,
        alternatives: alternatives,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocab = ref.read(vocabularyRepositoryProvider);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Did you mean…', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Tap an option to correct "${entry.textFor('fil')}".',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (alternatives.isEmpty)
              const Text('No alternatives available.')
            else
              for (final alt in alternatives)
                _AlternativeTile(
                  text: vocab.lookup(alt.wordId)?.filipino ?? '(word ${alt.wordId})',
                  confidence: alt.confidence,
                  onTap: () {
                    ref
                        .read(transcriptControllerProvider.notifier)
                        .correctEntry(entry.id, alt.wordId);
                    Navigator.of(context).pop();
                  },
                ),
          ],
        ),
      ),
    );
  }
}

class _AlternativeTile extends StatelessWidget {
  const _AlternativeTile({
    required this.text,
    required this.confidence,
    required this.onTap,
  });

  final String text;
  final int confidence;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.swap_horiz),
      title: Text(text),
      trailing: Text(
        '$confidence%',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: onTap,
    );
  }
}
