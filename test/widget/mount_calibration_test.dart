import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/application/providers.dart';
import 'package:talkhimik_app/core/strings/app_strings.dart';
import 'package:talkhimik_app/data/glove/glove_connection.dart';
import 'package:talkhimik_app/domain/models/device_status.dart';
import 'package:talkhimik_app/ui/screens/calibration_screen.dart';

import '../helpers/fake_glove_connection.dart';
import '../helpers/in_memory_calinfo_cache.dart';

void main() {
  late FakeGloveConnection glove;

  Widget wrap() => ProviderScope(
        overrides: [
          gloveConnectionProvider.overrideWithValue(glove),
          calInfoCacheProvider.overrideWithValue(InMemoryCalInfoCache()),
        ],
        child: const MaterialApp(home: CalibrationScreen()),
      );

  const fw13 = DeviceStatusPacket(
      mode: GloveMode.streaming,
      lastErrorCode: 0,
      mountUncalibrated: true,
      mountCalibrationId: 0);
  const pose1 = Key('mount-left-captureMountPose1');
  const pose2 = Key('mount-left-captureMountPose2');

  setUp(() => glove = FakeGloveConnection());

  Future<void> tapKey(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(key));
    await tester.pump();
  }

  testWidgets('fw 1.2.0 glove (no mount id) shows the update note',
      (tester) async {
    await tester.pumpWidget(wrap());
    glove.emitStatus(const DeviceStatusPacket(mode: GloveMode.streaming));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.mountNeedsNewFirmware), findsOneWidget);
    expect(find.byKey(pose1), findsNothing);
  });

  testWidgets('Pose 1 then Pose 2: stale STATUS ignored, results shown',
      (tester) async {
    await tester.pumpWidget(wrap());
    glove.emitStatus(fw13);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.mountStatusDefault), findsOneWidget);

    await tapKey(tester, pose1);
    expect(glove.commands.last, AppCommand.captureMountPose1);
    // A packet inside the stale window carries the previous result.
    glove.emitStatus(fw13.copyWithError(6));
    await tester.pump();
    expect(find.text(AppStrings.mountWorking), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    glove.emitStatus(fw13);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.mountPose1Ok), findsOneWidget);

    await tapKey(tester, pose2);
    await tester.pump(const Duration(milliseconds: 400));
    glove.emitStatus(fw13.copyWithError(7));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.mountNotPerpendicular), findsOneWidget);
  });

  testWidgets('silent NOTIFYs: a STATUS read after the capture gets the result',
      (tester) async {
    await tester.pumpWidget(wrap());
    glove.emitStatus(fw13);
    await tester.pumpAndSettle();
    glove.readableStatus = fw13.copyWithError(7);
    await tapKey(tester, pose2);
    await tester.pump(const Duration(seconds: 3));
    expect(glove.statusReads, 0); // capture still running: no stale reads
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(glove.statusReads, greaterThan(0));
    expect(find.text(AppStrings.mountNotPerpendicular), findsOneWidget);
  });

  testWidgets('a failed write says so at once', (tester) async {
    await tester.pumpWidget(wrap());
    glove.emitStatus(fw13);
    await tester.pumpAndSettle();
    glove.failCommands = true;
    await tapKey(tester, pose1);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.mountSendFailed), findsOneWidget);
  });

  testWidgets('no STATUS within 15 s reports no reply', (tester) async {
    await tester.pumpWidget(wrap());
    glove.emitStatus(fw13);
    await tester.pumpAndSettle();
    await tapKey(tester, const Key('mount-left-calibrateGyro'));
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.mountNoReply), findsOneWidget);
  });
}

extension on DeviceStatusPacket {
  DeviceStatusPacket copyWithError(int code) => DeviceStatusPacket(
      mode: mode,
      lastErrorCode: code,
      mountUncalibrated: mountUncalibrated,
      mountCalibrationId: mountCalibrationId);
}
