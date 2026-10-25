import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'anim.dart';

/// Header band in the signature language: a sky→azure diagonal gradient
/// fill with a 45° end cap, the fold-shadow gradient where the cap meets
/// the body, navy title text (AA), and a glass chip.
class HeaderBand extends StatelessWidget {
  const HeaderBand({
    super.key,
    required this.title,
    this.chipLabel,
    this.onTap,
  });

  final String title;

  /// Small pill in the band (calibration id, counts, …).
  final String? chipLabel;

  /// Optional action (e.g. the band doubles as a button).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final band = ClipPath(
      // 45° diagonal end cap on the right (the logo's slab language).
      clipper: const _DiagonalEndCap(corner: 26),
      child: Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        padding: const EdgeInsets.fromLTRB(14, 10, 40, 10),
        child: Stack(
          children: [
            // Fold shadow where the cap meets the band.
            Positioned(
              right: 26,
              top: 0,
              bottom: 0,
              child: Container(
                width: 10,
                decoration: const BoxDecoration(
                    gradient: AppColors.foldGradient),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.navyText,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (chipLabel != null)
                  Flexible(
                    child: KeyedOneShot(
                      // One-shot highlight when the chip content changes
                      // (e.g. calibration_id bump on Live).
                      trigger: chipLabel,
                      builder: (t, context) => Transform.scale(
                        scale: 0.94 + 0.06 * t.value,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Color.lerp(Colors.white,
                                AppColors.tintSky, t.value),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            chipLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppColors.navyText),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return band;
    return InkWell(onTap: onTap, child: band);
  }
}

/// Cuts a 45° diagonal end cap on the right.
class _DiagonalEndCap extends CustomClipper<Path> {
  const _DiagonalEndCap({required this.corner});

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
  bool shouldReclip(_DiagonalEndCap oldClipper) =>
      oldClipper.corner != corner;
}

