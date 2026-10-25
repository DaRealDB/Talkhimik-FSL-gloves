import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:talkhimik_app/data/storage/hive_log_store.dart';
import 'package:talkhimik_app/domain/models/log_entry.dart';

GestureLogEntry sampleEntry({
  String participantId = 'P-001',
  String sessionId = 'S-1',
  int wordId = 1,
}) =>
    GestureLogEntry(
      participantId: participantId,
      sessionId: sessionId,
      wordId: wordId,
      filipinoText: 'A',
      englishText: 'A',
      confidence: 95,
      confidenceLevel: 'green',
      latencyMs: 42,
      gloveTimestampMs: 1000,
      receivedAt: DateTime.fromMillisecondsSinceEpoch(1042),
      source: 'glove',
      appVersion: '0.0.1',
    );

void main() {
  late Directory tempDir;
  late HiveLogStore store;
  var boxCounter = 0;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('talkhimik_hive_');
    Hive.init(tempDir.path);
    store = HiveLogStore(Hive, boxPrefix: 't${boxCounter++}_');
    await store.init();
  });

  tearDown(() async {
    await store.close();
    await Hive.deleteFromDisk();
    tempDir.deleteSync(recursive: true);
  });

  test('appendEvent assigns an id and queues the event for sync', () async {
    final stored = await store.appendEvent(sampleEntry());

    expect(stored.id, isNotNull);
    final pending = await store.pendingSyncs();
    expect(pending, hasLength(1));
    expect(pending.single.logEntryId, stored.id);
  });

  test('events round-trip all fields through the adapter', () async {
    final original = sampleEntry(participantId: 'P-007', wordId: 100)
        // copy with corrected + originalWordId set
        ;
    final corrected = GestureLogEntry(
      participantId: original.participantId,
      sessionId: original.sessionId,
      wordId: 101,
      filipinoText: 'Magandang umaga',
      englishText: 'Good morning',
      confidence: original.confidence,
      confidenceLevel: original.confidenceLevel,
      latencyMs: original.latencyMs,
      gloveTimestampMs: original.gloveTimestampMs,
      receivedAt: original.receivedAt,
      corrected: true,
      originalWordId: 100,
      source: 'correction',
      appVersion: original.appVersion,
    );

    final stored = await store.appendEvent(corrected);
    final readBack = await store.eventsForSession('S-1');

    expect(readBack, hasLength(1));
    final e = readBack.single;
    expect(e.id, stored.id);
    expect(e.participantId, 'P-007');
    expect(e.wordId, 101);
    expect(e.corrected, isTrue);
    expect(e.originalWordId, 100);
    expect(e.source, 'correction');
    expect(e.receivedAt, original.receivedAt);
  });

  test('eventsForSession filters by session and sorts by receipt time',
      () async {
    await store.appendEvent(sampleEntry(sessionId: 'S-A', wordId: 1));
    await store.appendEvent(sampleEntry(sessionId: 'S-B', wordId: 2));
    final later = sampleEntry(sessionId: 'S-A', wordId: 3);
    await store.appendEvent(
      GestureLogEntry(
        participantId: later.participantId,
        sessionId: later.sessionId,
        wordId: later.wordId,
        filipinoText: later.filipinoText,
        englishText: later.englishText,
        confidence: later.confidence,
        confidenceLevel: later.confidenceLevel,
        latencyMs: later.latencyMs,
        gloveTimestampMs: later.gloveTimestampMs,
        receivedAt: later.receivedAt.add(const Duration(seconds: 5)),
        source: later.source,
        appVersion: later.appVersion,
      ),
    );

    final a = await store.eventsForSession('S-A');
    expect(a, hasLength(2));
    expect(a.first.wordId, 1);
    expect(a.last.wordId, 3);
  });

  test('sessions are stored and returned newest first', () async {
    final t0 = DateTime(2026, 9, 9, 10);
    await store.startSession(
        SessionMeta(sessionId: 'S-1', participantId: 'P-1', startedAt: t0));
    await store.startSession(SessionMeta(
        sessionId: 'S-2',
        participantId: 'P-1',
        startedAt: t0.add(const Duration(minutes: 5))));

    final sessions = await store.sessions();
    expect(sessions.map((s) => s.sessionId), ['S-2', 'S-1']);
  });

  test('markSynced removes only the marked queue entries', () async {
    final e1 = await store.appendEvent(sampleEntry(wordId: 1));
    final e2 = await store.appendEvent(sampleEntry(wordId: 2));
    expect(await store.pendingSyncs(), hasLength(2));

    final pending = await store.pendingSyncs();
    await store.markSynced([pending.first.id!]);

    final remaining = await store.pendingSyncs();
    expect(remaining, hasLength(1));
    expect(remaining.single.logEntryId, isNot(e1.id));
    expect(remaining.single.logEntryId, e2.id);
  });
}
