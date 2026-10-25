import 'package:flutter/material.dart';

import '../../core/constants/confidence.dart';
import '../../core/theme/app_theme.dart';

/// Color-coded confidence pill: green ≥80 / amber 60–79 / red <60 (SRS FR-4;
/// thresholds live in core/constants/confidence.dart).
class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge({
    super.key,
    required this.confidence,
    required this.level,
  });

  final int confidence;
  final ConfidenceLevel level;

  /// Public so tests (and the FR-4 documentation) can assert the mapping.
  static Color colorFor(ConfidenceLevel level) => switch (level) {
        ConfidenceLevel.high => AppColors.confidenceGreen,
        ConfidenceLevel.medium => AppColors.confidenceAmber,
        ConfidenceLevel.low => AppColors.confidenceRed,
      };

  Color get _color => colorFor(level);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Shape cue beyond color (design refresh): outline badge + dot.
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            '$confidence%',
            style: TalkhimikText.of(context).badge?.copyWith(color: _color),
          ),
        ],
      ),
    );
  }
}
