import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';

/// One finger's 0–90° angle as a pill progress bar with a numeric label
/// (master §6.1, design refresh). Invalid = hatched/dimmed; weak = amber.
class FingerBar extends StatelessWidget {
  const FingerBar({
    super.key,
    required this.name,
    required this.angleDeg,
    this.invalid = false,
    this.weak = false,
  });

  final String name;
  final double angleDeg;
  final bool invalid;
  final bool weak;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = invalid
        ? scheme.outline
        : weak
            ? AppColors.warning
            : scheme.tertiary;

    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            invalid ? '$name ✗' : (weak ? '$name ⚠' : name),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(
                  height: 14,
                  color: scheme.surfaceContainerHighest,
                ),
                // Animated fill along the gradient direction: the bar
                // eases to new values (the pose low-pass already smooths
                // telemetry; this animates the visual step).
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: (angleDeg / 90).clamp(0.0, 1.0)),
                  duration: TalkhimikMotion.of(context).resolve(
                      context, TalkhimikMotion.values.quick),
                  curve: Curves.easeOutCubic,
                  builder: (context, fraction, _) =>
                      FractionallySizedBox(
                    widthFactor: fraction,
                    child: AnimatedContainer(
                      height: 14,
                      duration: TalkhimikMotion.of(context).resolve(
                          context, TalkhimikMotion.values.quick),
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            invalid ? '' : '${angleDeg.round()}°',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
