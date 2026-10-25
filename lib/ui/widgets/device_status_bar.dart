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
  static const uncalibratedChipKey = Key('glove-uncalibrated-chip');
  static const connectButtonKey = Key('connect-glove-button');

  static String _phaseLabel(GloveConnectionPhase phase) => switch (phase) {
        GloveConnectionPhase.disconnected => AppStrings.disconnected,
        GloveConnectionPhase.scanning => 'Scanning…',
        GloveConnectionPhase.connecting => 'Connecting…',
        GloveConnectionPhase.discoveringServices => 'Discovering services…',
        GloveConnectionPhase.ready => AppStrings.connected,
        GloveConnectionPhase.reconnecting => AppStrings.reconnecting,
      };

  /// Firmware STATUS error codes (Code Reference §5.3); unmapped codes get
  /// the generic glove-error label.
  static String _errorLabel(int? code) =>
      switch (GloveErrorCode.fromCode(code)) {
        GloveErrorCode.none => '',
        GloveErrorCode.captureNotCalibrating => AppStrings.captureNotCalibrating,
        GloveErrorCode.unknownCommand => AppStrings.unknownCommand,
        GloveErrorCode.spanReject => AppStrings.spanReject,
        GloveErrorCode.resistanceFault => AppStrings.sensorFault,
        null => AppStrings.gloveError,
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
            // STATUS flags bit0: the glove streams placeholder angles until
            // the calibration wizard completes (Code Reference §5.3).
            if (status?.uncalibrated == true &&
                state.phase == GloveConnectionPhase.ready)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Chip(
                  key: uncalibratedChipKey,
                  label: const Text(AppStrings.uncalibrated),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            // The real glove connects explicitly (C-S1); the mock
            // auto-connects on the home screen.
            if (!isMock && state.phase == GloveConnectionPhase.disconnected)
              IconButton(
                key: connectButtonKey,
                tooltip: AppStrings.connectGlove,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.bluetooth_searching),
                onPressed: () async {
                  await ref.read(gloveControllerProvider.notifier).connect();
                  if (!context.mounted) return;
                  final error =
                      ref.read(gloveControllerProvider).connectError;
                  if (error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error)),
                    );
                  }
                },
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
