import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'application/providers.dart';
import 'data/storage/hive_log_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local persistence (FR-10): Hive boxes for events, the sync queue,
  // participants, and sessions. Pure Dart — same behavior on Windows and
  // Android field devices.
  final appDir = await getApplicationSupportDirectory();
  Hive.init(appDir.path);
  final logStore = HiveLogStore(Hive);
  await logStore.init();

  final container = ProviderContainer(
    overrides: [
      logStoreProvider.overrideWithValue(logStore),
    ],
  );
  runApp(UncontrolledProviderScope(container: container, child: const TalkhimikApp()));

  // Load TTS settings and initialize the engine without blocking startup.
  container.read(ttsControllerProvider.notifier).initialize();
}
