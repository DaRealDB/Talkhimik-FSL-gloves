import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../domain/models/telemetry_packet.dart';

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

/// Two animated hands driven by live finger angles + IMU.
///
/// Palm = rounded shape; each finger = 3 segments hinged at the palm with
/// the flexion split 40/40/20 % across joints; the thumb has 2 segments and
/// crosses the palm. The left hand is the right one mirrored (canvas.scale).
/// Roll/pitch tilt the whole hand; yaw rotates in-plane. Smoothing is a
/// low-pass toward the target at ticker rate — no setState per packet.
class HandView extends StatefulWidget {
  const HandView({
    super.key,
    required this.target,
    this.uncalibrated = false,
    this.stale = false,
    this.label,
  });

  /// Latest pose from telemetry (the view animates toward it).
  final HandPose target;

  /// Desaturates the hand and shows the "Uncalibrated" label.
  final bool uncalibrated;

  /// Freezes the hand at 40 % opacity (disconnected / no frames).
  final bool stale;

  /// Small caption under the hand (e.g. "L" / "R").
  final String? label;

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
    // Low-pass toward the target: v += (target − v) × 0.35 per tick (master §6.2).
    _ticker = createTicker((_) {
      if (!mounted) return;
      setState(() => _current = _current.lerpTo(widget.target, 0.35));
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: widget.stale ? 0.4 : 1,
          child: RepaintBoundary(
            child: CustomPaint(
              size: const Size(180, 200),
              painter: HandPainter(
                pose: _current,
                uncalibrated: widget.uncalibrated,
              ),
            ),
          ),
        ),
        if (widget.label != null)
          Text(
            widget.label!,
            style: Theme.of(context).textTheme.labelMedium,
          ),
      ],
    );
  }
}

/// Pure renderer for one hand (master §6.2).
class HandPainter extends CustomPainter {
  HandPainter({required this.pose, this.uncalibrated = false});

  final HandPose pose;
  final bool uncalibrated;

  static const _fingerLengths = [0.85, 1.0, 1.0, 0.9, 0.7]; // relative

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.55);
    final palmRadius = math.min(size.width, size.height) * 0.16;

    // Clamp tilt so the hand never leaves the canvas.
    final roll = pose.rollDeg.clamp(-35.0, 35.0) * math.pi / 180;
    final pitch = pose.pitchDeg.clamp(-35.0, 35.0) * math.pi / 180;
    final yaw = pose.yawDeg * math.pi / 180;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    // Left hand = right hand mirrored (same painter).
    if (pose.handedness == GloveHand.left) canvas.scale(-1, 1);
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

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = _grey;
    final fill = Paint()..color = _skin;

    // Palm (rounded shape) with a short wrist.
    final palmRect = Rect.fromCenter(
        center: Offset.zero, width: palmRadius * 1.9, height: palmRadius * 2.2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(palmRect, Radius.circular(palmRadius * 0.8)),
      fill,
    );
    canvas.drawLine(
        Offset(0, palmRadius * 1.1), Offset(0, palmRadius * 1.7), outline);

    // Finger base angles fan out from the palm (degrees from straight up).
    const baseAngles = [-38.0, -14.0, 8.0, 30.0, 52.0]; // thumb..pinky
    for (var i = 0; i < 5; i++) {
      final invalid = pose.invalidMask & (1 << i) != 0;
      final flex = pose.fingerDeg[i].clamp(0.0, 90.0) * math.pi / 180;
      final segments = i == 0 ? 2 : 3; // thumb: 2 segments across the palm
      var angle = baseAngles[i] * math.pi / 180;
      var point = Offset(0, -palmRadius * 0.7);
      for (var j = 0; j < segments; j++) {
        angle += flex / segments;
        final len = palmRadius * _fingerLengths[i] * 0.62;
        final end = point +
            Offset(math.sin(angle) * len, -math.cos(angle) * len);
        canvas.drawLine(point, end, invalid ? outline : _wideStroke);
        point = end;
      }
    }

    canvas.restore();
  }

  Paint get _wideStroke => Paint()
    ..strokeWidth = 14
    ..strokeCap = StrokeCap.round
    ..color = _skin;

  Color get _skin => uncalibrated ? const Color(0xFF9E9E9E) : const Color(0xFFE8C39E);

  Color get _grey => const Color(0xFF6B6B6B);

  @override
  bool shouldRepaint(HandPainter oldDelegate) =>
      oldDelegate.pose != pose || oldDelegate.uncalibrated != uncalibrated;
}
