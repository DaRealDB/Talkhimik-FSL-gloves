import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';

/// One finger's "ticker" card (step 4b): ~72 × 200 dp, finger name + state
/// glyph left, a 5 s mini sparkline right (rolling buffer kept in this
/// widget — no domain changes), tabular live angle. The focused card
/// scales to 1.06.
class FingerTickerCard extends StatefulWidget {
  const FingerTickerCard({
    super.key,
    required this.name,
    required this.angleDeg,
    this.invalid = false,
    this.weak = false,
    this.focused = false,
    this.onTap,
  });

  final String name;
  final double angleDeg;
  final bool invalid;
  final bool weak;
  final bool focused;
  final VoidCallback? onTap;

  @override
  State<FingerTickerCard> createState() => _FingerTickerCardState();
}

class _FingerTickerCardState extends State<FingerTickerCard> {
  /// Last ~5 s of samples (25 at 5 Hz); the ticker holds the buffer.
  final List<double> _history = [];

  @override
  void didUpdateWidget(FingerTickerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.angleDeg != widget.angleDeg) {
      _history.add(widget.angleDeg);
      if (_history.length > 25) _history.removeAt(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = TalkhimikMotion.of(context);
    return AnimatedScale(
      scale: widget.focused ? 1.06 : 1.0,
      duration: motion.resolve(context, motion.quick),
      curve: Curves.easeOutCubic,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onTap,
        child: Container(
          width: 200,
          height: 84,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.focused ? scheme.primary : scheme.outlineVariant,
              width: widget.focused ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowBlue,
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.invalid
                            ? '${widget.name} ✗'
                            : (widget.weak
                                ? '${widget.name} ⚠'
                                : widget.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Text(
                        widget.invalid
                            ? '—'
                            : '${widget.angleDeg.round()}°',
                        style: TalkhimikText.of(context)
                            .metric
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: CustomPaint(
                  size: const Size(double.infinity, 40),
                  painter: _SparklinePainter(
                    values: _history,
                    color: widget.invalid
                        ? scheme.outline
                        : scheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Minimal 5 s sparkline (own implementation — no dependency).
class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      // Single sample: a flat dash so the card never looks broken.
      final y = size.height / 2;
      final paint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..strokeWidth = 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - (values[i] / 90).clamp(0.0, 1.0) * size.height;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
