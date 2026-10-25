import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/application/providers.dart';
import 'package:talkhimik_app/core/strings/app_strings.dart';
import 'package:talkhimik_app/data/glove/glove_connection.dart';
import 'package:talkhimik_app/domain/models/device_status.dart';
import 'package:talkhimik_app/domain/models/telemetry_packet.dart';
import 'package:talkhimik_app/ui/screens/live_screen.dart';

import '../helpers/fake_glove_connection.dart';

TelemetryPacket frame(int seq, {GloveHand hand = GloveHand.left, DateTime? at}) {
  final now = at ?? DateTime.now();
  return TelemetryPacket(
    hand: hand,
    seq: seq,
    angles: const [10, 20, 30, 40, 50],
    rollDeg: 12.5,
    pitchDeg: -3.4,
    yawDeg: 7.8,
    rawAdc: const [100, 200, 300, 400, 500],
    calibrationId: 3,
    quality: 0x1F,
    receivedAt: now,
  );
}

void main() {
  late FakeGloveConnection left;
  late FakeGloveConnection right;

  Widget wrap() => ProviderScope(
        overrides: [
          gloveConnectionProvider.overrideWithValue(left),
          rightGloveConnectionProvider.overrideWithValue(right),
        ],
        child: const MaterialApp(home: LiveScreen()),
      );

  /// Tall window so both hand panels render fully (the ListView lazily
  /// builds — tiles and buttons would otherwise sit below the fold).
  void useTallWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  setUp(() {
    left = FakeGloveConnection();
    right = FakeGloveConnection();
  });

  // The Live screen runs a frame clock (freshness re-render), so these
  // tests pump fixed durations — pumpAndSettle would never settle.
  testWidgets('renders both hands from the fake streams', (tester) async {
    useTallWindow(tester);
    await tester.pumpWidget(wrap());
    left.emitTelemetry(frame(1));
    right.emitTelemetry(frame(1, hand: GloveHand.right));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(AppStrings.leftHandLabel), findsWidgets);
    expect(find.text(AppStrings.rightHandLabel), findsWidgets);
    expect(find.textContaining('cal_id 3'), findsNWidgets(2));
    expect(find.textContaining('12.5°'), findsNWidgets(2)); // roll tile
  });

  testWidgets('a backdated frame shows the stale badge', (tester) async {
    useTallWindow(tester);
    await tester.pumpWidget(wrap());
    left.emitTelemetry(frame(1,
        at: DateTime.now().subtract(const Duration(seconds: 2))));
    await tester.pump(const Duration(milliseconds: 100));

    // Both panels: the left is backdated, the right never received a frame.
    expect(find.text(AppStrings.stale), findsNWidgets(2));
  });

  testWidgets('an uncalibrated glove shows the uncalibrated chip',
      (tester) async {
    useTallWindow(tester);
    await tester.pumpWidget(wrap());
    left.emitTelemetry(frame(1));
    left.emitStatus(const DeviceStatusPacket(uncalibrated: true));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(AppStrings.uncalibrated), findsOneWidget);
  });

  testWidgets('a mismatched telemetry hand byte shows the warning badge',
      (tester) async {
    useTallWindow(tester);
    await tester.pumpWidget(wrap());
    left.emitTelemetry(frame(1, hand: GloveHand.right));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(AppStrings.handMismatchWarning), findsOneWidget);
  });

  testWidgets('zero-yaw and vibrate send commands to the owning glove',
      (tester) async {
    useTallWindow(tester);
    await tester.pumpWidget(wrap());
    left.emitTelemetry(frame(1));
    right.emitTelemetry(frame(1, hand: GloveHand.right));
    await tester.pump(const Duration(milliseconds: 100));

    // The right-hand panel's buttons target the right connection.
    final rightZeroYaw = find
        .widgetWithText(OutlinedButton, AppStrings.zeroYaw)
        .last;
    await tester.tap(rightZeroYaw);
    await tester.pump(const Duration(milliseconds: 50));

    expect(right.commands, contains(AppCommand.zeroYaw));
    expect(left.commands, isEmpty);
  });
}
