import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../application/recognition_controller.dart';
import '../../core/strings/app_strings.dart';

/// Live readout of the phone recognizer's internals (C1.5): raw class,
/// confidence, votes, gate reason, last emission. This is the panel that
/// diagnoses "nothing appears" — check [RecognitionState.blockedReason]
/// first.
class RecognitionDebugPanel extends ConsumerWidget {
  const RecognitionDebugPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recog = ref.watch(recognitionControllerProvider);
    final theme = Theme.of(context);
    final caption = theme.textTheme.bodySmall;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.recogDebugTitle,
                style: theme.textTheme.titleSmall),
            Text(
              AppStrings.recogDebugStandInNote,
              style: caption?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (!recog.enabled)
              Text(AppStrings.recogDebugInactive, style: caption)
            else if (recog.pausedForLabelPackets)
              Text(AppStrings.recogDebugPaused, style: caption)
            else ...[
              if (recog.activeHand == null)
                Text(AppStrings.recogDebugNoHand, style: caption)
              else
                _rows(recog, theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rows(RecognitionState recog, ThemeData theme) {
    final label = theme.textTheme.labelMedium;
    final value = theme.textTheme.bodyMedium;
    Widget row(String name, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: label),
              Text(v, style: value),
            ],
          ),
        );

    final hand = recog.activeHand?.name ?? '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(AppStrings.recogDebugClassifier, recog.classifier),
        row(AppStrings.recogDebugModelVersion, recog.modelVersion),
        row(AppStrings.recogDebugActiveHand, hand),
        row(AppStrings.recogDebugRawClass, recog.rawClass ?? '—'),
        row(AppStrings.recogDebugRawLabel, recog.rawLabel ?? '—'),
        row(
          AppStrings.recogDebugConfidence,
          recog.rawConfidence?.toStringAsFixed(2) ?? '—',
        ),
        row(
          AppStrings.recogDebugTop3,
          recog.top3.isEmpty ? '—' : recog.top3.join(', '),
        ),
        row(AppStrings.recogDebugVotes, '${recog.voteCount}'),
        row(AppStrings.recogDebugGate, recog.blockedReason ?? '—'),
        row(AppStrings.recogDebugLastEmitted,
            recog.lastEmittedLabel ?? '—'),
      ],
    );
  }
}
