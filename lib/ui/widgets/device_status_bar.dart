import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/glove/glove_connection.dart';
import '../../data/glove/mock_glove_connection.dart';
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
  static const rightSourceChipKey = Key('right-source-chip');

  static bool _busy(GloveConnectionPhase phase) => switch (phase) {
        GloveConnectionPhase.scanning ||
        GloveConnectionPhase.connecting ||
        GloveConnectionPhase.discoveringServices ||
        GloveConnectionPhase.reconnecting =>
          true,
        _ => false,
      };

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
    // Aggregate for the second glove (master §7.3): the bar keeps its
    // single-glove look while only the left is connected, and adds the
    // right hand only when it is actually up.
    final rightState = ref.watch(rightGloveControllerProvider);
    // Per-hand source indicator (bugfix FR-12): never ambiguous whether a
    // hand is the demo or the real glove — watches the provider so a live
    // Force-mock swap updates the labels.
    final isMock = ref.watch(gloveIsMockProvider);
    final rightIsMock =
        ref.watch(rightGloveConnectionProvider) is MockGloveConnection;
    final scheme = Theme.of(context).colorScheme;
    final status = state.status;
    final rightStatus = rightState.status;

    final leftReady = state.phase == GloveConnectionPhase.ready;
    final rightReady = rightState.phase == GloveConnectionPhase.ready;
    final anyBusy = _busy(state.phase) || _busy(rightState.phase);

    final dotColor = (leftReady || rightReady)
        ? AppColors.success
        : anyBusy
            ? AppColors.warning
            : scheme.outline;

    final battery = status?.batteryPercent;
    final batteryLow = battery != null && battery < 15;
    final errorLabel = _errorLabel(status?.lastErrorCode);
    final uncalibrated = (status?.uncalibrated ?? false) ||
        (rightStatus?.uncalibrated ?? false);
    final gloveLabel = isMock ? AppStrings.mockGloveName : AppStrings.realGloveName;

    final phaseText = (leftReady && rightReady)
        ? '${_phaseLabel(state.phase)} · L + R'
        : rightReady
            ? '${AppStrings.connected} (R)'
            : _phaseLabel(state.phase);

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
                '$gloveLabel · $phaseText',
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Trailing cluster wraps instead of overflowing at narrow
            // widths / large text scales (typography pass).
            Flexible(
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (battery != null)
                    Row(
                      key: batteryKey,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          batteryLow
                              ? Icons.battery_alert
                              : Icons.battery_full_outlined,
                          size: 16,
                          color: batteryLow
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                        ),
                        Text(
                          '$battery%',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: batteryLow ? scheme.error : null,
                                fontWeight: batteryLow
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                        ),
                      ],
                    ),
                  if (errorLabel.isNotEmpty)
                    Chip(
                      key: errorChipKey,
                      label: Text(errorLabel),
                      labelStyle: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: scheme.onErrorContainer),
                      backgroundColor: scheme.errorContainer,
                      visualDensity: VisualDensity.compact,
                    ),
                  // STATUS flags bit0: the glove streams placeholder angles
                  // until the calibration wizard completes (§5.3).
                  if (uncalibrated && (leftReady || rightReady))
                    Chip(
                      key: uncalibratedChipKey,
                      label: const Text(AppStrings.uncalibrated),
                      visualDensity: VisualDensity.compact,
                    ),
                  // The right glove's source, shown once it is up — the
                  // left glove's source is the main label.
                  if (rightReady)
                    Chip(
                      key: rightSourceChipKey,
                      label: Text(
                          'R · ${rightIsMock ? AppStrings.mockGloveName : AppStrings.realGloveName}'),
                      visualDensity: VisualDensity.compact,
                    ),
                  // The real glove connects explicitly (C-S1); the mock
                  // auto-connects on the home screen.
                  if (!isMock &&
                      state.phase == GloveConnectionPhase.disconnected)
                    IconButton(
                      key: connectButtonKey,
                      tooltip: AppStrings.connectGlove,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.bluetooth_searching),
                      onPressed: () async {
                        await ref
                            .read(gloveControllerProvider.notifier)
                            .connect();
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
            ),
          ],
        ),
        if (state.connectionLost || rightState.connectionLost)
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
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
