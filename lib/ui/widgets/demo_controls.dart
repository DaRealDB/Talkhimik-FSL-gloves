import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/glove_controller.dart';
import '../../application/providers.dart';
import '../../core/strings/app_strings.dart';
import '../../data/glove/glove_connection.dart';
import '../../data/glove/mock_glove_connection.dart';
import '../../domain/vocab/vocab_entry.dart';

/// Dev-only panel for driving the mock glove: scenarios, single gestures,
/// link drop/reconnect, and app commands. Hidden entirely when the real
/// glove is active (gloveIsMockProvider is false on Android).
class DemoControls extends ConsumerStatefulWidget {
  const DemoControls({super.key});

  @override
  ConsumerState<DemoControls> createState() => _DemoControlsState();
}

class _DemoControlsState extends ConsumerState<DemoControls> {
  int _selectedWordId = 1;

  @override
  Widget build(BuildContext context) {
    final isMock = ref.watch(gloveIsMockProvider);
    if (!isMock) return const SizedBox.shrink();

    final mock = ref.read(gloveConnectionProvider) as MockGloveConnection;
    final vocab = ref.read(vocabularyRepositoryProvider);
    final allEntries = [...vocab.letters, ...vocab.phrases];
    final controller = ref.read(gloveControllerProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.demoControlsTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final scenario in MockScenario.values)
                  OutlinedButton(
                    onPressed: () => mock.startScenario(scenario),
                    child: Text(scenario.label),
                  ),
                OutlinedButton(
                  onPressed: mock.stopScenario,
                  child: const Text(AppStrings.stopScenario),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedWordId,
                    decoration: const InputDecoration(
                      labelText: 'Word',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    items: [
                      for (final e in allEntries)
                        DropdownMenuItem(
                          value: e.wordId,
                          child: Text(
                            '${e.wordId}: ${e.filipino} '
                            '(${_categoryLabel(e.category)})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _selectedWordId = v ?? 1),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () => mock.emitGesture(
                    wordId: _selectedWordId,
                    confidence: 95,
                  ),
                  child: const Text(AppStrings.emitHigh),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => mock.emitGesture(
                    wordId: _selectedWordId,
                    confidence: 50,
                    alternatives:
                        vocab.fallbackAlternatives(_selectedWordId),
                  ),
                  child: const Text(AppStrings.emitLow),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.link, size: 16),
                  onPressed: () => controller.connect(),
                  label: const Text(AppStrings.connect),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.link_off, size: 16),
                  onPressed: () => controller.disconnect(),
                  label: const Text(AppStrings.disconnect),
                ),
                for (final command in AppCommand.values)
                  OutlinedButton(
                    onPressed: () => mock.sendCommand(command),
                    child: Text('${AppStrings.commandPrefix} '
                        '${command.name}'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _categoryLabel(VocabCategory category) =>
      category == VocabCategory.letter ? 'letter' : 'phrase';
}
