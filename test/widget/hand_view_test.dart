import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/core/theme/app_theme.dart';
import 'package:talkhimik_app/domain/models/telemetry_packet.dart';
import 'package:talkhimik_app/ui/widgets/hand_view.dart';

HandPose pose({GloveHand hand = GloveHand.right, int invalidMask = 0}) =>
    HandPose(
      fingerDeg: const [20, 40, 60, 80, 90],
      rollDeg: 5,
      pitchDeg: -3,
      yawDeg: 10,
      handedness: hand,
      invalidMask: invalidMask,
    );

void main() {
  test('roll/yaw lerp takes the short way across ±180°', () {
    expect(angleDelta(179, -179), closeTo(2, 1e-9));
    expect(angleDelta(-179, 179), closeTo(-2, 1e-9));
    expect(wrap180(181), closeTo(-179, 1e-9));
    expect(wrap180(-180), 180);
    final from = HandPose(fingerDeg: const [0, 0, 0, 0, 0], rollDeg: 179,
        yawDeg: -179, handedness: GloveHand.right);
    final to = HandPose(fingerDeg: const [0, 0, 0, 0, 0], rollDeg: -179,
        yawDeg: 179, handedness: GloveHand.right);
    final mid = from.lerpTo(to, 0.5);
    expect(mid.rollDeg.abs(), closeTo(180, 1e-9)); // not 0
    expect(mid.yawDeg.abs(), closeTo(180, 1e-9));
  });

  Widget wrap(Widget child) => MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: child),
      );

  test('fingerTipOffsets: five in-canvas tips for any pose', () {
    const size = Size(220, 220);
    final tips = HandPainter.fingerTipOffsets(size, pose());
    expect(tips, hasLength(5));
    for (final t in tips) {
      expect(t.dx, inInclusiveRange(0, size.width));
      expect(t.dy, inInclusiveRange(0, size.height));
    }
    // Higher flexion moves fingertips further from the palm center.
    final straight = HandPainter.fingerTipOffsets(
        size, pose().lerpTo(pose(), 0).copyWithFingerDeg([0, 0, 0, 0, 0]));
    expect(tips[1].distance, greaterThan(straight[1].distance));
  });

  testWidgets('renders the header band with title and cal chip',
      (tester) async {
    await tester.pumpWidget(wrap(HandView(
      target: pose(),
      title: 'Left hand',
      chipLabel: 'cal_id 3 · fw 1.2.0',
    )));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Left hand'), findsOneWidget);
    expect(find.textContaining('cal_id 3'), findsOneWidget);
  });

  testWidgets('stale hands render at 40 % opacity', (tester) async {
    await tester.pumpWidget(
        wrap(HandView(target: pose(), title: 'Right hand', stale: true)));
    // The stale fade is animated (motion pass); settle to the target.
    await tester.pump(const Duration(milliseconds: 300));

    final opacity = tester
        .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first);
    expect(opacity.opacity, 0.4);
  });

  testWidgets('the painter carries the pose handedness and state flags',
      (tester) async {
    await tester.pumpWidget(wrap(HandView(
      target: pose(hand: GloveHand.left, invalidMask: 2),
      title: 'Left hand',
      uncalibrated: true,
    )));
    await tester.pump(const Duration(milliseconds: 100));

    final custom = tester.widget<CustomPaint>(
        find.descendant(
            of: find.byType(RepaintBoundary),
            matching: find.byType(CustomPaint)));
    final painter = custom.painter! as HandPainter;
    expect(painter.pose.handedness, GloveHand.left);
    expect(painter.pose.invalidMask, 2);
    expect(painter.uncalibrated, isTrue);
    expect(painter.tokens.header, AppColors.sky);
  });
  test('fingerColorFor walks the 4-stop gradient (step 5 re-skin)', () {
    expect(HandPainter.fingerColorFor(0), AppColors.fingerLow);
    expect(HandPainter.fingerColorFor(90), AppColors.navy);
    final mid = HandPainter.fingerColorFor(45);
    // 45° sits between sky and azure (stops 1 and 2 of 3 segments).
    expect(mid, isNot(AppColors.fingerLow));
    expect(mid, isNot(AppColors.navy));
  });

  test('compact painters carry the compact flag (Home preview mode)', () {
    final painter = HandPainter(
      pose: pose(),
      tokens: TalkhimikTokens.light,
      text: TalkhimikText.fallback,
      compact: true,
    );
    expect(painter.compact, isTrue);
  });
}

extension on HandPose {
  HandPose copyWithFingerDeg(List<double> fingerDeg) => HandPose(
        fingerDeg: fingerDeg,
        rollDeg: rollDeg,
        pitchDeg: pitchDeg,
        yawDeg: yawDeg,
        handedness: handedness,
        invalidMask: invalidMask,
      );
}
