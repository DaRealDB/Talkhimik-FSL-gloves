import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import '../../domain/models/hand_state.dart';

/// Connection-health badges per hand (master §6.1): freshness (stale after
/// 500 ms), packet-loss % (rolling), update rate, and battery ("—" for
/// 0xFF, which the firmware always sends).
class ConnectionBadges extends StatelessWidget {
  const ConnectionBadges({super.key, required this.hand, required this.now});

  final HandState hand;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stale = hand.isStaleAt(now);
    final freshness = hand.lastFrameAt == null
        ? '—'
        : '${now.difference(hand.lastFrameAt!).inMilliseconds} ms';
    final battery = hand.status?.batteryPercent;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _badge(
          context,
          '${AppStrings.freshness}: $freshness',
          stale ? scheme.errorContainer : scheme.surfaceContainerHighest,
          stale ? scheme.onErrorContainer : scheme.onSurfaceVariant,
        ),
        if (stale)
          _badge(context, AppStrings.stale, scheme.errorContainer,
              scheme.onErrorContainer),
        _badge(
          context,
          '${AppStrings.packetLoss}: '
          '${hand.packetLossPercent.toStringAsFixed(1)}%',
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
        _badge(
          context,
          '${AppStrings.updateRate}: '
          '${hand.updateRateHz.toStringAsFixed(1)}/s',
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
        _badge(
          context,
          '${AppStrings.battery}: ${battery?.toString() ?? '—'}%',
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
        if (hand.handMismatch)
          _badge(context, AppStrings.handMismatchWarning, scheme.errorContainer,
              scheme.onErrorContainer),
      ],
    );
  }

  Widget _badge(BuildContext context, String text, Color bg, Color fg) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: TextStyle(color: fg, fontSize: 12)),
      );
}
