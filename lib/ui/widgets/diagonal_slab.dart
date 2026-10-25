import 'package:flutter/material.dart';

/// The signature 45° diagonal slab — a decorative parallelogram echoing
/// the reference icon's geometry. Lives on surfaces and hero backgrounds,
/// never inside tap targets (interactive controls stay pills).
class DiagonalSlab extends StatelessWidget {
  const DiagonalSlab({
    super.key,
    required this.width,
    required this.height,
    this.color = const Color(0x1454C5F8), // 8 % sky — background motif
    this.skewX = 0.4,
    this.alignment = Alignment.bottomLeft,
    this.child,
  });

  final double width;
  final double height;

  /// Slab fill (tinted blues only).
  final Color color;

  /// Horizontal shear: 0.4 ≈ 45°.
  final double skewX;

  final Alignment alignment;

  /// Optional content clipped to the slab (loaders, illustrations).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform(
        transform: Matrix4.identity()..setEntry(3, 1, skewX),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: color),
          child: child,
        ),
      ),
    );
  }
}

/// A diagonal-slab backdrop: a few large low-contrast slabs behind content
/// (Home/Live heroes). Purely decorative — never reduces text contrast.
class SlabBackdrop extends StatelessWidget {
  const SlabBackdrop({super.key, this.variant = 0});

  /// Which arrangement of slabs to draw (deterministic per screen).
  final int variant;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            // Two large slabs, offset by the variant for per-screen variety.
            DiagonalSlab(
              width: constraints.maxWidth * (variant.isEven ? 0.9 : 0.7),
              height: 180,
              color: const Color(0x1054C5F8), // 6 % sky
              alignment: Alignment.topRight,
            ),
            DiagonalSlab(
              width: constraints.maxWidth * (variant.isOdd ? 0.9 : 0.6),
              height: 140,
              color: const Color(0x0F29B6F6), // 6 % azure
              alignment: Alignment.bottomLeft,
            ),
          ],
        ),
      ),
    );
  }
}
