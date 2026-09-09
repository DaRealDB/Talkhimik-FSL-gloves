import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/glove/glove_connection.dart';
import '../data/glove/glove_connection_factory.dart';
import '../data/glove/mock_glove_connection.dart';
import '../data/storage/settings_service.dart';
import '../data/vocab/default_vocabulary_repository.dart';
import '../domain/repositories/log_store.dart';
import '../domain/repositories/vocabulary_repository.dart';
import 'glove_controller.dart';

/// Composition root — every provider in one panel-readable file.
/// Layer rule: ui → application → domain ← data.

final vocabularyRepositoryProvider = Provider<VocabularyRepository>(
  (ref) => DefaultVocabularyRepository(),
);

final settingsServiceProvider = Provider<SettingsService>(
  (ref) => SharedPrefsSettingsService(),
);

/// Real [LogStore] is created by the app bootstrap (main.dart) after Hive
/// init; tests and widget pumps override this with an in-memory store.
final logStoreProvider = Provider<LogStore>(
  (ref) => throw UnimplementedError('logStoreProvider is overridden at '
      'startup (see main.dart) or in tests'),
);

/// One connection instance for the app's lifetime.
final gloveConnectionProvider = Provider<GloveConnection>(
  (ref) => GloveConnectionFactory.create(),
);

/// True when the active connection is the simulated glove — gates the
/// dev-only demo controls.
final gloveIsMockProvider = Provider<bool>(
  (ref) => ref.read(gloveConnectionProvider) is MockGloveConnection,
);

final gloveControllerProvider =
    NotifierProvider<GloveController, GloveState>(GloveController.new);
