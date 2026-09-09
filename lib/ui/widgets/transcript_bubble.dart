import 'package:flutter/material.dart';

import '../../domain/models/transcript_entry.dart';
import 'confidence_badge.dart';

/// One chat-style bubble (SRS FR-3): signed entries sit on the left with a
/// confidence badge, partner replies on the right in large signer-facing
/// text (FR-7, NFR-7), system notices centered and muted.
class TranscriptBubble extends StatelessWidget {
  const TranscriptBubble({
    super.key,
    required this.entry,
    required this.language,
    required this.largeText,
    this.onTap,
  });

  final TranscriptEntry entry;
  final String language; // 'fil' | 'en'
  final bool largeText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (entry.kind == TranscriptKind.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          entry.textFor(language),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final isPartner = entry.kind == TranscriptKind.partner;

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isPartner ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(isPartner ? 14 : 3),
          bottomRight: Radius.circular(isPartner ? 3 : 14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            entry.textFor(language),
            style: TextStyle(
              fontSize: isPartner && largeText ? 22 : 16,
              fontWeight: isPartner ? FontWeight.w600 : FontWeight.normal,
              color: scheme.onSurface,
            ),
          ),
          if (entry.corrected) ...[
            const SizedBox(height: 2),
            Text(
              'corrected',
              style: TextStyle(fontSize: 10, color: scheme.outline),
            ),
          ],
        ],
      ),
    );

    final bubbleWithBadge = entry.kind == TranscriptKind.signed &&
            entry.confidence != null &&
            entry.confidenceLevel != null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              bubble,
              const SizedBox(height: 2),
              ConfidenceBadge(
                confidence: entry.confidence!,
                level: entry.confidenceLevel!,
              ),
            ],
          )
        : bubble;

    return Align(
      alignment: isPartner ? Alignment.centerRight : Alignment.centerLeft,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: bubbleWithBadge,
        ),
      ),
    );
  }
}
