import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/application/providers.dart';
import 'package:talkhimik_app/core/strings/app_strings.dart';
import 'package:talkhimik_app/data/glove/glove_connection.dart';
import 'package:talkhimik_app/domain/models/cal_info_packet.dart';
import 'package:talkhimik_app/domain/models/device_status.dart';
import 'package:talkhimik_app/ui/screens/calibration_screen.dart';

import '../helpers/fake_glove_connection.dart';
import '../helpers/in_memory_calinfo_cache.dart';

CalInfoPacket calInfo(int id) => CalInfoPacket(
      validMask: 0x1F,
      weakMask: 0,
      calibrationId: id,
      flatOhm: const [10000, 10000, 10000, 10000, 10000],
      bent90Ohm: const [30000, 30000, 30000, 30000, 30000],
      flatAdc: const [500, 500, 500, 500, 500],
      bent90Adc: const [1500, 1500, 1500, 1500, 1500],
      rDiv: const [10000, 10000, 10000, 10000, 10000],
      spanCounts: const [1000, 1000, 1000, 1000, 1000],
      firmwareVersion: '1.2.0',
    );

void main() {
  late FakeGloveConnection glove;

  Widget wrap() => ProviderScope(
        overrides: [
          gloveConnectionProvider.overrideWithValue(glove),
          calInfoCacheProvider.overrideWithValue(InMemoryCalInfoCache()),
        ],
        child: const MaterialApp(home: CalibrationScreen()),
      );

  setUp(() {
    glove = FakeGloveConnection();
  });

  testWidgets('idle screen shows the hand picker and no profile',
      (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.text(AppStrings.calibrationPickHand), findsOneWidget);
    expect(find.text(AppStrings.leftHandLabel), findsOneWidget);
    expect(find.text(AppStrings.rightHandLabel), findsOneWidget);
    expect(find.text(AppStrings.calibrationNoProfile), findsWidgets);
  });

  testWidgets('starting on a hand sends START_CALIBRATION and prompts per '
      'STATUS step (master §4.2)', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.tap(find.text(AppStrings.leftHandLabel));
    await tester.pumpAndSettle();
    expect(glove.commands, contains(AppCommand.startCalibration));

    glove.emitStatus(const DeviceStatusPacket(
        mode: GloveMode.calibrating, calibrationStep: 1));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.calibrationFlatPrompt('thumb')), findsOneWidget);

    glove.emitStatus(const DeviceStatusPacket(
        mode: GloveMode.calibrating, calibrationStep: 2));
    await tester.pumpAndSettle();
    expect(
        find.text(AppStrings.calibrationBendPrompt('thumb')), findsOneWidget);

    // Capture on the flat step sends 0x02.
    glove.emitStatus(const DeviceStatusPacket(
        mode: GloveMode.calibrating, calibrationStep: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.calibrationCapture));
    await tester.pumpAndSettle();
    expect(glove.commands, contains(AppCommand.captureFlat));
  });

  testWidgets('error 3 shows the redo message on the same step',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text(AppStrings.leftHandLabel));
    await tester.pumpAndSettle();

    glove.emitStatus(const DeviceStatusPacket(
        mode: GloveMode.calibrating, calibrationStep: 2, lastErrorCode: 3));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.calibrationSpanReject), findsOneWidget);
    expect(
        find.text(AppStrings.calibrationBendPrompt('thumb')), findsOneWidget);

    // The rejection shake is one-shot: after it settles, the tree is
    // quiet (no lingering animation) — motion pass acceptance.
    expect(tester.takeException(), isNull);
  });

  testWidgets('completion shows the CAL_INFO summary', (tester) async {
    await tester.pumpWidget(wrap());
    glove.emitCalInfo(calInfo(3));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.leftHandLabel));
    await tester.pumpAndSettle();
    glove.emitCalInfo(calInfo(4));
    glove.emitStatus(const DeviceStatusPacket(
        mode: GloveMode.streaming, calibrationStep: 0));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.calibrationSavedTitle), findsOneWidget);
    expect(find.textContaining('cal_id 4'), findsOneWidget);
    expect(find.text('✓'), findsNWidgets(5)); // all fingers valid
    expect(find.text(AppStrings.calibrationDone), findsOneWidget);
  });
}
