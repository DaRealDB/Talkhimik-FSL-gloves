import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/export_controller.dart';
import '../../application/providers.dart';

/// FR-16: sessions grouped by participant, with per-session CSV export and
/// an on-screen stats preview (count, mean latency, % corrected).
class ExportScreen extends ConsumerWidget {
  const ExportScreen({super.key});

  static const exportButtonKey = Key('export-session-button');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exportControllerProvider);
    final controller = ref.read(exportControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Session logs')),
      body: state.summaries.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No sessions yet. Recognized gestures appear here once '
                  'logging starts.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final summary in state.summaries)
                  Card(
                    child: ListTile(
                      title: Text('${summary.session.sessionId}'),
                      subtitle: Text(
                        'Participant ${summary.session.participantId} · '
                        '${summary.eventCount} events · '
                        'mean latency ${summary.meanLatencyMs} ms · '
                        '${summary.pctCorrected.toStringAsFixed(0)}% corrected',
                      ),
                      trailing: IconButton(
                        key: exportButtonKey,
                        icon: const Icon(Icons.download_outlined),
                        tooltip: 'Export CSV',
                        onPressed: () async {
                          final path = await controller
                              .exportSession(summary.session.sessionId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Saved to $path')),
                            );
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
