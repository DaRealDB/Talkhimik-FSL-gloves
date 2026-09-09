import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/constants/app_version.dart';
import '../data/glove/glove_connection.dart';
import '../data/glove/glove_connection_factory.dart';
import '../data/glove/mock_glove_connection.dart';
import '../data/storage/settings_service.dart';
import '../data/tts/flutter_tts_service.dart';
import '../data/tts/tts_service.dart';
import '../data/vocab/default_vocabulary_repository.dart';
import '../domain/repositories/log_store.dart';
import '../domain/repositories/vocabulary_repository.dart';
import 'export_controller.dart';
import 'glove_controller.dart';
import 'settings_controller.dart';
import 'transcript_controller.dart';
import 'tts_controller.dart';

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

final appVersionProvider = Provider<String>((ref) => kAppVersion);

final ttsServiceProvider = Provider<TtsService>((ref) => FlutterTtsService());

final ttsControllerProvider =
    NotifierProvider<TtsController, TtsState>(TtsController.new);

final transcriptControllerProvider =
    NotifierProvider<TranscriptController, TranscriptState>(
        TranscriptController.new);

final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);

/// Where FR-16 CSVs are written; overridden with a temp dir in tests.
final exportDirectoryProvider = Provider<Future<Directory>>((ref) async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/talkhimik_exports');
  await dir.create(recursive: true);
  return dir;
});

final exportControllerProvider =
    NotifierProvider<ExportController, ExportState>(ExportController.new);
