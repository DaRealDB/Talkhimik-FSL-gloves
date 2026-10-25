import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Olive-lime header band with the deep-green diagonal corner — the shared
/// design-language element for panel headers across screens.
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
    final tokens = Theme.of(context).extension<TalkhimikTokens>() ??
        TalkhimikTokens.light;
    final band = ClipPath(
      clipper: const _CornerClipper(corner: 22),
      child: Container(
        color: tokens.header,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: tokens.headerText,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            if (chipLabel != null)
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tokens.headerDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    chipLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (onTap == null) return band;
    return InkWell(onTap: onTap, child: band);
  }
}

/// Cuts the top-right diagonal corner.
class _CornerClipper extends CustomClipper<Path> {
  const _CornerClipper({required this.corner});

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
  bool shouldReclip(_CornerClipper oldClipper) =>
      oldClipper.corner != corner;
}
