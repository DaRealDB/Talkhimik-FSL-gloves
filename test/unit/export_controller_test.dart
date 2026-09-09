import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:talkhimik_app/application/providers.dart';
import 'package:talkhimik_app/domain/models/log_entry.dart';

import '../helpers/in_memory_log_store.dart';

void main() {
  late Directory tempDir;
  late InMemoryLogStore logStore;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('talkhimik_export_');
    logStore = InMemoryLogStore();
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        logStoreProvider.overrideWithValue(logStore),
        exportDirectoryProvider.overrideWith((ref) async => tempDir),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  GestureLogEntry sampleEvent({
    int wordId = 1,
    String participantId = 'P-001',
    String sessionId = 'S-1',
    int confidence = 95,
    String confidenceLevel = 'green',
    int latencyMs = 42,
    bool corrected = false,
    int? originalWordId,
    String source = 'glove',
  }) =>
      GestureLogEntry(
        participantId: participantId,
        sessionId: sessionId,
        wordId: wordId,
        filipinoText: 'Kumusta, kaibigan',
        englishText: 'How are you, friend?',
        confidence: confidence,
        confidenceLevel: confidenceLevel,
        latencyMs: latencyMs,
        gloveTimestampMs: 1000,
        receivedAt: DateTime.fromMillisecondsSinceEpoch(1042),
        corrected: corrected,
        originalWordId: originalWordId,
        source: source,
        appVersion: '0.1.0',
      );

  test('exportSession writes a CSV whose columns mirror the FR-10 schema '
      'with RFC-4180 quoting', () async {
    final c = makeContainer();
    await logStore.startSession(SessionMeta(
      sessionId: 'S-1',
      participantId: 'P-001',
      startedAt: DateTime(2026, 9, 9, 10),
    ));
    await logStore.appendEvent(sampleEvent());
    await logStore.appendEvent(sampleEvent(
      wordId: 104,
      confidence: 50,
      confidenceLevel: 'red',
      corrected: true,
      originalWordId: 1,
      source: 'correction',
    ));

    final controller = c.read(exportControllerProvider.notifier);
    final path = await controller.exportSession('S-1');

    final file = File(path);
    expect(file.existsSync(), isTrue);
    expect(path, contains('S-1.csv'));

    final lines = file.readAsLinesSync();
    expect(lines, hasLength(3)); // header + 2 rows

    final header = lines[0].split(',');
    expect(header.first, 'participantId');
    expect(header, contains('confidenceLevel'));
    expect(header, contains('latencyMs'));
    expect(header.last, 'modelVersion');

    // Both text fields contain commas, so they must arrive quoted; a naive
    // comma split therefore yields 2 extra pieces over the 15 columns.
    final row = lines[1];
    expect(row, contains('"Kumusta, kaibigan"'));
    expect(row, contains('"How are you, friend?"'));
    expect(row.split(',').length, header.length + 2);

    // Correction row carries the FR-5 fields.
    final correction = lines[2];
    expect(correction, contains('50,red,42,1000')); // confidence fields
    expect(correction, endsWith(',true,1,correction,0.1.0,n/a'));
  });

  test('exportSession throws for a session without events', () async {
    final c = makeContainer();
    await logStore.startSession(SessionMeta(
      sessionId: 'S-empty',
      participantId: 'P-001',
      startedAt: DateTime(2026, 9, 9, 10),
    ));
    final controller = c.read(exportControllerProvider.notifier);
    expect(() => controller.exportSession('S-empty'), throwsStateError);
  });

  test('summaries compute event count, mean latency, and % corrected',
      () async {
    final c = makeContainer();
    await logStore.startSession(SessionMeta(
      sessionId: 'S-1',
      participantId: 'P-001',
      startedAt: DateTime(2026, 9, 9, 10),
    ));
    await logStore.appendEvent(sampleEvent(latencyMs: 100));
    await logStore.appendEvent(sampleEvent(wordId: 2, latencyMs: 200));
    await logStore.appendEvent(sampleEvent(
      wordId: 3,
      latencyMs: 300,
      corrected: true,
      originalWordId: 2,
      source: 'correction',
    ));

    // Force the async load to finish before asserting.
    c.read(exportControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    final summaries = c.read(exportControllerProvider).summaries;
    expect(summaries, hasLength(1));
    final s = summaries.single;
    expect(s.eventCount, 3);
    expect(s.meanLatencyMs, 200);
    expect(s.pctCorrected, closeTo(33.3, 0.1));
  });
}
