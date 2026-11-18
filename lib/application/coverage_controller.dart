import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dataset/coverage_index.dart';
import '../domain/vocab/vocab_entry.dart';
import 'providers.dart';

/// What the "Dataset coverage" card renders (C2).
class CoverageState {
  const CoverageState({this.index, this.loaded = false});

  final CoverageIndex? index;
  final bool loaded;

  /// 28 letters + REST, in picker order (REST last).
  List<String> targetLabels(List<VocabEntry> letters) => [
        for (final e in letters) e.filipino,
        restLabel,
      ];

  /// "X of Y letters ready": targets excluding J/Z at ok takes or more.
  int readyCount(List<VocabEntry> letters) =>
      index?.readyCount(targetLabels(letters)) ?? 0;

  CoverageState copyWith({CoverageIndex? index, bool? loaded}) => CoverageState(
        index: index ?? this.index,
        loaded: loaded ?? this.loaded,
      );
}

/// Owns the coverage index lifecycle: loads it at startup and rebuilds it
/// when the recorder's data changes (take stops, sessions added/deleted).
/// The recorder never touches the index directly.
class CoverageController extends Notifier<CoverageState> {
  @override
  CoverageState build() {
    ref.listen(datasetRecorderControllerProvider, (prev, next) {
      final takeStopped = (prev?.takeActive ?? false) && !next.takeActive;
      final sessionsChanged =
          prev?.sessions.length != next.sessions.length;
      final rowsRemoved = prev?.revision != next.revision;
      if (takeStopped || sessionsChanged || rowsRemoved) {
        unawaited(_rebuild());
      }
    });
    _load();
    return const CoverageState();
  }

  Future<void> _load() async {
    try {
      final index = await ref.read(coverageIndexStoreProvider).load();
      if (!ref.mounted) return;
      state = state.copyWith(index: index, loaded: true);
    } catch (_) {
      // Directory unavailable (web): the card renders empty — never crash.
    }
  }

  Future<void> _rebuild() async {
    try {
      final index = await ref.read(coverageIndexStoreProvider).rebuild();
      if (!ref.mounted) return;
      state = state.copyWith(index: index, loaded: true);
    } catch (_) {
      // Same graceful degradation as _load.
    }
  }
}
