import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/constants/gatt_ids.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/glove/ble_diagnostics.dart';
import '../../domain/models/telemetry_packet.dart';

/// Settings → Developer → BLE diagnostics (fix B1): per-hand live link
/// values — phase, bond, MTU, characteristics, notify results, frame
/// counts, decode rejections by reason, last error, telemetry freshness.
class BleDiagnosticsPanel extends ConsumerWidget {
  const BleDiagnosticsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final map = ref.watch(bleDiagnosticsProvider);
    return ExpansionTile(
      title: const Text(AppStrings.bleDiagnosticsTitle),
      tilePadding: EdgeInsets.zero,
      children: [
        for (final hand in const [GloveHand.left, GloveHand.right])
          _handSection(context, hand, map[hand]!),
      ],
    );
  }

  Widget _handSection(
      BuildContext context, GloveHand hand, BleDiagnostics d) {
    final name = hand == GloveHand.left
        ? AppStrings.leftHandTitle
        : AppStrings.rightHandTitle;
    return ListenableBuilder(
      listenable: d,
      builder: (context, _) {
        final mtu = d.mtu;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              _row(context, AppStrings.diagPhase, d.phase.name),
              _row(context, AppStrings.diagBond, d.bondState),
              _row(context, AppStrings.diagMtu,
                  mtu == null ? '—' : '$mtu (attempts ${d.mtuAttempts})'),
              _row(context, AppStrings.diagChars,
                  d.characteristicsFound.entries
                      .map((e) => '${e.key.substring(0, 8)}…:'
                          '${e.value ? '✓' : '✗'}')
                      .join('  ')),
              _row(context, AppStrings.diagNotify, d.notifyResults.entries
                  .map((e) => '${e.key.substring(0, 8)}…:${e.value}')
                  .join('  ')),
              _row(context, AppStrings.diagFrames,
                  'telemetry ${d.notifyCounts[GattIds.telemetry] ?? 0}'
                      ' · status ${d.notifyCounts[GattIds.deviceStatus] ?? 0}'
                      ' · cal ${d.notifyCounts[GattIds.calInfo] ?? 0}'),
              _row(context, AppStrings.diagLastLen,
                  d.lastPayloadLength?.toString() ?? '—'),
              _row(
                  context,
                  AppStrings.diagRejects,
                  'length ${d.rejectsLength} · exception '
                      '${d.rejectsException} · hand ${d.rejectsHandMismatch}'),
              _row(context, AppStrings.diagLastError, d.lastError ?? '—'),
              _row(context, AppStrings.diagFreshness,
                  d.secondsSinceTelemetry()?.toString() ?? '—'),
            ],
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            Expanded(
              child: Text(value,
                  style: TalkhimikText.of(context).id),
            ),
          ],
        ),
      );
}
