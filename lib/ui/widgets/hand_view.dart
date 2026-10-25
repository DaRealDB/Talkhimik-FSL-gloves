import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';
import '../../domain/models/telemetry_packet.dart';
import 'header_band.dart';

/// Plain pose values for [HandPainter] — no business logic here (master §6.2).
class HandPose {
  const HandPose({
    required this.fingerDeg,
    this.rollDeg = 0,
    this.pitchDeg = 0,
    this.yawDeg = 0,
    required this.handedness,
    this.invalidMask = 0,
  });

  /// Flex 0–90° per finger, order thumb..pinky.
  final List<double> fingerDeg;

  /// IMU orientation in degrees (yaw is gyro-only / relative).
  final double rollDeg;
  final double pitchDeg;
  final double yawDeg;

  final GloveHand handedness;

  /// Bit0..4 = finger invalid (drawn outline-only).
  final int invalidMask;

  HandPose lerpTo(HandPose target, double t) => HandPose(
        fingerDeg: [
          for (var i = 0; i < fingerDeg.length; i++)
            fingerDeg[i] + (target.fingerDeg[i] - fingerDeg[i]) * t,
        ],
        rollDeg: rollDeg + (target.rollDeg - rollDeg) * t,
        pitchDeg: pitchDeg + (target.pitchDeg - pitchDeg) * t,
        yawDeg: yawDeg + (target.yawDeg - yawDeg) * t,
        handedness: handedness,
        invalidMask: target.invalidMask,
      );
}

/// One hand's full Live panel (design refresh): olive-lime header band with
/// the deep-green diagonal corner + calibration chip, then the animated
/// hand with per-finger badges (initial + live angle).
class HandView extends StatefulWidget {
  const HandView({
    super.key,
    required this.target,
    this.title,
    this.chipLabel,
    this.uncalibrated = false,
    this.stale = false,
  });

  /// Latest pose from telemetry (the view animates toward it).
  final HandPose target;

  /// Header band title ("Left hand" / "Right hand").
  final String? title;

  /// Calibration chip text shown in the header band (cal_id · firmware).
  final String? chipLabel;

  /// Desaturates the hand and shows the "Uncalibrated" label.
  final bool uncalibrated;

  /// Freezes the hand at 40 % opacity (disconnected / no frames).
  final bool stale;

  @override
  State<HandView> createState() => _HandViewState();
}

class _HandViewState extends State<HandView>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  late HandPose _current;

  @override
  void initState() {
    super.initState();
    _current = widget.target;
    // Low-pass toward the target: v += (target − v) × 0.35 per tick
    // (master §6.2). "Reduce motion" accessibility: jump straight to the
    // target instead of animating.
    _ticker = createTicker((_) {
      if (!mounted) return;
      final disableAnimations = MediaQuery.disableAnimationsOf(context);
      setState(() {
        _current = disableAnimations
            ? widget.target
            : _current.lerpTo(widget.target, 0.35);
      });
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<TalkhimikTokens>() ??
        TalkhimikTokens.light;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HeaderBand(title: widget.title ?? '', chipLabel: widget.chipLabel),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [scheme.surface, scheme.surfaceContainerHighest],
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
          ),
          child: AnimatedOpacity(
            opacity: widget.stale ? 0.4 : 1,
            duration: TalkhimikMotion.of(context)
                .resolve(context, TalkhimikMotion.values.quick),
            child: RepaintBoundary(
              child: CustomPaint(
                size: const Size(220, 220),
                painter: HandPainter(
                  pose: _current,
                  uncalibrated: widget.uncalibrated,
                  tokens: tokens,
                  text: TalkhimikText.of(context),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pure renderer for one hand (master §6.2, design refresh):
/// gradient fingers (neutral → lime with flexion), forest outline, soft
/// shadow, per-finger circular badges (initial + live angle).
class HandPainter extends CustomPainter {
  HandPainter({
    required this.pose,
    this.uncalibrated = false,
    required this.tokens,
    required this.text,
  });

  final HandPose pose;
  final bool uncalibrated;
  final TalkhimikTokens tokens;

  /// App typography styles for the badge text (never hard-coded sizes).
  final TalkhimikText text;

  static const _fingerLengths = [0.85, 1.0, 1.0, 0.9, 0.7]; // relative
  static const _baseAngles = [-38.0, -14.0, 8.0, 30.0, 52.0]; // deg from up
  static const _initials = ['T', 'P', 'M', 'R', 'P'];

  /// Fingertip positions in right-hand local space (badge anchors + tests).
  /// The left hand is drawn mirrored and badges are drawn AFTER the mirror
  /// transform so their text never flips.
  static List<Offset> fingerTipOffsets(Size size, HandPose pose) {
    final center = Offset(size.width / 2, size.height * 0.55);
    final palmRadius = math.min(size.width, size.height) * 0.16;
    final tips = <Offset>[];
    for (var i = 0; i < 5; i++) {
      final segments = i == 0 ? 2 : 3; // thumb: 2 segments across the palm
      final flex = pose.fingerDeg[i].clamp(0.0, 90.0) * math.pi / 180;
      var angle = _baseAngles[i] * math.pi / 180;
      var point = Offset(center.dx, center.dy - palmRadius * 0.7);
      for (var j = 0; j < segments; j++) {
        angle += flex / segments;
        final len = palmRadius * _fingerLengths[i] * 0.62;
        point += Offset(math.sin(angle) * len, -math.cos(angle) * len);
      }
      tips.add(point);
    }
    return tips;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.55);
    final palmRadius = math.min(size.width, size.height) * 0.16;
    final tips = fingerTipOffsets(size, pose);

    // Clamp tilt so the hand never leaves the canvas.
    final roll = pose.rollDeg.clamp(-35.0, 35.0) * math.pi / 180;
    final pitch = pose.pitchDeg.clamp(-35.0, 35.0) * math.pi / 180;
    final yaw = pose.yawDeg * math.pi / 180;
    final left = pose.handedness == GloveHand.left;

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = tokens.headerDark;
    final shadowColor = Colors.black.withValues(alpha: 0.22);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    // Left hand = right hand mirrored (same painter).
    if (left) canvas.scale(-1, 1);
    // yaw in-plane, roll/pitch as a mild perspective-ish skew.
    canvas.rotate(yaw);
    canvas.transform(Float64List.fromList([
      1,
      math.sin(roll) * 0.25,
      0,
      0, //
      math.sin(pitch) * 0.25,
      1,
      0,
      0, //
      0,
      0,
      1,
      0, //
      0,
      0,
      0,
      1,
    ]));

    // Soft drop shadow under the palm (reference card style).
    final palmRect = Rect.fromCenter(
        center: Offset.zero, width: palmRadius * 1.9, height: palmRadius * 2.2);
    final palmRRect =
        RRect.fromRectAndRadius(palmRect, Radius.circular(palmRadius * 0.8));
    canvas.drawShadow(Path()..addRRect(palmRRect), shadowColor, 6, true);

    // Palm fill + short wrist.
    canvas.drawRRect(palmRRect, Paint()..color = _palm);
    canvas.drawLine(Offset(0, palmRadius * 1.1), Offset(0, palmRadius * 1.7),
        outline);

    for (var i = 0; i < 5; i++) {
      final invalid = pose.invalidMask & (1 << i) != 0;
      final flex = pose.fingerDeg[i].clamp(0.0, 90.0);
      final segments = i == 0 ? 2 : 3;
      var angle = _baseAngles[i] * math.pi / 180;
      var point = Offset(0, -palmRadius * 0.7);
      // Fill gradient: neutral at low bend → lime at full flexion.
      final fillColor =
          Color.lerp(tokens.fingerLow, tokens.fingerHigh, flex / 90)!;
      final fill = Paint()
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = uncalibrated ? const Color(0xFF9E9E9E) : fillColor;
      for (var j = 0; j < segments; j++) {
        angle += (flex * math.pi / 180) / segments;
        final len = palmRadius * _fingerLengths[i] * 0.62;
        final end =
            point + Offset(math.sin(angle) * len, -math.cos(angle) * len);
        canvas.drawLine(point, end, invalid ? outline : fill);
        point = end;
      }
    }

    canvas.restore();

    // Badges: drawn outside the mirror transform so text stays readable.
    for (var i = 0; i < 5; i++) {
      final invalid = pose.invalidMask & (1 << i) != 0;
      var tip = tips[i];
      if (left) tip = Offset(size.width - tip.dx, tip.dy);
      _drawBadge(canvas, tip, _initials[i], pose.fingerDeg[i].round(),
          invalid: invalid, uncalibrated: uncalibrated);
    }
  }

  void _drawBadge(Canvas canvas, Offset tip, String initial, int angle,
      {required bool invalid, required bool uncalibrated}) {
    final center = tip + Offset(0, -12);
    final bg = Paint()
      ..color = invalid
          ? const Color(0xFFBFBDB6)
          : (uncalibrated ? const Color(0xFF9E9E9E) : tokens.header);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = tokens.headerDark;
    canvas.drawCircle(center, 10, bg);
    canvas.drawCircle(center, 10, border);

    _paintText(
      canvas,
      invalid ? '✗' : initial,
      center,
      text.badge!.copyWith(
        color: invalid ? const Color(0xFF4A4944) : tokens.headerText,
      ),
    );
    _paintText(
      canvas,
      invalid ? '' : '$angle°',
      center + const Offset(0, 22),
      text.caption!.copyWith(
        fontWeight: FontWeight.w600,
        color: const Color(0xFF4A4944),
      ),
    );
  }

  void _paintText(Canvas canvas, String text, Offset center, TextStyle style) {
    if (text.isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
        canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  Color get _palm => uncalibrated ? const Color(0xFF9E9E9E) : const Color(0xFFE8C39E);

  @override
  bool shouldRepaint(HandPainter oldDelegate) =>
      oldDelegate.pose != pose ||
      oldDelegate.uncalibrated != uncalibrated ||
      oldDelegate.tokens != tokens;
}
