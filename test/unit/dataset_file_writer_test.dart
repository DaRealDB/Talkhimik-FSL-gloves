import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/data/dataset/dataset_file_writer.dart';
import 'package:talkhimik_app/domain/models/calibration_table.dart';
import 'package:talkhimik_app/domain/models/dataset_row.dart';
import 'package:talkhimik_app/domain/models/dataset_session.dart';
import 'package:talkhimik_app/domain/models/telemetry_packet.dart';
import 'package:talkhimik_app/domain/sensing/sensor_math.dart';

DatasetSession session({
  int validMask = 0x1F,
  GloveHand hand = GloveHand.left,
}) =>
    DatasetSession(
      sessionId: 'S-1',
      signerId: 'anon-1234',
      hand: hand,
      calibrationId: 3,
      firmwareVersion: '1.2.0',
      validMask: validMask,
      rDiv: const [10000, 10000, 10000, 10000, 10000],
      fingers: [
        for (var i = 0; i < fingerNames.length; i++)
          FingerInfo(
            name: fingerNames[i],
            valid: validMask & (1 << i) != 0,
            weak: false,
            flatOhm: 10000,
            bent90Ohm: 30000,
            flatAdc: 500,
            bent90Adc: 1500,
            spanCounts: 1000,
          ),
      ],
      startedAt: DateTime.fromMillisecondsSinceEpoch(1000000),
    );

DatasetRow row() {
  const raw = [100, 200, 300, 400, 500];
  const rDiv = 10000.0;
  const flat = 10000.0;
  const bent = 30000.0;
  final ohms = [for (final adc in raw) adcToOhms(rDiv, adc)];
  final angles = [for (final o in ohms) ohmsToAngle(o, flat, bent)];
  return DatasetRow(
    timestampMs: 1000,
    label: 'A',
    takeId: 1,
    rawAdc: raw,
    ohms: ohms,
    angles: angles,
    rollDeg: 1.2,
    pitchDeg: -3.4,
    yawDeg: 5.6,
    qualityFlag: 0x1F,
  );
}

void main() {
  late Directory dir;
  late DatasetFileWriter writer;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('talkhimik_dataset_test');
    writer = DatasetFileWriter(() async => dir);
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<String> readCsv(DatasetSession s) async {
    final file = File(
        '${dir.path}/${DatasetFileWriter.fileNameFor(s.hand, s.sessionId, s.calibrationId, sidecar: false)}');
    return file.readAsString();
  }

  test('a CSV without a sidecar gets one rebuilt from the CSV', () async {
    final s = session(validMask: 0x1E); // thumb invalid
    await writer.openSession(s);
    await writer.appendRow(s, row());
    await writer.appendRow(s, row());
    // No closeSession: the app was killed mid-recording.
    expect(await writer.listSessions(), isEmpty);

    expect(await writer.recoverSidecars(), 1);
    final listed = (await writer.listSessions()).single;
    expect(listed.sessionId, s.sessionId);
    expect(listed.rows, 2);
    expect(listed.calibrationId, s.calibrationId);
    final sidecar = jsonDecode(await File('${dir.path}/${listed.sidecarName}')
        .readAsString()) as Map<String, Object?>;
    expect(sidecar['recovered'], isTrue);
    final fingers = sidecar['fingers']! as Map<String, Object?>;
    expect((fingers['thumb']! as Map)['valid'], isFalse);
    expect((fingers['pointer']! as Map)['valid'], isTrue);

    expect(await writer.recoverSidecars(), 0); // idempotent
  });

  test('deleteAll removes every dataset file', () async {
    final s = session();
    await writer.openSession(s);
    await writer.appendRow(s, row());
    await writer.closeSession(s);
    await File('${dir.path}/index.json').writeAsString('{}');
    await writer.deleteAll();
    expect(dir.listSync(), isEmpty);
  });

  test('full valid mask writes the exact §5.2 header on one line', () async {
    final s = session();
    await writer.openSession(s);
    final csv = await readCsv(s);
    expect(csv.trim(), [
      'timestamp_ms,session_id,signer_id,hand,calibration_id,label,take_id,',
      'raw_thumb,raw_pointer,raw_middle,raw_ring,raw_pinky,',
      'ohm_thumb,ohm_pointer,ohm_middle,ohm_ring,ohm_pinky,',
      'ang_thumb,ang_pointer,ang_middle,ang_ring,ang_pinky,',
      'roll,pitch,yaw,quality_flag',
    ].join());
  });

  test('an invalid thumb drops its three columns (master §5.2)', () async {
    final s = session(validMask: 0x1E); // thumb invalid
    await writer.openSession(s);
    final csv = await readCsv(s);
    expect(csv, isNot(contains('raw_thumb')));
    expect(csv, isNot(contains('ohm_thumb')));
    expect(csv, isNot(contains('ang_thumb')));
    expect(csv, contains('raw_pointer'));
  });

  test('appended rows recompute ohm/angle from raw + sidecar r_div', () async {
    final s = session();
    await writer.openSession(s);
    await writer.appendRow(s, row());
    await writer.closeSession(s);
    s.rows = 1;

    final csv = await readCsv(s);
    final lines = csv.trim().split('\r\n');
    expect(lines, hasLength(2));
    final cells = lines[1].split(',');
    // header: 7 meta + 5 raw + 5 ohm + 5 ang + 4 = 26 columns.
    expect(cells, hasLength(26));
    expect(cells[7], '100'); // raw_thumb
    final ohmThumb = double.parse(cells[12]);
    final angThumb = double.parse(cells[17]);

    // Re-derive from raw + sidecar alone (acceptance: master §3).
    final sidecar = jsonDecode(await File(
            '${dir.path}/${DatasetFileWriter.fileNameFor(s.hand, s.sessionId, s.calibrationId, sidecar: true)}')
        .readAsString())
        as Map<String, Object?>;
    final rDiv = sidecar['r_div'] as List;
    final fingers = sidecar['fingers'] as Map<String, Object?>;
    final thumb = fingers['thumb'] as Map<String, Object?>;
    expect(
      adcToOhms((rDiv[0] as num).toDouble(), 100),
      closeTo(ohmThumb, 0.01),
    );
    expect(
      ohmsToAngle(ohmThumb, (thumb['flat_ohm'] as num).toDouble(),
          (thumb['bent90_ohm'] as num).toDouble()),
      closeTo(angThumb, 0.01),
    );
  });

  test('sidecar JSON matches §5.3 exactly (keys and dropped counters)',
      () async {
    final s = session(validMask: 0x1E);
    await writer.openSession(s);
    s.rows = 240;
    s.droppedFrames = 2;
    s.adcRail = 1;
    s.seqGapDrops = 1;
    await writer.closeSession(s);

    final sidecar = jsonDecode(await File(
            '${dir.path}/${DatasetFileWriter.fileNameFor(s.hand, s.sessionId, s.calibrationId, sidecar: true)}')
        .readAsString())
        as Map<String, Object?>;
    expect(sidecar['session_id'], 'S-1');
    expect(sidecar['signer_id'], 'anon-1234');
    expect(sidecar['hand'], 'L');
    expect(sidecar['calibration_id'], 3);
    expect(sidecar['mount_calibration_id'], isNull); // fw 1.2.0 session
    expect(sidecar['roll_note'], contains('sin/cos(roll)'));
    expect(sidecar['sample_rate_hz'], 5);
    expect(sidecar['firmware_version'], '1.2.0');
    expect(sidecar['rows'], 240);
    expect(sidecar['dropped_frames'], 2);
    expect(sidecar['dropped'], {'adcRail': 1, 'seqGap': 1});
    final fingers = sidecar['fingers'] as Map<String, Object?>;
    expect(fingers.keys, containsAll(fingerNames));
    expect((fingers['thumb'] as Map)['valid'], false); // documents the gap
    expect((fingers['pointer'] as Map)['valid'], true);
  });

  test('listSessions rebuilds newest-first summaries with sizes', () async {
    final s = session();
    await writer.openSession(s);
    await writer.appendRow(s, row());
    await writer.closeSession(s);
    s.rows = 1;

    final sessions = await writer.listSessions();
    expect(sessions, hasLength(1));
    expect(sessions.single.sessionId, 'S-1');
    expect(sessions.single.hand, GloveHand.left);
    expect(sessions.single.rows, 0); // sidecar holds the on-close rows
    expect(sessions.single.csvName, 'talkhimik_L_S-1_cal3.csv');
    expect(sessions.single.sidecarName, 'talkhimik_L_S-1_cal3_sidecar.json');
  });
}
