import 'package:flutter/material.dart';

/// Roll / pitch / yaw as rounded chips (master §6.1, design refresh): 1
/// decimal, °; yaw is labelled relative because it is gyro-only and drifts
/// (no magnetometer).
class ImuTiles extends StatelessWidget {
  const ImuTiles({
    super.key,
    required this.rollDeg,
    required this.pitchDeg,
    required this.yawDeg,
  });

  final double rollDeg;
  final double pitchDeg;
  final double yawDeg;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _chip(context, 'Roll', rollDeg),
        _chip(context, 'Pitch', pitchDeg),
        _chip(context, 'Yaw (relative)', yawDeg),
      ],
    );
  }

  Widget _chip(BuildContext context, String label, double value) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(
              '${value.toStringAsFixed(1)}°',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}
