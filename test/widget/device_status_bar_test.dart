import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/application/glove_controller.dart';
import 'package:talkhimik_app/application/providers.dart';
import 'package:talkhimik_app/core/strings/app_strings.dart';
import 'package:talkhimik_app/core/theme/app_theme.dart';
import 'package:talkhimik_app/data/glove/glove_connection.dart';
import 'package:talkhimik_app/domain/models/device_status.dart';
import 'package:talkhimik_app/ui/widgets/device_status_bar.dart';

import '../helpers/fake_glove_connection.dart';

void main() {
  late FakeGloveConnection fake;

  Widget wrap(Widget child, {FakeGloveConnection? right}) => ProviderScope(
        overrides: [
          gloveConnectionProvider.overrideWithValue(fake),
          // The fake is not a MockGloveConnection; pin the demo branch so
          // these tests exercise the mock label.
          gloveIsMockProvider.overrideWithValue(true),
          gloveControllerProvider
              .overrideWith(() => GloveController((d) async {})),
          if (right != null) ...[
            rightGloveConnectionProvider.overrideWithValue(right),
            rightGloveControllerProvider.overrideWith(() =>
                GloveController((d) async {}, rightGloveConnectionProvider)),
          ],
        ],
        child: MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(body: child),
        ),
      );

  setUp(() {
    fake = FakeGloveConnection();
  });

  testWidgets('shows the not-connected pill with a neutral Demo tag',
      (tester) async {
    await tester.pumpWidget(wrap(const DeviceStatusBar()));

    expect(find.text(AppStrings.statusNotConnected), findsOneWidget);
    expect(find.text(AppStrings.demoTag), findsOneWidget);
    expect(find.byKey(DeviceStatusBar.connectionLostBannerKey), findsNothing);
  });

  testWidgets('shows battery and the connected label when ready',
      (tester) async {
    await tester.pumpWidget(wrap(const DeviceStatusBar()));
    fake.emitPhase(GloveConnectionPhase.ready);
    fake.emitStatus(const DeviceStatusPacket(batteryPercent: 87));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.statusOneConnected), findsOneWidget);
    expect(find.textContaining('87%'), findsOneWidget);
    expect(find.byKey(DeviceStatusBar.batteryKey), findsOneWidget);
  });

  testWidgets('both gloves connected reads as such', (tester) async {
    final right = FakeGloveConnection();
    await tester.pumpWidget(wrap(const DeviceStatusBar(), right: right));
    fake.emitPhase(GloveConnectionPhase.ready);
    right.emitPhase(GloveConnectionPhase.ready);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.statusBothConnected), findsOneWidget);
  });

  testWidgets('surfaces the connection lost banner on link drop',
      (tester) async {
    await tester.pumpWidget(wrap(const DeviceStatusBar()));
    fake.emitPhase(GloveConnectionPhase.ready);
    await tester.pumpAndSettle();

    fake.emitPhase(GloveConnectionPhase.disconnected);
    await tester.pumpAndSettle();

    expect(find.byKey(DeviceStatusBar.connectionLostBannerKey), findsOneWidget);
    expect(find.text(AppStrings.connectionLost), findsOneWidget);
  });

  testWidgets('an uncalibrated glove shows the calibrate-now banner',
      (tester) async {
    await tester.pumpWidget(wrap(const DeviceStatusBar()));
    fake.emitPhase(GloveConnectionPhase.ready);
    fake.emitStatus(const DeviceStatusPacket(uncalibrated: true));
    await tester.pumpAndSettle();

    expect(find.byKey(DeviceStatusBar.uncalibratedChipKey), findsOneWidget);
    expect(find.text(AppStrings.uncalibratedBanner), findsOneWidget);
  });

  testWidgets('a glove error shows the error banner', (tester) async {
    await tester.pumpWidget(wrap(const DeviceStatusBar()));
    fake.emitPhase(GloveConnectionPhase.ready);
    fake.emitStatus(const DeviceStatusPacket(
      batteryPercent: 80,
      lastErrorCode: 4, // resistance outside 1k..100k
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(DeviceStatusBar.errorChipKey), findsOneWidget);
    expect(find.text(AppStrings.gloveErrorDetail('L', 4)), findsOneWidget);
    expect(find.textContaining('Check its wiring'), findsOneWidget);
  });

  testWidgets('tapping the pill opens the per-hand details sheet',
      (tester) async {
    await tester.pumpWidget(wrap(const DeviceStatusBar()));
    await tester.tap(find.byKey(DeviceStatusBar.statusPillKey));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.connectionDetails), findsOneWidget);
    expect(find.text(AppStrings.leftHandTitle), findsOneWidget);
    expect(find.text(AppStrings.rightHandTitle), findsOneWidget);
  });
}
