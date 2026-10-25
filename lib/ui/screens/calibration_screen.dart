import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/calibration_controller.dart';
import '../../application/providers.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/calibration_table.dart';
import '../../domain/models/telemetry_packet.dart';
import '../widgets/header_band.dart';

/// Firmware-driven 10-step calibration wizard (master §4). The step shown
/// is always the glove's STATUS.calibrationStep — the app never advances
/// locally. The glove is the authority; the summary renders the mirrored
/// CAL_INFO table only.
class CalibrationScreen extends ConsumerWidget {
  const CalibrationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calibrationControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.calibrationTitle)),
      body: Column(
        children: [
          HeaderBand(
            title: AppStrings.calibrationTitle,
            chipLabel: state.step > 0 ? 'step ${state.step}/10' : null,
          ),
          Expanded(
            child: switch (state.phase) {
              CalibrationPhase.idle => _Idle(state: state),
              CalibrationPhase.running => _Running(state: state),
              CalibrationPhase.done => _Done(state: state),
            },
          ),
        ],
      ),
    );
  }
}

class _Idle extends ConsumerWidget {
  const _Idle({required this.state});

  final CalibrationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final summary =
        state.calInfo == null ? null : CalibrationTable(state.calInfo!);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(AppStrings.calibrationPickHand,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final hand in const [GloveHand.left, GloveHand.right])
          Card(
            child: ListTile(
              leading: Icon(hand == GloveHand.left
                  ? Icons.back_hand_outlined
                  : Icons.back_hand),
              title: Text(hand == GloveHand.left
                  ? AppStrings.leftHandLabel
                  : AppStrings.rightHandLabel),
              subtitle: Text(
                  '${AppStrings.calibrationProfileSummary}: '
                  '${summary == null ? AppStrings.calibrationNoProfile : 'cal_id ${summary.calibrationId} · fw ${summary.firmwareVersion}'}'),
              onTap: () async {
                await ref
                    .read(calibrationControllerProvider.notifier)
                    .loadCached(hand);
                if (context.mounted) {
                  await ref
                      .read(calibrationControllerProvider.notifier)
                      .start(hand);
                }
              },
            ),
          ),
        if (summary != null) ...[
          const SizedBox(height: 12),
          _SummaryTable(table: summary),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(AppStrings.calibrationNoProfile,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ),
      ],
    );
  }
}

class _Running extends ConsumerWidget {
  const _Running({required this.state});

  final CalibrationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(calibrationControllerProvider.notifier);
    final finger = fingerNames[state.fingerIndex];
    final prompt = state.isFlatStep
        ? AppStrings.calibrationFlatPrompt(finger)
        : AppStrings.calibrationBendPrompt(finger);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LinearProgressIndicator(
          value: state.step == 0 ? 0 : state.step / 10,
        ),
        const SizedBox(height: 16),
        Text(
          state.step == 0
              ? AppStrings.calibrationStart
              : '${AppStrings.calibrationProfileSummary}: '
                  'step ${state.step}/10',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        Text(
          state.step == 0 ? AppStrings.calibrationStart : prompt,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (state.step == 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              AppStrings.calibrationFlatPrompt(fingerNames[0]),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        if (state.error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(state.error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer)),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          icon: const Icon(Icons.check_circle_outline),
          label: Text(state.capturePending
              ? AppStrings.calibrationCapturing
              : AppStrings.calibrationCapture),
          onPressed: (state.step == 0 || state.capturePending)
              ? null
              : controller.capture,
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: controller.cancel,
          child: const Text(AppStrings.calibrationAbort),
        ),
      ],
    );
  }
}

class _Done extends ConsumerWidget {
  const _Done({required this.state});

  final CalibrationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary =
        state.calInfo == null ? null : CalibrationTable(state.calInfo!);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Icon(Icons.check_circle, size: 48),
        const SizedBox(height: 8),
        Text(AppStrings.calibrationSavedTitle,
            style: Theme.of(context).textTheme.titleLarge),
        if (summary != null) ...[
          const SizedBox(height: 12),
          Text(
              'cal_id ${summary.calibrationId}'
              ' · fw ${summary.firmwareVersion}'
              ' · R_DIV ${summary.packet.rDiv.map((v) => v.toStringAsFixed(0)).join(', ')}',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          _SummaryTable(table: summary),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () =>
              ref.read(calibrationControllerProvider.notifier).resetToIdle(),
          child: const Text(AppStrings.calibrationDone),
        ),
      ],
    );
  }
}

/// Per-finger summary: valid ✓/✗, weak ⚠, flat Ω, 90° Ω, span counts
/// (master §4.4). Source: the mirrored CAL_INFO — nothing else.
class _SummaryTable extends StatelessWidget {
  const _SummaryTable({required this.table});

  final CalibrationTable table;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.4),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1.2),
        3: FlexColumnWidth(1.2),
        4: FlexColumnWidth(1),
      },
      children: [
        TableRow(children: [
          for (final h in ['Finger', 'Valid', 'Flat Ω', '90° Ω', 'Span'])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(h, style: Theme.of(context).textTheme.labelMedium),
            ),
        ]),
        for (final f in table.fingers)
          TableRow(children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(f.name),
            ),
            Text(f.valid ? '✓' : '✗',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: f.valid ? AppColors.success : scheme.error)),
            Text(f.flatOhm.toStringAsFixed(0),
                style: TalkhimikText.of(context).metric),
            Text(f.bent90Ohm.toStringAsFixed(0),
                style: TalkhimikText.of(context).metric),
            Text(f.weak ? '⚠ ${f.spanCounts}' : '${f.spanCounts}',
                style: f.weak
                    ? TalkhimikText.of(context)
                        .metric
                        ?.copyWith(color: AppColors.warning)
                    : TalkhimikText.of(context).metric),
          ]),
      ],
    );
  }
}
