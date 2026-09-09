import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/application/glove_controller.dart';
import 'package:talkhimik_app/application/providers.dart';
import 'package:talkhimik_app/data/glove/glove_connection.dart';
import 'package:talkhimik_app/domain/models/device_status.dart';

import '../helpers/fake_glove_connection.dart';

void main() {
  late FakeGloveConnection fake;
  late List<Duration> requestedDelays;

  Future<void> recordingDelay(Duration d) async {
    requestedDelays.add(d);
    // Yield one event-loop turn per call. Without this, an instant delay
    // plus the retry-on-failure loop forms an endless microtask chain
    // inside pumpEventQueue and the test livelocks.
    await Future<void>.delayed(Duration.zero);
  }

  ProviderContainer makeContainer() {
    fake = FakeGloveConnection();
    requestedDelays = [];
    final container = ProviderContainer(
      overrides: [
        gloveConnectionProvider.overrideWithValue(fake),
        gloveControllerProvider.overrideWith(() => GloveController(recordingDelay)),
      ],
    );
    addTearDown(container.dispose);
    // Force the controller to build (and subscribe to the fake's streams)
    // before any test emits events.
    container.read(gloveControllerProvider);
    return container;
  }

  GloveState state(ProviderContainer c) => c.read(gloveControllerProvider);

  /// The fake's controllers are broadcast (async delivery), so each emit
  /// must be followed by a microtask flush before asserting.
  Future<void> emitPhase(GloveConnectionPhase phase) async {
    fake.emitPhase(phase);
    await pumpEventQueue();
  }

  Future<void> emitStatus(DeviceStatusPacket packet) async {
    fake.emitStatus(packet);
    await pumpEventQueue();
  }

  Future<void> flushAsync() async {
    // Advance the event loop a bounded number of turns: each turn lets one
    // delay (and, for the failure path, one reconnect attempt) complete.
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('phase changes from the connection flow into state', () async {
    final c = makeContainer();
    await emitPhase(GloveConnectionPhase.scanning);
    expect(state(c).phase, GloveConnectionPhase.scanning);

    await emitPhase(GloveConnectionPhase.ready);
    expect(state(c).phase, GloveConnectionPhase.ready);
    expect(state(c).connectionLost, isFalse);
  });

  test('device status packets update state', () async {
    final c = makeContainer();
    await emitStatus(const DeviceStatusPacket(batteryPercent: 87, linkUp: true));
    expect(state(c).status?.batteryPercent, 87);
  });

  test('link drop sets connectionLost immediately; a successful reconnect '
      'resets the backoff', () async {
    final c = makeContainer();
    await emitPhase(GloveConnectionPhase.ready);
    expect(state(c).connectionLost, isFalse);

    // Drop 1: banner immediate, reconnect after 1 s.
    await emitPhase(GloveConnectionPhase.disconnected);
    expect(state(c).connectionLost, isTrue);
    await flushAsync();
    expect(fake.reconnectCalls, 1);
    expect(requestedDelays, [const Duration(seconds: 1)]);

    // The glove comes back → banner off; a new drop starts back at 1 s.
    await emitPhase(GloveConnectionPhase.ready);
    expect(state(c).connectionLost, isFalse);
    await emitPhase(GloveConnectionPhase.disconnected);
    await flushAsync();
    expect(fake.reconnectCalls, 2);
    expect(requestedDelays.last, const Duration(seconds: 1));
  });

  test('repeated failed reconnects escalate the backoff and cap at 30 s',
      () async {
    final c = makeContainer();
    fake.failReconnects = true;

    fake.emitPhase(GloveConnectionPhase.disconnected);
    // Let the event reach the controller (microtask), then advance the
    // event loop one turn at a time: each turn lets one delay and one
    // failed attempt complete. Stop once six attempts have fired — the
    // seventh delay is then recorded but its attempt never runs.
    await Future<void>.delayed(Duration.zero);
    for (var i = 0; i < 20 && fake.reconnectCalls < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(requestedDelays.take(7).toList(), [
      const Duration(seconds: 1),
      const Duration(seconds: 2),
      const Duration(seconds: 4),
      const Duration(seconds: 8),
      const Duration(seconds: 30),
      const Duration(seconds: 30),
      const Duration(seconds: 30),
    ]);
    expect(fake.reconnectCalls, 6);
    expect(state(c).connectionLost, isTrue); // still down, banner persists
  });

  test('manual disconnect never schedules a reconnect', () async {
    final c = makeContainer();
    await emitPhase(GloveConnectionPhase.ready);

    await c.read(gloveControllerProvider.notifier).disconnect();
    expect(fake.disconnectCalls, 1);

    await emitPhase(GloveConnectionPhase.disconnected);
    expect(state(c).connectionLost, isFalse);
    await flushAsync();
    expect(fake.reconnectCalls, 0);
    expect(requestedDelays, isEmpty);
  });

  test('manual connect clears the manual-disconnect flag', () async {
    final c = makeContainer();
    await c.read(gloveControllerProvider.notifier).disconnect();
    await emitPhase(GloveConnectionPhase.disconnected);
    expect(state(c).connectionLost, isFalse);

    await c.read(gloveControllerProvider.notifier).connect();
    await emitPhase(GloveConnectionPhase.ready);
    await emitPhase(GloveConnectionPhase.disconnected);
    expect(state(c).connectionLost, isTrue);
    await flushAsync();
    expect(fake.reconnectCalls, 1);
  });

  test('ready clears the banner and resets the backoff sequence', () async {
    final c = makeContainer();
    await emitPhase(GloveConnectionPhase.disconnected);
    await flushAsync();
    expect(requestedDelays.single, const Duration(seconds: 1));

    await emitPhase(GloveConnectionPhase.ready);
    expect(state(c).connectionLost, isFalse);

    await emitPhase(GloveConnectionPhase.disconnected);
    await flushAsync();
    expect(requestedDelays.last, const Duration(seconds: 1));
  });
}
