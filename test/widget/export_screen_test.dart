import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/application/providers.dart';
import 'package:talkhimik_app/domain/models/log_entry.dart';
import 'package:talkhimik_app/ui/screens/export_screen.dart';

import '../helpers/in_memory_log_store.dart';
import '../helpers/test_overrides.dart';

void main() {
  testWidgets('lists sessions and exports a CSV to disk (FR-16)',
      (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('talkhimik_export_ui_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final logStore = InMemoryLogStore();
    await logStore.startSession(SessionMeta(
      sessionId: 'S-20260909-100000',
      participantId: 'P-007',
      startedAt: DateTime(2026, 9, 9, 10),
    ));
    await logStore.appendEvent(GestureLogEntry(
      participantId: 'P-007',
      sessionId: 'S-20260909-100000',
      wordId: 1,
      filipinoText: 'A',
      englishText: 'A',
      confidence: 95,
      confidenceLevel: 'green',
      latencyMs: 40,
      gloveTimestampMs: 1000,
      receivedAt: DateTime.fromMillisecondsSinceEpoch(1040),
      source: 'glove',
      appVersion: '0.1.0',
    ));

    final container = ProviderContainer(
      overrides: [
        ...testOverrides(logStore: logStore),
        exportDirectoryProvider.overrideWith((ref) async => tempDir),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ExportScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Session tile with the stats preview.
    expect(find.textContaining('S-20260909-100000'), findsOneWidget);
    expect(find.textContaining('P-007'), findsOneWidget);
    expect(find.textContaining('1 events'), findsOneWidget);

    // Export → snackbar reports the path → file exists with the header.
    // The CSV write is real async I/O; runAsync lets it finish (pumpAndSettle
    // alone only advances the fake clock).
    // Drive the button's own handler inside runAsync: the CSV write is real
    // async I/O that the fake test zone can't await, so the handler runs on
    // the real event loop instead. The tap-path equivalence is covered by
    // the key existing on a non-null handler.
    final button = tester.widget<IconButton>(
        find.byKey(ExportScreen.exportButtonKey));
    expect(button.onPressed, isNotNull);
    await tester.runAsync(() async => button.onPressed!());
    await tester.pumpAndSettle();

    expect(
      container.read(exportControllerProvider).lastExportPath,
      isNotNull,
      reason: 'export should have produced a path',
    );
    expect(find.textContaining('Saved to'), findsOneWidget);
    final csv = File('${tempDir.path}/S-20260909-100000.csv');
    expect(csv.existsSync(), isTrue);
    expect(csv.readAsLinesSync().first, startsWith('participantId,sessionId'));
  });
}
