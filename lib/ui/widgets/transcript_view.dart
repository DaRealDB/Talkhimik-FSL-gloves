import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/constants/confidence.dart';
import '../../core/strings/app_strings.dart';
import '../../domain/models/transcript_entry.dart';
import 'anim.dart';
import 'diagonal_slab.dart';
import 'quick_rephrase_sheet.dart';
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
      // Calm empty state: the diagonal slab motif plus one line of
      // guidance (typography & motion pass).
      return Stack(
        children: [
          const Positioned.fill(child: SlabBackdrop()),
          Center(
            child: FadeIn(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  AppStrings.emptyTranscript,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(12),
      itemCount: transcript.entries.length,
      itemBuilder: (context, index) {
        final entry = transcript.entries[index];
        // HERO treatment: the newest entry is the largest text in the
        // app; earlier signs step down in size and fade in opacity.
        final isNewest = index == transcript.entries.length - 1;
        final age = transcript.entries.length - 1 - index;
        final opacity = isNewest ? 1.0 : (age <= 2 ? 0.7 : 0.5);
        return Opacity(
          opacity: opacity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TranscriptBubble(
              entry: entry,
              language: transcript.language,
              largeText: transcript.largeText,
              hero: isNewest && entry.kind == TranscriptKind.signed,
              onTap: () => _onBubbleTap(context, entry),
            ),
          ),
        );
      },
    );
  }

  /// FR-5: low-confidence signed bubbles open the quick-rephrase sheet
  /// (packet alternatives first, vocabulary neighbors as fallback);
  /// everything else re-reads through TTS (FR-3).
  void _onBubbleTap(BuildContext context, TranscriptEntry entry) {
    final isLowConfidence = entry.kind == TranscriptKind.signed &&
        (entry.confidenceLevel == ConfidenceLevel.low ||
            entry.confidenceLevel == ConfidenceLevel.medium);
    if (!isLowConfidence) {
      ref.read(transcriptControllerProvider.notifier).reRead(entry.id);
      return;
    }

    final alternatives = entry.alternatives.isNotEmpty
        ? entry.alternatives
        : ref
            .read(vocabularyRepositoryProvider)
            .fallbackAlternatives(entry.wordId ?? -1);
    QuickRephraseSheet.show(
      context,
      ref,
      entry: entry,
      alternatives: alternatives,
    );
  }
}
