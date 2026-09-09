import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'application/providers.dart';
import 'data/glove/glove_connection_factory.dart';
import 'data/storage/hive_log_store.dart';
import 'data/storage/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local persistence (FR-10): Hive boxes for events, the sync queue,
  // participants, and sessions. Pure Dart — same behavior on Windows and
  // Android field devices.
  final appDir = await getApplicationSupportDirectory();
  Hive.init(appDir.path);
  final logStore = HiveLogStore(Hive);
  await logStore.init();

  // FR field-testing aid: the "Force mock" setting swaps the connection at
  // startup (the real BLE client is Android-only anyway).
  final settingsService = SharedPrefsSettingsService();
  final forceMock = await settingsService.forceMock();
  final glove = GloveConnectionFactory.create(forceMock: forceMock);

  final container = ProviderContainer(
    overrides: [
      logStoreProvider.overrideWithValue(logStore),
      gloveConnectionProvider.overrideWithValue(glove),
    ],
  );
  runApp(UncontrolledProviderScope(container: container, child: const TalkhimikApp()));

  // Load TTS settings and initialize the engine without blocking startup.
  container.read(ttsControllerProvider.notifier).initialize();
}
