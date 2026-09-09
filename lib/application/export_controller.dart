import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/csv_exporter.dart';
import '../domain/models/log_entry.dart';
import 'providers.dart';

/// One session's export-ready summary (FR-16).
class SessionSummary {
  const SessionSummary({
    required this.session,
    required this.eventCount,
    required this.meanLatencyMs,
    required this.pctCorrected,
  });

  final SessionMeta session;
  final int eventCount;
  final int meanLatencyMs;
  final double pctCorrected;
}

class ExportState {
  const ExportState({
    this.summaries = const [],
    this.lastExportPath,
    this.loaded = false,
  });

  final List<SessionSummary> summaries;
  final String? lastExportPath;
  final bool loaded;

  ExportState copyWith({
    List<SessionSummary>? summaries,
    String? lastExportPath,
    bool? loaded,
  }) =>
      ExportState(
        summaries: summaries ?? this.summaries,
        lastExportPath: lastExportPath,
        loaded: loaded ?? this.loaded,
      );
}

/// FR-16: session listing and one-tap CSV export, ready for the analysis
/// plan (95% CIs, Cohen's Kappa, Likert means — M5).
class ExportController extends Notifier<ExportState> {
  @override
  ExportState build() {
    _load();
    return const ExportState();
  }

  Future<void> _load() async {
    final store = ref.read(logStoreProvider);
    final sessions = await store.sessions();
    final summaries = <SessionSummary>[];
    for (final session in sessions) {
      final events = await store.eventsForSession(session.sessionId);
      if (events.isEmpty) continue;
      summaries.add(SessionSummary(
        session: session,
        eventCount: events.length,
        meanLatencyMs: events.isEmpty
            ? 0
            : (events.map((e) => e.latencyMs).reduce((a, b) => a + b) /
                    events.length)
                .round(),
        pctCorrected: events.isEmpty
            ? 0
            : events.where((e) => e.corrected).length / events.length * 100,
      ));
    }
    state = state.copyWith(summaries: summaries, loaded: true);
  }

  /// Writes `talkhimik_exports/S-….csv` and returns the path.
  Future<String> exportSession(String sessionId) async {
    final events = await ref.read(logStoreProvider).eventsForSession(sessionId);
    if (events.isEmpty) {
      throw StateError('No events recorded for session $sessionId');
    }
    final csv = CsvExporter.toCsv([
      _header,
      for (final e in events) _row(e),
    ]);

    final dir = await ref.read(exportDirectoryProvider);
    final file = File('${dir.path}/$sessionId.csv');
    await file.writeAsString(csv);

    state = state.copyWith(lastExportPath: file.path);
    return file.path;
  }

  /// Column order mirrors GestureLogEntry 1:1 (the FR-10 schema).
  static const _header = [
    'participantId',
    'sessionId',
    'wordId',
    'filipinoText',
    'englishText',
    'confidence',
    'confidenceLevel',
    'latencyMs',
    'gloveTimestampMs',
    'receivedAt',
    'corrected',
    'originalWordId',
    'source',
    'appVersion',
    'modelVersion',
  ];

  static List<String> _row(GestureLogEntry e) => [
        e.participantId,
        e.sessionId,
        '${e.wordId}',
        e.filipinoText,
        e.englishText,
        '${e.confidence}',
        e.confidenceLevel,
        '${e.latencyMs}',
        '${e.gloveTimestampMs}',
        e.receivedAt.toIso8601String(),
        '${e.corrected}',
        '${e.originalWordId ?? ''}',
        e.source,
        e.appVersion,
        e.modelVersion,
      ];
}
