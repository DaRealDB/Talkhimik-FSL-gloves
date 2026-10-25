import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/application/providers.dart';
import 'package:talkhimik_app/application/settings_controller.dart';
import 'package:talkhimik_app/data/glove/mock_glove_connection.dart';

import '../helpers/in_memory_settings_service.dart';

void main() {
  test('toggling forceMock swaps the connection instance and disposes the '
      'old one', () async {
    final settings = InMemorySettingsService();
    final container = ProviderContainer(
      overrides: [
        settingsServiceProvider.overrideWithValue(settings),
        forceMockProvider.overrideWith(() => ForceMockController()),
      ],
    );
    addTearDown(container.dispose);

    // On the test VM both states build a mock (no mobile platform), so the
    // swap is asserted via instance identity, not class.
    final before = container.read(gloveConnectionProvider);
    expect(before, isA<MockGloveConnection>());

    await container.read(forceMockProvider.notifier).set(true);
    await pumpEventQueue();

    final after = container.read(gloveConnectionProvider);
    expect(identical(before, after), isFalse);
    expect(after, isA<MockGloveConnection>());
    expect(container.read(gloveIsMockProvider), isTrue);
    // The right glove swaps too.
    final rightBefore = container.read(rightGloveConnectionProvider);
    await container.read(forceMockProvider.notifier).set(false);
    await pumpEventQueue();
    expect(identical(rightBefore, container.read(rightGloveConnectionProvider)),
        isFalse);
  });

  testWidgets('a live swap cancels the old connection timers — '
      'pumpAndSettle must settle', (tester) async {
    final settings = InMemorySettingsService();
    late ProviderContainer container;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWithValue(settings),
        forceMockProvider.overrideWith(() => ForceMockController()),
      ],
      child: Builder(builder: (context) {
        container = ProviderScope.containerOf(context);
        return const SizedBox();
      }),
    ));

    // Start the mock's periodic telemetry timers (default config).
    final mock =
        container.read(gloveConnectionProvider) as MockGloveConnection;
    unawaited(mock.connect());
    // Advance past BOTH connect delays (2 × 250 ms) so the connect is
    // complete and the telemetry engine is running before the swap.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    // Swap: the provider's onDispose must cancel the timers. If it
    // doesn't, pumpAndSettle hits its timeout and the test fails.
    await container.read(forceMockProvider.notifier).set(true);
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
  });
}
