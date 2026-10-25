import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';
import '../../data/glove/glove_connection.dart';
import 'anim.dart';

/// ONE status pill (design refresh): filled brand-blue dot + one short
/// label, a neutral "Demo" tag only in mock mode, battery ONLY when the
/// glove reports a real value (0xFF = unknown → hidden, never a
/// placeholder). Tapping opens the per-hand connection details sheet.
/// A banner slot below shows warnings with the diagonal end cap.
class DeviceStatusBar extends ConsumerWidget {
  const DeviceStatusBar({super.key});

  static const connectionLostBannerKey = Key('connection-lost-banner');
  static const batteryKey = Key('battery-indicator');
  static const errorChipKey = Key('glove-error-chip');
  static const uncalibratedChipKey = Key('glove-uncalibrated-chip');
  static const connectButtonKey = Key('connect-glove-button');
  static const statusPillKey = Key('status-pill');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gloveControllerProvider);
    final rightState = ref.watch(rightGloveControllerProvider);
    final isMock = ref.watch(gloveIsMockProvider);
    final scheme = Theme.of(context).colorScheme;

    final leftReady = state.phase == GloveConnectionPhase.ready;
    final rightReady = rightState.phase == GloveConnectionPhase.ready;
    final anyBusy = _busy(state.phase) || _busy(rightState.phase);
    final connected = leftReady || rightReady;

    final label = !connected && anyBusy
        ? AppStrings.statusConnecting
        : leftReady && rightReady
            ? AppStrings.statusBothConnected
            : leftReady || rightReady
                ? AppStrings.statusOneConnected
                : AppStrings.statusNotConnected;

    final battery = state.status?.batteryPercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The status pill — tap for per-hand details + reconnect.
        InkWell(
          key: statusPillKey,
          borderRadius: BorderRadius.circular(999),
          onTap: () => _showDetails(context, ref),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowBlue,
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Filled brand-blue dot = connected; pulse while busy.
                LoopPulse(
                  scale: 1.3,
                  pulse: anyBusy && !connected,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: connected ? scheme.primary : scheme.outline,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: TalkhimikMotion.of(context).resolve(
                        context, TalkhimikMotion.values.quick),
                    child: Text(
                      label,
                      key: ValueKey(label),
                      style: Theme.of(context).textTheme.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Neutral "Demo" tag — mock mode only; never brand blue.
                if (isMock)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      AppStrings.demoTag,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                // Battery only when the glove reports a real value.
                if (battery != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Row(
                      key: batteryKey,
                      children: [
                        Icon(
                          battery < 15
                              ? Icons.battery_alert
                              : Icons.battery_full_outlined,
                          size: 16,
                          color: battery < 15
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                        ),
                        Text(
                          '$battery%',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: battery < 15 ? scheme.error : null,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Banner slot: one warning at a time (connection lost /
        // uncalibrated / low battery), diagonal end cap.
        if (state.connectionLost || rightState.connectionLost)
          _Banner(
            key: connectionLostBannerKey,
            text: AppStrings.connectionLost,
            colors: [scheme.errorContainer, scheme.error],
            textColor: scheme.onErrorContainer,
          )
        else if ((state.status?.uncalibrated ?? false) ||
            (rightState.status?.uncalibrated ?? false))
          _Banner(
            key: uncalibratedChipKey,
            text: AppStrings.uncalibratedBanner,
            colors: [AppColors.azure, AppColors.navy],
            textColor: AppColors.navyText,
          )
        else if (state.status?.hasError ?? false)
          _Banner(
            key: errorChipKey,
            text: AppStrings.gloveError,
            colors: [scheme.errorContainer, scheme.error],
            textColor: scheme.onErrorContainer,
          ),
      ],
    );
  }

  static bool _busy(GloveConnectionPhase phase) => switch (phase) {
        GloveConnectionPhase.scanning ||
        GloveConnectionPhase.connecting ||
        GloveConnectionPhase.discoveringServices ||
        GloveConnectionPhase.reconnecting =>
          true,
        _ => false,
      };

  /// Per-hand status + reconnect, in a bottom sheet (progressive
  /// disclosure — BLE detail stays one tap away, not on the surface).
  void _showDetails(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => const _DetailsSheet(),
    );
  }
}

class _DetailsSheet extends ConsumerWidget {
  const _DetailsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final left = ref.watch(gloveControllerProvider);
    final right = ref.watch(rightGloveControllerProvider);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          Text(AppStrings.connectionDetails,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _handRow(context, AppStrings.leftHandTitle, left.phase, () => ref
              .read(gloveControllerProvider.notifier)
              .connect()),
          _handRow(context, AppStrings.rightHandTitle, right.phase, () => ref
              .read(rightGloveControllerProvider.notifier)
              .connect()),
        ],
      ),
    );
  }

  Widget _handRow(BuildContext context, String hand,
      GloveConnectionPhase phase, VoidCallback onReconnect) {
    return ListTile(
      title: Text(hand),
      subtitle: Text(phase.name),
      trailing: phase == GloveConnectionPhase.ready
          ? const Icon(Icons.check_circle, color: AppColors.success)
          : OutlinedButton(
              onPressed: onReconnect,
              child: const Text(AppStrings.connectGlove),
            ),
    );
  }
}

/// 40 dp banner strip with the 45° diagonal end cap (signature shape).
class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.text,
    required this.colors,
    required this.textColor,
  });

  final String text;
  final List<Color> colors;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    // Banners slide + fade in (motion pass).
    return FadeIn(
      offset: 10,
      child: ClipPath(
        clipper: const _BannerCap(corner: 22),
        child: Container(
          height: 40,
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: textColor, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

/// 45° diagonal cap on the right of the banner.
class _BannerCap extends CustomClipper<Path> {
  const _BannerCap({required this.corner});

  final double corner;

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width - corner, 0)
    ..lineTo(size.width, corner)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(_BannerCap oldClipper) => oldClipper.corner != corner;
}
