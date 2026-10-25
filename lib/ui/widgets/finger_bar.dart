import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

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
                FractionallySizedBox(
                  widthFactor: (angleDeg / 90).clamp(0.0, 1.0),
                  child: Container(
                    height: 14,
                    color: color,
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
