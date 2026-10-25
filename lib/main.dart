import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'application/providers.dart';
import 'application/settings_controller.dart';
import 'data/storage/hive_log_store.dart';
import 'data/storage/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local persistence (FR-10): Hive boxes for events, the sync queue,
  // participants, and sessions. Pure Dart — same behavior on Windows and
  // Android field devices. On web Hive uses IndexedDB and ignores the path
  // (path_provider has no web implementation), so skip the lookup there.
  final appDir = kIsWeb ? '' : (await getApplicationSupportDirectory()).path;
  Hive.init(appDir);
  final logStore = HiveLogStore(Hive);
  await logStore.init();

  // FR field-testing aid: the "Force mock" setting swaps each glove's
  // connection class (provider-driven, live-swappable — see providers.dart).
  // The flag is preloaded here so startup has no flicker; from then on the
  // Settings toggle swaps connections without a restart.
  final settingsService = SharedPrefsSettingsService();
  final forceMock = await settingsService.forceMock();

  final container = ProviderContainer(
    overrides: [
      logStoreProvider.overrideWithValue(logStore),
      forceMockProvider
          .overrideWith(() => ForceMockController(initial: forceMock)),
    ],
  );
  runApp(UncontrolledProviderScope(container: container, child: const TalkhimikApp()));

  // Load TTS settings and initialize the engine without blocking startup.
  container.read(ttsControllerProvider.notifier).initialize();
}
