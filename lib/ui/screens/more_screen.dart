import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/strings/app_strings.dart';
import '../widgets/demo_controls.dart';

/// "More": grouped glass cards for Calibration, Session logs, and the
/// Developer group (mock demo controls live here — out of the Home
/// prime space — and only while the mock glove is active).
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMock = ref.watch(gloveIsMockProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.moreTab)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.tune_outlined),
              title: const Text(AppStrings.calibrationTitle),
              subtitle: const Text(AppStrings.calibrationPickHand),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pushNamed('/calibration'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('Session logs'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pushNamed('/export'),
            ),
          ),
          if (isMock) ...[
            const SizedBox(height: 24),
            const DemoControls(),
          ],
        ],
      ),
    );
  }
}
