import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/application/glove_controller.dart';
import 'package:talkhimik_app/application/providers.dart';
import 'package:talkhimik_app/core/strings/app_strings.dart';
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
        child: MaterialApp(home: Scaffold(body: child)),
      );

  setUp(() {
    fake = FakeGloveConnection();
  });

  testWidgets('shows mock glove name and disconnected phase initially',
      (tester) async {
    await tester.pumpWidget(wrap(const DeviceStatusBar()));
    expect(find.textContaining(AppStrings.mockGloveName), findsOneWidget);
    expect(find.textContaining(AppStrings.disconnected), findsOneWidget);
    expect(find.byKey(DeviceStatusBar.connectionLostBannerKey), findsNothing);
  });

  testWidgets('shows battery and connected state when ready',
      (tester) async {
    await tester.pumpWidget(wrap(const DeviceStatusBar()));
    fake.emitPhase(GloveConnectionPhase.ready);
    fake.emitStatus(const DeviceStatusPacket(batteryPercent: 87));
    await tester.pumpAndSettle();

    expect(find.textContaining('87%'), findsOneWidget);
    expect(find.textContaining(AppStrings.connected), findsOneWidget);
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

  testWidgets('clears the banner when the link returns', (tester) async {
    await tester.pumpWidget(wrap(const DeviceStatusBar()));
    fake.emitPhase(GloveConnectionPhase.disconnected);
    await tester.pumpAndSettle();
    expect(find.byKey(DeviceStatusBar.connectionLostBannerKey), findsOneWidget);

    fake.emitPhase(GloveConnectionPhase.ready);
    await tester.pumpAndSettle();
    expect(find.byKey(DeviceStatusBar.connectionLostBannerKey), findsNothing);
  });

  testWidgets('shows an error chip for a resistance fault (code 4)',
      (tester) async {
    await tester.pumpWidget(wrap(const DeviceStatusBar()));
    fake.emitPhase(GloveConnectionPhase.ready);
    fake.emitStatus(const DeviceStatusPacket(
      batteryPercent: 80,
      lastErrorCode: 4, // resistance outside 1k..100k
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(DeviceStatusBar.errorChipKey), findsOneWidget);
    expect(find.text(AppStrings.sensorFault), findsOneWidget);
  });

  testWidgets('shows the uncalibrated chip while the glove streams '
      'placeholder angles', (tester) async {
    await tester.pumpWidget(wrap(const DeviceStatusBar()));
    fake.emitPhase(GloveConnectionPhase.ready);
    fake.emitStatus(const DeviceStatusPacket(
      batteryPercent: 80,
      uncalibrated: true, // STATUS flags bit0
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(DeviceStatusBar.uncalibratedChipKey), findsOneWidget);
    expect(find.text(AppStrings.uncalibrated), findsOneWidget);
  });

  testWidgets('aggregates both gloves when left and right are ready '
      '(master §7.3)', (tester) async {
    final right = FakeGloveConnection();
    await tester.pumpWidget(wrap(const DeviceStatusBar(), right: right));
    fake.emitPhase(GloveConnectionPhase.ready);
    right.emitPhase(GloveConnectionPhase.ready);
    await tester.pumpAndSettle();

    expect(find.textContaining('L + R'), findsOneWidget);
  });

  testWidgets('shows the right glove when only it is connected',
      (tester) async {
    final right = FakeGloveConnection();
    await tester.pumpWidget(wrap(const DeviceStatusBar(), right: right));
    right.emitPhase(GloveConnectionPhase.ready);
    await tester.pumpAndSettle();

    expect(find.textContaining('Connected (R)'), findsOneWidget);
  });

  testWidgets('the uncalibrated chip reflects either glove', (tester) async {
    final right = FakeGloveConnection();
    await tester.pumpWidget(wrap(const DeviceStatusBar(), right: right));
    right.emitPhase(GloveConnectionPhase.ready);
    right.emitStatus(const DeviceStatusPacket(
      batteryPercent: 80,
      uncalibrated: true,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(DeviceStatusBar.uncalibratedChipKey), findsOneWidget);
  });

  testWidgets('real glove shows a connect button and surfaces failures',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        gloveConnectionProvider.overrideWithValue(fake),
        // The real connection connects explicitly (C-S1).
        gloveIsMockProvider.overrideWithValue(false),
        gloveControllerProvider
            .overrideWith(() => GloveController((d) async {})),
      ],
      child: const MaterialApp(home: Scaffold(body: DeviceStatusBar())),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining(AppStrings.realGloveName), findsOneWidget);
    final button = find.byKey(DeviceStatusBar.connectButtonKey);
    expect(button, findsOneWidget);

    // A failed attempt surfaces the friendly message once, no banner.
    fake.throwOnConnect = Exception('simulated scan timeout');
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.connectFailed), findsOneWidget);
    expect(find.byKey(DeviceStatusBar.connectionLostBannerKey), findsNothing);
    expect(fake.connectCalls, 1);

    // Let the snackbar elapse; the next attempt succeeds silently.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    fake.throwOnConnect = null;
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(fake.connectCalls, 2);
    expect(find.text(AppStrings.connectFailed), findsNothing);
  });
}
