import 'package:flutter/material.dart';

/// Roll / pitch / yaw tiles (master §6.1): 1 decimal, °; yaw is labelled
/// relative because it is gyro-only and drifts (no magnetometer).
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
        _tile(context, 'Roll', rollDeg),
        _tile(context, 'Pitch', pitchDeg),
        _tile(context, 'Yaw (relative)', yawDeg),
      ],
    );
  }

  Widget _tile(BuildContext context, String label, double value) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
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
      ),
    );
  }
}
