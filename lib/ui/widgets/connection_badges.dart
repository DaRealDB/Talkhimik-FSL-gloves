import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import '../../domain/models/hand_state.dart';

/// One merged connection-health line per hand (master §6.1, simplified):
/// freshness + packet loss + update rate in a single chip, plus a stale
/// chip and the hand-mismatch warning when they apply. Battery is hidden
/// until the firmware actually reports it (it always sends 0xFF today).
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

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _badge(
          context,
          '${AppStrings.freshness}: $freshness'
          ' · ${AppStrings.packetLoss}: '
          '${hand.packetLossPercent.toStringAsFixed(1)}%'
          ' · ${AppStrings.updateRate}: '
          '${hand.updateRateHz.toStringAsFixed(1)}/s',
          stale ? scheme.errorContainer : scheme.surfaceContainerHighest,
          stale ? scheme.onErrorContainer : scheme.onSurfaceVariant,
        ),
        if (stale)
          _badge(context, AppStrings.stale, scheme.errorContainer,
              scheme.onErrorContainer),
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
