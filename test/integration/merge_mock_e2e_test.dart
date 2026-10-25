import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/application/calibration_controller.dart';
import 'package:talkhimik_app/application/dataset_recorder_controller.dart';
import 'package:talkhimik_app/application/providers.dart';
import 'package:talkhimik_app/data/glove/mock_glove_connection.dart';
import 'package:talkhimik_app/domain/models/telemetry_packet.dart';
import 'package:talkhimik_app/domain/sensing/sensor_math.dart';

import '../helpers/in_memory_calinfo_cache.dart';
import '../helpers/in_memory_settings_service.dart';

/// Master Phase 6 acceptance: on the mock alone, calibrate → record a
/// labeled take → export, and the CSV re-derives to the same ohm/angle
/// values from raw + sidecar (concept C3).
void main() {
  test('mock end-to-end: calibrate → record → export → re-derive', () async {
    final dir =
        await Directory.systemTemp.createTemp('talkhimik_mock_e2e');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final mock = MockGloveConnection(
      config: const MockGloveConfig(
        connectStepDelay: Duration.zero,
        telemetryEnabled: true,
        telemetryRate: Duration(milliseconds: 10),
      ),
    );
    final settings = InMemorySettingsService()
      ..participant = 'P-001'
      ..consent = true;
    final container = ProviderContainer(
      overrides: [
        gloveConnectionProvider.overrideWithValue(mock),
        settingsServiceProvider.overrideWithValue(settings),
        calInfoCacheProvider.overrideWithValue(InMemoryCalInfoCache()),
        datasetDirectoryProvider.overrideWithValue(Future.value(dir)),
        datasetRecorderControllerProvider.overrideWith(
            () => DatasetRecorderController(const Duration(hours: 1))),
      ],
    );
    addTearDown(container.dispose);

    // Boot: mock connects and starts streaming telemetry.
    await mock.connect();
    await pumpEventQueue();
    container.read(liveControllerProvider);
    await pumpEventQueue();

    // --- Calibrate: drive the 10-step wizard through the mock's firmware.
    final calibration = container.read(calibrationControllerProvider.notifier);
    await calibration.start(GloveHand.left);
    await pumpEventQueue();
    expect(container.read(calibrationControllerProvider).step, 1);
    for (var step = 1; step <= 10; step++) {
      await calibration.capture();
      await pumpEventQueue();
    }
    expect(container.read(calibrationControllerProvider).phase,
        CalibrationPhase.done);
    expect(mock.calibrationId, 1); // id bumped on save

    // --- Record a labeled take.
    final recorder = container.read(datasetRecorderControllerProvider.notifier);
    await recorder.start();
    expect(container.read(datasetRecorderControllerProvider).phase,
        RecordingPhase.recording);
    await recorder.startTake('A');
    // Let the mock's 10 ms telemetry timer deliver a few frames first.
    await Future<void>.delayed(const Duration(milliseconds: 60));
    for (var i = 0; i < 5; i++) {
      await recorder.sampleNow();
    }
    await recorder.stop();
    final sessions = container.read(datasetRecorderControllerProvider).sessions;
    expect(sessions, hasLength(1));
    expect(sessions.single.calibrationId, 1);
    expect(sessions.single.signerId, 'P-001');

    // --- Export: read the files and re-derive.
    final csv = File('${dir.path}/${sessions.single.csvName}');
    final sidecar = File('${dir.path}/${sessions.single.sidecarName}');
    final lines = (await csv.readAsString()).trim().split('\r\n');
    expect(lines.length, greaterThan(1)); // header + recorded rows
    final header = lines.first.split(',');
    final firstRow = lines[1].split(',');

    final sidecarJson =
        jsonDecode(await sidecar.readAsString()) as Map<String, Object?>;
    final rDiv = (sidecarJson['r_div'] as List).cast<num>();
    final fingers = sidecarJson['fingers'] as Map<String, Object?>;
    final thumb = fingers['thumb'] as Map<String, Object?>;

    int columnOf(String name) => header.indexOf(name);
    final rawThumb = int.parse(firstRow[columnOf('raw_thumb')]);
    final ohmThumb = double.parse(firstRow[columnOf('ohm_thumb')]);
    final angThumb = double.parse(firstRow[columnOf('ang_thumb')]);

    expect(
      adcToOhms(rDiv[0].toDouble(), rawThumb),
      closeTo(ohmThumb, 0.01),
    );
    expect(
      ohmsToAngle(ohmThumb, (thumb['flat_ohm'] as num).toDouble(),
          (thumb['bent90_ohm'] as num).toDouble()),
      closeTo(angThumb, 0.01),
    );
  });
}
