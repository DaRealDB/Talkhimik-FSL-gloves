import 'package:flutter/material.dart';

/// Shared error card for gating failures (no participant id, no consent,
/// etc.) on the calibration and record-mode screens.
class GatingCard extends StatelessWidget {
  const GatingCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        leading: Icon(Icons.warning_amber_rounded,
            color: Theme.of(context).colorScheme.onErrorContainer),
        title: Text(message),
      ),
    );
  }
}
