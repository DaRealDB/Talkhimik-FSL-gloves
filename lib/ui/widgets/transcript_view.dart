import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/strings/app_strings.dart';
import 'transcript_bubble.dart';

/// Scrollable chat-style transcript (SRS FR-3). Auto-scrolls to the newest
/// bubble; tapping a bubble re-reads it through TTS.
class TranscriptView extends ConsumerStatefulWidget {
  const TranscriptView({super.key});

  @override
  ConsumerState<TranscriptView> createState() => _TranscriptViewState();
}

class _TranscriptViewState extends ConsumerState<TranscriptView> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final transcript = ref.watch(transcriptControllerProvider);
    _scrollToBottom();

    if (transcript.entries.isEmpty) {
      return Center(
        child: Text(
          AppStrings.emptyTranscript,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(12),
      itemCount: transcript.entries.length,
      itemBuilder: (context, index) {
        final entry = transcript.entries[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: TranscriptBubble(
            entry: entry,
            language: transcript.language,
            largeText: transcript.largeText,
            onTap: () => ref
                .read(transcriptControllerProvider.notifier)
                .reRead(entry.id),
          ),
        );
      },
    );
  }
}
