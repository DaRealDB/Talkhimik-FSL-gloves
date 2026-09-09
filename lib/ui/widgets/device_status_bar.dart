import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/strings/app_strings.dart';
import '../../data/glove/glove_connection.dart';
import '../../domain/models/device_status.dart';

/// One-line connection status: pairing phase, glove name (mock vs real),
/// battery, error states, and the "connection lost" banner (SRS FR-12,
/// C-S5, NFR-9).
class DeviceStatusBar extends ConsumerWidget {
  const DeviceStatusBar({super.key});

  static const connectionLostBannerKey = Key('connection-lost-banner');
  static const batteryKey = Key('battery-indicator');
  static const errorChipKey = Key('glove-error-chip');

  static String _phaseLabel(GloveConnectionPhase phase) => switch (phase) {
        GloveConnectionPhase.disconnected => AppStrings.disconnected,
        GloveConnectionPhase.scanning => 'Scanning…',
        GloveConnectionPhase.connecting => 'Connecting…',
        GloveConnectionPhase.discoveringServices => 'Discovering services…',
        GloveConnectionPhase.ready => AppStrings.connected,
        GloveConnectionPhase.reconnecting => AppStrings.reconnecting,
      };

  static String _errorLabel(int? code) =>
      switch (GloveErrorCode.fromCode(code)) {
        GloveErrorCode.none => '',
        GloveErrorCode.sensorFault => AppStrings.sensorFault,
        GloveErrorCode.lowBattery => AppStrings.lowBattery,
        GloveErrorCode.powerFault => AppStrings.powerFault,
        GloveErrorCode.bleFault => AppStrings.bleFault,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gloveControllerProvider);
    final isMock = ref.watch(gloveIsMockProvider);
    final scheme = Theme.of(context).colorScheme;
    final status = state.status;

    final dotColor = switch (state.phase) {
      GloveConnectionPhase.ready => Colors.green,
      GloveConnectionPhase.disconnected => scheme.outline,
      _ => Colors.amber,
    };

    final battery = status?.batteryPercent;
    final batteryLow = battery != null && battery < 15;
    final errorLabel = _errorLabel(status?.lastErrorCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${isMock ? AppStrings.mockGloveName : AppStrings.realGloveName}'
                ' · ${_phaseLabel(state.phase)}',
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (battery != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  key: batteryKey,
                  children: [
                    Icon(
                      batteryLow
                          ? Icons.battery_alert
                          : Icons.battery_full_outlined,
                      size: 16,
                      color: batteryLow ? scheme.error : scheme.onSurfaceVariant,
                    ),
                    Text(
                      '$battery%',
                      style: TextStyle(
                        color: batteryLow ? scheme.error : null,
                        fontWeight:
                            batteryLow ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            if (errorLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Chip(
                  key: errorChipKey,
                  label: Text(errorLabel),
                  labelStyle: TextStyle(color: scheme.onErrorContainer),
                  backgroundColor: scheme.errorContainer,
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        if (state.connectionLost)
          Container(
            key: connectionLostBannerKey,
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              AppStrings.connectionLost,
              style: TextStyle(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
