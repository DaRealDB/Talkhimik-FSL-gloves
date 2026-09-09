import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/strings/app_strings.dart';

/// FR-7: the hearing partner types here; the message is shown in the
/// transcript as large signer-facing text (the app's only return channel —
/// FSL→speech stays one-way this iteration, M6).
class ReplyPanel extends ConsumerStatefulWidget {
  const ReplyPanel({super.key});

  @override
  ConsumerState<ReplyPanel> createState() => _ReplyPanelState();
}

class _ReplyPanelState extends ConsumerState<ReplyPanel> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    ref.read(transcriptControllerProvider.notifier).addPartnerMessage(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: AppStrings.replyHint,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: AppStrings.sendReply,
            icon: const Icon(Icons.send),
            onPressed: _send,
          ),
        ],
      ),
    );
  }
}
